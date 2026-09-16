---
name: xjb-extends-jetbrains
description: Use JetBrains official documentation to run and debug projects in GoLand, IntelliJ IDEA, WebStorm, PyCharm, and other JetBrains IDEs on Windows, macOS, and Linux. Use for IDE Run/Debug configurations, shared .run files, keymaps, and controlling the correct project window; browser page debugging uses web-browser-debug.
metadata:
  version: "0.1.0"
  hermes:
    category: development
    tags: [jetbrains, ide, debug]
---

# xjb-extends-jetbrains

## 官方知识来源

先读取 [官方知识库入口](references/official-docs.md)，再按当前 IDE 产品、版本、操作系统和 Keymap 打开对应官方说明。GoLand 链接只用于 GoLand；其他产品从官方文档首页选择，不猜测跨产品快捷键或配置行为。

官方已有的操作说明只引用，不复制手册，不另造教程或维护快捷键表。只加载本次运行、调试或配置问题涉及的说明；链接由仓库现有上游检查流程维护。

## 本项目的集成约定

- 首次打开仓库先检查根目录 `.run/*.run.xml`。`xjb_code` 已有 `.run/xjb_code-debug.run.xml`，优先核对右上方 Run/Debug 选择器是否已识别 `xjb_code-debug`，复用它；缺失时按官方配置文档排查 SDK、插件、信任状态与项目根，不另外造启动器。
- 配置保留 `$PROJECT_DIR$` 等 IDE 宏，不写当前电脑绝对路径或凭证。跨平台核对当前 IDE 的 SDK / 运行时、工作目录和实际配置，不能凭 macOS 成功宣称 Windows/Linux 已实测。
- 多项目窗口并存时，每次运行/停止/重启前核对目标窗口项目路径、配置名与进程。只控制被授权的项目窗口；无法限定到窗口时不要通过反复激活整个应用抢占用户操作。用户要求取消控制时停止动作并释放控制会话。
- 用户本机 macOS Keymap 的操作经验：焦点放在非文件编辑区域后 `Command+R` 可重启。它是本地约定，执行前核对当前动作；Windows/Linux 不机械替换成 `Ctrl+R`。不确定快捷键时使用可见的 Run/Debug 动作，快捷键以官方 Keymap 与当前设置为准。
- 端口/PID/父进程用于核对目标；IDE 启动成功、进程存在、HTTP 可用和业务流程通过分别验收。只清理本次启动的进程，保留用户原有运行会话。

## 与浏览器调试的边界

IDE 的配置、启动、停止、调试和窗口选择属于本 Skill。需要验证 Web 页面时，另用可用的 web-browser-debug；单独安装本 Skill 也能处理 IDE 调试，不依赖浏览器 Skill。
