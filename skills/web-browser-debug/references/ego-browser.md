# ego-browser 官方指南：发现、加载与升级

## 官方来源与边界

- 产品：ego lite，官网 <https://lite.ego.app/>。
- 官方入口是当前宿主加载的 `ego-browser` Skill；先读其 `SKILL.md`，再执行 `ego-browser skill` 获取与本机安装版本对应的完整指南。
- 当前指南以 `[ego-browser:skill] end of guide` 行结束。没有该行即输出不完整；按用户和目标项目的临时目录约定保存后分段读取，不猜测缺失部分。
- 本仓库只引用官方指南，不复制正文，不固定安装路径、Skill 子文件清单或浏览器 API 快照，也不把它纳入 `scripts/update_upstreams.sh` 的快照机制。
- 不按操作系统硬编码可用性；按 CLI、指南和实际连接判断。安装方式及平台支持读取当前官方 `references/install.md` 或官网，不把某个平台安装脚本的限制当成产品限制。

## 宿主加载

从当前宿主的 Skill 清单定位官方 `ego-browser`。宿主加载方式、平台路径及关联配置以当前官方指南为准，不从旧安装路径补建链接或复制副本。缺失时报告缺口；安装、升级和宿主配置变更按当前用户授权执行，不修改插件安装缓存。

## 每次会话的核对

```bash
bash <skill-dir>/scripts/check_tools.sh
ego-browser skill
```

脚本只读不写：报告平台、CLI 版本及完整指南是否可用，不启动浏览器、不创建任务空间、不修改宿主配置。脚本通过不等于浏览器已连通，操作时仍须按完整指南检查所需能力。没有 Bash 的宿主直接运行 `ego-browser --version` 和 `ego-browser skill`，运行脚本不是选层前提。

## 安装与关联

命令缺失或 `skill` 子命令不可用时，读取官方 Skill 的 `references/install.md`；没有官方 Skill 时给出官网入口。核对已有授权，只执行授权范围内的安装、升级或配置动作。首次引导、权限提示和用户空间接管仍由用户按官方流程完成，不用修改 PATH、启动替代浏览器等方式绕开环境问题。

## 升级

指南要求升级或输出更新提示时，按当前官方流程完成本轮并告知用户；执行 `ego-browser upgrade` 必须在授权范围内。升级后重新执行并阅读 `ego-browser skill`，不沿用旧 API 指南。没有安装、升级授权时报告缺口，不能自行修改环境。

## 与 Playwright MCP 的差异（选层依据）

| 维度 | ego-browser | Playwright MCP |
| --- | --- | --- |
| 可用性 | 当前 CLI、指南及实际连接 | 宿主工具清单及实际连接 |
| 登录态与并发 | 按官方任务空间规则复用，用户所属空间接管需明确授权 | 按宿主实际 profile 与会话隔离能力核对，不假定已登录或可并行 |
| 接口 | 仅当前指南列出的 API，不推断 Playwright API | 宿主当前提供的 Playwright MCP 工具 |
| 状态清理 | 先读官方 `references/clearing-state.md` 并核对授权 | 先核对 profile 归属、影响范围及授权 |

优先使用可用的 ego-browser；存在实际能力缺口时先说明，再回退宿主 Playwright MCP。两者均不可用则报告缺口，不自行增加第三套浏览器执行层。
