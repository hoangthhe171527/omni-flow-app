import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val googleServicesFile = layout.projectDirectory.file("google-services.json")

// Debug builds remain usable in a fresh clone without Firebase credentials.
// Release builds are guarded below so an artifact without generated Firebase
// resources can never be produced accidentally.
if (googleServicesFile.asFile.isFile) {
    apply(plugin = "com.google.gms.google-services")
    // Crashlytics depends on google-services having run, so it is applied in the
    // same branch and never on its own.
    apply(plugin = "com.google.firebase.crashlytics")
}

val verifyReleaseGoogleServices by tasks.registering {
    group = "verification"
    description = "Verifies that the release build has an app-specific Firebase config."

    doLast {
        if (!googleServicesFile.asFile.isFile) {
            throw GradleException(
                "Missing android/app/google-services.json. " +
                    "Release builds require Firebase config for " +
                    "vn.sunriseieco.viomni.",
            )
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(verifyReleaseGoogleServices)
}

// Signing credentials live in android/key.properties, which is gitignored and
// points at a keystore kept outside the repo. Absent (fresh clone, CI without
// secrets) the release build falls back to the debug key so it still builds —
// but such an artifact must never be uploaded to Play.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val signingStoreFile = keystoreProperties.getProperty("storeFile") ?: System.getenv("ANDROID_KEYSTORE_PATH")
val signingStorePassword = keystoreProperties.getProperty("storePassword") ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
val signingKeyAlias = keystoreProperties.getProperty("keyAlias") ?: System.getenv("ANDROID_KEY_ALIAS")
val signingKeyPassword = keystoreProperties.getProperty("keyPassword") ?: System.getenv("ANDROID_KEY_PASSWORD")
val hasSigningConfig = listOf(
    signingStoreFile,
    signingStorePassword,
    signingKeyAlias,
    signingKeyPassword,
).all { !it.isNullOrBlank() }

android {
    namespace = "vn.sunriseieco.viomni"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "vn.sunriseieco.viomni"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasSigningConfig) {
            create("release") {
                storeFile = file(signingStoreFile!!)
                storePassword = signingStorePassword
                keyAlias = signingKeyAlias
                keyPassword = signingKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
