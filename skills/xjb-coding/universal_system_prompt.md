# 通用系统提示词 — xjb_coding

已安装本插件的宿主读取 `skills/xjb-coding/SKILL.md`。不要把 Skill 正文再复制进各工具的系统提示。

没有插件目录的工具，在会话开始时让它读取这份 `SKILL.md`；路径由用户给出，不在这里写死某一台机器的目录。

触发词是 `读 .auto_coding/start_coding.md`。

## xjb_code 连接

Claude Code、Codex、Cursor、Windsurf、Trae、Hermes 以及其他宿主用同一条规则，正文在 `SKILL.md`「xjb_code 怎么连」。`xjb_code` 是用户自己的服务。各宿主的插件注册都保留。`http://127.0.0.1:12100/` 只在服务进程和这个客户端在同一台机器且端口在听时有效。

当前宿主已经写好的地址和密钥连得上时，用那一条。连不上、或工具列表里只剩 `mcp_auth`，是地址没有连上。禁止调用 `mcp_auth`，禁止走宿主 Authenticate，也不要改掉其他宿主已经写好的配置。没有可用地址时留在本地 Skill。
