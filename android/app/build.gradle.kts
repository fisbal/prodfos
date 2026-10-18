import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release signing ─────────────────────────────────────────────
// One permanent key (android/keystore/prodfos-release.p12) so every new
// APK installs as an UPDATE over the previous one — no uninstall needed.
// The keystore file is useless without its password, which is NEVER
// committed: CI reads it from the ANDROID_KEYSTORE_PASSWORD secret, local
// builds from android/key.properties (git-ignored: storePassword=...).
val releaseKeystore = rootProject.file("keystore/prodfos-release.p12")
val localKeyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val releaseKeystorePassword: String? =
    System.getenv("ANDROID_KEYSTORE_PASSWORD")?.takeIf { it.isNotBlank() }
        ?: localKeyProps.getProperty("storePassword")?.takeIf { it.isNotBlank() }
val hasReleaseKey = releaseKeystore.exists() && releaseKeystorePassword != null

android {
    namespace = "com.martinb.prodfos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.martinb.prodfos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                storeFile = releaseKeystore
                storeType = "PKCS12"
                storePassword = releaseKeystorePassword
                keyAlias = "prodfos"
                keyPassword = releaseKeystorePassword
            }
        }
    }

    buildTypes {
        release {
            // Permanent ProDFOS key when the password is available, otherwise
            // fall back to the debug key so builds never fail.
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release")
                            else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
