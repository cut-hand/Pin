# Pin — 无钉子版

基于 [southflowpeak/Pin](https://github.com/southflowpeak/Pin) 的个人分支。移除置顶窗口上的钉子按钮，保留菜单栏操作。

<p align="center">
  <img src="pin-agent/Pin/Resources/Assets.xcassets/AppIcon.appiconset/pin-macOS-128x128@2x.png" width="128" height="128" alt="Pin App Icon">
</p>

<p align="center">
  <strong>Keep any window always on top on macOS</strong>
</p>

---

## 🎬 How it works

See Pin in action: [southflowpeak.com/pin](https://southflowpeak.com/pin)

## ✨ Features

- 🪟 **Pin Any Window** - Select any window and keep it always visible on top
- 🔍 **Adjustable Opacity** - Make pinned windows semi-transparent (10% - 100%) to see through them
- 📋 **Menu Bar Control** - Easily select and manage windows from the menu bar
- 🧼 **No Window Badge** - No pin icon or invisible button over the pinned window
- 🔔 **Manual Updates** - Check for Updates opens this fork’s GitHub Releases; no upstream auto-update

## 📥 Installation

### Download

👉 [**下载无钉子版 / Download**](https://github.com/cut-hand/Pin/releases/latest)

安装包同时支持 Apple 芯片和 Intel Mac。解压后将 `Pin.app` 放入“应用程序”，先退出原版再启动。此版本使用 ad-hoc 签名，未经 Apple 公证；若系统拦截，请到“系统设置 → 隐私与安全性”允许打开。首次使用可能需要重新授予屏幕录制权限。

### System Requirements

- macOS 14.0 (Sonoma) or later

### 🔐 Screen Recording Permission

Pin requires **Screen Recording** permission to function.

<p align="center">
  <img src="docs/images/screen-recording-dialog.png" width="400" alt="Screen Recording Permission Dialog">
</p>

On first launch, you'll see the dialog above. Click "Open System Settings" and enable Pin in the Privacy & Security settings.

<p align="center">
  <img src="docs/images/screen-recording-settings.png" width="400" alt="Screen Recording Settings">
</p>

#### 💡 Why is Screen Recording permission required?

Pin uses macOS's **ScreenCaptureKit API** to keep windows on top:

1. **SCStream** captures the target window's content in real-time
2. The captured frames are displayed using **AVSampleBufferDisplayLayer**
3. This layer is placed in a floating window set to `NSWindow.Level.floating`

This creates a "mirror window" that stays on top even when the original window is behind other windows. Since ScreenCaptureKit is used to capture window content, macOS requires Screen Recording permission.

## 🚀 Usage

1. Click the 📌 icon in the menu bar
2. Select "Pin Window..." and choose the window you want to pin
3. To unpin, select **Unpin** from the menu bar. The pinned window has no extra pin button.

## Build

Requires macOS and the Xcode Command Line Tools (`xcode-select --install`). No third-party frameworks or signing certificates are needed.

```sh
scripts/build-release.sh v0.1.4-no-badge.1
```

Output: `build/releases/v0.1.4-no-badge.1/Pin.app`, a universal ZIP, and its SHA-256 checksum. Each build uses a fresh version directory.

Pushing a `v*` tag runs the same build in GitHub Actions and publishes the ZIP and checksum as a Release. Builds are ad-hoc signed and are not notarized by Apple.

## 📄 License

MIT License
