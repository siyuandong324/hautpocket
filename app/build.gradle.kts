plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "cn.edu.haut.hautpocket"
    compileSdk = 34

    defaultConfig {
        applicationId = "cn.edu.haut.hautpocket"
        minSdk = 23
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            // 使用默认 debug 签名，确保在 GitHub Actions 无私钥环境下 assembleRelease 也能直接产出可安装的 APK
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // 仅使用 Android SDK 原生标准库，零外部依赖冲突，确保云端 GitHub Actions 100% 编译通过
}
