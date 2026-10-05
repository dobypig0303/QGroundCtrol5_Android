# QGroundControl 4.0.11 — Android 4.4+（KitKat）32 位构建

为 **Android 4.4.4** 设备构建的 `armeabi-v7a` 版本 QGroundControl。

## 成果文件

| 文件 | 说明 |
|---|---|
| `QGroundControl-4.0.11-armeabi-v7a-android4.4.apk` | **可直接安装的 APK**（debug 签名） |
| `patches/build.gradle` | 替换 `androiddeployqt` 生成的过时模板（AGP 8.8.0） |
| `patches/gradle.properties` | 修正路径反斜杠转义 + 对齐本机 SDK 版本 |
| `../build-android-4.0.11.ps1` | 一键复现完整构建流程 |

APK 元数据（`aapt2 dump badging` 实测）：

```
package:              org.mavlink.qgroundcontrol
minSdkVersion:        19        <- Android 4.4 KitKat
targetSdkVersion:     28
native-code:          armeabi-v7a
extractNativeLibs:    true      <- 4.4 必须，否则 .so 无法加载
application-label:    QGroundControl
```

## 目标设备兼容性

- **Android 4.4 = API 19**，所以 `minSdkVersion 19` 正好覆盖；Android 4.1~4.3（API 16~18）不在支持范围内。
- 只包含 **armeabi-v7a**（32 位 ARM）。Android 4.4 时代的设备基本都是 32 位 ARM，符合预期。
- `extractNativeLibs=true` 是关键：AGP 8 默认把它设为 `false`（库直接留在 APK 内、需要 Android 6+ 的加载方式），4.4 上会直接启动失败。

### 签名（已实测）

```
Verified using v1 scheme (JAR signing): true          <- Android 4.4 只认这一种
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): false
```

APK 同时带 v1 + v2 签名（`META-INF/CERT.SF`、`META-INF/CERT.RSA`、`META-INF/MANIFEST.MF` 都在），
所以从 Android 4.4 一直到现代 Android 都能安装。这点很关键 —— Android 4.4 完全忽略 v2/v3 签名方案。

## 安装到真机（Android 4.4.4）

1. 设备端打开 USB 调试。Android 4.4 的路径是：
   「设置 → 关于手机/平板 → 连点『版本号』7 次」→ 返回「设置 → 开发者选项 → USB 调试」。
2. 确认设备已被识别：

   ```powershell
   adb devices
   ```

3. 安装：

   ```powershell
   adb install -r "qgc-4.0.11-android\QGroundControl-4.0.11-armeabi-v7a-android4.4.apk"
   ```

   若设备上装过 QGC 5.0（包名相同、versionCode 更高），需要允许降级：

   ```powershell
   adb install -r -d "qgc-4.0.11-android\QGroundControl-4.0.11-armeabi-v7a-android4.4.apk"
   ```

4. 启动并观察日志：

   ```powershell
   adb shell am start -n org.mavlink.qgroundcontrol/org.mavlink.qgroundcontrol.QGCActivity
   adb logcat -s Qt:* QGroundControl:* AndroidRuntime:E
   ```

排查用对照表：

| 报错 | 含义 |
|---|---|
| `INSTALL_FAILED_OLDER_SDK` | 设备低于 API 19，不是 Android 4.4+ |
| `INSTALL_PARSE_FAILED_NO_CERTIFICATES` | v1 签名缺失（本 APK 已确认存在） |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | 上面漏了 `-d` |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 设备上已有同包名但签名不同的版本，先 `adb uninstall org.mavlink.qgroundcontrol` |

## 重新构建

```powershell
# 完整构建（qmake + 编译 + 打包）
.\build-android-4.0.11.ps1

# 只重新打包（复用已有的 libQGroundControl.so，几十秒完成）
.\build-android-4.0.11.ps1 -SkipCompile

# 构建并安装到当前连接的设备
.\build-android-4.0.11.ps1 -SkipCompile -Install
```

产物路径：`C:\qgc40-build\android-build\build\outputs\apk\debug\android-build-debug.apk`

## 为什么需要 `patches/`

`androiddeployqt` **总是**用它自带的 Qt 5.12.6 模板覆盖 `build.gradle` 和 `gradle.properties`，
而那两个模板在现代环境下无法工作。踩到的三个坑：

### 1. `gradle.properties` 的反斜杠转义

`androiddeployqt` 写入的是：

```properties
qt5AndroidDir=C:\Qt5\5.12.6\android_armv7/src/android/java
```

Java properties 解析器会把 `\` 当转义符，于是变成 `C:Qt55.12.6android_armv7/...`，Gradle 报：

```
Cannot convert URL 'C:Qt55.12.6android_armv7/src/android/java/src' to a file.
```

→ 改用正斜杠。

### 2. AGP 1.1.0 与 Groovy 3 不兼容

Qt 5.12.6 的模板请求：

```gradle
classpath 'com.android.tools.build:gradle:1.1.0'   // 且仓库用 jcenter()
```

- `jcenter()` 已于 2022 年关停。
- AGP 1.1.0 是 Groovy 时代编译的插件，它的 `BasePlugin.verifyRetirementAge()`
  调用 `StringGroovyMethods.contains(String, String)`，而该签名在 Gradle 8.x 自带的
  Groovy 3.0.22 中已不存在，报：

```
NoSuchMethodError: 'boolean org.codehaus.groovy.runtime.StringGroovyMethods.contains(java.lang.String, java.lang.String)'
    at com.android.build.gradle.BasePlugin.getRetirementAge(BasePlugin.groovy:200)
```

→ 改用 **AGP 8.8.0 + Gradle 8.12.1 + JDK 17**。这正是本机构建 QGC 5.0 时用过的组合，
所以 `~/.gradle/caches` 里已有全部构件，不需要再下载任何东西。

### 3. AGP 8 的默认值变化

- `aidl` / `buildConfig` 生成**默认关闭** → `QtLoader.java` 找不到
  `org.kde.necessitas.ministro.IMinistro`（由 Qt 自带的 `.aidl` 生成），报 8 个“找不到符号”。
- `extractNativeLibs` 默认 `false` → 4.4 无法加载原生库。
- 清单里的 `package=` 属性不再被支持 → 改用 `build.gradle` 的 `namespace`。
- `lintOptions {}` → `lint {}`；`resources.srcDirs` / `renderscript.srcDirs` 已移除。

## 中文汉化（4.0.11）

4.0.11 的汉化比 5.0 复杂：**翻译文件本身显示 99.6% 完成，界面却大面积英文**。排查后是三个独立问题叠加。

### 1. `.ts` 与源码完全脱节（最严重）

仓库里的 `localization/qgc_zh_CN.ts` **从未用 `lupdate` 跟随源码更新过**：

```
[lupdate 结果]
Found 2773 source text(s) (430 new and 2343 already existing)
Kept 391 obsolete entries
```

- **430 条源字符串根本不在 `.ts` 里** → 只能显示英文（界面上看到的 `Ground Speed`、`Flight Time`、`Take off` 就是这类）
- **391 条因字符串换文件而失效** → 译文仍挂在旧 `context` 下，运行时查找必然失败。例如 `Waiting For Vehicle Connection` 在 `.ts` 里属于 `MainToolBarIndicators.qml`，实际源码已在 `MainToolBar.qml:318`

处理流程（把 lupdate 标为 obsolete 的旧译文抢救回来）：

```bash
lupdate qgroundcontrol.pro -ts localization/qgc_zh_CN.ts          # 重新对齐源码
python tools/ts_reuse_translations.py old.ts new.ts               # 回填 obsolete 条目里的旧译文
python tools/zh_translate.py analyze localization/qgc_zh_CN.ts    # 统计剩余缺口
python tools/zh_translate.py export  localization/qgc_zh_CN.ts --out todo.json
python tools/zh_translate.py apply   localization/qgc_zh_CN.ts --out translated.json
python tools/ts_fix_broken.py localization/qgc_zh_CN.ts           # 修复「返航Return」这类损坏译文
python tools/json_facts_to_ts.py localization/qgc_zh_CN.ts        # 把 JSON 事实字符串并入 .ts
```

> `lupdate` 必须在设置好 `ANDROID_NDK_ROOT` 的环境下运行，否则 qmake 读不到
> `mkspecs/android-clang/qmake.conf`，会扫描到 **0 个源字符串并把整份文件标记为 obsolete**。

### 2. JSON 事实字符串从不参与翻译

`src/Vehicle/VehicleFact.json` 等 23 个文件里的 `shortDescription` 由
`FactMetaData` 直接读取（`FactMetaData.cc:1124`），**没有任何翻译处理**，
所以「高度 / 地速 / 飞行时间」等始终是英文。QGC 5.x 为此引入了
`JsonHelper::translator()` 通道，4.0.11 完全没有。

### 3. 翻译时机不对（最容易踩）

即使把 JSON 字符串纳入 `.ts`，**在解析 JSON 时翻译仍然无效**：

```
工具箱创建（含离线载具 → 解析 VehicleFact.json）
    ↓
QGCApplication 安装 QTranslator      ← 翻译器这时才存在
    ↓
界面加载
```

载具的 `FactGroup` 在翻译器安装**之前**就已构造，查找必然失败，英文名被永久写进元数据。
因此补丁必须放在**显示时**：`Fact::shortDescription()` / `longDescription()`。

### 补丁清单

统一使用固定 context `"QGCJson"`，与 `qgc_zh_CN.ts` 中的 `QGCJson` 上下文对应。

| 文件 | 改动 |
|---|---|
| `src/FactSystem/Fact.cc` | 新增 `_translateFactJsonString()`；`shortDescription()` / `longDescription()` 出口翻译 |
| `src/FactSystem/FactMetaData.cc` | `jsonFactTr()` 包裹 `setShortDescription` / `setLongDescription` / `addEnumInfo` |

完整 unified diff 见 `patches/zh-localization.patch`，改造后的源文件见 `patches/*.patched`。

> 教训：编辑 `C:\qgc40` 下的源码时，编辑工具**偶尔会静默破坏文件**（有一次吃掉了
> `Fact::type()` 和 `Fact::cookedDefaultValueString()`，表现为链接期
> `undefined reference`）。**改完务必用 `git -C C:\qgc40 diff` 审计改动**，
> 确认没有非预期的删除。

### 最终结果

```
lrelease: Generated 3323 translation(s) (3311 finished, 12 unfinished)
```

| 项目 | 数值 |
|---|---|
| `.ts` 总条目 | 3342（含 176 条 JSON 字符串） |
| 已翻译 | **3309 / 3342 = 99.0%** |
| 剩余 33 条 | 全部不可翻译：JWT 代码片段、纯数字（`0.1`、`10,000`）、符号（`+`、`-`、`L`）、品牌名（`Sony DSC-RX0`）、缩写（`HDOP`、`VDOP`、`n/a`） |

真机（HTC D820u / Android 4.4.4）实测：顶栏「返航 / 起飞 / 飞行」、右侧「正在等待飞机连接」、
比例尺「2000 千米」、遥测面板「高度 (相对) / 地速 / 飞行时间」全部为中文。

## 已知限制

- **无视频流**：构建时未安装 GStreamer 1.14.4，`androiddeployqt` 输出
  `Skipping support for video streaming (GStreamer libraries not installed)`。其余功能不受影响。
- **debug 签名**：由 Gradle 用 `~/.android/debug.keystore` 自动签名，适合测试；正式发布需自行签名。
- **包名冲突**：与 QGC 5.0 同为 `org.mavlink.qgroundcontrol`，且 versionCode 更低（401100 < 660000000），
  同机安装时会替换掉 5.0（脚本用 `adb install -r -d`）。
- **尚未在真实 Android 4.4.4 设备上验证**：手边只有 Redmi 2311DRK48C（Android 16），
  它可以用作安装/启动的冒烟测试，但不能替代 4.4.4 的真机验证。

## 构建环境

| 组件 | 路径 |
|---|---|
| 源码 | `C:\qgc40`（commit `fead95d5d671dc4859acf40c8be164e87256d1d2`） |
| 构建目录 | `C:\qgc40-build` |
| Qt | `C:\Qt5\5.12.6\android_armv7` |
| mingw32-make | `C:\Qt5\Tools\mingw730_64\bin` |
| NDK | `C:\qgc40-deps\android-ndk-r20b` (r20b) |
| JDK 8 | `C:\qgc40-deps\jdk8`（仅供 androiddeployqt 使用） |
| JDK 17 | `C:\Program Files\Android\Android Studio\jbr`（AGP 8.x 要求） |
| Gradle | `~\.gradle\wrapper\dists\gradle-8.12.1-bin`（复用，无下载） |
| AGP | 8.8.0（复用 `~\.gradle\caches`） |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk`，platform 35 / build-tools 35.0.0 |
