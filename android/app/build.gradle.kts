plugins {
    id("com.android.application")
    kotlin("android")
}

android {
    compileSdk = 34

    defaultConfig {
        applicationId = "com.android.niddepoulet"  // ⚠️ doit correspondre au google-services.json
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        getByName("release") {
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
