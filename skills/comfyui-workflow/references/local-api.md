# 本机接口与文件

## 官方工具安装与关联

只使用官方 [comfy-mcp](https://github.com/Comfy-Org/comfy-mcp) 与 [comfy-cli](https://github.com/Comfy-Org/comfy-cli)，不使用第三方 Comfy MCP、同名替代包或非官方镜像的源码。前者是本机 stdio MCP，调用后者执行；安装 MCP 不会自动安装 CLI。在 Git Bash/macOS/Linux 中用 `bash <skill-dir>/scripts/check_tools.sh` 检查 PATH 或 `COMFY_BIN`；MCP 宿主若使用绝对路径，还要核对该路径和已加载工具清单。检查安装包元数据和来源指向上述官方仓库，名称或版本输出本身不能证明来源。

缺失时先给 Agent/用户以下指引，**不自动执行安装**。官方工具需要 Python 3.10+，这是外部工具的运行要求；本仓库的官方来源更新脚本不需要 Python。

经用户授权后，在用户指定的工具目录创建独立环境（不要修改现有 ComfyUI 的 venv）：

```bash
# macOS/Linux；将 /absolute/tools/comfy 换成用户指定目录
python3 -m venv /absolute/tools/comfy
/absolute/tools/comfy/bin/python -m pip install comfy-mcp 'comfy-cli>=1.14.0'
/absolute/tools/comfy/bin/comfy --version
/absolute/tools/comfy/bin/comfy-mcp --version
# 关联已存在的 ComfyUI，禁止为已有安装再次执行 comfy install
/absolute/tools/comfy/bin/comfy set-default /absolute/path/to/ComfyUI
codex mcp add comfy-mcp --env COMFY_BIN=/absolute/tools/comfy/bin/comfy --env COMFY_LOCAL_URL=http://127.0.0.1:8188 -- /absolute/tools/comfy/bin/comfy-mcp
```

Windows Git Bash 对应命令（路径按实际替换）：

```bash
py -3 -m venv C:/tools/comfy
C:/tools/comfy/Scripts/python.exe -m pip install comfy-mcp 'comfy-cli>=1.14.0'
C:/tools/comfy/Scripts/comfy.exe --version
C:/tools/comfy/Scripts/comfy-mcp.exe --version
C:/tools/comfy/Scripts/comfy.exe set-default D:/ComfyUI_windows_portable/ComfyUI
codex mcp add comfy-mcp --env COMFY_BIN=C:/tools/comfy/Scripts/comfy.exe --env COMFY_LOCAL_URL=http://127.0.0.1:8188 -- C:/tools/comfy/Scripts/comfy-mcp.exe
```

先检查宿主已有的 `comfy-mcp`/`comfy-local` 配置，更新现有项，避免重复注册。其他 MCP 宿主使用同样的 `command` 与 `COMFY_BIN` 环境变量。指定 loopback 的 `COMFY_LOCAL_URL`，不同时配置远程 `COMFYUI_URL`。重新加载宿主后调用 `server_info`，确认现场地址和安装；版本命令通过不证明 MCP 已关联或 ComfyUI 已运行。

Claude Code 对应关联命令（选择实际需要的宿主，不必三家都注册）：

```bash
claude mcp add --transport stdio comfy-mcp -e COMFY_BIN=/absolute/tools/comfy/bin/comfy -e COMFY_LOCAL_URL=http://127.0.0.1:8188 -- /absolute/tools/comfy/bin/comfy-mcp
```

Hermes Agent 在用户授权后合并到其 `~/.hermes/config.yaml`，保留其他配置；Windows 将路径换成上述 `Scripts/*.exe`：

```yaml
mcp_servers:
  comfy-mcp:
    command: /absolute/tools/comfy/bin/comfy-mcp
    env:
      COMFY_BIN: /absolute/tools/comfy/bin/comfy
      COMFY_LOCAL_URL: http://127.0.0.1:8188
```

安装 Skill 与关联 MCP 是独立步骤。Codex、Claude Code、Hermes Agent 都读取同一个 `SKILL.md` 和相对引用；人工导出的 `workflow.json` 不依赖宿主。切换宿主时读取最后保存的文件，另存新版本，不覆盖原件。

宿主依据：[Codex Skills](https://learn.chatgpt.com/docs/build-skills)、[Claude Code plugins](https://code.claude.com/docs/en/plugins-reference)、[Hermes Skills](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills)、[Hermes MCP](https://hermes-agent.nousresearch.com/docs/reference/mcp-config-reference/)。实际安装前核对当前宿主 CLI 帮助和配置，不能把本文命令当作未来版本不变的保证。

通过本机 MCP 的 `search_nodes`、`search_models`、`search_templates`、`validate_workflow` 发现和检查；CLI 直接调用始终加 `--where local --json`，具体子命令先读当前 `comfy --help`。生成前检查节点是否走外部 API。禁止 `partner_generate`、`auth_login`、Cloud 登录及 API Key 配置。普通反复生成由用户在 ComfyUI 执行。

## 可选文件辅助

`local_comfy.py` 仅需 Python 3.10+ 标准库，用于 loopback 查询、UI 基本结构检查及按字节另存。macOS 用 `python3`；Windows 用 `py -3` 或现有 Python。它不要求激活或修改 ComfyUI 的 Python 环境。

在目标项目运行，`<skill-dir>` 替换为加载的 Skill 绝对路径；URL 参数放在子命令前：

```bash
python3 <skill-dir>/scripts/local_comfy.py --url http://127.0.0.1:8188 system
python3 <skill-dir>/scripts/local_comfy.py nodes --query upscale --limit 8
python3 <skill-dir>/scripts/local_comfy.py node ImageScale
python3 <skill-dir>/scripts/local_comfy.py models --folder checkpoints --query sdxl
python3 <skill-dir>/scripts/local_comfy.py templates
python3 <skill-dir>/scripts/local_comfy.py inspect workflows/restore/v1/workflow.json --live
python3 <skill-dir>/scripts/local_comfy.py save tmp/comfyui/edited.json --output workflows/restore/v2/workflow.json
```

Windows 示例：

```powershell
py -3 "C:\path\to\comfyui-workflow\scripts\local_comfy.py" --url http://127.0.0.1:8188 nodes --query upscale
```

`system` 读取 `/system_stats`；`models` 无 `--folder` 时仅列模型类型。`nodes` 在本地筛选全量 `/object_info` 后输出有限条名称/类别，不把全量 schema 送进上下文；`node` 读取指定类的 schema。`templates` 仅列 `/workflow_templates` 的扩展模块目录。均以现场 API 是否支持为准，错误会以 JSON 返回并以非零状态退出。

`inspect` 只支持 UI JSON 的基本检查：0.4 六元组 links 与 1.0 对象 links、节点和连线 ID、端点和 slot 回指。`--live` 额外查询所用节点是否存在、是否被标记为 API 节点。子图、前端专用节点、完整 schema、widget 到执行输入的映射、模型兼容性、必填输入和结果质量均不在它的验证范围内；报告 `limitations` / `review_nodes`，不能据退出码 0 宣称可执行。缺失节点或已知 API 节点会导致 live 检查非零退出。

`save` 检查基本格式后独占创建目标文件，已有文件（包括符号链接）会被拒绝；没有覆盖开关。API JSON 会被拒绝，避免把只有执行信息的文件误当作可编辑源。它不会自动创建 API JSON，也不会登记未经实测的环境信息。

## 文件权威与结构

- UI JSON 包含 `nodes`、`links`、`groups`、布局、widget 值及扩展信息；API JSON 通常是 node ID 到 `class_type` / `inputs` 的映射。不要互相改名代替转换。
- `widgets_values` 可能包含前端专用控制项，不能与后端 `input_order` 简单 zip。复用对应节点/前端版本生成的画布，再通过 ComfyUI 前端导出 API。
- 子图、新版 reroute、动态输入或自定义前端节点可能超出脚本支持范围；保留源文件，在 ComfyUI 中打开验证，不扁平化重写未知结构。
- 模型路径和节点扩展因机器而异。移到另一台机器后重新检查；同一 seed 不保证跨设备/版本逐像素一致。

官方接口依据：[Server routes](https://docs.comfy.org/development/comfyui-server/comms_routes)、[Workflow JSON](https://docs.comfy.org/specs/workflow_json)、[ComfyUI README](https://github.com/Comfy-Org/ComfyUI)。实现以用户实际安装版本为准。
