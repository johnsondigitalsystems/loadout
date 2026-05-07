plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.johnsondigital.loadout.wear"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.johnsondigital.loadout.wear"
        // Wear OS 3 (Android 11 / API 30) is the practical floor for new Compose
        // for Wear apps. Going lower forces the legacy Wear support library and
        // Compose for Wear OS will not be available.
        minSdk = 30
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        compose = true
    }

    buildTypes {
        release {
            // Mirrors the phone module — the debug keystore is used for the
            // moment so `./gradlew :wear:assembleRelease` works during local
            // development. Replace this with the real release signing config
            // before any Play Console upload.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // Compose BOM keeps the various compose artifacts on a single
    // compatible release. Bump the BOM, not individual versions.
    val composeBom = platform("androidx.compose:compose-bom:2024.06.00")
    implementation(composeBom)

    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.0")

    // Compose for Wear OS — the wear.compose.* artifacts are distinct from
    // the regular androidx.compose.material.* set. Don't mix them.
    implementation("androidx.wear.compose:compose-material:1.3.1")
    implementation("androidx.wear.compose:compose-foundation:1.3.1")
    implementation("androidx.wear.compose:compose-navigation:1.3.1")

    // Phone <-> watch transport. Pulled in eagerly so the scaffolding
    // already compiles against the API even though we don't open a
    // listener yet.
    implementation("com.google.android.gms:play-services-wearable:18.2.0")

    // Tooling-only deps so previews work in Android Studio.
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
