import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load android/key.properties if it exists. This file is .gitignore'd and
// holds the release keystore passwords + alias. When it is missing (e.g.
// fresh checkout, CI without secrets, or anyone who hasn't run
// scripts/generate_release_keystore.sh yet), we fall back to the debug
// signing config so `flutter run --release` still works.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val hasReleaseSigning = keystorePropertiesFile.exists() &&
    keystoreProperties.getProperty("storeFile") != null &&
    keystoreProperties.getProperty("storePassword") != null &&
    keystoreProperties.getProperty("keyAlias") != null &&
    keystoreProperties.getProperty("keyPassword") != null

android {
    namespace = "com.johnsondigital.loadout"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.johnsondigital.loadout"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        //
        // minSdk = 29 (Android 10) — explicit floor.
        // ----------------------------------------------------------------------
        // Pinned to 29 so Android 10 phones can install LoadOut. Per Google's
        // distribution dashboard (refresh date 2025-Q4) Android 10 still
        // accounts for ~15% of in-the-wild Android handsets — locking it out
        // would needlessly shrink the install base for what is otherwise a
        // standard Flutter app. We deliberately don't use `flutter.minSdkVersion`
        // because that default has drifted over Flutter releases (currently 24)
        // and we want this number to be intentional, not implicit.
        //
        // Why not lower than 29?
        //   * `flutter_blue_plus` requires API 21+, fine.
        //   * `purchases_flutter` (RevenueCat) requires API 21+, fine.
        //   * `firebase_auth` v6 series supports API 21+, fine.
        //   * Some optional features (Wear OS pairing) require API 30+; we
        //     hide those affordances on Android 10 via the Device
        //     Compatibility screen rather than blocking install.
        //   * BLE on API 29 needs `ACCESS_FINE_LOCATION` at runtime — handled
        //     in `lib/services/ble/ble_service.dart` `ensurePermissions()`.
        //
        // See CLAUDE.md § 9 for the full Android-floor rationale and the
        // Device Compatibility screen wiring.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                // storeFile is resolved relative to this module (android/app).
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // If android/key.properties is present we sign with the real
            // release keystore. Otherwise fall back to the debug keystore so
            // local `flutter run --release` keeps working without secrets.
            // The debug fallback MUST NOT ship to the Play Store — see
            // CLAUDE.md "Android gotchas".
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 / mapping-file note — see CLAUDE.md §29:
            //
            // `isMinifyEnabled` is intentionally NOT set here (defaults to
            // false). When it eventually flips to true (pre-launch APK-size
            // optimization), the Crashlytics Gradle plugin will start
            // auto-uploading the generated `mapping.txt` to Firebase on
            // every release build — this is the Android analogue of the
            // iOS `[CP] Crashlytics Upload dSYMs` build phase. The plugin
            // configures it automatically (`mappingFileUploadEnabled`
            // defaults to true); no extra wiring needed here.
            //
            // The cost of flipping R8 on is: every plugin that uses
            // reflection (firebase, drift, kotlinx_serialization, etc.)
            // needs explicit -keep rules to survive code shrinking, and
            // the whole release flow needs a smoke test pass. Treat it as
            // its own pre-launch task, not a freebie.
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Google Play Services Wearable Data Layer — used by WatchBridge.kt to
    // mirror the iOS WatchSessionBridge: DataItems for lossy DOPE / active-
    // load payloads and Messages for the live timer / shot-log channel.
    // Required by every reference under `com.google.android.gms.wearable.*`
    // and `com.google.android.gms.tasks.Tasks` in the phone module.
    // See CLAUDE.md §15 for the watch / Wear OS architecture overview.
    implementation("com.google.android.gms:play-services-wearable:18.2.0")
}
