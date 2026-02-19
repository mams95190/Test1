plugins {
    id("com.android.application")
    kotlin("android")
    id("com.google.gms.google-services") // <-- IMPORTANT: Google Services
}

android {
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.nid_poule_app"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.0")
    implementation("androidx.core:core-ktx:1.10.1")
}
