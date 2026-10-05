<#
.SYNOPSIS
    Builds QGroundControl 4.0.11 for Android 4.4+ (armeabi-v7a, 32-bit) using Qt 5.12.6.

.DESCRIPTION
    Reproduces the complete flow required by this legacy stack:

      1. qmake configure   - Qt 5.12.6 / android-clang / armeabi-v7a / release
      2. mingw32-make -j   - C++ compile + link libQGroundControl.so
      3. mingw32-make install INSTALL_ROOT=<android-build>/
                           - androiddeployqt refuses to continue unless the .so
                             is already inside <android-build>/libs/<abi>/
      4. androiddeployqt   - copies the Qt libs + QML assets, copies QGC's own
                             android/ package dir over Qt's template, patches the
                             manifest placeholders and writes gradle.properties
      5. re-apply patches  - androiddeployqt ALWAYS overwrites build.gradle and
                             gradle.properties with Qt 5.12.6's own templates
      6. gradle assembleDebug - AGP 8.8.0 + Gradle 8.12.1 + JDK 17

    Why step 5 is needed (three separate real bugs found the hard way):

      a) gradle.properties : androiddeployqt writes qt5AndroidDir with backslashes.
         The Java properties parser eats them, giving
             Cannot convert URL 'C:Qt55.12.6android_armv7/src/android/java/src'
         -> we rewrite the file using forward slashes.

      b) build.gradle : Qt 5.12.6's template requests
             com.android.tools.build:gradle:1.1.0   +   jcenter()
         jcenter() has been dead since 2022, and AGP 1.1.0 is a Groovy-compiled
         plugin whose BasePlugin.verifyRetirementAge() calls
         StringGroovyMethods.contains(String, String) - a method that no longer
         exists in the Groovy 3.0.22 shipped with Gradle 8.x. Applying it dies with
             NoSuchMethodError: 'boolean ...StringGroovyMethods.contains(...)'
         -> we build with AGP 8.8.0 + Gradle 8.12.1 instead (the same combination
            that already built QGC 5.0 on this machine, so ~/.gradle/caches already
            holds every artifact and nothing new needs downloading).

      c) AGP 8 defaults : aidl and buildConfig generation are OFF by default,
         and extractNativeLibs defaults to false. Qt 5.12's QtLoader.java needs the
         org.kde.necessitas.ministro AIDL stubs, and Android 4.4 needs the native
         libraries extracted from the APK.

.PARAMETER SkipCompile
    Skip steps 1-2 (reuse the existing release\libQGroundControl.so).

.PARAMETER Install
    After a successful build, run 'adb install -r' on the connected device.
    NOTE: QGC 4.0.11 and QGC 5.0 share the package name org.mavlink.qgroundcontrol,
    and 4.0.11 has a LOWER versionCode, so -d (allow downgrade) is used and this
    REPLACES any installed QGC 5.0.

.EXAMPLE
    .\build-android-4.0.11.ps1
    .\build-android-4.0.11.ps1 -SkipCompile
#>
[CmdletBinding()]
param(
    [switch]$SkipCompile,
    [switch]$Install,

    # Cosmetic: QGC's committed AndroidManifest.xml still carries a stale
    # "3.0.0-243-gd759437" version. Set to $false to keep it as-is.
    [bool]$FixVersionName = $true
)

# NOTE: deliberately "Continue", not "Stop".
# qmake / make / androiddeployqt write ordinary progress and warnings to stderr,
# and with ErrorActionPreference = "Stop" PowerShell turns any stderr output from a
# native command into a terminating error - which killed this script at the
# androiddeployqt step. Every native invocation below is therefore followed by an
# explicit $LASTEXITCODE check instead.
$ErrorActionPreference = "Continue"

# ------------------------------------------------------------------ configuration
$SRC         = "C:\qgc40"
$BUILD       = "C:\qgc40-build"
$ANDROID_OUT = "$BUILD\android-build"
$QT_ANDROID  = "C:\Qt5\5.12.6\android_armv7"
$MINGW_BIN   = "C:\Qt5\Tools\mingw730_64\bin"
$NDK         = "C:\qgc40-deps\android-ndk-r20b"
$JDK8        = "C:\qgc40-deps\jdk8"                             # for androiddeployqt's own steps
$JBR         = "C:\Program Files\Android\Android Studio\jbr"     # JDK 17, required by AGP 8.x
$SDK         = "$env:LOCALAPPDATA\Android\Sdk"
$PATCHES     = Join-Path $PSScriptRoot "qgc-4.0.11-android\patches"
$SETTINGS    = "$BUILD\android-libQGroundControl.so-deployment-settings.json"

$QMAKE    = Join-Path $QT_ANDROID "bin\qmake.exe"
$DEPLOYQT = Join-Path $QT_ANDROID "bin\androiddeployqt.exe"
$MAKE     = Join-Path $MINGW_BIN "mingw32-make.exe"
$ADB      = Join-Path $SDK "platform-tools\adb.exe"

function Write-Step($text) { Write-Host ""; Write-Host "=== $text ===" -ForegroundColor Cyan }

function Get-GradleBat {
    # Reuse the Gradle distribution that already built QGC 5.0, so the wrapper
    # never has to download anything.
    # AGP 8.8.0 requires Gradle >= 8.10.2, so parse the version and pick the
    # highest one that satisfies that. (A naive string regex matches "gradle-8.2"
    # as well, which fails with AGP 8.8.0.)
    $candidates = Get-ChildItem "$env:USERPROFILE\.gradle\wrapper\dists" -Recurse -Filter gradle.bat -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($_.FullName -match 'gradle-(\d+)\.(\d+)(?:\.(\d+))?') {
                [pscustomobject]@{
                    Path = $_.FullName
                    Maj  = [int]$Matches[1]
                    Min  = [int]$Matches[2]
                    Pat  = if ($Matches[3]) { [int]$Matches[3] } else { 0 }
                }
            }
        } | Where-Object { $_.Maj -eq 8 -and $_.Min -ge 10 }

    if (-not $candidates) {
        throw "No Gradle >= 8.10 found under $env:USERPROFILE\.gradle\wrapper\dists (AGP 8.8.0 needs >= 8.10.2)"
    }
    return ($candidates | Sort-Object Min, Pat -Descending | Select-Object -First 1).Path
}

# ------------------------------------------------------------------ sanity checks
foreach ($p in @($SRC, $QT_ANDROID, $MINGW_BIN, $NDK, $JBR, $SDK, $PATCHES)) {
    if (-not (Test-Path $p)) { throw "Missing required path: $p" }
}
if (-not (Test-Path $SETTINGS) -and $SkipCompile) {
    throw "No deployment settings at $SETTINGS - drop -SkipCompile for the first run."
}

# ------------------------------------------------------------------ 1 + 2 + 3
if (-not $SkipCompile) {
    $env:ANDROID_NDK_ROOT   = $NDK
    $env:ANDROID_NDK_HOST   = "windows-x86_64"
    $env:ANDROID_SDK_ROOT   = $SDK
    $env:ANDROID_HOME       = $SDK
    $env:ANDROID_NDK_PLATFORM = "android-16"
    $env:JAVA_HOME          = $JDK8
    $env:PATH = "$QT_ANDROID\bin;$MINGW_BIN;$env:JAVA_HOME\bin;$env:PATH"

    New-Item -ItemType Directory -Force -Path $BUILD | Out-Null
    Set-Location $BUILD

    Write-Step "1/6  qmake configure"
    & $QMAKE "$SRC\qgroundcontrol.pro" -spec android-clang "CONFIG+=release" `
             "ANDROID_TARGET_ARCH=armeabi-v7a" "CONFIG+=StableBuild"
    if ($LASTEXITCODE -ne 0) { throw "qmake failed ($LASTEXITCODE)" }

    Write-Step "2/6  compiling C++ (this takes a long time)"
    & $MAKE -j8
    if ($LASTEXITCODE -ne 0) { throw "make failed ($LASTEXITCODE)" }
}

# ---------------------------------------------------------------- 3 + 4 (deploy)
$env:ANDROID_NDK_ROOT   = $NDK
$env:ANDROID_NDK_HOST   = "windows-x86_64"
$env:ANDROID_SDK_ROOT   = $SDK
$env:ANDROID_HOME       = $SDK
$env:ANDROID_NDK_PLATFORM = "android-16"
$env:JAVA_HOME          = $JDK8
$env:PATH = "$QT_ANDROID\bin;$MINGW_BIN;$env:JAVA_HOME\bin;$env:PATH"
Set-Location $BUILD

Write-Step "3/6  make install INSTALL_ROOT=$ANDROID_OUT"
& $MAKE install "INSTALL_ROOT=$ANDROID_OUT/"
if ($LASTEXITCODE -ne 0) { throw "make install failed ($LASTEXITCODE)" }

$so = Join-Path $ANDROID_OUT "libs\armeabi-v7a\libQGroundControl.so"
if (-not (Test-Path $so)) { throw "libQGroundControl.so did not land in $ANDROID_OUT" }

# androiddeployqt is expected to end in "Building the android package failed!"
# (exit 14) because Qt 5.12.6's own template requests AGP 1.1.0 + the dead
# jcenter(), which cannot run on any modern Gradle. Everything we need has already
# been copied and patched by the time it gets that far, so exit 14 is tolerated
# here and the build is finished by Gradle in steps 5-6.
& $DEPLOYQT --input $SETTINGS --output $ANDROID_OUT --deployment bundled --gradle *> "$BUILD\deploy.log"
$deployExit = $LASTEXITCODE
Write-Host "androiddeployqt exit code: $deployExit (14 = expected, see note above)"
if ($deployExit -ne 0 -and $deployExit -ne 14) {
    Get-Content "$BUILD\deploy.log" -Tail 25 | ForEach-Object { "  | $_" }
    throw "androiddeployqt failed unexpectedly with exit code $deployExit"
}

# ------------------------------------------------------------------ 5. re-patch
Write-Step "5/6  re-applying the build.gradle / gradle.properties / manifest patches"

Copy-Item (Join-Path $PATCHES "build.gradle")       (Join-Path $ANDROID_OUT "build.gradle")       -Force
Copy-Item (Join-Path $PATCHES "gradle.properties")  (Join-Path $ANDROID_OUT "gradle.properties")  -Force

$agp = Get-Content (Join-Path $ANDROID_OUT "build.gradle") -Raw
if ($agp -notmatch 'com\.android\.tools\.build:gradle:8\.8\.0') {
    throw "build.gradle patch did not stick - refusing to run Gradle"
}
if ($agp -notmatch 'aidl = true') {
    throw "build.gradle is missing 'aidl = true' - QtLoader.java will fail to compile"
}

# AGP 8 dropped support for the package= attribute; the namespace now lives in
# build.gradle. Also refresh the stale version number QGC 4.0 committed.
$mf = Join-Path $ANDROID_OUT "AndroidManifest.xml"
$manifestText = Get-Content $mf -Raw
$manifestText = $manifestText -replace '\s*package="org\.mavlink\.qgroundcontrol"', ''
if ($FixVersionName) {
    $manifestText = $manifestText -replace 'android:versionName="[^"]*"\s+android:versionCode="[^"]*"', `
                                        'android:versionName="4.0.11" android:versionCode="401100"'
}
Set-Content -Path $mf -Value $manifestText -Encoding ASCII
if ((Get-Content $mf -Raw) -match 'package="org\.mavlink\.qgroundcontrol"') {
    throw "Failed to strip the package= attribute from AndroidManifest.xml"
}

# ------------------------------------------------------------------ 6. gradle
Write-Step "6/6  gradle assembleDebug (AGP 8.8.0 / Gradle 8.12.1 / JDK 17)"
$env:JAVA_HOME        = $JBR
$env:ANDROID_SDK_ROOT = $SDK
$env:ANDROID_HOME     = $SDK
$env:PATH = "$JBR\bin;$env:PATH"

$gradle = Get-GradleBat
Write-Host "using: $gradle"

Set-Location $ANDROID_OUT
& $gradle assembleDebug --console=plain
if ($LASTEXITCODE -ne 0) { throw "gradle assembleDebug failed ($LASTEXITCODE)" }

$apk = Get-ChildItem (Join-Path $ANDROID_OUT "build\outputs") -Recurse -Filter *.apk |
       Sort-Object Length -Descending | Select-Object -First 1
if (-not $apk) { throw "Gradle reported success but no APK was produced" }

Write-Host ""
Write-Host "APK: $($apk.FullName)" -ForegroundColor Green
Write-Host ("size: {0:N1} MB" -f ($apk.Length / 1MB)) -ForegroundColor Green

if ($Install) {
    Write-Step "installing on the connected device (-d: 4.0.11 has a lower versionCode than 5.0)"
    & $ADB install -r -d $apk.FullName
}
