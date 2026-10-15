# xjb_coding 适配

本文件由 `skills/archify/SKILL.md` 显式加载。它只维护本仓库与宿主的差异；图表 schema、编写方法、交付门禁与修复规则以随包官方 Skill 为准。

- **路径与分发**：随 Skill 分发完整 `references/.upstream/archify/archify/`，包括 CLI、renderers、schemas、examples、assets、locales 和许可证。`.upstream/` 是随包资源，打包或复制时须保留；对跳过隐藏目录的发现器，它可隔离原版 `SKILL.md`，本 Skill 顶层 `SKILL.md` 是指定的公开入口。包含隐藏目录的递归扫描不受此隔离，使用这类宿主或执行环境时须另行核对实际发现结果，不能据目录结构测试宣称宿主验收通过。所有官方相对资料链接以官方 `SKILL.md` 所在目录解析；命令使用该目录下 CLI 的绝对路径，不切到插件目录写文件。不依赖全局 Archify 安装、维护缓存、仓库 submodule 或上游开发仓库中的构建脚本。
- **产物归属**：正式 HTML 与可继续编辑的 JSON 保存在目标项目，用户指定位置优先；默认沿用官方 `.archify/<type>-<slug>-<时间>/`。先创建目标项目 `tmp/archify/`，在单次 CLI 命令的环境中把 `TMPDIR` 和 `ARCHIFY_UPDATE_CACHE_DIRECTORY` 设为该目录的绝对路径（Windows 的临时目录使用 `TEMP` / `TMP`）；浏览器临时目录和更新缓存随之落在项目内，不更改全局环境变量。临时截图与探针也放目标项目 `tmp/`。输入、输出和回执分开命名，保留人工修改与历史版本。
- **运行与验收**：使用官方 `finalize`；非零退出或任一门禁未通过都不算交付成功。它的 `browser-check` 是官方 CLI 自带的 Chrome / Chromium 自动检查，不使用宿主 Playwright MCP 或 ego-browser；缺少所需浏览器时报告该门禁缺口，不拿人工打开页面替代其回执，也不自动安装浏览器。继续生成或诊断可复用官方 `deliver`、严格 provenance `check`，报告实际通过的层次。
- **人工浏览器检查**：额外的交互检查、预览、截图按当前项目浏览器规则执行，macOS 优先官方 ego-browser；本仓库执行层见 `skills/web-browser-debug/SKILL.md`。单独安装本 Skill 时直接使用宿主已有浏览器能力，缺项明确报告。官方自动检查回执与人工视觉检查分别记录；保留最终预览页，只关闭本轮临时进程。
- **更新**：官方内置更新提示只提供信息，不授权下载、安装或覆盖本包。随包原文由本仓库 `scripts/update_upstreams.sh` 统一维护；维护者先检查更新与本文件的冲突，再发布插件。不要对插件缓存执行上游安装、npm 构建或更新命令，也不改动用户已有独立 Archify 安装。
- **许可**：Archify 自有代码为 MIT；保留原包 `LICENSE`、`THIRD_PARTY_NOTICES.md` 和字体 OFL。商标、品牌图标适用其各自条款，不能把整个包概括为所有素材均可按 MIT 使用；默认语义图标无需额外品牌素材。

普通交付按官方规则简短给出 HTML 链接；验证不完整、缺失源码证据或有官方更新提醒时，明确写出相应事实。
