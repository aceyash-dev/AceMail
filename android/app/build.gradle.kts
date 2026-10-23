import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing.
//
// `android/key.properties` is git-ignored: CI writes it from repository secrets
// and it points at `android/ace-release.jks`. Without it the release build
// falls back to the debug key, so a plain `flutter run --release` still works —
// but only a build signed with the release key can update an installed app.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "app.tab.mail"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications schedules by time, which needs java.time
        // on API levels that predate it. Without this the release build fails
        // in dexing, not in Dart, so it is easy to miss until CI.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "app.tab.mail"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // NB: the ABIs that end up in the APK are chosen by Flutter, not here.
        // The Flutter Gradle plugin writes abiFilters itself, so an `ndk {}`
        // block in defaultConfig is silently overridden. Pass
        // `--target-platform android-arm,android-arm64` to `flutter build apk`
        // instead — that is what keeps x86_64 out of the release.
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 removes the code nothing reaches, and the resource shrinker
            // removes the files nothing references. Neither costs a feature:
            // what goes is what was already unreachable, and the debug build
            // keeps everything so a stack trace still names names.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            // `--target-platform` keeps the x86/x86_64 Flutter and Dart code
            // out, but the engine still ships libdartjni.so for x64. Strip the
            // whole ABI so the APK carries arm only.
            excludes += listOf("lib/x86/**", "lib/x86_64/**")
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

dependencies {
    // Backs `isCoreLibraryDesugaringEnabled` above. Without it the release
    // build fails while dexing, with a message that does not mention
    // notifications at all.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
