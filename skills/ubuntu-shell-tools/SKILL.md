---
name: ubuntu-shell-tools
description: Use 0xdevelop/shell_tools for Ubuntu 20.04+ server setup, software installation, Redis/Nginx configuration, network diagnostics, SSH transfers, and user management. Other xjb_coding skills inherit it as a commit-pinned dependency via fetch.sh when installing software. Use when the user requests shell_tools, these Ubuntu administration tasks, or another skill needs an Ubuntu install script already in shell_tools.
---

# Ubuntu shell_tools

本页仓库链接供人工浏览；执行时优先从本次加载的插件目录读取 URL 中 `blob/latest/` 后的同路径文件，不依赖固定安装目录或线上正文。单独安装时，URL 中 `skills/ubuntu-shell-tools/` 对应当前 Skill 目录。

脚本唯一来源是 [0xdevelop/shell_tools](https://github.com/0xdevelop/shell_tools)。本 Skill 提供选择、获取和执行约定，不复制脚本或维护一份容易过期的工具清单。

通过下面的 `fetch.sh` 获取外部仓当次 `main`，在同一任务内沿用记录的 commit。脚本不复制进插件，也不注册 Git submodule；运维脚本更新不必等插件发版。

其他 Skill 要在 Ubuntu 上安装软件时，先走本 Skill：当次副本已有对应安装脚本就用它；没有再用该软件自己的官方入口。不要自己 `wget` `shell_tools/main`，也不要把脚本复制进别的 Skill。

## 获取本次版本

在**当前任务项目根目录**运行本 Skill 的 [scripts/fetch.sh](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/ubuntu-shell-tools/scripts/fetch.sh)，用实际 Skill 安装路径替换下方占位路径：

```bash
bash /absolute/path/to/ubuntu-shell-tools/scripts/fetch.sh
```

每次开始新的工具任务时获取远端 `main`，浅克隆到当前项目 `tmp/shell-tools/` 下的新目录，并输出 `source`、`ref`、`commit`、`path`。同一任务后续步骤沿用这次目录和 commit，避免执行中途版本变化。获取脚本只下载，不执行上游脚本、不安装软件、不修改现有 checkout。需要 Bash、Git 和网络；Windows 使用 Git Bash，缺少时报告先决不满足，不用 PowerShell／CMD 重写，也不在 Windows 执行 Ubuntu 安装脚本。获取失败就报告错误，不能把旧目录说成最新版。用户明确指定本地修改或历史版本时遵从指定来源，并说明它不是远端最新版。

`shell_tools/main` 更新后，下次使用会获取更新，不需要等待 `xjb_coding` 发版；Skill 自身的规则变化仍需更新插件。这里的“最新”指本次获取时的远端 `main` commit，不代表最新 Release，也不表示后台持续同步。

## 选择和执行

1. 读取本次目录的 `README.md`、`LICENSE` 和相关脚本。先读开头契约，再核对实际执行路径中的下载、写入、服务操作和清理；说明与实现不一致时报告差异，不以注释代替核查。以当前文件发现工具和参数，新加入的工具无需修改 Skill 清单。现有仓库为 MIT；若许可发生变化，按项目许可约束处理。已 fetch 后用当次文件，不要再 `wget`，也不要照抄 README 里跳过 TLS 校验的下载命令。
2. 核对**目标机器**的 `/etc/os-release`、架构、权限、依赖与已有服务。Ubuntu 20.04+ 是使用范围，不代表每个脚本都已验证所有后续版本。macOS/Windows 可以获取和检查脚本；Ubuntu 管理脚本只在用户指定的 Ubuntu 目标执行。
3. 先明确要改变的状态和实际验收方式，再根据已有授权执行。检查脚本头部配置、交互、覆盖路径、服务重启和外部下载；只处理用户要求的组件。个别脚本可能关闭 Pro/ESM、修改 SSH 或网络配置，不能由“初始化”一词自行推定这些操作都在范围内。
4. 需要修改配置时，在本次目录旁建立工作副本，保留原始下载内容和 commit。凭证不写回仓库。工作文件、下载与日志均放当前项目 `tmp/`；远程执行时使用目标项目的 `tmp/`。
5. 检查选中脚本是否继续下载其他脚本。若存在指向 `shell_tools/main` 的调用，优先直接运行同次获取的对应组件；确需聚合入口时，在工作副本中将相关调用改成同一 commit 的地址或本地文件，并记录改动。依赖的软件源版本另行核实，固定仓库 commit 不等于固定全部外部依赖。不要照抄 README 中跳过 TLS 校验的下载命令。
6. 根据真实目的验收：安装服务检查配置及实际连接，请求或上传检查目标结果，网络改动检查目标连通性。脚本退出成功不代替这些结果。只清理本次用于验证的临时进程，复查无残留；用户要求安装并运行的服务属于交付状态。

交付时简要给出目标环境、脚本与 commit、配置改动和真实结果。没有 Ubuntu 目标时只完成获取、检查与执行准备，明确未做系统级实测。

## 其他 Skill 装软件

1. 用 `fetch.sh` 取当次副本，读当次 `README.md` 和脚本文件名，以当次文件为准，不凭记忆断定有没有某安装脚本。
2. 目标是 Ubuntu 20.04+，且当次已有能覆盖该软件的安装脚本：按本页「选择和执行」用那份脚本。调用形态与上游一致时用 `&&` 串成一行，核对所选脚本的成功自删、失败与取消保留路径；工作副本仍按第 5 条处理同次获取的组件。
3. 当次没有对应脚本，或目标不是 Ubuntu：用该软件官方入口。仍不自动安装；用户授权且目标机器明确后才执行。
