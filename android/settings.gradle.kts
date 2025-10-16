pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    // Try to include the build from the Flutter SDK. If the SDK path is not
    // writable or available (some Linux packaging setups), fall back to a
    // project-local copy generated during development at
    // android/flutter_tools_gradle (created by the dev environment).
    val sdkGradle = file("$flutterSdkPath/packages/flutter_tools/gradle")
    // Prefer the Flutter SDK gradle helper only when the path exists, is a
    // directory and is writable by the Gradle process. Some system-installed
    // SDKs are not writable or have permission layouts that make Gradle
    // treat them as unavailable. In that case fall back to the project-local
    // copy under android/flutter_tools_gradle which we ship for development.
    // For development environments where the system-installed Flutter SDK
    // layout is restricted or not usable by Gradle, prefer the project-local
    // copy of the gradle helper. This avoids path/permission checks that can
    // fail on some distributions. Use the SDK path only if the local copy is
    // missing.
    val localCopy = file("flutter_tools_gradle")
    if (localCopy.exists() && localCopy.isDirectory) {
        includeBuild(localCopy.absolutePath)
    } else if (sdkGradle.exists() && sdkGradle.isDirectory) {
        includeBuild(sdkGradle.absolutePath)
    } else {
        throw GradleException("Unable to find flutter_tools_gradle in project or SDK")
    }

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
