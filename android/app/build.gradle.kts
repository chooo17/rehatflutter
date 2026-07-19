plugins {
    id("com.android.application")
    // Firebase (google-services) — harus sebelum plugin Flutter.
    id("com.google.gms.google-services")
    // Crashlytics (simbolikasi mapping R8 pada build rilis).
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.rehat.rehat_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rehat.rehat_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // minSdk 23: disyaratkan oleh flutter_secure_storage (EncryptedSharedPreferences).
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // R8: buang kode & resource tak terpakai + obfuscate → APK lebih kecil.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // Dua audiens: "customer" (app pelanggan, ramping, tanpa izin Bluetooth) &
    // "admin" (kasir, dengan printer thermal Bluetooth). applicationId sama
    // agar cocok dengan google-services.json (Firebase) yang sama.
    flavorDimensions += "audience"
    productFlavors {
        create("customer") {
            dimension = "audience"
        }
        create("admin") {
            dimension = "audience"
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
