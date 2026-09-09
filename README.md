# xjb_coding

面向 Codex、Claude Code、Hermes Agent 及其他 Agent Skills 宿主的工作流 Skills 仓库，支持自驱编码、草图生成 Web 原型，以及 Blender + Three.js 资产接入。

安装 plugin 后，宿主根据任务匹配对应 Skill，再按需读取其参考资料和脚本。需要跨会话、跨设备或多 Agent 共享状态时，可连接独立的 [xjb_code](https://github.com/0xdevelop/xjb_code) 后端。

## 支持的 Skills 与领域

| Skill | 领域 | 支持的工作 |
| --- | --- | --- |
| [xjb-coding](skills/xjb-coding/SKILL.md) | 软件开发 | 项目初始化、需求细化、任务分解、编码、四层质量门禁、断点续做 |
| [xjb-coding-codex](skills/xjb-coding-codex/SKILL.md) | Codex 宿主适配 | 为自驱编码提供 controller / worker 协作、改动审查与恢复规则 |
| [sketch-to-prototype](skills/sketch-to-prototype/SKILL.md) | 产品与 Web 原型 | 从草图、截图和零散说明整理产品模型、UX 交互、可点击原型及编码交接 |
| [blender-threejs](skills/blender-threejs/SKILL.md) | 3D 资产与 Web 展示 | Blender 集合导出 GLB，接入 Three.js 材质、贴图、动画、交互并在浏览器验收 |

自驱编码流程不绑定单一编程语言。原型与 3D 页面默认面向桌面 Web，用户指定其他平台时按实际需求处理。普通 2D Web 任务不需要加载 Blender + Three.js Skill。

## 安装与更新

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

### Hermes Agent / 其他 Agent Skills 宿主

可按需安装单个 Skill，或把本仓库 `skills/` 加入宿主的外部 Skills 路径。例如：

```bash
hermes skills install 0xdevelop/xjb_coding/skills/xjb-coding
hermes skills install 0xdevelop/xjb_coding/skills/sketch-to-prototype
hermes skills install 0xdevelop/xjb_coding/skills/blender-threejs
```

单独分发 Skill 时保留其完整目录，包括 `references/` 和 `scripts/`。没有 Skills 加载机制的宿主，可直接读取对应 `SKILL.md`。

### 工具与参考资料

- 安装 plugin 即包含上述四个 Skills；直接描述相关任务即可由宿主匹配，也可以点名 Skill。
- Blender + Three.js Skill 附带六份固定版本的 Three.js 官方 API 文档，覆盖 GLB 加载、动画、计时、纹理和相机控制。资料按问题读取，不要求用户下载官方源码或初始化 submodule。
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

流程为：需求细化 → 按依赖拆任务 → 编码与验证 → 工程、架构、业务、专项门禁 → 交付或保存断点。Codex 宿主同时使用 `xjb-coding-codex` 适配规则。

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

流程为：理解输入 → 产品模型 → UX 设计 → 可点击原型 → 浏览器验证 → 编码交接。阶段与必需产物见 [workflow.yaml](skills/sketch-to-prototype/references/workflow.yaml)。

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

## 连接 xjb_code（可选）

`xjb_coding` 定义工作步骤、约束和验收规则；`xjb_code` 管理确定性的任务、运行和产物状态。两者独立，未连接 MCP 时仍可使用项目本地文件完成工作。

先在独立 checkout 启动后端：

```bash
git clone git@github.com:0xdevelop/xjb_code.git
cd xjb_code
go run .
```

仓库根 `.mcp.json` 已声明默认地址 `http://localhost:12100/`。宿主未从 plugin 加载配置时，可显式添加：

```bash
codex mcp add xjb-code --url http://localhost:12100/
claude mcp add --transport http xjb-code http://localhost:12100/
```

支持 MCP 状态管理的工作流按需使用 `skills.source_status` / `skills.sync`，再通过 `workflow.*`、`requirement.*`、`task.*` 和 `artifact.add` 推进。不要为独立资产导出强制创建后端工作流。

- `xjb_coding` 是 Skills 和 workflow manifest 的唯一第一源，各宿主共享规则；`xjb_code` 保存固定运行快照和状态，不维护另一份可编辑规则。
- `project_id`、`user_id`、`device_id` 分别表示工作空间、成员和设备来源，用于关系校验与追踪，不等于身份认证；对外部署需要可信认证层。
- MCP 原型流程显式传入 `workflow.start.language`。`workflow.complete` 要求阶段任务完成且必需产物全部 `ready`。
- 不再使用时，关闭自己启动的后端进程。

## 上游引用与维护

Three.js 官方源码由 `vendor/three.js` submodule 固定 commit。选定文档原样同步到 `skills/blender-threejs/references/threejs/`，随 plugin 分发，保留 MIT LICENSE 和记录版本、commit、文件哈希的 `SOURCE.json`。

这是维护仓库时的步骤，普通 plugin 用户无需执行：

```bash
git submodule update --init vendor/three.js
# 在 vendor/three.js 中 fetch 并选择已审核的发布 commit；不自动追随 latest/main。
git add vendor/three.js
python3 scripts/sync_threejs_docs.py --write
python3 scripts/sync_threejs_docs.py --check
git add skills/blender-threejs/references/threejs
```

不直接编辑生成文档。更新引用后，检查 API 变化并复测 Blender → GLB → Three.js 主流程；目标业务项目不会因此自动升级 Three.js。

## 仓库结构与发版

```text
.claude-plugin/                  Claude Code manifest / marketplace
.codex-plugin/                   Codex manifest
.agents/plugins/                 Codex marketplace
.mcp.json                        xjb_code 默认 MCP 地址
skills/
  xjb-coding/                    自驱编码
  xjb-coding-codex/              Codex 宿主适配
  sketch-to-prototype/           草图生成 Web 原型
  blender-threejs/               Blender + Three.js 工作流、脚本与官方参考资料
vendor/three.js/                 固定版本的官方 submodule
scripts/
  claude_worker_bridge.sh        可选 Claude worker 桥接
  sync_threejs_docs.py           官方文档同步与校验
git_tag.sh                       版本同步、changelog、提交与标签推送
```

先校验改动并提交功能，再在干净的工作区发版：

```bash
python3 scripts/sync_threejs_docs.py --check
./git_tag.sh
```

发版脚本同步 plugin 与编码 Skill 版本、生成 changelog 并推送版本标签和 `latest`；GitHub Actions 校验官方文档后创建 Release。当前发布流程保留近期版本，并清理旧版本，执行前应核对脚本与工作区状态。

## 许可证与依赖边界

本仓库采用 [BSD-3-Clause](LICENSE)。引用的 Three.js 官方代码与文档保留其 [MIT 许可证](skills/blender-threejs/references/threejs/LICENSE)。

新增开源依赖优先 MIT，其次 BSD、Apache-2.0，不引入 GPL/AGPL 库或隐式接入付费服务。Blender 作为外部工具使用，不在 plugin 中分发其 GPL 本体；第三方模型、贴图和扩展分别检查许可证。
