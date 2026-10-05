为 **Android 4.4（KitKat）** 老设备构建的 32 位 QGroundControl 4.0.11。

## 包含内容

- Qt 5.12.6 / NDK r20b / **armeabi-v7a**（32 位 ARM）
- **minSdk 19（Android 4.4）**，targetSdk 28
- `extractNativeLibs=true` —— Android 4.4 无法从 APK 内直接加载 `.so`，必须解压到应用目录
- **v1 + v2 双重签名** —— Android 4.4 完全忽略 v2/v3，只认可 v1（JAR）签名方案
- 构建时未安装 GStreamer 1.14.4，因此**不含视频流功能**；其余功能正常

## 安装

```bash
adb install -r QGroundControl-4.0.11-armeabi-v7a-android4.4.apk
```

若设备上已安装 5.0（包名相同且 versionCode 更高：401100 < 660000000），需要允许降级：

```bash
adb install -r -d QGroundControl-4.0.11-armeabi-v7a-android4.4.apk
```

包名 `org.mavlink.qgroundcontrol`，debug 签名，仅供测试使用。

## 构建说明

完整可复现的构建脚本见仓库根目录的 `build-android-4.0.11.ps1`。
这套老工具链有三个必须绕过的坑（`gradle.properties` 反斜杠转义、Qt 模板请求的 AGP 1.1.0
与 Groovy 3 不兼容、AGP 8 关闭了 aidl/buildConfig 且 `extractNativeLibs` 默认为 false），
完整分析见 `qgc-4.0.11-android/README.md`。

## 校验

```
SHA256: 53D6148862BEB171B515D56C7C877A33F9456C0070271CC921D8DE6CC7CE63A1
大小:   35.8 MB
```
