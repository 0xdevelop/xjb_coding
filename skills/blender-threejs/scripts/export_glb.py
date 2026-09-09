"""将指定 Blender 集合导出为新的 GLB 文件。"""

import argparse
import sys
from pathlib import Path

import bpy


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--collection", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    output = args.output.expanduser().resolve()
    if output.suffix.lower() != ".glb":
        parser.error("输出必须为 .glb")
    if output.exists():
        parser.error(f"输出已存在，不覆盖：{output}")
    collection = bpy.data.collections.get(args.collection)
    if collection is None:
        parser.error(f"集合不存在：{args.collection}")
    objects = [obj for obj in collection.all_objects if obj.type not in {"CAMERA", "LIGHT"}]
    if not any(obj.type == "MESH" for obj in objects):
        parser.error("集合中没有可导出的 mesh")
    if any(obj.name not in bpy.context.view_layer.objects for obj in objects):
        parser.error("集合中存在不属于当前 view layer 的对象，请在源文件中核对导出范围")
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        parser.error("请在 Object Mode 下导出")
    selected = list(bpy.context.selected_objects)
    active = bpy.context.view_layer.objects.active
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        for obj in selected:
            obj.select_set(False)
        for obj in objects:
            obj.select_set(True)
        if set(bpy.context.selected_objects) != set(objects):
            parser.error("集合有无法选中的隐藏对象，请核对其可见性后导出")
        result = bpy.ops.export_scene.gltf(
            filepath=str(output), export_format="GLB", use_selection=True,
            export_yup=True, export_animations=True, export_apply=False,
            export_cameras=False, export_lights=False,
        )
        if "FINISHED" not in result or not output.is_file() or output.stat().st_size <= 20:
            raise RuntimeError(f"GLB 导出失败：{result}")
        print(f"GLB exported: {output} ({output.stat().st_size} bytes)")
    finally:
        for obj in bpy.context.selected_objects:
            obj.select_set(False)
        for obj in selected:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = active


if __name__ == "__main__":
    main()
