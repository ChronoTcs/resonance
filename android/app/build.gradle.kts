import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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

    signingConfigs {
        create("release") {
            val keyAliasProp = keystoreProperties.getProperty("keyAlias")
            val keyPasswordProp = keystoreProperties.getProperty("keyPassword")
            val storeFileProp = keystoreProperties.getProperty("storeFile")
            val storePasswordProp = keystoreProperties.getProperty("storePassword")

            if (keyAliasProp != null && keyPasswordProp != null && storeFileProp != null && storePasswordProp != null) {
                keyAlias = keyAliasProp
                keyPassword = keyPasswordProp
                storeFile = if (file(storeFileProp).isAbsolute) {
                    file(storeFileProp)
                } else {
                    rootProject.file(storeFileProp).takeIf { it.exists() } ?: file(storeFileProp)
                }
                storePassword = storePasswordProp
            }
        }
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.getByName("release")
            signingConfig = if (releaseConfig.storeFile?.exists() == true) {
                releaseConfig
            } else {
                signingConfigs.getByName("debug")
            }
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
    implementation("com.jakewharton.timber:timber:5.0.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
