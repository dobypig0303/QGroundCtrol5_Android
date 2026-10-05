为 **Android 4.4（KitKat）** 老设备构建的 32 位 QGroundControl 4.0.11。

## 包含内容

- Qt 5.12.6 / NDK r20b / **armeabi-v7a**（32 位 ARM）
- **minSdk 19（Android 4.4）**，targetSdk 28
- `extractNativeLibs=true` —— Android 4.4 无法从 APK 内直接加载 `.so`，必须解压到应用目录
- **v1 + v2 双重签名** —— Android 4.4 完全忽略 v2/v3，只认可 v1（JAR）签名方案
- 构建时未安装 GStreamer 1.14.4，因此**不含视频流功能**；其余功能正常

## 中文汉化（完整版）

这个 APK 的界面**已基本全部中文化**，而不是官方仓库里那份「显示 99.6% 完成、界面却大面积英文」的状态。

官方 `localization/qgc_zh_CN.ts` 存在三个叠加问题：

1. **从未用 `lupdate` 跟随源码更新** —— 重扫后发现 **430 条源字符串根本不在 `.ts` 里**，另有
   **391 条因字符串换了文件而失效**（译文仍挂在已不再发出该字符串的 `context` 下，运行时必然查不到）。
   界面上看到的 `Ground Speed`、`Flight Time`、`Take off` 就属于第一类。
2. **JSON 事实字符串完全不参与翻译** —— `src/Vehicle/VehicleFact.json` 等 23 个文件里的
   `shortDescription` 由 `FactMetaData` 直接读取，无任何翻译处理（QGC 5.x 才引入
   `JsonHelper::translator()` 通道）。这导致「高度 / 地速 / 飞行时间」始终是英文。
3. **翻译时机不对** —— 载具的 `FactGroup` 在 `QGCApplication` 安装 `QTranslator` **之前**
   就解析了 JSON，所以即使把 JSON 字符串纳入 `.ts`，在解析时翻译也无效；必须在**显示时**翻译，
   即 `Fact::shortDescription()` / `Fact::longDescription()`。

处理流程：`lupdate` 重新对齐源码 → 抢救回 569 条旧译文 → 新翻译 226 条 + 176 条 JSON 字符串 →
修复 23 条损坏译文（`返航Return`、`定高Altitude`、`任务Mission` —— 英文被拼在中文后）→
打 5 行 C++ 补丁改为显示时翻译。

```
lrelease: Generated 3323 translation(s) (3311 finished, 12 unfinished)
```

翻译完成度 **3309 / 3342 = 99.0%**；剩余 33 条均为不可翻译项（JWT 代码片段、纯数字（`0.1`、`10,000`）、
符号（`+`、`-`、`L`）、品牌名（`Sony DSC-RX0`）、缩写（`HDOP`、`VDOP`、`n/a`）。

已在 **HTC D820u（Android 4.4.4）真机验证**：顶栏「返航 / 起飞 / 飞行」、右侧「正在等待飞机连接」、
比例尺「2000 千米」、遥测面板「值 / 高度 (相对) / 地速 / 飞行时间」全部为中文。

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
SHA256: BF8C6625B30500F7D1D978AC14236ABBDF1A92AC8F0867C41F172638AD473626
大小:   50.7 MB
```
