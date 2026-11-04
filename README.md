# Pin

Mac 窗口置顶工具。**v0.1.4 起仅支持 Apple 芯片，要求 macOS 15.2 或更新版本。**

基于 [southflowpeak/Pin](https://github.com/southflowpeak/Pin) 重写。窗口上不显示钉子，也没有额外的透明按钮覆盖内容。

[下载最新版](https://github.com/cut-hand/Pin/releases/latest) · [下载旧版 v0.1.3（支持 Intel，macOS 14+）](https://github.com/southflowpeak/Pin/releases/tag/v0.1.3)

## 使用

1. 下载 `Pin-v0.1.4-macos-arm64.zip`，解压后将 `Pin.app` 放入“应用程序”。先退出原版 Pin，再启动新版。
2. 点击菜单栏图标，选择“选择窗口置顶…”，用系统选窗器选择一个窗口。
3. 点击置顶画面可切回原应用操作；鼠标移出后恢复置顶。窗口会跟随原窗口移动和缩放。
4. 菜单栏中可以调整透明度或“取消置顶”。

系统选窗器只捕获你选择的窗口，不申请辅助功能权限。画面仅在本机处理，不保存或上传。

安装包使用 ad-hoc 签名，未经 Apple 公证。如果系统阻止打开，可到“系统设置 → 隐私与安全性”允许打开。

## 开发

使用 Swift 6、Swift Package Manager、AppKit、ScreenCaptureKit 和 AVFoundation，无第三方依赖。

```sh
swift test --arch arm64 -Xswiftc -warnings-as-errors
scripts/build-release.sh v0.1.4
```

安装 Xcode Command Line Tools（`xcode-select --install`）即可构建，工具链需支持 Swift 6。输出位于 `build/releases/v0.1.4/`，包含应用、ZIP 和 SHA-256 校验文件。每个版本使用新的输出目录。

源码只有四个文件：菜单与生命周期、捕获会话、视频视图、窗口坐标计算。捕获和启动均使用 `async/await`；UI 在主 actor 上运行，视频回调在主队列同步消费，不跨 actor 传递视频帧。

推送 `v*` 标签会运行测试、仅构建 arm64，并生成 Release。“检查更新…”只打开本仓库的发布页面，不自动替换应用。

[v0.1.3](https://github.com/southflowpeak/Pin/releases/tag/v0.1.3) 保留上游原版；后续版本均仅支持 Apple 芯片。

## 许可证

沿用原项目的 MIT License，原作者及提交历史保留在 Git 记录中。
