# Trae Agent 系统提示词 — xjb_coding

本文件只做 Trae 入口。把已安装插件中的 `skills/xjb-coding/SKILL.md` 作为工作流正文，不要把 Skill 再贴一份到这里。

触发词是 `读 .auto_coding/start_coding.md`。项目里还没有该文件时，先按 SKILL.md 的初始化步骤准备。

## xjb_code 连接

与 Claude Code、Codex、Cursor、Windsurf、Hermes 相同，正文在 `SKILL.md`「xjb_code 怎么连」。`xjb_code` 是用户自己的服务。各宿主的插件注册都保留。`http://127.0.0.1:12100/` 只在服务进程和这个客户端在同一台机器且端口在听时有效。

本宿主已经写好的地址和密钥连得上时，用那一条。连不上不是登录，不要走宿主 Authenticate，也不要改掉其他宿主已经写好的配置。没有可用地址时留在本地 Skill。

## Trae 配置步骤

1. 打开 Trae → Settings → Agent
2. 在 System Prompt 中写入：读取插件内 `skills/xjb-coding/SKILL.md`
3. 保存后，在 Trae Chat 输入：`读 .auto_coding/start_coding.md`
