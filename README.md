# xjb_coding

面向 Codex、Claude Code、Hermes Agent 及其他 Agent Skills 宿主的工作流 Skills 仓库，支持自驱编码、草图生成 Web 原型、Blender + Three.js 资产接入，以及本机 ComfyUI 工作流设计。

安装 plugin 后，宿主根据任务匹配对应 Skill，再按需读取其参考资料和脚本。需要跨会话、跨设备或多 Agent 共享状态时，可连接独立的 [xjb_code](https://github.com/0xdevelop/xjb_code) 后端。

兼容目标是当前 Codex、Claude Code、Hermes Agent；按各宿主的官方入口加载完整 Skill 目录，不依赖宿主专有继承机制。人工保存的工作流始终可以重新打开并作为下一轮输入，更新插件或切换宿主不会迁移、覆盖这些业务文件。每次发版区分入口校验、宿主实测和生成结果验收，不承诺未经验证的未来版本。

## 支持的 Skills 与领域

| Skill | 领域 | 支持的工作 |
| --- | --- | --- |
| [xjb-coding](skills/xjb-coding/SKILL.md) | 软件开发 | 项目初始化、需求细化、任务分解、编码、四层质量门禁、断点续做 |
| [xjb-coding-codex](skills/xjb-coding-codex/SKILL.md) | Codex 宿主适配 | 为自驱编码提供 controller / worker 协作、改动审查与恢复规则 |
| [sketch-to-prototype](skills/sketch-to-prototype/SKILL.md) | 产品与 Web 原型 | 从草图、截图和零散说明整理产品模型、UX 交互、可点击原型及编码交接 |
| [blender-threejs](skills/blender-threejs/SKILL.md) | 3D 资产与 Web 展示 | Blender 集合导出 GLB，接入 Three.js 材质、动画、粒子景深、缩放、重组与交互并在浏览器验收 |
| [comfyui-workflow](skills/comfyui-workflow/SKILL.md) | 本机生成工作流 | 官方 Comfy Skills 原文 + 本机扩展，查询模型/节点、设计和保存可人工优化的 ComfyUI 画布 |
| [web-browser-debug](skills/web-browser-debug/SKILL.md) | Web 调试与验收 | 选定真浏览器执行层：macOS 优先官方 ego-browser（ego lite），回退宿主 Playwright MCP；统一截图、证据与任务空间约定 |

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
hermes skills install 0xdevelop/xjb_coding/skills/comfyui-workflow
hermes skills install 0xdevelop/xjb_coding/skills/web-browser-debug
```

单独分发 Skill 时保留其完整目录，包括 `references/` 和 `scripts/`。没有 Skills 加载机制的宿主，可直接读取对应 `SKILL.md`。

已有本地 checkout（包括私有仓库）时，也可在 Hermes 的 `~/.hermes/config.yaml` 合并以下配置，路径替换为实际目录：

```yaml
skills:
  external_dirs:
    - /absolute/path/to/xjb_coding/skills
```

用 `hermes skills list` 确认发现结果。外部目录若可写，Hermes 也可能修改其中的 Skill；业务工作流仍保存在目标项目，官方快照的改动会在维护校验时拒绝覆盖。入口依据见 [Hermes 官方 Skills 文档](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills#external-skill-directories)。

### 工具与参考资料

- 安装 plugin 即包含上述五个 Skills；直接描述相关任务即可由宿主匹配，也可以点名 Skill。
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

需要粒子场景时：

```text
使用 blender-threejs，做一个有前后景深的粒子场景，支持平滑缩放和球体、环形之间的连续重组。
```

内置 [粒子示例](skills/blender-threejs/assets/particles/) 可直接运行，支持拖动、滚轮、景深滑杆、暂停和静态 GLB 采样；具体启动方法与支持边界见 Skill。

### 本机 ComfyUI 工作流

```text
使用 comfyui-workflow，连接本机 ComfyUI。
基于我最后保存的 workflows/restore/v1/workflow.json 优化照片修复流程。
优先已有模型，保留画布布局和备注，只设计并检查，另存为 v2，交给我在 ComfyUI 里调整。
```

`comfyui-workflow` 入口明确加载 `extend/local.md`，再按任务参考随包附带的官方 `Comfy-Org/comfy-skills` 原文。`extend/` 是本项目的目录约定，不依赖宿主提供继承机制。官方原版当前面向 Comfy Cloud，保留为参考文件；插件只暴露本机入口，不注册官方云端命令或 MCP。

优先使用用户独立安装的官方 `comfy-mcp` / `comfy-cli`。运行 Skill 内 `scripts/check_tools.sh` 检查工具；缺失时按 [安装与关联说明](skills/comfyui-workflow/references/local-api.md#官方工具安装与关联) 提示 Agent/用户，不自动安装。可选 Python 标准库辅助脚本支持本机查询、UI 基本检查与按字节保存。没有接入官方工具时不能宣称已关联；基本检查通过不等于实际生成成功。

可编辑画布保存在目标项目 `workflows/<用途>/<版本>/workflow.json`，人工调整后保存为下一轮输入。需要程序运行时，再从同版 ComfyUI 画布导出 `workflow.api.json`；环境与实际验证信息记入 `environment.json`。缓存放目标项目 `tmp/comfyui/`。关闭 Agent 后仍可在 ComfyUI 独立反复运行。

### Web 调试与浏览器验收

Web 类任务的真浏览器验证统一走 [web-browser-debug](skills/web-browser-debug/SKILL.md)：先运行 `scripts/check_tools.sh`，macOS 上有 ego lite 时优先用官方 `ego-browser` Skill（App 随身携带于 `~/.local/share/ego/ego-skills`，本仓库只引用不复制，Claude Code 经 `~/.claude/skills/ego-browser` 符号链接加载，Codex 可链接到 `~/.agents/skills`），否则回退宿主 Playwright MCP，两者都没有时报告缺口、经用户授权再安装。叠加约定：一个目标一个 TaskSpace、联调结束保留结果页、截图落目标项目 `tmp/`、不做 profile 级状态清理。`sketch-to-prototype` 的 UX Review 与 `blender-threejs` 的浏览器验证阶段都由它提供执行层。

## 连接 xjb_code（可选）

`xjb_coding` 定义工作步骤、约束和验收规则；`xjb_code` 管理确定性的任务、运行和产物状态。两者独立，未连接 MCP 时仍可使用项目本地文件完成工作。

使用已独立部署的后端地址；需要部署时，在服务端独立 checkout 按 `xjb_code` 的配置说明启动：

```bash
git clone git@github.com:0xdevelop/xjb_code.git
cd xjb_code
go run .
```

插件自动注册 `xjb-code`，默认地址为 `http://127.0.0.1:12100/`。本机使用无需改地址；私有部署时修改下面的用户级配置，升级插件不会覆盖用户值。保留服务要求的完整路径。

### 用户体系与凭证

`xjb_code` 是多用户服务：每人一个账号（管理员用 `auth.admin.create_account` 建号），登录 Dashboard `http://<host>:12101/` 后在「API key」面板签发一把 `xjbk_` 前缀的用户级 API key。**同一用户的所有 agent（Claude Code、Codex、多台机器）共用这一把 key**，宿主以 HTTP `Authorization: Bearer <key>` 头发送；`agent_id` 只用于区分是哪一个 agent 在干活。授权规则：所有用户可查看全部项目与任务；编辑只允许记录归属人；管理员拥有全部权限；技能目录写操作（`skills.sync` 等）仅管理员。

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

先前通过 `claude mcp add --scope user` 添加的独立服务存放在 `~/.claude.json` 的顶层 `mcpServers.xjb-code`，直接在 `settings.json` 顶层写 `mcpServers` 无效。迁移到插件配置时，先复制原 URL 到上述 `mcp_url`；若旧条目还带认证或其他字段，先确认插件配置能够保留这些行为，再移除旧条目。仅 URL 的旧条目迁移后可运行 `claude mcp remove --scope user xjb-code`，防止以后改地址时加载两条连接。不要移除其他 MCP 服务。

修改后重启宿主；Codex 新开任务加载更新后的插件。保留其他配置，不编辑插件缓存。`127.0.0.1` 指运行客户端的电脑，独立服务器必须通过可达地址、代理或隧道连接。

通过两端 `/mcp` 确认连接和工具列表，再执行所需业务。连接失败与业务认证失败分开诊断：`initialize` / `tools/list` 与 `test` 不需要凭证，连接不上是地址、`bind_address` 或网络问题；受保护方法返回 `error_code=10004 permission denied` 才是凭证缺失、错误或已吊销，这时去 Dashboard 重新签发 key 并更新宿主配置。这不是宿主的 MCP OAuth 流程，不要走 Authenticate 按钮。

配置行为以 [Codex 官方 MCP 文档](https://developers.openai.com/codex/mcp)、[Claude Code 插件用户配置](https://code.claude.com/docs/en/plugins-reference#user-configuration) 和 [Claude Code 官方 MCP 文档](https://code.claude.com/docs/en/mcp) 为准。

支持 MCP 状态管理的工作流按需使用 `skills.source_status` / `skills.sync`，再通过 `workflow.*`、`requirement.*`、`task.*` 和 `artifact.add` 推进。不要为独立资产导出强制创建后端工作流。

- `xjb_coding` 是 Skills 和 workflow manifest 的唯一第一源，各宿主共享规则；`xjb_code` 保存固定运行快照和状态，不维护另一份可编辑规则。
- `project_id` 是工作空间；`user_id`、`device_id` 由服务端从凭证得出（API key 对应签发时的设备），不再作为入参传递。
- MCP 原型流程显式传入 `workflow.start.language`。`workflow.complete` 要求阶段任务完成且必需产物全部 `ready`。
- 不再使用时，关闭自己启动的后端进程。

## 上游引用与维护

维护本仓库时，一条命令更新已接入的官方来源：

```bash
bash scripts/update_upstreams.sh
```

macOS、Linux 和 Windows Git Bash 使用同一命令。更新链路只依赖 Bash 3.2+、Git、awk、grep、sed、curl、常用 Unix 工具，以及 `sha256sum` 或 `shasum`，不调用 jq、Python 或 Node；缺少工具时明确报错，不自动安装。默认获取 Three.js 最新正式 `rN` 标签并更新 `vendor/three.js` 的 checkout，获取 Comfy Skills 官方 `main`，随后按实际 commit 同步原文、许可、API 文档及一层同仓库引用。Comfy Skills 源仓库缓存放本项目 `tmp/upstreams/`，仍采用原文快照分发，不额外创建 submodule。

先准备全部候选文件、校验旧快照，再替换生成文件；人工修改过的原版、额外文件或 submodule 改动会被拒绝覆盖。只有旧清单登记且哈希未变的过期生成文件会被移除。`extend/`、业务工作流和运行依赖不在更新范围内；脚本不会暂存、提交、安装插件或下载模型。当前官方 Skills/文档的许可或入口结构不满足要求时停止，不能承诺未来每个上游版本无需适配。

更新或预演在 `tmp/upstreams/<时间>/report.tsv` 和 `report.json` 留下前后 commit、文件增删改、引用状态和官方 API 链接可达性；同目录保留候选及旧快照。在线链接的 HTTP 错误记为 `unavailable`，TLS/超时等网络错误记为 `unknown`，在终端和报告里提示，不阻止已经校验完整的本地快照更新。失败会明确报告是否已部分应用，不自动 reset/clean。版本变化后仍需检查官方步骤与 `extend/` 是否冲突，更新成功不代表模型生成效果或业务主流程已验证。

```bash
# 只校验本地快照与引用，不联网
bash scripts/update_upstreams.sh --check
# 下载候选并查看差异，不替换分发文件或移动 submodule HEAD
bash scripts/update_upstreams.sh --dry-run
# 需要更深的同仓库引用时（0–3 层，默认 1）
bash scripts/update_upstreams.sh --reference-depth 2
# 指定版本，适合重现一次已选定的更新
bash scripts/update_upstreams.sh --three-ref r185 --comfy-ref <完整commit>
```

Three.js 文档原样保存到 `skills/blender-threejs/references/threejs/`；`SOURCE.tsv` 是维护清单，记录 revision、commit、文件哈希和引用映射；`SOURCE.json` 从清单生成供 Skill 按需读取，不作为脚本输入。Comfy Skills 原文保存到 `skills/comfyui-workflow/references/upstream/comfy-skills/`，保留 MIT LICENSE、README、全部 `claude-code/commands/*.md` 和范围内引用的资源；不注册其中的云端命令/MCP。本机差异只放 `extend/`。

**次级引用有明确边界。** 支持 Markdown 链接、引用式链接、HTML/MDX 的 `href`/`src`，按同一个 commit 递归收录允许的同仓库文档和小型图片/JSON 等资源，循环引用去重。单文件上限 4 MiB，每个来源上限 128 文件。缺失的相对链接会阻止更新；跨站链接、源码、超出深度或范围的文件列在 `SOURCE.json`，不假装已经离线收录。复杂 MDX import、动态路由及隐含的类型名称不属于链接解析范围。

Comfy 官方 `Comfy-Org/docs` 文档仓库采用 GPL，按本项目规则只保留在线 API 引用，并检查 `local-api.md` 中 `docs.comfy.org` 链接的可达性，不随插件打包其正文。HTTP 可达不代表内容与当前本机版本一致；现场 `/object_info` 等接口仍是运行能力的依据。

普通 plugin 使用者无需运行这些维护命令。更新与校验统一使用 `update_upstreams.sh`，引用提取和 TSV 到 JSON 输出由同目录 `upstream_text.awk` 完成，不使用 JSON 解析器。清单和 JSON 都会校验，不要直接编辑生成文档。Git 属性固定脚本换行并禁止转换官方原文，避免 Windows autocrlf 破坏哈希。

## 仓库结构与发版

```text
.claude-plugin/                  Claude Code manifest / marketplace
.codex-plugin/                   Codex manifest
.agents/plugins/                 Codex marketplace
.mcp.codex.json                  Codex MCP 默认地址
.mcp.claude.json                 Claude MCP 用户配置引用
skills/
  xjb-coding/                    自驱编码
  xjb-coding-codex/              Codex 宿主适配
  sketch-to-prototype/           草图生成 Web 原型
  blender-threejs/               Blender + Three.js 工作流、脚本与官方参考资料
  comfyui-workflow/              官方 Comfy Skills 原版、本机 extend 和查询/保存脚本
  web-browser-debug/             真浏览器执行层选择（ego-browser 优先）、官方 Skill 引用与检查脚本
vendor/three.js/                 固定版本的官方 submodule
scripts/
  claude_worker_bridge.sh        可选 Claude worker 桥接
  update_upstreams.sh            一键更新与校验官方来源、submodule 和次级引用
  upstream_text.awk              文本引用提取与 TSV 到 JSON 输出
git_tag.sh                       版本同步、changelog、提交与标签推送
```

先校验改动并提交功能，再在干净的工作区发版：

```bash
bash scripts/update_upstreams.sh --check
./git_tag.sh
```

发版脚本同步 plugin 与编码 Skill 版本、生成 changelog 并推送版本标签和 `latest`；GitHub Actions 校验官方文档后创建 Release。当前发布流程保留近期版本，并清理旧版本，执行前应核对脚本与工作区状态。

## 许可证与依赖边界

本仓库自有代码采用 [BSD-3-Clause](LICENSE)。随包引用的 Three.js 文档和 Comfy Skills 原文分别保留 [Three.js MIT](skills/blender-threejs/references/threejs/LICENSE) 与 [Comfy Skills MIT](skills/comfyui-workflow/references/upstream/comfy-skills/LICENSE)，来源及 commit 见各自的 `SOURCE.json`。

以下是用户单独安装的外部工具，不复制、链接其代码或随本仓库打包二进制；本仓库仅提供操作指引及标准接口调用：

| 外部工具 | 官方来源 / 许可证 |
| --- | --- |
| ComfyUI | [Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI) · [GPL-3.0](https://github.com/Comfy-Org/ComfyUI/blob/master/LICENSE) |
| comfy-cli | [Comfy-Org/comfy-cli](https://github.com/Comfy-Org/comfy-cli) · [GPL-3.0](https://github.com/Comfy-Org/comfy-cli/blob/main/LICENSE) |
| comfy-mcp | [Comfy-Org/comfy-mcp](https://github.com/Comfy-Org/comfy-mcp) · [AGPL-3.0-or-later 或商业许可](https://github.com/Comfy-Org/comfy-mcp/blob/main/LICENSE) |

外部工具按各自许可证使用。来源声明不替代许可证义务；将来复制、修改或重新分发其代码时，应重新评估许可要求。

新增开源依赖优先 MIT，其次 BSD、Apache-2.0，不引入 GPL/AGPL 库或隐式接入付费服务。Blender 作为外部工具使用，不在 plugin 中分发其 GPL 本体；第三方模型、贴图和扩展分别检查许可证。
