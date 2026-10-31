#!/usr/bin/env bash
set -e
echo "========================================================"
echo "  Hautpocket (河南工业大学教务口袋助手) 一键打包 APK 脚本"
echo "========================================================"
if ! command -v flutter &> /dev/null; then
    echo "[错误] 未检测到 Flutter SDK，请先安装 Flutter，或将本工程推送至 GitHub 使用内置 GitHub Actions 云端自动编译 APK。"
    exit 1
fi
flutter create --platforms=android --org cn.edu.haut --project-name hautpocket .
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
echo "[完成] APK 已生成至: build/app/outputs/flutter-apk/app-release.apk"
