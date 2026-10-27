# xjb_coding

面向 Codex、Claude Code、Hermes Agent 及其他 Agent Skills 宿主的工作流 Skills 仓库：自驱编码（需求细化 → 拆任务 → TDD → 四层质量门禁 → 断点续做）、多用户多 agent 协同、Bruno 接口与流程测试、真浏览器 Web 调试（按实际能力优先官方 ego-browser）、草图生成 Web 原型、draw.io 可编辑图表、Archify 交互图表、Blender + Three.js 资产接入、本机 ComfyUI 工作流设计。一份 Skills，Codex、Claude Code、Cursor、Hermes 共用。

安装 plugin 后，宿主根据任务匹配对应 Skill，再按需读取其参考资料和脚本。需要跨会话、跨设备或多 Agent 共享状态时，连接独立部署的 [xjb_code](https://github.com/0xdevelop/xjb_code) 后端：每人一账号一把 API key，同一用户的所有 agent 共用；公司项目全实例可读、个人项目仅成员可读，编辑限记录归属人或管理员；看板实时显示任务、待批决策点与工具调用统计。

兼容目标是当前 Codex、Claude Code、Cursor、Hermes Agent；按各宿主的官方入口加载完整 Skill 目录，不依赖宿主专有继承机制。人工保存的工作流始终可以重新打开并作为下一轮输入，更新插件或切换宿主不会迁移、覆盖这些业务文件。每次发版区分入口校验、宿主实测和生成结果验收，不承诺未经验证的未来版本。

## 支持的 Skills 与领域

| Skill | 领域 | 支持的工作 |
| --- | --- | --- |
| [xjb-coding](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/xjb-coding/SKILL.md) | 软件开发 | 项目初始化、需求细化、任务分解、编码、四层质量门禁、断点续做 |
| [bruno-api-tests](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/bruno-api-tests/SKILL.md) | 接口与业务流程测试 | 关联 Bruno 官方 skills 与文档，生成完整集合、接通参数和文件，由 Agent 验证全新导入及真实场景 |
| [sketch-to-prototype](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/sketch-to-prototype/SKILL.md) | 产品与 Web 原型 | 从草图、截图和零散说明整理产品模型、UX 交互、可点击原型及编码交接 |
| [planning-prototype](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/planning-prototype/SKILL.md) | 需求规划原型 | 把一个需求做成可落码的自包含 HTML：两端界面对照、调用链与传参、各端 check 项、路径差异；综合 / 产品 / 技术三个视角同源生成；开工前按八项清单交互问询补齐必备项 |
| [blender-threejs](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/blender-threejs/SKILL.md) | 3D 资产与 Web 展示 | Blender 集合导出 GLB，接入 Three.js 材质、动画、粒子景深、缩放、重组与交互并在浏览器验收 |
| [comfyui-workflow](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/comfyui-workflow/SKILL.md) | 本机生成工作流 | 官方 Comfy Skills 原文 + 本机扩展，查询模型/节点、设计和保存可人工优化的 ComfyUI 画布 |
| [xjb-extends-jetbrains](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/xjb-extends-jetbrains/SKILL.md) | JetBrains IDE 调试 | 独立管理官方知识库引用、`.run` 集成、Run/Debug 与项目窗口边界，覆盖 Windows / macOS / Linux |
| [web-browser-debug](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/web-browser-debug/SKILL.md) | Web 调试与验收 | 按当前官方指南与实际能力选择 ego-browser（ego lite）或宿主 Playwright MCP；按确认契约与实际链路验收 |
| [ubuntu-shell-tools](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/ubuntu-shell-tools/SKILL.md) | Ubuntu 20.04+ 运维 | 使用时获取 shell_tools 最新 main，检查并使用服务器配置、软件安装、网络诊断和 SSH 等脚本 |
| [archify](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/archify/SKILL.md) | 交互图表 | 从描述、Mermaid 或源码证据生成独立 HTML：架构、流程、时序、数据流、状态、ER、类、树、时间线与执行瀑布图 |
| [drawio](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/drawio/SKILL.md) | 可编辑图表 | 随包提供 draw.io 官方 Skill 与 XML / Mermaid 参考，生成和修改原生 `.drawio`，通过已有 Desktop CLI 导出 PNG/SVG/PDF |

自驱编码流程不绑定单一编程语言。原型与 3D 页面默认面向桌面 Web，用户指定其他平台时按实际需求处理。普通 2D Web 任务不需要加载 Blender + Three.js Skill。

读取、审计 Skill 不会部署到目标项目；首次启用才按授权初始化，已有项目先恢复原项目、任务与会话，不覆盖状态或重复追加宿主规则。各宿主共用主引擎的恢复、锁与存档协议，MCP 可用且已认证时沿用服务端状态，确实不可用才用既有 markdown 回退。断点保存与提交、推送、发版解耦，各项 Git 操作分别遵守用户授权。验证按改动范围增量执行，最终验收仍满足项目既定标准；技能不能覆盖宿主安全要求、用户现行授权与已确认项目约定。

## 安装与更新

各宿主只读自己的清单。公共字段（名称、版本、作者、仓库、MCP 默认地址）只写在 `agents.public.json`，由 `scripts/sync_public_infos.sh` 按各宿主格式写入对应键。`git_tag.sh` 先改这份 version，再调同步。Claude 的 Git marketplace 清单不写 `version`，更新跟随仓库提交。工作流正文是 `skills/xjb-coding/SKILL.md`。

Skill、参考资料和脚本随插件一起安装、更新，用户无需逐个安装 Skill 或修改资料路径。README 与公开 Skill 入口的仓库链接使用 HTTPS，供人在插件预览中直接打开；Agent 执行时优先从宿主实际加载的插件目录读取 URL 中 `blob/latest/` 后的同路径文件，使用随包版本，不依赖线上正文、用户名、主目录、默认缓存位置或固定版本。单独安装某个 Skill 时，URL 中 `skills/<名称>/` 对应当前 Skill 目录。文档中的 `~/...` 仅标明宿主配置文件等约定位置。

### Codex

首次安装：

```bash
codex plugin marketplace add git@github.com:0xdevelop/xjb_coding.git --ref latest
codex plugin add xjb-coding@xjb-coding-codex-marketplace
```

从 Git marketplace 更新：

```bash
codex plugin marketplace upgrade xjb-coding-codex-marketplace
codex plugin add xjb-coding@xjb-coding-codex-marketplace
codex plugin list
```

若 marketplace 指向本地 checkout，先更新该 checkout，再执行 `codex plugin add`。安装或更新后新建一个 Codex 任务，让宿主发现新版 Skills。

### Claude Code

首次安装：

```text
/plugin marketplace add git@github.com:0xdevelop/xjb_coding.git
/plugin install xjb-coding@xjb-coding-marketplace
/reload-plugins
```

更新：

```text
/plugin marketplace update xjb-coding-marketplace
/plugin update xjb-coding@xjb-coding-marketplace
/reload-plugins
```

### Cursor

仓库根的 `.cursor-plugin/marketplace.json` 是 Cursor 的源索引，`.cursor-plugin/plugin.json` 是 Cursor 自己读的插件描述。安装源是 GitHub 上的本仓库，不使用某台机器的 `~/.cursor/skills` 符号链接，也不使用 Claude 插件缓存里的版本目录。发布脚本同步这份清单的 `version`。

团队：Dashboard → Plugins & MCPs → Team Marketplaces → Import from Repo，粘贴 `https://github.com/0xdevelop/xjb_coding`。Marketplace Settings 里打开 Auto Refresh，并给该仓库装上 Cursor GitHub App。成员在 Customize 里安装 `xjb-coding`，范围选用户。推送到被跟踪的分支后由 Auto Refresh 重新索引，最多约 10 分钟一批；正在跑的对话仍用启动时的版本，新开对话才读到新版本。

本机试装把仓库拷进 `~/.cursor/plugins/local/`，不要用指向仓库外的符号链接。官方 Marketplace 上架仍要单独提交审核；审核通过前，以上述 Git 导入为准。

地址和 key 不写进仓库正文。Cursor 与 Claude、Codex 一样保留插件注册；同一台机器上的地址是 `http://127.0.0.1:12100/`。Configure 的 `XJB_CODE_MCP_URL`、`XJB_CODE_API_KEY`，或 `~/.cursor/mcp.json` 里已经写好的私有地址，连得上就用那一条。连不上的注册不覆盖它，也不要因此走宿主登录。不要改 Codex、Claude 已经写好的配置。

官方依据：[Plugins](https://cursor.com/docs/plugins)、[Plugins reference](https://cursor.com/docs/reference/plugins)。

### Orca

在 Orca **设置 → 插件 → 管理源** 添加 `https://github.com/0xdevelop/xjb_coding.git`，ref 选 `latest`，再从该源安装 `0xdevelop.xjb-coding`。源索引是根目录 `orca-marketplace.json`，插件描述是 `orca-plugin.json`；发布脚本同步 plugin 版本。首次支持范围为 Orca `1.4.224` 及以上，更新时先刷新源，再审查并安装插件更新。

安装包包含本仓库现有的 `skills/`。目前的命令 **xjb_coding：填入 Skills 读取提示** 只把目录路径和 Skill 列表填到 agent 输入框；用户发送后，agent 才读取对应文件。它尚未完成 agent 的自动发现与注册，也不自动配置 MCP。Codex、Claude Code 及其他 agents 的工作方法、协作规则和状态后端仍由原有入口定义，Orca 部分只说明安装格式和实际入口行为。

Orca 当前没有原生 Skills / MCP 贡献点。该提示命令在工作区只有一个终端时可以确定目标；多个终端时不会写入提示。这是该命令的接口限制，不是 agents 的协作限制。MCP 配置沿用下方 [用户体系与凭证](#用户体系与凭证)。原生插件在桌面本机运行；SSH / 远程 agent 需在实际执行机器安装同版 Skills。已经安装的 Codex / Claude plugin 继续按原入口加载。

官方接口依据：[原生插件示例](https://github.com/stablyai/orca/tree/main/examples/plugins/hello-orca)、[plugin manifest](https://github.com/stablyai/orca/blob/main/src/shared/plugins/plugin-manifest.ts)、[marketplace](https://github.com/stablyai/orca/blob/main/src/shared/plugins/plugin-marketplace.ts)。原生安装、命令加载和后端协同分别验收，不能以插件出现在列表代替任务协同验证。

### Hermes Agent

支持 Agent Plugins v1 的 Hermes 可通过根级 `plugin.json` 安装整个 Skills 包；不需要 Python 注册脚本，也不需要挂载工作区 checkout。清单的名称、版本、作者与仓库地址继续由 `agents.public.json` 和 `scripts/sync_public_infos.sh` 统一同步，`git_tag.sh` 发版时自动执行，不单独维护 Hermes 版本。

首次通过 GitHub SSH 安装：

```bash
hermes plugins install git@github.com:0xdevelop/xjb_coding.git --no-enable
hermes plugins list
```

按安装输出或列表里的实际插件 ID 启用、检查与更新，不硬编码宿主生成的命名空间：

```bash
hermes plugins enable <实际插件ID>
hermes plugins doctor <实际插件ID> --ci
hermes plugins check-updates
hermes plugins update <实际插件ID>
```

这里安装仓库根目录，跟随默认分支；完整 SSH 地址保留为更新来源，`owner/repo` 简写在 Hermes 中使用 HTTPS。`--ref` 是固定完整提交 SHA，不是 `latest` 分支/标签选择器，固定后不会随普通更新漂移。安装或更新后新开 Hermes 会话，确认全部直属 `skills/*/SKILL.md` 都出现在技能列表并可读取；仅下载成功、插件出现在列表不算加载验收。

首次使用前在实际运行 Hermes 的账号下核对 GitHub SSH 认证和主机指纹。扫描出现 `caution` 时审阅 findings 并按宿主提示明确确认；`dangerous` 不放行。若旧版 Web 只显示安装失败而没有扫描确认信息，先用终端查看原因，不关闭安全扫描、不盲目 `--force`。安装 Skill 不会安装 Blender、ComfyUI、模型或浏览器；重型工具另做硬件与依赖预检。包内不带根级 `mcp.json`，可选 `xjb_code` 沿用户已有配置独立接入。

旧的单 Skill Hub 安装和整包插件是两套来源。先验收整包，再按原安装标识迁移需要替换的旧项，避免重复技能；不要先删除已有可用技能。外部 checkout 的更新由 checkout 自身负责，不是 `hermes plugins update` 管理的安装。宿主入口依据见 [Hermes 官方插件文档](https://hermes-agent.nousresearch.com/docs/user-guide/features/plugins)。

### 其他 Agent Skills 宿主 / 按需单独安装

可按需安装单个 Skill，或把本仓库 `skills/` 加入宿主的外部 Skills 路径。例如：

```bash
hermes skills install 0xdevelop/xjb_coding/skills/xjb-coding
hermes skills install 0xdevelop/xjb_coding/skills/bruno-api-tests
hermes skills install 0xdevelop/xjb_coding/skills/sketch-to-prototype
hermes skills install 0xdevelop/xjb_coding/skills/planning-prototype
hermes skills install 0xdevelop/xjb_coding/skills/blender-threejs
hermes skills install 0xdevelop/xjb_coding/skills/comfyui-workflow
hermes skills install 0xdevelop/xjb_coding/skills/xjb-extends-jetbrains
hermes skills install 0xdevelop/xjb_coding/skills/web-browser-debug
hermes skills install 0xdevelop/xjb_coding/skills/ubuntu-shell-tools
hermes skills install 0xdevelop/xjb_coding/skills/archify
hermes skills install 0xdevelop/xjb_coding/skills/drawio
```

单独分发 Skill 时保留其完整目录，包括 `references/` 和 `scripts/`。没有 Skills 加载机制的宿主，可直接读取对应 `SKILL.md`。Hermes 与其他宿主连接 `xjb_code` 的规则和 Codex、Claude Code、Cursor 相同，见 `skills/xjb-coding/SKILL.md`「xjb_code 怎么连」：本机地址只在端口在听时有效，已经写好的私有地址优先，连不上不走宿主登录，也不改其他宿主的配置。

已有本地 checkout（包括私有仓库）时，也可在 Hermes 的 `~/.hermes/config.yaml` 合并以下配置，路径替换为实际目录：

```yaml
skills:
  external_dirs:
    - /absolute/path/to/xjb_coding/skills
```

用 `hermes skills list` 确认发现结果。外部目录若可写，Hermes 也可能修改其中的 Skill；业务工作流仍保存在目标项目，官方快照的改动会在维护校验时拒绝覆盖。入口依据见 [Hermes 官方 Skills 文档](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills#external-skill-directories)。

### 工具与参考资料

- 安装 plugin 即包含上述 Skills；直接描述相关任务即可由宿主匹配，也可以点名 Skill。
- Bruno 测试由 `bruno-api-tests` 入口按任务读取官方 skills 和当前文档；维护沿原上游链接检查，用户更新插件后按原宿主加载方式使用，不需要另装官方 skills、运行维护脚本或同步后端。
- draw.io 官方 Skill、XML / Mermaid 参考和许可随本聚合包分发，沿现有上游快照机制更新，不需要另加 draw.io 插件市场或插件。原生 `.drawio` 生成不依赖 Desktop；Mermaid 转换、自动布局和图片/PDF 导出复用本机 draw.io Desktop。
- `ubuntu-shell-tools` 每次开始工具任务时，将 [shell_tools](https://github.com/0xdevelop/shell_tools) 最新 `main` 浅克隆到当前项目 `tmp/shell-tools/` 的独立目录，记录 commit，检查后按任务执行；上游脚本更新无需等待插件发版。获取失败明确报错，不自动执行旧副本。Skill 规则自身更新仍随插件发布，Ubuntu 各版本的适用性按选中脚本和目标机器核实。
- Blender + Three.js Skill 以十份 Three.js 官方 API 文档为入口，并附带固定版本的同仓库次级引用，覆盖 GLB 加载、动画、计时、纹理、相机控制、粒子与网格采样。资料按问题读取，不要求用户下载官方源码或初始化 submodule。
- 未收录内容或与目标项目版本不同的 API，再核对相应版本的官方资料。附带文档不等于完整离线知识库。
- Blender 本体需在本机安装，Blender MCP 可选；Three.js 是目标项目依赖，使用该项目的包管理器与 lockfile。安装 plugin 不会自动安装这些运行工具。

## 使用方法

### 自驱编码

在目标项目中初始化：

```text
使用 xjb_coding 初始化当前项目
```

开始工作：

```text
读 .auto_coding/start_coding.md
需求：实现邮箱登录，并验证真实登录主流程。
```

流程为：需求细化 → 按依赖拆任务 → 编码与验证 → 工程、架构、业务、专项门禁 → 交付或保存断点。controller / worker 协作规则统一在 `.auto_coding/AGENT_COLLABORATION.md`，Claude Code / Codex / Hermes 只是执行层不同（见 Skill「宿主差异」）。

| 模式 | 用法 | 结果 |
| --- | --- | --- |
| 完整流程 | `读 .auto_coding/start_coding.md` | 从需求推进到实现与验收 |
| 只细化需求 | `读 .auto_coding/start_coding.md --refine` | 细化需求后等待确认 |
| 只拆任务 | `读 .auto_coding/start_coding.md --task_plan` | 完成任务分解后停止 |
| Worker | `读 .auto_coding/start_coding.md --worker <agent-id>` | 执行一个有界任务 |
| 单轮驱动 | `读 .auto_coding/start_coding.md --tick [N]` | 最多处理 N 个任务后保存状态 |
| 断点续做 | `读 .auto_coding/start_coding.md，从断点续做` | 恢复未完成任务 |

### 草图生成 Web 原型

```text
使用 sketch-to-prototype。
读取 sketches/ 下全部草图和说明，输出产品模型、完整 UX 交互和可点击 Web 原型，并在浏览器走通主流程。
```

流程为：理解输入 → 产品模型 → UX 设计 → 可点击原型 → 浏览器验证 → 编码交接。阶段与必需产物见 [workflow.yaml](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/sketch-to-prototype/references/workflow.yaml)。

默认产物：

```text
product/
  PRODUCT.yaml
  UX_DECISIONS.md
  CODING_HANDOFF.md
prototype/
review/
  UX_REPORT.md
  screenshots/
```

`PRODUCT.yaml` 是产品模型事实源。页面、状态、动作和用户流使用稳定 ID，原型与审核结果需要对应这些 ID。面向用户的说明跟随对话主语言，机器字段和稳定 ID 不翻译。

### Bruno 接口与流程测试

```text
基于当前项目生成 Bruno 导入即用测试用例，覆盖已确认的业务流程。
复用现有配置与素材，接好鉴权、前后请求参数、附件和异步状态；由你验证全新导入与真实执行。
```

宿主匹配 [bruno-api-tests](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/bruno-api-tests/SKILL.md)，读取 [本仓库约定](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/bruno-api-tests/extend/local.md) 及 [官方知识索引](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/bruno-api-tests/references/official-docs.md)。不初始化额外工作区、创建后端工作流或另造执行器。已有集合按原格式和原入口修改；新集合提供完整文件与确定的 Send / Runner 入口，避免让用户补参数、脚本或附件。

Agent 在已有授权内复用真实配置、秘密引用和业务输入，核对目标 App / CLI 版本及沙箱。交付前验证目标 App 的全新导入、空运行状态下的真实流程及业务终态，CLI 补充回归；接口清单、静态检查、HTTP 2xx 或 mock 通过均不能作为“导入即用”的依据。确实缺少不可推导的凭证、业务输入、工具或权限时明确说明，不能交付占位集合并宣称可用。Bruno 是用户独立安装的工具，更新插件不修改其配置。

### Blender + Three.js

```text
使用 blender-threejs。
把 assets/product.blend 中的 Asset 集合导出为 GLB，接入现有 Three.js 页面，验证模型显示、旋转缩放和动画播放/暂停。
```

已有 GLB 时可以直接描述接入需求：

```text
把 assets/product.glb 接入当前页面，保留材质与动画，并处理加载失败和重试。
```

流程为：检查或制作资产 → 指定集合导出 GLB → Three.js 加载与交互 → 浏览器验收。保留可编辑 `.blend`，导出脚本拒绝覆盖已有 GLB；通过主流程后交付源资产、GLB 和接入代码。

需要粒子场景时：

```text
使用 blender-threejs，做一个有前后景深的粒子场景，支持平滑缩放和球体、环形之间的连续重组。
```

内置 [粒子示例](https://github.com/0xdevelop/xjb_coding/tree/latest/skills/blender-threejs/assets/particles) 可直接运行，支持拖动、滚轮、景深滑杆、暂停和静态 GLB 采样；具体启动方法与支持边界见 Skill。

### 本机 ComfyUI 工作流

```text
使用 comfyui-workflow，连接本机 ComfyUI。
基于我最后保存的 workflows/restore/v1/workflow.json 优化照片修复流程。
优先已有模型，保留画布布局和备注，只设计并检查，另存为 v2，交给我在 ComfyUI 里调整。
```

`comfyui-workflow` 入口明确加载 `extend/local.md`，再按任务参考随包附带的官方 `Comfy-Org/comfy-skills` 原文。`extend/` 是本项目的目录约定，不依赖宿主提供继承机制。官方原版当前面向 Comfy Cloud，保留为参考文件；插件只暴露本机入口，不注册官方云端命令或 MCP。

优先使用用户独立安装的官方 `comfy-mcp` / `comfy-cli`。运行 Skill 内 `scripts/check_tools.sh` 检查工具；缺失时按 [安装与关联说明](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/comfyui-workflow/references/local-api.md#官方工具安装与关联) 提示 Agent/用户，不自动安装。可选 Python 标准库辅助脚本支持本机查询、UI 基本检查与按字节保存。没有接入官方工具时不能宣称已关联；基本检查通过不等于实际生成成功。

可编辑画布保存在目标项目 `workflows/<用途>/<版本>/workflow.json`，人工调整后保存为下一轮输入。需要程序运行时，再从同版 ComfyUI 画布导出 `workflow.api.json`；环境与实际验证信息记入 `environment.json`。缓存放目标项目 `tmp/comfyui/`。关闭 Agent 后仍可在 ComfyUI 独立反复运行。

### Archify 交互图表

```text
使用 archify，按当前仓库的真实源码画一张请求调用链图，输出可独立打开的 HTML，保留 JSON 供后续修改。
```

来源为 [archify.si](https://archify.si) / [tt-a1i/archify](https://github.com/tt-a1i/archify)。本包通过 [archify Skill](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/archify/SKILL.md) 加载完整官方运行包和独立的 [本仓库适配](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/archify/extend/local.md)，无需另装全局 Archify、初始化 submodule 或 npm install；运行需 Node.js 18+。可按描述、Mermaid 或仓库证据生成十种图表；数值统计图、网站实现和需求规划原型使用各自对应工具。

官方 `finalize` 依次执行验证、生成、严格 provenance 检查和内置 Chrome/Chromium 浏览器检查。浏览器缺失或任一门禁失败须报告实际缺口；ego-browser 的人工交互/视觉检查另留证据，不替代官方自动检查回执。CLI 更新提示不授权覆盖随包版本，原文仍由本仓库统一维护。正式 HTML 与 JSON 保存在目标项目，缓存、临时截图与浏览器临时目录放目标项目 `tmp/`。

### draw.io 可编辑图表

```text
使用 drawio，按当前仓库画一张请求调用链图，保留可逐节点编辑的 .drawio；本机支持时同时导出 PNG。
```

通过 [drawio Skill](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/drawio/SKILL.md) 使用 [draw.io 官方 Skill](https://github.com/jgraph/drawio-mcp/tree/main/plugins/codex/drawio) 和同版参考资料。只安装、更新本聚合包即可加载，无需单独安装官方插件或 MCP。用到转换、布局或导出时才检测本机 Desktop CLI 及版本；缺少能力则说明影响，给出对应系统的官方安装/升级与续做步骤，同时先完成可生成的原生 XML。源文件始终保留，已有图表可继续人工或由 Agent 修改；交互式独立 HTML 图表沿用 Archify。验收区分源文件结构检查、实际导出与视觉/编辑检查，不把未运行的部分报为通过。

### Web 调试与浏览器验收

Web 类任务的真浏览器验证统一走 [web-browser-debug](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/web-browser-debug/SKILL.md)：先运行 `scripts/check_tools.sh`，读取 `ego-browser skill` 输出的完整当前指南，按实际能力选择官方 ego-browser 或宿主 Playwright MCP；没有可用层时报告缺口，经用户授权再安装。执行时按确认契约核对实际经过的服务、数据层、字段转换与落点，不因验收新增表、字段或写路径。结果页、证据目录和进程生命周期服从当前用户及目标项目约定，保留法律条款确认与用户空间接管等安全要求。`sketch-to-prototype` 的 UX Review 与 `blender-threejs` 的浏览器验证阶段都由它提供执行层。

## 连接 xjb_code（可选）

`xjb_coding` 定义工作步骤、约束和验收规则；`xjb_code` 管理确定性的任务、运行和产物状态。两者独立，未连接 MCP 时仍可使用项目本地文件完成工作。

使用已独立部署的后端地址；需要部署时，在服务端独立 checkout 按 `xjb_code` 的配置说明启动：

```bash
git clone git@github.com:0xdevelop/xjb_code.git
cd xjb_code
go run .
```

插件继续为 Codex、Claude Code、Cursor 注册 `xjb-code`。同一台机器上的地址是 `http://127.0.0.1:12100/`，端口在听才算连上。用户在自己的宿主配置里写了私有地址和密钥后，用那一条；升级插件不覆盖用户值。局域网或公司内部署写实际可达地址。连不上是地址问题，不是宿主登录。没有可用地址时 Skill 仍可用。各宿主的注册都保留，不因为改一个宿主就拆掉另一个。

### 用户体系与凭证

`xjb_code` 是多用户服务：每人一个账号。管理员登录 Dashboard `http://<host>:12101/`，右上「账号与 key」弹窗里建号，点选该账号即可为其签发一把 `xjbk_` 前缀的用户级 API key 交给本人；成员登录后同一入口只看到本人的 key，可自签。**同一用户的所有 agent（Claude Code、Codex、多台机器）共用这一把 key**，宿主以 HTTP `Authorization: Bearer <key>` 头发送；`agent_id` 只用于区分是哪一个 agent 在干活。授权规则：公司项目（`company`）本实例所有账号可查看任务详情与历史记忆；个人项目（`private`，新建默认）只有活跃成员可查看，管理员也不绕过；编辑只允许记录归属人或管理员；技能目录写操作（`skills.sync` 等）仅管理员。

Codex：在 `~/.codex/config.toml` 中添加或修改同名条目，用户配置优先于插件默认值。插件自带的 MCP 定义不能携带请求头，所以 key 必须写在这里（二选一）：

```toml
[mcp_servers.xjb-code]
url = "http://192.168.167.239:12100/"
http_headers = { Authorization = "Bearer xjbk_..." }
# 或者从环境变量读取：
# bearer_token_env_var = "XJB_CODE_API_KEY"
```

Claude Code：在用户级 `~/.claude/settings.json` 中合并地址；key 是 `sensitive` 配置项，通过 `/plugin` 的配置对话框填写（存入系统钥匙串，不落 `settings.json`）：

```json
{
  "pluginConfigs": {
    "xjb-coding@xjb-coding-marketplace": {
      "options": {
        "mcp_url": "http://192.168.167.239:12100/"
      }
    }
  }
}
```

这是 Claude 官方 `userConfig` / `pluginConfigs` 机制：插件声明 `mcp_url` 与 `mcp_api_key`，MCP 配置引用 `${user_config.mcp_url}` 和 `headers.Authorization = "Bearer ${user_config.mcp_api_key}"`。设置写在用户目录，不能放到项目 `.claude/settings.json`；如果从其他 marketplace 安装，键名使用实际的 `插件名@marketplace名`。Codex 和 Claude 使用各自的 MCP 配置文件，避免把一种宿主的占位符交给另一种宿主解析。

Cursor：`.mcp.cursor.json` 使用 `${XJB_CODE_MCP_URL}` 和 `${XJB_CODE_API_KEY}`。未改 Configure 时，同一台机器的地址是 `http://127.0.0.1:12100/`。Configure 或 `~/.cursor/mcp.json` 里已经写好私有 URL 和 `Authorization`、并且连得上时，用那一条。插件注册名 `plugin-xjb-coding-xjb-code` 没有连上时，不要用它覆盖已写好的配置，也不要调用宿主的 `mcp_auth`。这条限制同样适用于 Claude 和 Codex：连不上就改地址或密钥，不走宿主登录，也不改写其他宿主已经写好的配置。

先前通过 `claude mcp add --scope user` 添加的独立服务存放在 `~/.claude.json` 的顶层 `mcpServers.xjb-code`，直接在 `settings.json` 顶层写 `mcpServers` 无效。迁移到插件配置时，先复制原 URL 到上述 `mcp_url`；若旧条目还带认证或其他字段，先确认插件配置能够保留这些行为，再移除旧条目。仅 URL 的旧条目迁移后可运行 `claude mcp remove --scope user xjb-code`，防止以后改地址时加载两条连接。不要移除其他 MCP 服务。

修改后重启宿主；Codex 新开任务加载更新后的插件。保留其他配置，不编辑插件缓存。`127.0.0.1` 指运行客户端的电脑，独立服务器必须通过可达地址、代理或隧道连接。

通过两端 `/mcp` 确认连接和工具列表，再执行所需业务。连接失败与业务认证失败分开诊断：`initialize` / `tools/list` 与 `test` 不需要凭证，连接不上是地址、`bind_address` 或网络问题。命名空间失败，或工具列表里只剩宿主的 `mcp_auth`，同样是地址没有连上。禁止调用 `mcp_auth`，禁止走 Authenticate。受保护方法返回 `error_code=10004 permission denied` 才是凭证缺失、错误或已吊销，这时去用户自己的 Dashboard 重新签发 key 并更新宿主配置。

配置行为以 [Codex 官方 MCP 文档](https://developers.openai.com/codex/mcp)、[Claude Code 插件用户配置](https://code.claude.com/docs/en/plugins-reference#user-configuration) 和 [Claude Code 官方 MCP 文档](https://code.claude.com/docs/en/mcp) 为准。

支持 MCP 状态管理的工作流按需使用 `skills.source_status` / `skills.sync`，再通过 `workflow.*`、`requirement.*`、`task.*` 和 `artifact.add` 推进。不要为独立资产导出强制创建后端工作流。

- `xjb_coding` 是 Skills 和 workflow manifest 的唯一第一源，各宿主共享规则；`xjb_code` 保存固定运行快照和状态，不维护另一份可编辑规则。
- `project_id` 是工作空间；`user_id`、`device_id` 由服务端从凭证得出（API key 对应签发时的设备），不再作为入参传递。
- MCP 原型流程显式传入 `workflow.start.language`。`workflow.complete` 要求阶段任务完成且必需产物全部 `ready`。
- 不再使用时，关闭自己启动的后端进程。

## 上游引用与维护

`git_tag.sh` 发版前自动调用现有上游更新脚本；维护时也可单独运行：

```bash
bash scripts/update_upstreams.sh
```

macOS、Linux 和 Windows Git Bash 使用同一命令。更新链路只依赖 Bash 3.2+、Git、awk、grep、sed、curl、常用 Unix 工具，以及 `sha256sum` 或 `shasum`，不调用 jq、Python 或 Node；缺少工具时明确报错，不自动安装。脚本动态读取 `.gitmodules` 和 `skills/` 下已有 `SOURCE.tsv`，逐个更新原文、许可、API 文档及一层同仓库引用，不在脚本中维护来源名单。submodule 按已声明的 branch 更新；未声明 branch 且已有 revision 数字标签的快照延续该标签策略（Three.js 当前为 `rN`），其他来源跟随远端 HEAD（Comfy Skills 当前为 main）。非 submodule 的 Git 缓存放本项目 `tmp/upstreams/`。

首次接入 submodule 时，在它已有的 `.gitmodules` 段中声明 `references = skills/<skill>/references/<名称>` 作为引用输出目录；`referenceRoot` 可重复声明上游文件或目录，限定引用范围。不声明 `referenceRoot` 时默认选择 LICENSE、README、SKILL.md 和 commands 中的 Markdown；`referenceUrl` 可声明官方文档网址前缀，用于同仓库链接映射。这些是本仓库的自定义字段，不是 Git 原生更新选项。`SOURCE.tsv` 和 `SOURCE.json` 均由脚本生成，不需手写；之后会自动发现并更新。目录根保留为目录声明，每轮重新枚举其文件，使完整运行包的新模块和资源能随上游进入快照；每个包最多 512 个文件、单文件最多 4 MiB，超限停止。已有快照直接沿用当前目录，不要求重新登记。缺少输出位置、许可不符合要求或目录已有其他内容时停止，保留现状。

先准备全部候选文件、校验旧快照，再替换生成文件；人工修改过的原版、额外文件或 submodule 改动会被拒绝覆盖。只有旧清单登记且哈希未变的过期生成文件会被移除。`extend/`、业务工作流和用户独立安装的外部工具不在更新范围内；脚本不会暂存、提交、安装插件或下载模型。当前官方 Skills/文档的许可或入口结构不满足要求时停止，不能承诺未来每个上游版本无需适配。

更新或预演在 `tmp/upstreams/<时间>/report.tsv` 和 `report.json` 留下前后 commit、文件增删改、引用状态和官方 API 链接可达性；同目录保留候选及旧快照。在线链接的 HTTP 错误记为 `unavailable`，TLS/超时等网络错误记为 `unknown`，在终端和报告里提示，不阻止已经校验完整的本地快照更新。失败会明确报告是否已部分应用，不自动 reset/clean。版本变化后仍需检查官方步骤与 `extend/` 是否冲突，更新成功不代表模型生成效果或业务主流程已验证。

```bash
# 只校验本地快照与引用，不联网
bash scripts/update_upstreams.sh --check
# 下载候选并查看差异，不替换分发文件或移动 submodule HEAD
bash scripts/update_upstreams.sh --dry-run
# 需要更深的同仓库引用时（0–3 层，默认 1）
bash scripts/update_upstreams.sh --reference-depth 2
# 指定版本，适合重现一次已选定的更新
bash scripts/update_upstreams.sh --ref threejs r185 --ref comfy-skills <完整commit>
```

Three.js 文档原样保存到 `skills/blender-threejs/references/threejs/`；`SOURCE.tsv` 是维护清单，记录 revision、commit、文件哈希和引用映射；`SOURCE.json` 从清单生成供 Skill 按需读取，不作为脚本输入。Comfy Skills 原文保存到 `skills/comfyui-workflow/references/upstream/comfy-skills/`，保留 MIT LICENSE、README、全部 `claude-code/commands/*.md` 和范围内引用的资源；不注册其中的云端命令/MCP。本机差异只放 `extend/`。

Archify 完整官方 `archify/` 目录保存在 `skills/archify/references/.upstream/archify/archify/`，原始目录结构、字节内容与许可说明保持不变；清单位于上一级，来源为缓存型 Git 仓库，更新自动发现，无新增 submodule。隐藏的 `.upstream/` 随 Skill 一并分发，对跳过隐藏目录的发现器隔离原始入口；指定公开入口为顶层 `skills/archify/SKILL.md`。包含隐藏目录的递归扫描须另行验收，目录结构检查不代表真实宿主发现或安装通过。运行包内的开发 npm scripts 可能引用未分发的上游开发仓库，只使用 Skill 文档中的运行命令；本仓库适配保留在 `skills/archify/extend/`，不随原文更新覆盖。

**次级引用有明确边界。** 支持 Markdown 链接、引用式链接、HTML/MDX 的 `href`/`src`，按同一个 commit 递归收录允许的同仓库文档和小型图片/JSON 等资源，循环引用去重。单文件上限 4 MiB，每个来源上限 512 文件。缺失的相对链接会阻止更新；跨站链接、超出深度或范围的文件列在 `SOURCE.json`，不假装已经离线收录。源码不靠文档链接自动收录，完整运行包通过目录根显式纳入。复杂 MDX import、动态路由及隐含的类型名称不属于链接解析范围。

Comfy 官方 `Comfy-Org/docs` 文档仓库采用 GPL，按本项目规则只保留在线 API 引用，并检查 `local-api.md` 中 `docs.comfy.org` 链接的可达性，不随插件打包其正文。HTTP 可达不代表内容与当前本机版本一致；现场 `/object_info` 等接口仍是运行能力的依据。

Bruno 官方 skills 与文档通过 `skills/bruno-api-tests/references/official-docs.md` 在线关联，自动进入同一个官方链接检查，不新增来源分支或专用更新器。生成任务按需读取当前原文并核对目标版本；维护时的 HEAD 检查只记录可达性，不代表正文已同步或流程已验证。未经确认允许再分发的上游原文不随插件复制，用户无需额外执行维护命令。

普通 plugin 使用者无需运行这些维护命令。更新与校验统一使用 `update_upstreams.sh`，引用提取和 TSV 到 JSON 输出由同目录 `upstream_text.awk` 完成，不使用 JSON 解析器。清单和 JSON 都会校验，不要直接编辑生成文档。Git 属性固定脚本换行并禁止转换官方原文，避免 Windows autocrlf 破坏哈希。

## 仓库结构与发版

```text
agents.public.json               各宿主共用的名称、版本、作者、仓库与 MCP 默认地址
plugin.json                      Hermes / Agent Plugins v1 整包清单（由 sync_public_infos.sh 写入）
.claude-plugin/                  Claude Code manifest / marketplace
.codex-plugin/                   Codex manifest
.cursor-plugin/                  Cursor manifest / marketplace
.agents/plugins/                 Codex marketplace
.mcp.codex.json                  Codex MCP 默认地址
.mcp.claude.json                 Claude MCP 用户配置引用
.mcp.cursor.json                 Cursor MCP 变量占位
skills/
  xjb-coding/                    自驱编码
  bruno-api-tests/               Bruno 官方知识关联、完整集合生成与真实导入验收
  sketch-to-prototype/           草图生成 Web 原型
  planning-prototype/            需求规划原型（两端界面、调用链、check 项）
  blender-threejs/               Blender + Three.js 工作流、脚本与官方参考资料
  comfyui-workflow/              官方 Comfy Skills 原版、本机 extend 和查询/保存脚本
  xjb-extends-jetbrains/         独立 JetBrains IDE 调试、官方知识库引用与跨平台约定
  web-browser-debug/             真浏览器执行层选择（ego-browser 优先）、官方 Skill 引用与检查脚本
  ubuntu-shell-tools/            Ubuntu 运维脚本选择与使用时获取最新 shell_tools
  archify/                       Archify 官方完整运行包、交互图表入口与本仓库适配
vendor/three.js/                 固定版本的官方 submodule
scripts/
  claude_worker_bridge.sh        可选 Claude worker 桥接
  sync_public_infos.sh           把 agents.public.json 写入各宿主清单
  update_upstreams.sh            一键更新与校验官方来源、submodule 和次级引用
  upstream_text.awk              文本引用提取与 TSV 到 JSON 输出
git_tag.sh                       改公共 version、调同步、changelog、提交与标签推送
```

先校验改动并提交功能，再在干净的工作区发版：

```bash
bash scripts/update_upstreams.sh --check
./git_tag.sh
```

发版脚本先自动更新引用，上游获取或校验失败即停止，然后同步 plugin 与编码 Skill 版本、生成 changelog 并推送版本标签和 `latest`；GitHub Actions 只校验发布 commit 的固定快照后创建 Release。当前发布流程保留近期版本，并清理旧版本，执行前应核对脚本与工作区状态。

## 许可证与依赖边界

本仓库自有代码采用 [BSD-3-Clause](https://github.com/0xdevelop/xjb_coding/blob/latest/LICENSE)。随包引用的 Three.js 文档和 Comfy Skills 原文分别保留 [Three.js MIT](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/blender-threejs/references/threejs/LICENSE) 与 [Comfy Skills MIT](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/comfyui-workflow/references/upstream/comfy-skills/LICENSE)，来源及 commit 见各自的 `SOURCE.json`。

Archify 自有代码保留 [MIT LICENSE](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/archify/references/.upstream/archify/archify/LICENSE)。其品牌图标和嵌入字体分别适用 [第三方说明](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/archify/references/.upstream/archify/archify/THIRD_PARTY_NOTICES.md) 中的各自许可与商标条款（包括部分图标的非商业/相同方式共享条件及字体 OFL），不能将所有素材统一视为 MIT。

以下是用户单独安装的外部工具，不复制、链接其代码或随本仓库打包二进制；本仓库仅提供操作指引及标准接口调用：

| 外部工具 | 官方来源 / 许可证 |
| --- | --- |
| ComfyUI | [Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI) · [GPL-3.0](https://github.com/Comfy-Org/ComfyUI/blob/master/LICENSE) |
| comfy-cli | [Comfy-Org/comfy-cli](https://github.com/Comfy-Org/comfy-cli) · [GPL-3.0](https://github.com/Comfy-Org/comfy-cli/blob/main/LICENSE) |
| comfy-mcp | [Comfy-Org/comfy-mcp](https://github.com/Comfy-Org/comfy-mcp) · [AGPL-3.0-or-later 或商业许可](https://github.com/Comfy-Org/comfy-mcp/blob/main/LICENSE) |

外部工具按各自许可证使用。来源声明不替代许可证义务；将来复制、修改或重新分发其代码时，应重新评估许可要求。

新增开源依赖优先 MIT，其次 BSD、Apache-2.0，不引入 GPL/AGPL 库或隐式接入付费服务。Blender 作为外部工具使用，不在 plugin 中分发其 GPL 本体；第三方模型、贴图和扩展分别检查许可证。
