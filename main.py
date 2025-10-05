# main.py
import os
import uuid
import shutil
import subprocess
import logging
from pathlib import Path
from typing import Dict, Any

from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks, Query
from pydantic import BaseModel
from dotenv import load_dotenv

import cloudinary
import cloudinary.uploader
import cloudinary.api

from scenedetect import VideoManager, SceneManager, open_video
from scenedetect.detectors import ContentDetector
from faster_whisper import WhisperModel
import soundfile as sf
import numpy as np


# ---------------------------
# Load config / env
# ---------------------------
load_dotenv()

CLOUD_NAME = os.getenv("CLOUDINARY_CLOUD_NAME")
CLOUD_API_KEY = os.getenv("CLOUDINARY_API_KEY")
CLOUD_API_SECRET = os.getenv("CLOUDINARY_API_SECRET")
UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR", "uploads"))
MAX_HIGHLIGHTS = int(os.getenv("MAX_HIGHLIGHTS", "5"))
WHISPER_MODEL_NAME = os.getenv("WHISPER_MODEL", "small")
EXCITING_KEYWORDS = set(os.getenv("EXCITING_KEYWORDS",
                                  "wow,amazing,yes,goal,great,important,incredible,awesome"
                                  ).split(","))

# New: configurable minimum clip settings
MIN_CLIP_LENGTH = float(os.getenv("MIN_CLIP_LENGTH", "20.0"))  # seconds
MIN_SCENE_SKIP = float(os.getenv("MIN_SCENE_SKIP", "3.0"))     # skip scenes shorter than this

# Subprocess timeouts (seconds)
CURL_TIMEOUT = int(os.getenv("CURL_TIMEOUT", "60"))
FFMPEG_TIMEOUT = int(os.getenv("FFMPEG_TIMEOUT", "60"))
FFPROBE_TIMEOUT = int(os.getenv("FFPROBE_TIMEOUT", "30"))

if not (CLOUD_NAME and CLOUD_API_KEY and CLOUD_API_SECRET):
    raise RuntimeError("Cloudinary credentials not set in environment variables (.env).")

cloudinary.config(
    cloud_name=CLOUD_NAME,
    api_key=CLOUD_API_KEY,
    api_secret=CLOUD_API_SECRET
)

UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------
# Logging
# ---------------------------
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("relive-backend")

# ---------------------------
# Load Whisper model globally
# ---------------------------
logger.info("Loading Whisper model: %s", WHISPER_MODEL_NAME)
model = WhisperModel(WHISPER_MODEL_NAME, device="cpu", compute_type="int8")

# ---------------------------
# In-memory task store (replace with Redis/DB for production)
# ---------------------------
TASKS: Dict[str, Dict[str, Any]] = {}

# ---------------------------
# Helpers
# ---------------------------
def safe_run(cmd, timeout=None):
    logger.debug("Running command: %s", " ".join(cmd))
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=timeout)
    return res.stdout.decode(errors="ignore"), res.stderr.decode(errors="ignore")

def compute_loudness(audio_path: str) -> float:
    try:
        data, sr = sf.read(audio_path)
        if data is None or data.size == 0:
            return -100.0
        if data.ndim > 1:
            data = np.mean(data, axis=1)
        rms = np.sqrt(np.mean(np.square(data.astype(float))))
        db = 20 * np.log10(rms + 1e-9)
        return float(db)
    except Exception as e:
        logger.exception("compute_loudness failed: %s", e)
        return -100.0

def cleanup_task_files(task_id: str):
    try:
        for f in UPLOAD_DIR.glob(f"*{task_id}*"):
            try:
                f.unlink()
            except Exception:
                if f.is_dir():
                    shutil.rmtree(f, ignore_errors=True)
    except Exception as e:
        logger.warning("cleanup_task_files error for %s: %s", task_id, e)

# ---------------------------
# FastAPI app
# ---------------------------
app = FastAPI(title="Relive AI Backend")

@app.post("/upload-video/")
async def upload_video(file: UploadFile = File(...)):
    filename = file.filename or f"upload_{uuid.uuid4().hex}.mp4"
    safe_name = f"{uuid.uuid4().hex}_{filename}"
    out_path = UPLOAD_DIR / safe_name
    with out_path.open("wb") as f:
        f.write(await file.read())
    logger.info("Uploaded file saved to %s", out_path)
    return {"file_path": str(out_path)}

class VideoRequest(BaseModel):
    video_url: str

@app.post("/process-video")
async def process_video(req: VideoRequest, background_tasks: BackgroundTasks):
    video_url = req.video_url.strip()
    if not video_url:
        raise HTTPException(status_code=400, detail="Invalid video_url")

    task_id = uuid.uuid4().hex
    TASKS[task_id] = {"status": "Queued", "progress": 0, "highlights": []}
    background_tasks.add_task(run_processing, video_url, task_id)
    logger.info("Queued processing task %s for %s", task_id, video_url)
    return {"task_id": task_id}

@app.get("/status/{task_id}")
async def get_status(task_id: str):
    return TASKS.get(task_id, {"error": "Invalid task_id"})


# 🟢 UPDATED ENDPOINT: list recent Cloudinary uploads (with created_at)
@app.get("/list-uploads/")
async def list_uploads():
    try:
        # Fetch latest 30 uploaded videos
        resources = cloudinary.api.resources(
            resource_type="video",
            type="upload",
            max_results=30,
            direction="desc"
        )

        if "resources" not in resources or not resources["resources"]:
            return {"uploads": []}

        uploads = [
            {
                "public_id": r["public_id"],
                "url": r["secure_url"],
                "created_at": r.get("created_at", "")
            }
            for r in resources["resources"]
        ]

        return {"uploads": uploads}

    except cloudinary.exceptions.Error as e:
        logger.exception("Cloudinary API error: %s", e)
        raise HTTPException(status_code=502, detail="Cloudinary API failure")
    except Exception as e:
        logger.exception("list_uploads failed: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/delete-upload/")
async def delete_upload(public_id: str = Query(...)):
    try:
        result = cloudinary.uploader.destroy(public_id, resource_type="video")
        if result.get("result") != "ok":
            raise HTTPException(status_code=400, detail=f"Delete failed: {result}")
        return {"status": "success", "public_id": public_id}
    except Exception as e:
        logger.exception("delete_upload failed")
        raise HTTPException(status_code=500, detail=str(e))

# ---------------------------
# Core processing logic
# ---------------------------
def run_processing(video_url: str, task_id: str):
    task = TASKS.get(task_id)
    if task is None:
        logger.error("run_processing called with unknown task_id %s", task_id)
        return

    tmp_prefix = f"task_{task_id}"
    local_path = UPLOAD_DIR / f"{tmp_prefix}.mp4"

    try:
        TASKS[task_id]["status"] = "Downloading video"
        TASKS[task_id]["progress"] = 5
        logger.info("[%s] Downloading %s", task_id, video_url)

        try:
            safe_run(["curl", "-L", "-o", str(local_path), video_url], timeout=CURL_TIMEOUT)
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Failed to download video: {e.stderr if hasattr(e,'stderr') else e}")

        TASKS[task_id]["status"] = "Detecting scenes"
        TASKS[task_id]["progress"] = 20
        logger.info("[%s] Detecting scenes", task_id)

        try:
            video_manager = VideoManager([str(local_path)])
            scene_manager = SceneManager()
            scene_manager.add_detector(ContentDetector(threshold=10.0))
            video_manager.set_downscale_factor()
            video_manager.start()
            scene_manager.detect_scenes(frame_source=video_manager)
            scene_list = scene_manager.get_scene_list()
            video_manager.release()
        except Exception as e:
            logger.exception("Scene detection failed, falling back to fixed segments: %s", e)
            scene_list = []

        # 🟣 NEW PART: get total_duration and enforce min clip length
        try:
            out, _ = safe_run([
                "ffprobe", "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                str(local_path)
            ], timeout=FFPROBE_TIMEOUT)
            total_duration = float(out.strip())
        except Exception:
            total_duration = 0.0

        if not scene_list:
            scene_list = []
            start = 0.0
            while start < total_duration:
                end = min(start + 20.0, total_duration)
                scene_list.append((start, end))
                start += 20.0

        clips = []
        total_scenes = len(scene_list) if scene_list else 0
        logger.info("[%s] Found %d scene(s)", task_id, total_scenes)

        for i, scene in enumerate(scene_list, start=1):
            TASKS[task_id]["status"] = f"Processing scene {i}/{total_scenes}"
            TASKS[task_id]["progress"] = min(20 + int((i / max(1,total_scenes)) * 60), 90)

            if hasattr(scene[0], "get_seconds"):
                start_time = float(scene[0].get_seconds())
                end_time = float(scene[1].get_seconds())
            else:
                start_time = float(scene[0])
                end_time = float(scene[1])

            if total_duration > 0:
                start_time = max(0.0, min(start_time, total_duration))
                end_time = max(0.0, min(end_time, total_duration))

            duration = end_time - start_time
            logger.debug("[%s] Scene %d: %.2f -> %.2f (%.2fs)", task_id, i, start_time, end_time, duration)

            # Skip ultra-short scenes
            if duration < MIN_SCENE_SKIP:
                logger.debug("[%s] Skipping short scene %d (%.2fs)", task_id, i, duration)
                continue

            # Extend short clips to MIN_CLIP_LENGTH
            if duration < MIN_CLIP_LENGTH:
                new_end = min(start_time + MIN_CLIP_LENGTH, total_duration if total_duration > 0 else (end_time + (MIN_CLIP_LENGTH - duration)))
                if new_end > end_time:
                    logger.debug("[%s] Extending scene %d from %.2fs to %.2fs (min_length)", task_id, i, duration, new_end - start_time)
                    end_time = new_end
                    duration = end_time - start_time
                if duration < MIN_SCENE_SKIP:
                    logger.debug("[%s] Scene %d still too short (%.2fs) after extension, skipping", task_id, i, duration)
                    continue

            clip_name = f"clip_{i}_{tmp_prefix}.mp4"
            clip_path = UPLOAD_DIR / clip_name

            try:
                safe_run([
                    "ffmpeg", "-y", "-i", str(local_path),
                    "-ss", str(start_time), "-t", str(duration),
                    "-c", "copy", str(clip_path)
                ], timeout=FFMPEG_TIMEOUT)
            except subprocess.CalledProcessError:
                logger.info("[%s] ffmpeg copy failed for scene %d, falling back to re-encode", task_id, i)
                safe_run([
                    "ffmpeg", "-y", "-i", str(local_path),
                    "-ss", str(start_time), "-t", str(duration),
                    "-c:v", "libx264", "-c:a", "aac", str(clip_path)
                ], timeout=FFMPEG_TIMEOUT)

            try:
                segments, _ = model.transcribe(str(clip_path))
                transcript = " ".join([seg.text for seg in segments]) if segments else ""
            except Exception as e:
                logger.exception("[%s] Whisper transcription failed for clip %d: %s", task_id, i, e)
                transcript = ""

            audio_path = clip_path.with_suffix(".wav")
            try:
                safe_run(["ffmpeg", "-y", "-i", str(clip_path), "-q:a", "0", "-map", "a", str(audio_path)], timeout=FFMPEG_TIMEOUT)
                loudness_db = compute_loudness(str(audio_path))
            except Exception:
                logger.exception("[%s] Audio extraction/loudness failed for clip %d", task_id, i)
                loudness_db = -100.0

            audio_score = max(0.0, 100.0 + float(loudness_db))
            keyword_score = sum(1 for word in transcript.lower().split() if word in EXCITING_KEYWORDS)
            total_score = audio_score + (keyword_score * 10)

            try:
                upload_result = cloudinary.uploader.upload(str(clip_path), resource_type="video")
                clip_url = upload_result.get("secure_url") or upload_result.get("url")
            except Exception as e:
                logger.exception("[%s] Cloudinary upload failed for clip %d: %s", task_id, i, e)
                clip_url = None

            clip_info = {
                "scene": i,
                "start_time": start_time,
                "end_time": end_time,
                "duration": duration,
                "url": clip_url,
                "transcript": transcript.strip(),
                "score": float(total_score)
            }
            clips.append(clip_info)

            try:
                if audio_path.exists():
                    audio_path.unlink()
            except Exception:
                pass

        clips = [c for c in clips if c.get("url")]
        clips = sorted(clips, key=lambda x: x.get("score", 0.0), reverse=True)
        highlights = clips[:MAX_HIGHLIGHTS]

        TASKS[task_id]["status"] = "Completed"
        TASKS[task_id]["progress"] = 100
        TASKS[task_id]["highlights"] = highlights
        logger.info("[%s] Processing completed, highlights: %d", task_id, len(highlights))

    except Exception as e:
        logger.exception("Processing error for task %s: %s", task_id, e)
        TASKS[task_id]["status"] = f"Error: {str(e)}"
        TASKS[task_id]["progress"] = 100
        TASKS[task_id]["highlights"] = []
    finally:
        try:
            cleanup_task_files(task_id)
            if local_path.exists():
                local_path.unlink()
        except Exception as e:
            logger.warning("Final cleanup error for %s: %s", task_id, e)
