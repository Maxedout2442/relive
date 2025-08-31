plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // more standard alias for kotlin-android
    id("dev.flutter.flutter-gradle-plugin")

    // Firebase Google Services plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.relive"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.relive"   // ✅ Fixed
        minSdk = flutter.minSdkVersion         // ✅ Fixed
        targetSdk = flutter.targetSdkVersion   // ✅ Fixed
        versionCode = flutter.versionCode      // ✅ Fixed
        versionName = flutter.versionName      // ✅ Fixed
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BOM (ensures all versions stay in sync)
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))

    // Add the Firebase SDKs you need
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")
}
