#!/usr/bin/env python3
"""资源完整性校验（Step 0.4）：资源 ↔ .import 配对检查。
报告未 import 资源（缺 .import，需重新 import）与孤儿 .import（资源已删）。
仅检查 Godot 会 import 的媒体类型（.json/.atlas/.txt 等数据文件本就无 .import）。

用法: python tools/ci/asset_check.py [资源目录]
"""
from __future__ import annotations

import os
import sys

# Godot 会生成 .import 的媒体类型
MEDIA_EXT = (
    ".png", ".jpg", ".jpeg", ".webp", ".svg", ".mp3", ".ogg", ".wav",
    ".ttf", ".otf", ".csv", ".glb", ".gltf",
)


def main(argv: list[str]) -> int:
    root = argv[1] if len(argv) > 1 else "assets"
    no_import: list[str] = []
    orphan_import: list[str] = []
    for dirpath, _dirs, files in os.walk(root):
        for fname in files:
            full = os.path.join(dirpath, fname)
            if fname.endswith(".import"):
                resource = full[: -len(".import")]
                if not os.path.isfile(resource):
                    orphan_import.append(os.path.relpath(full, root).replace("\\", "/"))
            elif fname.lower().endswith(MEDIA_EXT):
                if not os.path.isfile(full + ".import"):
                    no_import.append(os.path.relpath(full, root).replace("\\", "/"))

    # P2-门禁-3：补扫项目根顶层孤儿 .import（assets 子树已由上 os.walk 覆盖）
    project_root = os.path.dirname(os.path.abspath(root))
    orphan_import.extend(_check_root_level_orphan_imports(project_root))

    print(f"未 import 资源（缺 .import）: {len(no_import)}")
    for rel in no_import[:20]:
        print(f"  {rel}")
    print(f"孤儿 .import（资源已删）: {len(orphan_import)}")
    for rel in orphan_import[:20]:
        print(f"  {rel}")
    # P2-门禁-3：.uid 一致性检查（扫描 scripts/ 下 .gd.uid 孤儿，对应 .gd 已删）
    orphan_uids = _check_orphan_gd_uids(root)
    print(f"孤儿 .gd.uid（脚本已删）: {len(orphan_uids)}")
    for rel in orphan_uids[:20]:
        print(f"  {rel}")
    ok = not no_import and not orphan_import and not orphan_uids
    print("完整性通过 ✅" if ok else "完整性问题 ❌")
    return 0 if ok else 1


def _check_orphan_gd_uids(assets_root: str) -> list[str]:
    """P2-门禁-3：扫描项目根 scripts/ 下 .gd.uid 孤儿（对应 .gd 文件已删除）。

    assets_root 是资源目录（assets/），scripts/ 在项目根（其父目录）下。
    门禁-P1-1 修复：此前用 assets_root/scripts 定位，拼出不存在的路径 →
    isdir 否直接 return → 孤儿检查永远报 0（门禁假绿）。
    """
    orphans: list[str] = []
    project_root = os.path.dirname(os.path.abspath(assets_root))
    scripts_dir = os.path.join(project_root, "scripts")
    if not os.path.isdir(scripts_dir):
        return orphans
    for dirpath, _dirs, files in os.walk(scripts_dir):
        for fname in files:
            if fname.endswith(".gd.uid"):
                full = os.path.join(dirpath, fname)
                base = full[: -len(".uid")]
                if not os.path.isfile(base):
                    orphans.append(os.path.relpath(full, project_root).replace("\\", "/"))
    return orphans


def _check_root_level_orphan_imports(project_root: str) -> list[str]:
    """P2-门禁-3：扫项目根顶层孤儿 .import（资源已删/移走，.import 残留）。

    非递归（assets 子树由 main 的 os.walk 覆盖）；项目根散落的 .import 之前漏检
    （P2-3），如 screenshot.png.import 资源移至 screenshots/ 归档后根级残留。
    """
    orphans: list[str] = []
    if not os.path.isdir(project_root):
        return orphans
    for fname in os.listdir(project_root):
        if not fname.endswith(".import"):
            continue
        full = os.path.join(project_root, fname)
        if not os.path.isfile(full):
            continue
        resource = full[: -len(".import")]
        if not os.path.isfile(resource):
            orphans.append(fname)
    return orphans


if __name__ == "__main__":
    sys.exit(main(sys.argv))
