# QGC Android Builds

QGroundControl 的 Android 构建脚本、中文汉化成果与构建产物归档。这个仓库记录了两套完整可复现的
Android 构建：一套面向现代设备，一套面向 **Android 4.4** 老设备。

> **APK 不放在仓库里**，请到 [Releases](../../releases) 下载。

## 两个构建

| | QGC 5.0 | QGC 4.0.11 |
|---|---|---|
| Qt | 6.8.3 (`android_arm64_v8a`) | 5.12.6 (`android_armv7`) |
| ABI | `arm64-v8a` | `armeabi-v7a` (32 位) |
| minSdk | 28 (Android 9) | **19 (Android 4.4)** |
| targetSdk | 35 | 28 |
| 构建系统 | CMake + Ninja | qmake + mingw32-make |
| Gradle | AGP 8.x | AGP 8.8.0 / Gradle 8.12.1 |
| APK 体积 | 81.3 MB | 35.8 MB |
| 适用设备 | 现代手机/平板 | **老旧设备（4.4+），树莓派屏、老无人机遥控器等** |

两者包名都是 `org.mavlink.qgroundcontrol`，**同一台设备上不能共存**（4.0.11 的 versionCode 更低，
安装时需要 `adb install -r -d` 允许降级）。

## 目录结构

```
.
├── build-android.ps1              # QGC 5.0 一键构建（CMake + Qt 6.8.3）
├── build-android-4.0.11.ps1       # QGC 4.0.11 一键构建（qmake + Qt 5.12.6）
├── backup-v5.0-android/           # 5.0 成果归档
│   ├── README.md
│   ├── build-android.ps1
│   ├── patches/
│   │   └── LibEvents-CMakeLists.txt   # 固定 libevents 的 commit，避开上游 API 漂移
│   ├── tools/zh_translate.py          # 汉化工具（analyze/autofill/export/apply）
│   ├── translations/                  # 汉化后的 .ts（附 .bak 原始版本）
│   └── translation-work/              # 汉化过程中拆分的 JSON 分片
├── qgc-4.0.11-android/            # 4.0.11 成果归档
│   ├── README.md                      # 详细的构建踩坑记录 + 真机安装指南
│   └── patches/
│       ├── build.gradle
│       └── gradle.properties
├── screenshots/                   # 汉化效果与运行截图
└── tools/                         # 汉化工具开发版
```

## 中文汉化

QGroundControl 官方仓库的中文翻译完成度很低（源码字符串 55.5%、JSON 字符串 35.4%），大量界面
在实际使用中仍是英文。这里把两套 `.ts` 文件补全到接近 100%：

| 文件 | 补全前 | 补全后 |
|---|---|---|
| `qgc_source_zh_CN.ts` | 55.5% (1877/3382) | **99.9% (3377/3382)** |
| `qgc_json_zh_CN.ts` | 35.4% (282/796) | **96.6% (769/796)** |

共翻译约 1800 条字符串，已在实际设备上验证（顶栏状态、"未连接 - 点击手动连接"、各设置菜单等均为中文）。

`tools/zh_translate.py` 提供 4 个子命令：

```bash
python tools/zh_translate.py analyze  # 统计完成度、列出未翻译项
python tools/zh_translate.py export   # 导出未翻译条目为 JSON 分片（便于分批处理）
python tools/zh_translate.py autofill # 用已有译文/术语表自动回填
python tools/zh_translate.py apply    # 把 JSON 译文写回 .ts
```

> `.ts` 文件里的换行是**真实换行符**而非字面量 `\n`，`apply` 已处理这一点。

## 构建要点

### QGC 5.0

```powershell
.\build-android.ps1
```

需要 Qt 6.8.3 的 Android kit、NDK、CMake。两个容易踩的坑：

- **源码和构建目录的路径必须是纯 ASCII**。中文路径会让 GStreamer 自带的 pkg-config 0.27.1 和
  Qt 的 `qmlimportscanner` 双双失败（后者会输出乱码 `鍥哄畾缈?`）。仓库里用了一个 ASCII 目录联接
  （`mklink /J C:\qgc C:\...\固定翼\qgc\qgroundcontrol`）绕开。
- **libevents 必须固定 commit**。`main` 分支在 2026-09 的提交 `0ef305fa` 引入了与当期 MAVLink
  不兼容的改动，导致 `receive.h` 报 `use of undeclared identifier 'mavlink_msg_target_field'`。
  已固定到其父提交 `077677a7d2f48f0af0eb8a4e4a7b6310956728bc`。

### QGC 4.0.11（Android 4.4）

```powershell
.\build-android-4.0.11.ps1              # 完整构建
.\build-android-4.0.11.ps1 -SkipCompile # 只重新打包
```

这套老工具链有三个必须绕过的坑，`qgc-4.0.11-android/README.md` 里有完整分析：

1. **`gradle.properties` 的反斜杠转义** —— `androiddeployqt` 写入 `C:\Qt5\5.12.6\...`，Java properties
   解析器把 `\` 当转义符吃掉，Gradle 报 `Cannot convert URL 'C:Qt55.12.6android_armv7/...'`。
2. **AGP 1.1.0 与 Groovy 3 不兼容** —— Qt 5.12.6 的模板请求 `com.android.tools.build:gradle:1.1.0`
   + 已于 2022 年关停的 `jcenter()`。AGP 1.1.0 是 Groovy 时代编译的插件，其
   `BasePlugin.verifyRetirementAge()` 调用的 `StringGroovyMethods.contains(String, String)`
   在 Gradle 8.x 携带的 Groovy 3.0.22 中已不存在。改用 AGP 8.8.0 + Gradle 8.12.1。
3. **AGP 8 的默认值变化** —— `aidl`/`buildConfig` 默认关闭（`QtLoader.java` 需要 Qt 自带 `.aidl`
   生成的 `IMinistro` 存根），`extractNativeLibs` 默认 `false`（Android 4.4 必须为 `true`），
   清单里的 `package=` 属性不再被支持。

> `androiddeployqt` **总是**用它自带的 Qt 模板覆盖 `build.gradle` / `gradle.properties`，所以
> `patches/` 里的文件必须在它跑完之后再复制进去 —— 这脚本已经做了，并且会在执行 Gradle 前校验落盘。

## 已知限制

- **4.0.11 构建不含视频流**：未安装 GStreamer 1.14.4，`androiddeployqt` 明确跳过了它。
- 两个 APK 都是 **debug 签名**（`~/.android/debug.keystore`），仅供测试，正式发布需自行签名。
- QGC 5.0 的源码没有收录在本仓库中（上游克隆体积过大且带子模块），请按 tag `Stable_V5.0` 自行克隆。
