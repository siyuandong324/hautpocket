@echo off
chcp 65001 >nul
echo ========================================================
echo   Hautpocket (河南工业大学教务口袋助手) 一键打包 APK 脚本
echo ========================================================
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未检测到 Flutter SDK，请先安装 Flutter 并添加到 PATH 环境变量，或直接将本项目上传至 GitHub 使用内置 GitHub Actions 自动云端打包 APK！
    pause
    exit /b 1
)
echo [1/4] 补全 Android Gradle Wrapper 基础配置...
call flutter create --platforms=android --org cn.edu.haut --project-name hautpocket .
echo [2/4] 安装项目依赖...
call flutter pub get
echo [3/4] 生成河南工业大学吉祥物应用图标...
call dart run flutter_launcher_icons
echo [4/4] 开始编译 Release APK...
call flutter build apk --release
echo.
echo [完成] APK 已生成至: build\app\outputs\flutter-apk\app-release.apk
pause
