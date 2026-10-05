# QGroundControl 5.0 Android (arm64) 构建成果备份

构建日期：2026-10-05

## 目录内容

| 路径 | 说明 |
|---|---|
| `QGroundControl-5.0-arm64-signed.apk` | **已签名 APK**（81 MB），可直接安装 |
| `translations/` | 补齐后的中文翻译文件（99.9% / 96.6%） |
| `translations/*.ts.bak` | 原始官方翻译文件（修改前备份） |
| `build-android.ps1` | 一键构建脚本（含自动签名） |
| `tools/zh_translate.py` | 翻译辅助工具（analyze/autofill/export/apply） |
| `translation-work/` | 翻译中间产物（待翻译清单 + 译文 JSON） |
| `patches/LibEvents-CMakeLists.txt` | libevents 版本固定补丁 |

## APK 信息

```
包名        : org.mavlink.qgroundcontrol
versionCode : 660000000
minSdk      : 28  (Android 9.0)
targetSdk   : 35  (Android 15)
ABI         : arm64-v8a（仅 64 位）
签名        : Android debug keystore (v3 scheme)
```

## 构建环境（本机）

| 组件 | 版本 / 路径 |
|---|---|
| 源码 | QGC `Stable_V5.0` @ `0e7d0e3b49990424b3c452d21782bb072847ccad` |
| Qt | 6.8.3，`C:\Qt\6.8.3\android_arm64_v8a`（target）+ `msvc2022_64`（host） |
| NDK | r26b `26.1.10909125` |
| JDK | Android Studio JBR `17.0.6` |
| CMake | 4.4.0（`C:\Program Files\CMake\bin`） |
| Ninja | SDK 自带 `cmake\3.22.1\bin\ninja.exe` |
| 构建目录 | `C:\qgc-build`（**必须英文路径**） |
| 源码英文联接 | `C:\qgc\qgroundcontrol` → `...\固定翼\qgc\qgroundcontrol` |

## 重新构建

```
cd c:\Users\dobyp\Documents\固定翼\qgc
powershell -ExecutionPolicy Bypass -File .\build-android.ps1
```
增量编译约 1 分钟；会直接产出**已签名** APK 到 `C:\qgc-build\android-build\QGroundControl.apk`。

## 装到手机

```
adb install -r QGroundControl-5.0-arm64-signed.apk
# 首次运行授予「所有文件访问」：
adb shell appops set org.mavlink.qgroundcontrol MANAGE_EXTERNAL_STORAGE allow
```

## 已解决的关键问题（复查用）

1. **Qt 6.8+ 安卓包换了仓库路径**：在 `all_os/android/qt6_683/`（不是 `windows_x86/android`）
2. **pip 版 CMake 3.31.6 会崩溃**（`FindGit.cmake` 处 `0xC0000409`）→ 用系统 CMake 4.4.0
3. **中文路径破坏工具链**：
   - GStreamer 自带 pkg-config 0.27.1 读不了中文路径 → 构建目录用 `C:\qgc-build`
   - Qt `qmlimportscanner` 把中文路径转乱码 → 源码用英文联接 `C:\qgc\qgroundcontrol`
4. **libevents 的 `main` 分支漂移**导致编译失败 → 固定到父提交 `077677a7d2f48f0af0eb8a4e4a7b6310956728bc`
5. **官方中文翻译不完整**（55.5% / 35.4%）→ 补齐到 99.9% / 96.6%

## 遗留的英文（无法通过翻译解决）

- HUD 上的 `AirSpd` / `Thr`：硬编码在 `src/API/QGCCorePlugin.cc:183`（`value->setText("AirSpd")`，未用 `tr()`）
- 地图上的洲名/洋名（AMERICA、EUROPE…）：地图瓦片图片自带
