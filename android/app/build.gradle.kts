import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "id.web.idm.pvc"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }



    defaultConfig {
        applicationId = "id.web.idm.pvc"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 1
        versionName = "1.0"

        manifestPlaceholders.put("io.flutter.embedding.android.EnableImpeller", "false")
    }

    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("x86_64", "armeabi-v7a", "arm64-v8a")
            isUniversalApk = true
        }
    }

    buildTypes {
        getByName("release") {

            isMinifyEnabled = false
            isShrinkResources = false
            ndk {
                abiFilters.addAll(listOf("x86_64", "armeabi-v7a", "arm64-v8a"))
                debugSymbolLevel = "FULL"
            }
        }
        getByName("debug") {

            isMinifyEnabled = false
            isShrinkResources = false
            ndk {
                abiFilters.addAll(listOf("x86_64", "armeabi-v7a", "arm64-v8a"))
                debugSymbolLevel = "FULL"
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}