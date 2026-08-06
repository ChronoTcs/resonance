plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.chronostudio.resonance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.chronostudio.resonance"
        // Pinned: audio_service requires minSdk 21. targetSdk 34 required for POST_NOTIFICATIONS.
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    applicationVariants.all {
        val variant = this
        if (variant.buildType.name == "release") {
            val copyTask = tasks.register<Copy>("copy${variant.name.capitalize()}Apk") {
                // Flutter typically places the final APK here
                from(layout.buildDirectory.dir("outputs/flutter-apk/app-release.apk"))
                into(layout.buildDirectory.dir("outputs/resonance/"))
                rename { "Resonance-v${variant.versionName}-Android.apk" }
                
                doFirst {
                    mkdir(layout.buildDirectory.dir("outputs/resonance/"))
                }
            }
            variant.assembleProvider.configure {
                finalizedBy(copyTask)
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.github.ZemerTeam:zemer-cipher:master-SNAPSHOT")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
