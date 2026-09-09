---
name: blender-threejs
description: Create or edit Blender assets and integrate exported glTF/GLB models into Three.js, including materials, animation, interaction, and browser verification. Use for Blender to Three.js tasks or GLB integration problems; ordinary 2D Web work does not need this skill.
metadata:
  version: "0.1.0"
---

# Blender + Three.js

完成 Blender 资产到 Three.js 页面中的真实使用流程。沿用目标项目的技术栈、目录、命名和验收要求，默认面向桌面 Web。已有 GLB 时直接从加载与验证开始，不要求重新建模。

## 边界与来源

- 本 Skill 属于 `xjb_coding`。Blender 是外部已安装工具；Three.js 是目标项目依赖，用现有包管理器和 lockfile 固定版本。不要把 Blender 本体、额外渲染框架或模型生成服务加入 plugin。
- 宿主中立：优先使用可用的 Blender CLI 或现有 MCP。没有 MCP 时可用 CLI 完成同一流程；不要把工作流规则搬进 `xjb_code`，也不要为该流程新增后端接口。
- 按需阅读 [Blender 导出与 Three.js 接入](references/blender.md) 和下表中的官方 API 文档。文档由 submodule 原样生成，[SOURCE.json](references/threejs/SOURCE.json) 记录来源 commit、版本和文件哈希；不直接编辑生成文件。
- 文档对应固定版本，不代表目标项目也必须升级。先检查项目实际 `three` 版本；若 API 不同，以该版本源码及官方文档为准。官方文档中的示例服务、额外插件和可选解码器不等于本任务的依赖或授权。

| 当前问题 | 按需读取 |
| --- | --- |
| GLB 加载、压缩扩展、失败回调 | [GLTFLoader](references/threejs/GLTFLoader.html.md) |
| 动画推进、暂停与重播 | [AnimationMixer](references/threejs/AnimationMixer.html.md)、[AnimationAction](references/threejs/AnimationAction.html.md) |
| 帧时间、后台标签页恢复 | [Timer](references/threejs/Timer.html.md) |
| 色彩空间、UV、纹理释放 | [Texture](references/threejs/Texture.html.md) |
| 旋转、缩放、相机控制 | [OrbitControls](references/threejs/OrbitControls.html.md) |

这些文档的 `.html` 相对链接指向 Three.js 在线 API 页面，不是本地文件；未收录页面通过 `https://threejs.org/docs/pages/<页面>.html` 查阅，并核对版本。

## 执行

1. **确认使用场景。** 读取指定 `.blend` / GLB、页面和说明；明确资产对象、单位、朝向、动画片段、用户操作和性能要求。盘点已有进程与未保存场景；只操作本任务的文件、集合和进程。
2. **制作或检查资产。** Blender 中保留可编辑源文件。使用明确命名的集合组织导出对象；材质先采用 glTF 可表示的 Principled BSDF，程序纹理按需烘焙。不要为了导出任意应用骨架修改器、重置姿态或统一缩放全部模型。
3. **导出 GLB。** 明确导出集合，导出后复查材质、贴图、对象和动画是否齐全。需要 CLI 时使用下方脚本；它不保存或覆盖 `.blend`，也不覆盖已有 GLB。压缩仅在实际体积或性能需要时加入。
4. **接入 Three.js。** 使用与 `three` 相同版本的 `three/addons/`；`GLTFLoader` 加载 GLB，以包围盒适配相机。按实际片段名控制 `AnimationMixer`，每帧只计算一次 delta。页面提供加载中、可交互、加载失败和重试状态。普通原型无需新增 React Three Fiber、GSAP 或后处理依赖。
5. **真实验证。** 在目标浏览器看到实际模型，操作旋转/缩放和任务所需交互；有动画时验证播放、暂停、恢复。检查刷新、窗口缩放、资源失败后的重试；记录控制台、资源请求、材质/动画结果以及实测帧时间和 `renderer.info`。性能阈值来自目标设备与需求，不由示例的固定数字代替。
6. **交付与清理。** 交付源资产、GLB、接入代码和必要的使用说明；有现有产物登记流程时沿用。页面卸载时释放模型、纹理、动画、controls 和 renderer；关闭本任务启动的服务与 Blender/浏览器实例并复查。所有缓存和中间文件放目标项目 `tmp/`。主流程未通过时明确剩余问题，不能只凭文件存在或构建通过宣称完成。

## CLI 导出

`<skill-dir>` 是当前已加载 Skill 的绝对目录，`--collection` 是资产所在集合名：

```bash
blender --factory-startup --background /absolute/path/asset.blend --python-exit-code 1 \
  --python <skill-dir>/scripts/export_glb.py -- \
  --collection Asset --output /absolute/path/asset.glb
```

仅当用户允许重新生成该输出时，先移走旧输出或改用新路径。不要自动删除旧文件来绕过脚本的覆盖保护。
