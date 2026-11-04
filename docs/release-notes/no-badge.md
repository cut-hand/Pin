移除置顶窗口左上角的钉子图标及其点击区域，画面上不再显示额外按钮。

- 保留窗口置顶、透明度调整和鼠标交互。
- 通过菜单栏的 **Unpin** 取消置顶。
- “Check for Updates...” 打开本仓库的 Releases，不会自动安装上游原版。
- 支持 macOS 14 及以上，安装包同时包含 Apple 芯片和 Intel 架构。

下载 `Pin-*-macos-universal.zip`，解压后将 `Pin.app` 放入“应用程序”。请先退出原版 Pin，避免同时运行。

此定制版使用临时签名（ad-hoc），未经 Apple 公证。若系统阻止打开，可在“系统设置 → 隐私与安全性”中允许打开；首次启动可能需要重新授予屏幕录制权限。

本机已通过双架构编译、签名完整性和安装包检查；Intel 真机与实际置顶交互尚未验证。

原项目：[southflowpeak/Pin](https://github.com/southflowpeak/Pin)。
