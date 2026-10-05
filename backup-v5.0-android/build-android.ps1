# ============================================================
# QGroundControl - Android (arm64-v8a) build script
# Qt 6.8.3 + Android SDK + NDK r26b + JDK 17 + CMake 4.4.0
# Run: powershell -ExecutionPolicy Bypass -File .\build-android.ps1
# ============================================================
$ErrorActionPreference = 'Stop'

# ---------- Paths ----------
$SDK     = "$env:LOCALAPPDATA\Android\Sdk"
$NDK     = "$SDK\ndk\26.1.10909125"                          # NDK r26b (required by Qt 6.8.3)
$JAVA    = "C:\Program Files\Android\Android Studio\jbr"     # JDK 17
$QT      = "C:\Qt\6.8.3\android_arm64_v8a"                   # Qt for Android (target)
$QTHOST  = "C:\Qt\6.8.3\msvc2022_64"                         # Qt for Windows (host tools)
$CMAKE   = "C:\Program Files\CMake\bin"                      # CMake 4.4.0 (3.31.6 crashes on FindGit)
$NINJA   = "$SDK\cmake\3.22.1\bin"                           # ninja.exe

$SRC   = "C:\qgc\qgroundcontrol"   # ASCII junction -> ...\固定翼\qgc\qgroundcontrol
# IMPORTANT: build/source paths MUST be ASCII-only.
#  - GStreamer's bundled pkg-config 0.27.1 and Qt's qmlimportscanner
#    cannot handle non-ASCII (Chinese) paths.
$BUILD = "C:\qgc-build"

# ---------- Environment ----------
$env:JAVA_HOME        = $JAVA
$env:ANDROID_HOME     = $SDK
$env:ANDROID_SDK_ROOT = $SDK
$env:ANDROID_NDK_ROOT = $NDK
$env:ANDROID_NDK_HOME = $NDK
$env:ANDROID_NDK      = $NDK
$env:QT_ROOT_DIR      = $QT
$env:QT_HOST_PATH     = $QTHOST
# Sign with the Android debug keystore so the APK is installable (sideload) right away.
# For a real release, point these at your own keystore instead.
$env:QT_ANDROID_KEYSTORE_PATH       = "$env:USERPROFILE\.android\debug.keystore"
$env:QT_ANDROID_KEYSTORE_ALIAS      = "androiddebugkey"
$env:QT_ANDROID_KEYSTORE_STORE_PASS = "android"
$env:QT_ANDROID_KEYSTORE_KEY_PASS   = "android"
$env:PATH = "$CMAKE;$NINJA;$JAVA\bin;$QT\bin;$env:PATH"

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " QGC Android build" -ForegroundColor Cyan
Write-Host "   Source : $SRC"
Write-Host "   Build  : $BUILD"
Write-Host "   Qt     : $QT"
Write-Host "   NDK    : $NDK"
Write-Host "   JDK    : $JAVA"
Write-Host "   CMake  : $CMAKE"
Write-Host "===================================================" -ForegroundColor Cyan

# ---------- Configure ----------
Write-Host "`n[1/2] CMake configure..." -ForegroundColor Yellow
& "$CMAKE\cmake.exe" -S $SRC -B $BUILD -G Ninja `
    -DCMAKE_TOOLCHAIN_FILE="$QT\lib\cmake\Qt6\qt.toolchain.cmake" `
    -DCMAKE_PREFIX_PATH="$QT" `
    -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_WARN_DEPRECATED=FALSE `
    -DQT_ANDROID_ABIS="arm64-v8a" `
    -DQT_ANDROID_BUILD_ALL_ABIS=OFF `
    -DQT_HOST_PATH="$QTHOST" `
    -DQT_ANDROID_SIGN_APK=ON `
    -DQT_DEBUG_FIND_PACKAGE=ON `
    -DQGC_STABLE_BUILD=ON
if ($LASTEXITCODE -ne 0) { throw "CMake configure FAILED (exit $LASTEXITCODE)" }

# ---------- Build ----------
Write-Host "`n[2/2] Building..." -ForegroundColor Yellow
& "$CMAKE\cmake.exe" --build $BUILD --target all
if ($LASTEXITCODE -ne 0) { throw "Build FAILED (exit $LASTEXITCODE)" }

# ---------- Result ----------
Write-Host "`nBuild finished. APK:" -ForegroundColor Green
Get-ChildItem "$BUILD" -Recurse -Filter *.apk |
    Select-Object FullName, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}
