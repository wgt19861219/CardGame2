#!/usr/bin/env python3
"""【已废弃】全量资源迁移（Step 0.4，一次性工具，迁移已完成 2026-06-24）。
保留作历史记录，不应再运行。资源维护用 asset_check.py + 编辑器 import。
原用途：从旧版 assets/ 复制资源到本项目 assets/，
排除 Godot 元数据（.import/.uid/.remap，让本项目全新 import 分配 UID），
并就地解压 FCA(.ani) 为 PNG 序列帧。

用法: python tools/migrate_assets.py
源: D:\\workspace\\projects\\CardGame\\assets（旧版产物，复用）
目的: D:\\workspace\\projects\\CardGame2\\assets
"""
from __future__ import annotations

import os
import shutil
import sys
import zipfile

SRC = r"D:\workspace\projects\CardGame\assets"
DST = r"D:\workspace\projects\CardGame2\assets"
# Godot 元数据后缀，复制时排除（由本项目重新 import 生成）
EXCLUDE_EXT = (".import", ".uid", ".remap", ".tmp", ".pyc", ".csel")
EXCLUDE_ENDSWITH = (".gd.uid",)


def main() -> int:
    if not os.path.isdir(SRC):
        print(f"源目录不存在: {SRC}")
        return 1
    copied = 0
    skipped_meta = 0
    skipped_exist = 0
    for root, _dirs, files in os.walk(SRC):
        rel = os.path.relpath(root, SRC)
        dest_root = DST if rel == "." else os.path.join(DST, rel)
        os.makedirs(dest_root, exist_ok=True)
        for fname in files:
            if fname.endswith(EXCLUDE_EXT) or any(fname.endswith(s) for s in EXCLUDE_ENDSWITH):
                skipped_meta += 1
                continue
            src_path = os.path.join(root, fname)
            dst_path = os.path.join(dest_root, fname)
            if os.path.exists(dst_path):
                skipped_exist += 1
                continue
            shutil.copy2(src_path, dst_path)
            copied += 1

    # FCA(.ani) 就地解压为 PNG 序列帧（ani_extractor 逻辑）
    ani_dir = os.path.join(DST, "anim_frames")
    ani_count = 0
    ani_errors = 0
    if os.path.isdir(ani_dir):
        for fname in sorted(os.listdir(ani_dir)):
            if not fname.endswith(".ani"):
                continue
            base = fname[:-4]
            dest = os.path.join(ani_dir, base)
            if os.path.exists(os.path.join(dest, "sheet.png")):
                continue
            try:
                with zipfile.ZipFile(os.path.join(ani_dir, fname), "r") as zf:
                    os.makedirs(dest, exist_ok=True)
                    zf.extractall(dest)
                    ani_count += 1
            except Exception as exc:  # noqa: BLE001
                ani_errors += 1
                print(f"  FCA 错误 {fname}: {exc}")

    print(f"复制 {copied} 资源，跳过 {skipped_meta} 元数据 / {skipped_exist} 已存在")
    print(f"FCA(.ani) 解压 {ani_count} 个，错误 {ani_errors} 个")
    return 0


if __name__ == "__main__":
    sys.exit(main())
