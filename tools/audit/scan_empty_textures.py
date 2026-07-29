#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scan_empty_textures.py — 扫描 scenes/ 下所有 .tscn，找出图片类节点但无 texture 赋值的节点。

稳健解析：逐行状态机切分节点块，不使用贪婪正则 + re.DOTALL（避免 07-28 的 75 处误报 bug）。

运行（仓库根目录下）：
    python tools/audit/scan_empty_textures.py
"""
import os
import re
import glob
from collections import Counter

IMG_TYPES = {"TextureRect", "TextureButton", "Sprite2D", "NinePatchRect"}
TEXTURE_ATTRS = {
    "texture", "texture_normal", "texture_pressed",
    "texture_hover", "texture_focused",
}
# 留空节点需要附带报告的布局属性
KEY_ATTR_RE = re.compile(
    r'^(position|offset_left|offset_right|offset_top|offset_bottom|'
    r'offset_position|size|anchor_left|anchor_right|anchor_top|anchor_bottom)\b'
)
# 匹配 "标识符 = 右值"
ASSIGN_RE = re.compile(r'^([A-Za-z_]\w*)\s*=\s*(.*)$')
# 右值为真正的纹理资源赋值
TEX_RHS_RE = re.compile(r'^(ExtResource|load|preload)\b')


def parse_header(header):
    name = re.search(r'name="([^"]*)"', header)
    typ = re.search(r'type="([^"]*)"', header)
    parent = re.search(r'parent="([^"]*)"', header)
    return {
        "name":   name.group(1) if name else None,
        "type":   typ.group(1) if typ else None,
        "parent": parent.group(1) if parent else None,
        "inst":   "instance=ExtResource" in header,
    }


def is_section_start(s):
    s = s.strip()
    return s.startswith("[") and s.endswith("]")


def evaluate(cur, path, findings):
    """评估一个节点块：若是图片类且无 texture 赋值，则记入 findings。"""
    meta = parse_header(cur["header"])
    if meta["type"] not in IMG_TYPES:
        return
    has_texture = False
    key_attrs = []
    for line in cur["body"]:
        m = ASSIGN_RE.match(line)
        if not m:
            continue
        ident, rhs = m.group(1), m.group(2)
        if ident in TEXTURE_ATTRS and TEX_RHS_RE.match(rhs):
            has_texture = True
        if KEY_ATTR_RE.match(line):
            key_attrs.append(line)
    if has_texture:
        return
    findings.append({
        "path":   path,
        "name":   meta["name"],
        "type":   meta["type"],
        "parent": meta["parent"],
        "line":   cur["start"],
        "inst":   meta["inst"],
        "attrs":  key_attrs,
    })


def scan_file(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
    findings = []
    cur = None  # 当前节点块：{'start': 行号, 'header': str, 'body': [str]}
    for i, raw in enumerate(lines):
        ln = i + 1
        s = raw.strip()
        if s.startswith("[node "):
            if cur is not None:
                evaluate(cur, path, findings)
            cur = {"start": ln, "header": s, "body": []}
        elif is_section_start(s):
            # 任何非 node 的 section 头都会结束当前节点块
            if cur is not None:
                evaluate(cur, path, findings)
                cur = None
        else:
            if cur is not None:
                cur["body"].append(s)
    if cur is not None:
        evaluate(cur, path, findings)
    return findings


def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    scenes_dir = os.path.join(repo_root, "scenes")
    tscn_files = sorted(glob.glob(os.path.join(scenes_dir, "**", "*.tscn"), recursive=True))

    findings = []
    for tf in tscn_files:
        rel = os.path.relpath(tf, repo_root)
        for item in scan_file(tf):
            item["path"] = rel  # 统一用相对仓库根的路径展示
            findings.append(item)

    print("=== 留空图片节点清单 ===")
    findings.sort(key=lambda d: (d["path"], d["line"]))
    for d in findings:
        inst_tag = " [INSTANCED]" if d["inst"] else ""
        attrs = (" | attrs: " + "; ".join(d["attrs"])) if d["attrs"] else ""
        print(f"[{d['path']}] | {d['name']}({d['type']}) parent={d['parent']}{inst_tag} | 行号 {d['line']}{attrs}")

    print()
    print("=== 统计 ===")
    total = len(findings)
    files = len(set(d["path"] for d in findings))
    print(f"留空节点总数 {total}，分布在 {files} 个 tscn")
    c = Counter(d["type"] for d in findings)
    if c:
        print("按类型分布: " + ", ".join(f"{t}={n}" for t, n in sorted(c.items())))
    inst_n = sum(1 for d in findings if d["inst"])
    print(f"（其中 instanced 节点 {inst_n} 个，texture 通常来自所实例化的场景）")


if __name__ == "__main__":
    main()
