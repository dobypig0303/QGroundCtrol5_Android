QGroundControl 5.0 的 Android `arm64-v8a` 构建，中文界面已补全。

## 包含内容

- Qt 6.8.3 / NDK r26b / **arm64-v8a**（64 位 ARM）
- minSdk **28**（Android 9），targetSdk 35
- 中文翻译补全：源码字符串 **55.5% → 99.9%**（3377/3382）、JSON 字符串 **35.4% → 96.6%**（769/796），共约 1800 条
- 已修复「把语言切到中文后，多数界面仍然是英文」的问题

## 安装

```bash
adb install -r QGroundControl-5.0-arm64-signed.apk
```

包名 `org.mavlink.qgroundcontrol`，debug 签名，仅供测试使用。

## 校验

```
SHA256: 4C82F03197196C3CE794F28CA3C2C127A8EE2F364F8691B9ED91F5402D1E820B
大小:   81.3 MB
```
