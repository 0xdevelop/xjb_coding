# JetBrains 官方知识库入口

适用于 Windows、macOS、Linux 上的 JetBrains IDE。通用操作以对应产品、版本、操作系统和当前 Keymap 的官方页面为准；这里只维护入口，不复制手册、快捷键表或自造调试协议。

| 需要解决的问题 | 官方入口 |
| --- | --- |
| 产品文档选择（GoLand / IntelliJ IDEA / WebStorm 等） | https://www.jetbrains.com/help/ |
| GoLand Run/Debug 配置、项目文件与 Before launch | https://www.jetbrains.com/help/go/run-debug-configuration.html |
| 运行、停止与重新运行 | https://www.jetbrains.com/help/go/running-applications.html |
| 断点、调试会话与变量检查 | https://www.jetbrains.com/help/go/debugging-code.html |
| Windows / macOS / Linux Keymap 与冲突排查 | https://www.jetbrains.com/help/go/configuring-keyboard-and-mouse-shortcuts.html |

## 本项目的集成约定

- 首次打开仓库先检查根目录 `.run/*.run.xml`。`xjb_code` 已有 `.run/xjb_code-debug.run.xml`，优先核对右上方 Run/Debug 选择器是否已识别 `xjb_code-debug`，复用它；缺失时按官方配置文档排查 SDK、插件、信任状态与项目根，不另外造启动器。
- 配置保留 `$PROJECT_DIR$` 等 IDE 宏，不写当前电脑绝对路径或凭证。跨平台核对 Go SDK、工作目录和实际配置，不能凭 macOS 成功宣称 Windows/Linux 已实测。
- 多项目窗口并存时，每次运行/停止/重启前核对目标窗口项目路径、配置名与进程。只控制被授权的项目窗口；无法限定到窗口时不要通过反复激活整个应用抢占用户操作。用户要求取消控制时停止动作并释放控制会话。
- 用户本机 macOS Keymap 的操作经验：焦点放在非文件编辑区域后 `Command+R` 可重启。它是本地约定，执行前核对当前动作；Windows/Linux 不机械替换成 `Ctrl+R`。不确定快捷键时使用可见的 Run/Debug 动作，快捷键以官方 Keymap 与当前设置为准。
- 端口/PID/父进程用于核对目标；IDE 启动成功、进程存在、HTTP 可用和业务流程通过分别验收。只清理本次启动的进程，保留用户原有运行会话。

链接纳入 `scripts/update_upstreams.sh` 既有在线引用检查，状态写入同一份 `tmp/upstreams/.../api.tsv` / `api.json`；不下载镜像、不纳入源码 vendor、不把在线手册标成 MIT。
