plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.goftarin.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.goftarin.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing: GOFTARIN_KEYSTORE (path), GOFTARIN_KEYSTORE_PASSWORD and GOFTARIN_KEY_ALIAS
    // select the private upload key (for store releases). Without them, test builds are
    // signed with the committed test key, so each test build installs over the previous one.
    val ks = System.getenv("GOFTARIN_KEYSTORE")
    val useUpload = ks != null && file(ks).exists()
    signingConfigs {
        create("release") {
            if (useUpload) {
                storeFile = file(ks!!)
                storePassword = System.getenv("GOFTARIN_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("GOFTARIN_KEY_ALIAS") ?: "goftarin"
                keyPassword = System.getenv("GOFTARIN_KEYSTORE_PASSWORD")
            } else {
                storeFile = file("test-signing.jks")
                storePassword = "goftarin-test"
                keyAlias = "goftarin-test"
                keyPassword = "goftarin-test"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
