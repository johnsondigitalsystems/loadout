pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // Crashlytics Gradle plugin — required for the native Android SDK to
    // bootstrap fully (without it, Dart-side `recordError` calls succeed
    // but Firebase silently drops the reports and the Console keeps
    // showing the "Add SDK" onboarding page). Pinned to 2.9.9 because
    // 3.x requires the Gradle daemon to run on JDK 17; our daemon is
    // currently on Java 11. Move to 3.x when the daemon's JVM moves.
    id("com.google.firebase.crashlytics") version("2.9.9") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // Compose Compiler plugin — required by `:wear` (Compose for Wear OS) since
    // Kotlin 2.0. Only the `:wear` module applies it; the Flutter `:app` module
    // does not pull this in.
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.20" apply false
}

include(":app")
include(":wear")
