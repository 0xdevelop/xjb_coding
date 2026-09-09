#!/usr/bin/env python3
"""同步或校验 submodule 中选定的 Three.js 官方文档。"""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "vendor/three.js"
OUTPUT = ROOT / "skills/blender-threejs/references/threejs"
PAGES = (
    "GLTFLoader",
    "AnimationMixer",
    "AnimationAction",
    "Timer",
    "Texture",
    "OrbitControls",
)


def git(directory, *args):
    return subprocess.check_output(["git", "-C", str(directory), *args])


def expected_files():
    if not (SOURCE / ".git").exists():
        raise ValueError("先执行 git submodule update --init vendor/three.js")
    commit = git(SOURCE, "rev-parse", "HEAD").decode().strip()
    entries = git(ROOT, "ls-files", "--stage", "--", "vendor/three.js").decode().splitlines()
    if len(entries) != 1 or entries[0].split()[:3] != ["160000", commit, "0"]:
        raise ValueError("submodule HEAD 与主仓库 gitlink 不一致；审核版本后先 git add vendor/three.js")
    if git(SOURCE, "status", "--porcelain", "--untracked-files=normal").strip():
        raise ValueError("Three.js submodule 有本地改动，不能作为文档源")
    paths = {f"{page}.html.md": f"docs/pages/{page}.html.md" for page in PAGES}
    paths["LICENSE"] = "LICENSE"
    files = {name: git(SOURCE, "show", f"{commit}:{path}") for name, path in paths.items()}
    package = json.loads(git(SOURCE, "show", f"{commit}:package.json"))
    source = {
        "repository": "https://github.com/mrdoob/three.js",
        "commit": commit,
        "version": package["version"],
        "files": {
            name: {"path": paths[name], "sha256": hashlib.sha256(data).hexdigest()}
            for name, data in files.items()
        },
    }
    files["SOURCE.json"] = (json.dumps(source, ensure_ascii=False, indent=2) + "\n").encode()
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true", help="从已审核并登记的 submodule 生成文档")
    mode.add_argument("--check", action="store_true", help="检查已分发文档与固定上游完全一致")
    args = parser.parse_args()
    try:
        files = expected_files()
        existing = {p.relative_to(OUTPUT).as_posix() for p in OUTPUT.rglob("*") if p.is_file()}
        extra = existing - files.keys()
        if extra:
            raise ValueError(f"文档目录存在非生成文件，请先核对：{', '.join(sorted(extra))}")
        if args.write:
            OUTPUT.mkdir(parents=True, exist_ok=True)
            for name, data in files.items():
                (OUTPUT / name).write_bytes(data)
        else:
            changed = [name for name, data in files.items()
                       if not (OUTPUT / name).is_file() or (OUTPUT / name).read_bytes() != data]
            if changed:
                raise ValueError(f"文档不同步：{', '.join(changed)}；执行 scripts/sync_threejs_docs.py --write")
        print(f"Three.js 官方文档 {'已同步' if args.write else '校验通过'}：{len(PAGES)} 页")
    except (ValueError, subprocess.CalledProcessError, OSError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
