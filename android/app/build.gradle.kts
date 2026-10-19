plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.chaska.app"
    compileSdk = flutter.compileSdkVersion
    // NDK not required: pure-Dart app with no native code.
    // (flutter.ndkVersion removed to avoid forced NDK download on this VM.)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("chaska") {
            storeFile = file("chaska-test.keystore")
            storePassword = "chaska123"
            keyAlias = "chaska"
            keyPassword = "chaska123"
        }
    }

    defaultConfig {
        applicationId = "com.chaska.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signed with the persistent test keystore so updates install
            // cleanly over previous builds (same signature every time).
            // (Final Play Store key will replace this before launch.)
            signingConfig = signingConfigs.getByName("chaska")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
