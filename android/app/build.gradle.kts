plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "com.example.knit"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.knit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // record (audio capture) requires API 23+; floor the Flutter default to it.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Build flavors (dev / staging / prod). Each gets a distinct application id
    // suffix so all three install side by side, and a flavor-specific app name
    // surfaced to the manifest via @string/app_name. Pair with the matching
    // Dart entry point, e.g. `flutter run --flavor dev -t lib/main_dev.dart`.
    // AGP 9 disables resValue by default; the flavors need it for app_name.
    buildFeatures {
        resValues = true
    }
    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Knit Dev")
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "Knit Staging")
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "Knit")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
