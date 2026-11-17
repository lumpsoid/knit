import java.util.Properties

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

// Release signing reads android/key.properties (gitignored): storeFile,
// storePassword, keyAlias, keyPassword. storeFile may be absolute, so the
// keystore can live outside the repo. Without the file, release builds fall
// back to the debug key so `flutter run --release` still works.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "io.github.lumpsoid.knit"
    // API 37 ships as a minor-versioned platform (platforms/android-37.0).
    compileSdk {
        version = release(37) { minorApiLevel = 0 }
    }
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.lumpsoid.knit"
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

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
