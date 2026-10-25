# CLAUDE.md — AI 编码规范

本文件只做 Claude Code 项目入口。工作流、约束和验收读已安装插件里的 `skills/xjb-coding/SKILL.md`。

收到 `读 .auto_coding/start_coding.md` 后，读取该文件，按用户指定范围和模式执行。读取、审计和续做不触发部署、覆盖已有状态或重复追加宿主规则。

多 agent 协作或断点恢复时，先读 `.auto_coding/AGENT_COLLABORATION.md`，再执行 `.auto_coding/start_coding.md`。
