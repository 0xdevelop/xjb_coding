# Runloop 接单与续做

`--tick` 是宿主的一轮有界推进；需要持久化定时调度、Dashboard 下发事项或手机接单时，使用 xjb_code 的原生 Go `runloop` 执行端。服务端保存目标与轮次，本机 CLI 执行工作，Skill 提供步骤和约束。不要另写 Python 调度器或在 Skill 中复制状态库。

先沿用已绑定项目、已配置的服务地址与成员 API key；缺少配置时说明所需信息，由用户维护，不擅自改环境。在已安装并已登录 Codex / Claude Code / Hermes Agent 的机器运行：

```sh
# 服务地址与 API key 使用执行端既有配置，不写入仓库或日志。
xjb_code runloop --project /absolute/project --project-id PROJECT_UUID --host codex
```

`--host claude` / `--host hermes` 切换宿主；`--skill /absolute/SKILL.md` 指定此 Skill；`--once` 至多接一单退出。宿主和项目路径必须由本机执行端明确配置，微信文字不能自行切换到任意本地目录。执行端跟随既有宿主权限，不绕过审批。

收到带 `run_id` 和结果文件路径的目标时：

1. 读取目标项目指令，恢复、锁与存档统一按 `start_coding.md` §0、§6、§7 和 `AGENT_COLLABORATION.md` 执行；不要因为执行端已创建 `.auto_coding/runloop/` 就覆盖或重新初始化整个工作区。
2. 核对 MCP 连接、认证、真实项目、原始目标和前轮断点；已知 `project_id` / `task_id` / `session_id` 时先恢复，不重新建会话或拆单。MCP 可用时用原服务端状态，确实不可用才走既有 markdown 回退，恢复后核对并接回原任务。沿用目标项目工具链与运行配置；Web 调试按 web-browser-debug 选择实际可用浏览器。
3. 先查已有决定与授权。仅实质越界或缺少必须由人决定的信息时，将具体问题写入 `summary`，状态返回 `blocked`；合理技术选择自主处理。能继续则返回 `continue` 并保存明确断点，不能将等待结束当成用户同意。法律条款确认、用户空间接管等真实安全要求仍须满足。
4. 实际验证结果后，写入执行端指定的 JSON 文件，并输出同一份 JSON：

```json
{"status":"succeeded","summary":"完成内容","evidence":"真实步骤、结果及产物位置","continuation":""}
```

`succeeded` 必须有证据；`continue` 必须有 `continuation`。未完成可返回 `failed` / `blocked`。执行端负责租约和回写，agent 不另行 claim/finish 同一个 run，避免双重接单。断点保留用户关键原话及出处、确认边界、否决路线、验收和已有验证记录；Git 状态只核对文件事实，不覆盖需求、架构或授权。进程生命周期和临时目录服从当前用户及目标项目约定。checkpoint 不要求 commit / push；提交、推送、发版或部署分别按用户授权执行，未授权不妨碍保存断点。

用户主动使用 Runloop 时，目标、摘要、断点和证据会存入其配置的 xjb_code 服务；绑定微信后，相应文字和工作状态会通过微信传输。不要将凭证或不必要的源码放进这些字段。

微信采用 Hermes 支持的个人 ClawBot / iLink 协议，Go 后台直接接入，无需安装 Python 网关。Dashboard 扫码后普通文字创建目标，“状态”查询进展，`/继续 RUN_ID 补充说明` 恢复；同一账号只由一个接收实例管理。

完整部署、状态和验收边界以 xjb_code 的 [Runloop 文档](https://github.com/0xdevelop/xjb_code/blob/main/docs/ability_runloop.md)及 [Weixin 文档](https://github.com/0xdevelop/xjb_code/blob/main/docs/ability_weixin.md)为准。宿主已支持的命令适配不等于在当前机器验收通过，分别记录 Codex / Claude / Hermes 的实际结果。
