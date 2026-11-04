从 v0.1.4 开始，仅支持 Apple 芯片（arm64），最低 macOS 15.2。

- 移除置顶画面上的钉子及其点击区域。
- 使用系统原生选窗器，保留置顶、透明度、窗口位置同步和点击操作原应用。
- 使用 Swift 6 严格并发检查、async/await 和 Swift Package Manager。
- 移除旧状态机、Raycast/AppleScript 通信、辅助功能权限请求及自动更新依赖。
- 无第三方依赖，也不会自动安装上游版本。

下载 `Pin-v0.1.4-macos-arm64.zip`，解压后将 `Pin.app` 移至“应用程序”。先退出原版再启动。

此构建使用 ad-hoc 签名，未经 Apple 公证。若系统阻止打开，可在“系统设置 → 隐私与安全性”允许打开。

需要 Intel 支持或 macOS 14 兼容性，请下载[上游 v0.1.3](https://github.com/southflowpeak/Pin/releases/tag/v0.1.3)。
