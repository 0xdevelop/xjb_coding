---
name: blender-threejs
description: Create Blender assets and Three.js scenes with GLB loading, materials, animation, particles, depth effects, camera zoom, and particle reassembly. Use for Blender to Three.js tasks, GLB integration, or interactive 3D particle scenes; ordinary 2D Web work does not need this skill.
metadata:
  version: "0.2.0"
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
| 粒子绘制、形态重组、粒子景深 | [Points](references/threejs/Points.html.md)、[BufferGeometry](references/threejs/BufferGeometry.html.md)、[ShaderMaterial](references/threejs/ShaderMaterial.html.md) |
| GLB 静态网格表面采样 | [MeshSurfaceSampler](references/threejs/MeshSurfaceSampler.html.md) |

遇到 `.html` 相对链接时，先查 [SOURCE.json](references/threejs/SOURCE.json) 的 `references`：`bundled` 条目的 `local` 指向同 commit 的本地 `.html.md` 文件，按需读取。原文链接不被重写；`depth_limit`、`outside_scope` 或 `external` 条目没有离线收录，再按实际需要查询官方来源并核对版本。不要把附带的次级引用当作完整 Three.js 知识库。

## 执行

1. **确认使用场景。** 读取指定 `.blend` / GLB、页面和说明；明确资产对象、单位、朝向、动画片段、用户操作和性能要求。盘点已有进程与未保存场景；只操作本任务的文件、集合和进程。
2. **制作或检查资产。** Blender 中保留可编辑源文件。使用明确命名的集合组织导出对象；材质先采用 glTF 可表示的 Principled BSDF，程序纹理按需烘焙。不要为了导出任意应用骨架修改器、重置姿态或统一缩放全部模型。
3. **导出 GLB。** 明确导出集合，导出后复查材质、贴图、对象和动画是否齐全。需要 CLI 时使用下方脚本；它不保存或覆盖 `.blend`，也不覆盖已有 GLB。压缩仅在实际体积或性能需要时加入。
4. **接入 Three.js。** 使用与 `three` 相同版本的 `three/addons/`；`GLTFLoader` 加载 GLB，以包围盒适配相机。按实际片段名控制 `AnimationMixer`，每帧只计算一次 delta。页面提供加载中、可交互、加载失败和重试状态。普通原型无需新增 React Three Fiber、GSAP 或后处理依赖。
5. **真实验证。** 浏览器执行层按 `web-browser-debug` Skill 选定（macOS 优先官方 ego-browser）。在目标浏览器看到实际模型，操作旋转/缩放和任务所需交互；有动画时验证播放、暂停、恢复。检查刷新、窗口缩放、资源失败后的重试；记录控制台、资源请求、材质/动画结果以及实测帧时间和 `renderer.info`。性能阈值来自目标设备与需求，不由示例的固定数字代替。
6. **交付与清理。** 交付源资产、GLB、接入代码和必要的使用说明；有现有产物登记流程时沿用。页面卸载时释放模型、纹理、动画、controls 和 renderer；关闭本任务启动的服务与 Blender/浏览器实例并复查。所有缓存和中间文件放目标项目 `tmp/`。主流程未通过时明确剩余问题，不能只凭文件存在或构建通过宣称完成。

## CLI 导出

`<skill-dir>` 是当前已加载 Skill 的绝对目录，`--collection` 是资产所在集合名：

```bash
blender --factory-startup --background /absolute/path/asset.blend --python-exit-code 1 \
  --python <skill-dir>/scripts/export_glb.py -- \
  --collection Asset --output /absolute/path/asset.glb
```

仅当用户允许重新生成该输出时，先移走旧输出或改用新路径。不要自动删除旧文件来绕过脚本的覆盖保护。

## 粒子场景

用户要求粒子、景深、缩放或重组时，可从 [assets/particles/](assets/particles/) 的可运行示例开始，再按目标场景修改。它只依赖固定版本 Three.js，包含球体、环形、散开、GLB 静态网格采样、连续重组、拖动旋转、平滑滚轮缩放、景深调节及播放/暂停。无需 Blender 即可运行内置形态。

将完整示例复制到目标项目的合适目录，首次安装依赖后启动本地服务：

```bash
npm ci --ignore-scripts
python3 -m http.server 8080 --bind 127.0.0.1
```

依赖缓存放目标项目 `tmp/`；验证后关闭服务。示例可独立使用，也可以把对应粒子代码接入已有页面，不要求替换项目框架。

- 重组保留同一批粒子，用当前位置作为下一次过渡起点，避免连续点击时跳变；缓动覆盖起止速度。
- 示例景深是按粒子相机空间深度改变点精灵的模糊半径和透明度，不是整个场景的光学后处理。若需要模型、遮挡和背景共同参与景深，应按任务改用合适的后处理，并实际检查性能。
- 保留暂停和 reduced-motion 行为；缩放使用平滑相机移动，不通过突然切换粒子数量模拟镜头。
- GLB 采样仅支持内嵌资源的普通静态 mesh，按世界空间表面积采样并归一化显示尺度；不保留贴图、骨架、实例或形变动画。这不改变源文件。复杂资产先在 Blender 中整理后再导出。
- 验收至少覆盖景深调节、滚轮/滑杆缩放、拖动旋转、连续重组、暂停恢复、无效 GLB 后重试、重复导入与资源释放。
