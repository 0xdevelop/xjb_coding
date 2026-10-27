# CLAUDE.md — AI 编码规范

本文件只做 Claude Code 项目入口。工作流、约束和验收读已安装插件里的 `skills/xjb-coding/SKILL.md`。

收到 `读 .auto_coding/start_coding.md` 后，读取该文件，按用户指定范围和模式执行。读取、审计和续做不触发部署、覆盖已有状态或重复追加宿主规则。

多 agent 协作或断点恢复时，先读 `.auto_coding/AGENT_COLLABORATION.md`，再执行 `.auto_coding/start_coding.md`。

## xjb_code 连接

与 Codex、Cursor、Windsurf、Trae、Hermes 相同，正文在 `SKILL.md`「xjb_code 怎么连」。`xjb_code` 是用户自己的服务。插件注册保留。`http://127.0.0.1:12100/` 只在服务进程和这个客户端在同一台机器且端口在听时有效。

Claude 的 `pluginConfigs` 里已经写好的地址连得上时，用那一条。连不上不是登录，不要走宿主 Authenticate，也不要改掉其他宿主已经写好的配置。`error_code=10004` 才去用户自己的 Dashboard 重新签发密钥。没有可用地址时留在本地 Skill。
