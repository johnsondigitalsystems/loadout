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
        // Generate `BuildConfig` so the Settings screen can pull
        // `versionName` / `versionCode` straight from Gradle. AGP 8
        // disables this by default; without it `BuildConfig` doesn't
        // exist as a generated class.
        buildConfig = true
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

    // Foundation supplies the `HorizontalPager` we use for the four-page
    // navigation root. Wear OS Compose 1.3.x doesn't yet ship a watch-
    // specific pager, so we use the foundation pager paired with Wear's
    // `HorizontalPageIndicator` (in compose-material).
    implementation("androidx.compose.foundation:foundation")

    // Compose for Wear OS — the wear.compose.* artifacts are distinct from
    // the regular androidx.compose.material.* set. Don't mix them.
    implementation("androidx.wear.compose:compose-material:1.3.1")
    implementation("androidx.wear.compose:compose-foundation:1.3.1")
    implementation("androidx.wear.compose:compose-navigation:1.3.1")

    // Lifecycle for `ViewModel` + `viewModelScope`. Both `MotionDetector`
    // and `TimerEngine` extend ViewModel; the engine launches a
    // 1-Hz coroutine on `viewModelScope`. Without this dependency
    // explicitly listed we'd be relying on a transitive pull from
    // `activity-compose`, which can shift versions on Compose BOM bumps.
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.8.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.0")

    // Phone <-> watch transport. Required for `MessageClient`,
    // `DataClient`, and `CapabilityClient`.
    implementation("com.google.android.gms:play-services-wearable:18.2.0")

    // Tooling-only deps so previews work in Android Studio.
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // ----- Tests -----
    // JVM unit tests — `TimerEngine`, `MotionDetector`, payload parsers,
    // `WatchAppState`. Robolectric handles the SharedPreferences /
    // Vibrator / SensorManager seams without a connected device.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.12.2")
    testImplementation("androidx.test:core:1.5.0")
    testImplementation("androidx.test.ext:junit:1.1.5")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")

    // Compose UI tests for the navigation root. Run via
    // `./gradlew :wear:connectedDebugAndroidTest`.
    //
    // The BOM applies in `androidTestImplementation` configurations
    // too, but Gradle picks up the version override from the
    // `platform(...)` declaration only when it's listed in the same
    // configuration. We re-add it here so `ui-test-junit4` resolves
    // to the BOM-pinned version.
    androidTestImplementation(platform("androidx.compose:compose-bom:2024.06.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}

// JVM unit tests (Robolectric needs the Android resources unpacked).
// Without this block the `:wear:test` task can't see the manifest /
// resource references that ViewModel-based engines pull in.
android.testOptions {
    unitTests {
        isIncludeAndroidResources = true
    }
}
