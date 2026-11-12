plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "com.accounting.system"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = "com.accounting.system"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "النظام المحاسبي"
    }
    buildTypes {
        // CI debug APKs use runner-specific signing keys. Keep them separate from
        // the installed production package so updates never fail on signature mismatch.
        getByName("debug") {
            applicationIdSuffix = ".diagnostic"
            versionNameSuffix = "-diagnostic"
            manifestPlaceholders["appLabel"] = "النظام المحاسبي - فحص"
        }
        release {
            // Install the shared preview beside older diagnostic builds. Never
            // require deleting a previous installation or its accounting data.
            applicationIdSuffix = ".preview"
            versionNameSuffix = "-preview"
            manifestPlaceholders["appLabel"] = "النظام المحاسبي - تجربة"
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
flutter { source = "../.." }
