# ego-browser 官方 Skill：位置、加载与升级

## 官方来源与边界

- 产品：ego lite（macOS App，Bundle `com.citrolabs.ego.lite`），官网 <https://lite.ego.app/>。
- CLI：App 首次运行完成 onboarding 后把 `ego-browser` 注册到 `~/.local/bin/ego-browser`（符号链接指向 `~/.local/share/ego/active_version_dir/Helpers/ego-browser`）。
- 官方 Skill：`~/.local/share/ego/ego-skills/`（含 `SKILL.md`、`references/{api,install,clearing-state}.md`、`scripts/install.sh`）。App 升级时同步更新，`ego-browser --version` 与 Skill 内容对应同一版本。
- 该目录没有公开 Git 仓库和许可证文件，本仓库**不 vendor、不改写**其内容，也不进入 `scripts/update_upstreams.sh` 的快照机制；引用方式是「按本机路径读取当前版本」。
- 官方安装脚本仅支持 macOS（`uname -s` 为 `Darwin`）。其他平台按官网指引由用户安装；没有 ego lite 时本 Skill 退到宿主 Playwright MCP。

## 宿主如何加载官方 Skill

| 宿主 | 做法 |
| --- | --- |
| Claude Code | onboarding 已创建 `~/.claude/skills/ego-browser -> ~/.local/share/ego/ego-skills`；会话内 `Skill` 工具可直接调用 `ego-browser`。缺失时补建同名符号链接。 |
| Codex | Codex 支持符号链接的 skill 目录，扫描 `~/.agents/skills`、仓库各级 `.agents/skills`：`ln -s ~/.local/share/ego/ego-skills ~/.agents/skills/ego-browser`，任务内用 `$ego-browser` 调用；或按绝对路径读取 `~/.local/share/ego/ego-skills/SKILL.md`。 |
| Hermes Agent | `hermes skills install` 只接受仓库来源；本地目录按 Hermes 外部 Skills 路径配置加入，或按绝对路径读取。 |

无论哪种宿主，都读**同一份**本机文件，不在各宿主目录复制副本；复制会在 App 升级后漂移。

## 每次会话的核对

```bash
bash <skill-dir>/scripts/check_tools.sh
```

脚本只读不写：报告平台、`ego-browser --version`、官方 Skill 目录与关键文件、Claude 侧符号链接是否指向官方目录。任一项缺失时给出下面的处理，不自动安装。

## 安装与关联（用户授权后）

```bash
# macOS：官方脚本下载 DMG、安装到 /Applications、去除隔离属性并打开 App
sh ~/.local/share/ego/ego-skills/scripts/install.sh      # 已有官方目录时
# 首次安装没有官方目录：由用户从 https://lite.ego.app/ 下载安装
```

安装后用户在 App 内完成 onboarding（可选导入 Chrome 等浏览器数据）；onboarding 才会注册 `ego-browser` 命令。`~/.local/bin` 不在 PATH 时临时 `export PATH="$HOME/.local/bin:$PATH"`。验证：

```bash
ego-browser nodejs -e "console.log('ego-browser ready')"
```

## 升级

官方 Skill 输出含 `[ego-browser:notice]` 表示 App 有更新：先完成当前浏览器任务，告知用户，**经用户批准**再执行 `ego-browser upgrade`，升级后重新读取官方 `SKILL.md`。不要在任务中途升级。

## 与 Playwright MCP 的差异（选层依据）

| 维度 | ego-browser | Playwright MCP |
| --- | --- | --- |
| 平台 | 仅 macOS | 跨平台 |
| 登录态 | 复用用户 profile，Agent 任务空间隔离 | 独立 profile，需重新登录 |
| 并发 | 多会话各自任务空间 | 同一 profile 被一个会话独占（"Browser is already in use"） |
| 接口 | 官方自定义 TaskSpace / Page API（非 Playwright） | Playwright 工具集 |
| 状态清理 | profile 级清理会波及用户全部站点，须按官方 `clearing-state.md` | 独立 profile，影响面小 |

用户 2026-08-26 指示：调试默认用 ego lite，Playwright MCP 作为能力缺口时的临时回退，回退前先报告缺口。
