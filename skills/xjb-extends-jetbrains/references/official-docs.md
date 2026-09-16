# JetBrains 官方知识库入口

适用于 Windows、macOS、Linux 上的 JetBrains IDE。通用操作以对应产品、版本、操作系统和当前 Keymap 的官方页面为准；这里只维护入口，不复制手册、快捷键表或自造调试协议。

| 需要解决的问题 | 官方入口 |
| --- | --- |
| 产品文档选择（GoLand / IntelliJ IDEA / WebStorm 等） | https://www.jetbrains.com/help/ |
| GoLand Run/Debug 配置、项目文件与 Before launch | https://www.jetbrains.com/help/go/run-debug-configuration.html |
| 运行、停止与重新运行 | https://www.jetbrains.com/help/go/running-applications.html |
| 断点、调试会话与变量检查 | https://www.jetbrains.com/help/go/debugging-code.html |
| Windows / macOS / Linux Keymap 与冲突排查 | https://www.jetbrains.com/help/go/configuring-keyboard-and-mouse-shortcuts.html |

链接纳入 `scripts/update_upstreams.sh` 既有在线引用检查，状态写入同一份 `tmp/upstreams/.../api.tsv` / `api.json`；不下载镜像、不纳入源码 vendor、不把在线手册标成 MIT。
