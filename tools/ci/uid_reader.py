#!/usr/bin/env python3
"""UID 读取工具（Step 0.4）：从 .import 读资源 UID，治旧版「UID 猜测」反模式。
程序需要资源 UID 时从 .import 读，不靠猜/硬编码。

用法:
  python tools/ci/uid_reader.py <目录>        扫描输出 资源路径→UID 映射
  python tools/ci/uid_reader.py <资源文件>    输出单个资源 UID
"""
from __future__ import annotations

import os
import re
import sys

_UID_RE = re.compile(r'^uid="(uid://[^"]+)"', re.MULTILINE)
_SRC_RE = re.compile(r'^source_file="([^"]+)"', re.MULTILINE)


def read_import(import_path: str) -> tuple[str | None, str | None]:
    """从 .import 读 (uid, source_file)。"""
    with open(import_path, encoding="utf-8") as handle:
        text = handle.read()
    uid = _UID_RE.search(text)
    src = _SRC_RE.search(text)
    return (uid.group(1) if uid else None, src.group(1) if src else None)


def scan_dir(root: str) -> dict[str, str]:
    """扫描目录所有 .import，返回 {source_file: uid}。"""
    mappings: dict[str, str] = {}
    for dirpath, _dirs, files in os.walk(root):
        for fname in files:
            if fname.endswith(".import"):
                uid, src = read_import(os.path.join(dirpath, fname))
                if src and uid:
                    mappings[src] = uid
    return mappings


def main(argv: list[str]) -> int:
    target = argv[1] if len(argv) > 1 else "assets"
    if os.path.isdir(target):
        mappings = scan_dir(target)
        for src in sorted(mappings):
            print(f"{mappings[src]}\t{src}")
        print(f"\n共 {len(mappings)} 个资源 UID")
        return 0
    # 单文件：读对应 .import
    import_path = target + ".import"
    if os.path.isfile(import_path):
        uid, _src = read_import(import_path)
        print(uid or "无 UID")
        return 0 if uid else 1
    print(f"无对应 .import: {import_path}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
