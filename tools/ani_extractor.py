#!/usr/bin/env python3
"""FCA(.ani) → PNG 序列帧转换工具。

.axmol 的 .ani(FCA) 本质是 zip 包，解压即得 PNG 序列帧 + sheet 元数据。
纯标准库，零外部依赖。复用旧版 ani_extractor 逻辑。

用法: python tools/ani_extractor.py [ani_dir] [out_dir]
默认 ani_dir=out_dir=assets/anim_frames。已转换（存在 sheet.png）则跳过。
"""
from __future__ import annotations

import os
import sys
import zipfile


def extract(ani_dir: str, out_dir: str) -> int:
    if not os.path.isdir(ani_dir):
        print(f"目录不存在: {ani_dir}")
        return 1
    os.makedirs(out_dir, exist_ok=True)
    count = 0
    skipped = 0
    errors = 0
    for fname in sorted(os.listdir(ani_dir)):
        if not fname.endswith(".ani"):
            continue
        base = fname[:-4]
        dest = os.path.join(out_dir, base)
        if os.path.exists(os.path.join(dest, "sheet.png")):
            skipped += 1
            continue
        try:
            with zipfile.ZipFile(os.path.join(ani_dir, fname), "r") as zf:
                os.makedirs(dest, exist_ok=True)
                zf.extractall(dest)
                count += 1
        except Exception as exc:  # noqa: BLE001
            errors += 1
            print(f"  错误 {fname}: {exc}")
    print(f"FCA 转换: 提取 {count} 个, 跳过 {skipped} 个(已转), 错误 {errors} 个")
    return 0


if __name__ == "__main__":
    ani_dir = sys.argv[1] if len(sys.argv) > 1 else "assets/anim_frames"
    out_dir = sys.argv[2] if len(sys.argv) > 2 else ani_dir
    sys.exit(extract(ani_dir, out_dir))
