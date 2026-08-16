#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scan_texture_aspect.py — 审计"纹理被非等比拉伸"（纵横比破坏）的 UI 组件。

背景（2026-08-15 货币栏两连修教训）：非正方形纹理被统一正方形 rect 强拉会变形
（金币 43×39/钻石 50×38/体力 44×50 全中招）。本脚本系统性扫全项目同类问题。

两路扫描：
  A. scenes/**/*.tscn 的 TextureRect 节点（默认 STRETCH_SCALE 拉满 rect）：
     - 显示尺寸 = offset 差（anchors 全 0 才可信，其余跳过）
     - 纹理逻辑尺寸 = png 文件尺寸（AtlasTexture 取 region）
     - NinePatchRect（Scale9 拉伸是设计意图）与显式 stretch_mode 的跳过
  B. scripts/**/*.gd 的 _add_texture_rect(...) 调用（项目通用工具，第 4 参为显示尺寸）：
     - 实参为 res:// 字符串或常量名（常量表从同文件 const 定义解析）

判据：|显示ratio - 纹理ratio| / 纹理ratio > THRESHOLD(8%) → 嫌疑。
注意：嫌疑 ≠ 必然 bug（背景/底板类拉伸可能是设计意图），输出供人工分类。

运行（仓库根目录下）：
    python tools/audit/scan_texture_aspect.py
"""
import os
import re
import glob
import struct
from collections import Counter

THRESHOLD = 0.08   # 纵横比偏差阈值（8%）

ASSIGN_RE = re.compile(r'^([A-Za-z_]\w*)\s*=\s*(.*)$')
OFFSET_RE = re.compile(r'^offset_(left|right|top|bottom)\s*=\s*(-?[\d.]+)$')
ANCHOR_RE = re.compile(r'^anchor_(left|right|top|bottom)\s*=\s*(-?[\d.]+)$')
SCALE_RE = re.compile(r'^scale\s*=\s*Vector2\(\s*(-?[\d.]+),\s*(-?[\d.]+)\s*\)')
VECTOR2_RE = re.compile(r'Vector2\(\s*(-?[\d.]+),\s*(-?[\d.]+)\s*\)')
RES_STR_RE = re.compile(r'"(res://[^"]+\.(?:png|jpg|webp))"')
EXTRES_RE = re.compile(r'^\[ext_resource type="[^"]*" path="([^"]+)" id="([^"]+)"')
SUBRES_HEADER_RE = re.compile(r'^\[sub_resource type="([^"]+)" id="([^"]+)"')
REGION_RE = re.compile(r'region\s*=\s*Rect2\(\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+)')

TEX_CACHE = {}


def png_size(path):
    """读 PNG/JPG 尺寸（带缓存）。"""
    if path in TEX_CACHE:
        return TEX_CACHE[path]
    size = None
    try:
        with open(path, "rb") as f:
            head = f.read(2)
            if head == b"\x89P":   # PNG：IHDR
                d = f.read(31)
                size = struct.unpack(">II", d[14:22])
            elif head == b"\xff\xd8":   # JPG：扫 SOF0/1/2 段
                while True:
                    marker = f.read(2)
                    if len(marker) < 2 or marker[0] != 0xFF:
                        break
                    if marker[1] in (0xC0, 0xC1, 0xC2):
                        f.read(3)   # 段长(2) + 精度(1)
                        h, w = struct.unpack(">HH", f.read(4))
                        size = (w, h)
                        break
                    seg_len = struct.unpack(">H", f.read(2))[0]
                    f.seek(seg_len - 2, 1)
    except (OSError, struct.error):
        size = None
    TEX_CACHE[path] = size
    return size


def parse_tscn(path):
    """两遍解析 tscn：资源表 + TextureRect 节点。"""
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
    # 第一遍：ext_resource 与 AtlasTexture sub_resource
    ext = {}          # id -> abs path
    atlas = {}        # sub id -> (w, h)  region 尺寸
    cur_sub = None
    for raw in lines:
        s = raw.strip()
        m = EXTRES_RE.match(s)
        if m:
            ext[m.group(2)] = m.group(1)
            continue
        m = SUBRES_HEADER_RE.match(s)
        if m:
            cur_sub = m.group(2) if m.group(1) == "AtlasTexture" else None
            continue
        if cur_sub:
            if s.startswith("[") and not s.startswith("[sub_resource"):
                cur_sub = None
                continue
            m = REGION_RE.search(s)
            if m:
                atlas[cur_sub] = (float(m.group(3)), float(m.group(4)))
    # 第二遍：节点块
    findings = []
    cur = None
    for i, raw in enumerate(lines):
        ln = i + 1
        s = raw.strip()
        if s.startswith("[node "):
            if cur:
                evaluate_node(cur, path, ln, ext, atlas, findings)
            cur = {"header": s, "body": [], "line": ln}
        elif s.startswith("["):
            if cur:
                evaluate_node(cur, path, ln, ext, atlas, findings)
                cur = None
        elif cur is not None:
            cur["body"].append(s)
    if cur:
        evaluate_node(cur, path, len(lines), ext, atlas, findings)
    return findings


def evaluate_node(cur, path, _end_ln, ext, atlas, findings):
    m = re.search(r'type="([^"]*)"', cur["header"])
    if not m:
        return
    typ = m.group(1)
    name_m = re.search(r'name="([^"]*)"', cur["header"])
    name = name_m.group(1) if name_m else "?"
    if typ not in ("TextureRect", "Sprite2D"):
        return
    offsets = {}
    anchors = {}
    scale = None
    stretch = None
    tex_ref = None   # ("ext", id) | ("sub", id) | ("str", path)
    for line in cur["body"]:
        am = ASSIGN_RE.match(line)
        if not am:
            continue
        ident, rhs = am.group(1), am.group(2)
        if ident.startswith("offset_"):
            om = OFFSET_RE.match(line)
            if om:
                offsets[ident] = float(om.group(2))
        elif ident.startswith("anchor_"):
            anm = ANCHOR_RE.match(line)
            if anm:
                anchors[ident] = float(anm.group(2))
        elif ident == "scale" and typ == "Sprite2D":
            sm = SCALE_RE.match(rhs)
            if sm:
                scale = (float(sm.group(1)), float(sm.group(2)))
        elif ident == "stretch_mode" and typ == "TextureRect":
            stretch = rhs.strip()
        elif ident == "texture" and typ == "TextureRect":
            if rhs.startswith("ExtResource"):
                tex_ref = ("ext", re.search(r'"([^"]+)"', rhs).group(1))
            elif rhs.startswith("SubResource"):
                tex_ref = ("sub", re.search(r'"([^"]+)"', rhs).group(1))
            else:
                rm = RES_STR_RE.search(rhs)
                if rm:
                    tex_ref = ("str", rm.group(1))
    repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    # 纹理逻辑尺寸
    tex_size = None
    tex_name = ""
    if tex_ref:
        kind, key = tex_ref
        if kind == "sub" and key in atlas:
            tex_size = atlas[key]
            tex_name = f"AtlasTexture({key})"
        else:
            p = ext.get(key) if kind == "ext" else (key if kind == "str" else None)
            if p:
                tex_name = os.path.basename(p)
                full = os.path.join(repo, p.replace("res://", ""))
                tex_size = png_size(full)
    if not tex_size:
        return
    tw, th = tex_size
    if tw <= 0 or th <= 0:
        return
    tex_ratio = tw / th

    if typ == "Sprite2D":
        if scale and abs(scale[0] - scale[1]) / max(abs(scale[0]), 1e-6) > THRESHOLD and scale[0] != scale[1]:
            findings.append({
                "path": path, "name": name, "type": typ, "line": cur["line"],
                "desc": f"scale=({scale[0]},{scale[1]}) 非等比（纹理 {tw:.0f}x{th:.0f}）",
                "dev": abs(scale[0] / scale[1] - 1.0),
            })
        return

    # TextureRect：显式 stretch_mode 尊重设计；anchors 非 0 跳过（自适应不可静态判定）
    if stretch is not None:
        return
    if anchors and any(v != 0 for v in anchors.values()):
        return
    need = {"offset_left", "offset_right", "offset_top", "offset_bottom"}
    if not need.issubset(offsets.keys()):
        return
    dw = offsets["offset_right"] - offsets["offset_left"]
    dh = offsets["offset_bottom"] - offsets["offset_top"]
    if dw <= 1 or dh <= 1:
        return
    disp_ratio = dw / dh
    dev = abs(disp_ratio - tex_ratio) / tex_ratio
    if dev > THRESHOLD:
        findings.append({
            "path": path, "name": name, "type": typ, "line": cur["line"],
            "desc": f"显示 {dw:.0f}x{dh:.0f}(ratio {disp_ratio:.2f}) vs 纹理 {tw:.0f}x{th:.0f}(ratio {tex_ratio:.2f}) [{tex_name}]",
            "dev": dev,
        })


CONST_DEF_RE = re.compile(r'^const\s+([A-Za-z_]\w*)\s*(?::[^=]+)?=\s*"(res://[^"]+\.(?:png|jpg|webp))"')


def scan_gd(path):
    """扫 _add_texture_rect(...) 调用（第 2 参纹理、第 4 参显示尺寸）。"""
    with open(path, encoding="utf-8", errors="replace") as f:
        src = f.read()
    consts = {m.group(1): m.group(2) for m in CONST_DEF_RE.finditer(src)}
    repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    findings = []
    for m in re.finditer(r'_add_texture_rect\(([^;]+?)\)\s*(?:\n|$)', src):
        args = m.group(1)
        line = src[:m.start()].count("\n") + 1
        vm = VECTOR2_RE.findall(args)
        if len(vm) < 2:
            continue
        # 第 4 参 size = 第 2 个 Vector2；纹理 = 第 2 参开头
        dw, dh = float(vm[1][0]), float(vm[1][1])
        parts = [p.strip() for p in args.split(",")]
        tex_arg = parts[1] if len(parts) > 1 else ""
        res_path = None
        rm = RES_STR_RE.search(tex_arg)
        if rm:
            res_path = rm.group(1)
        else:
            for cname, cpath in consts.items():
                if tex_arg == cname:
                    res_path = cpath
                    break
        if not res_path or dw <= 1 or dh <= 1:
            continue
        tex = png_size(os.path.join(repo, res_path.replace("res://", "")))
        if not tex:
            continue
        tw, th = tex
        dev = abs(dw / dh - tw / th) / (tw / th)
        if dev > THRESHOLD:
            findings.append({
                "path": path, "name": f"{os.path.basename(res_path)}", "type": "gd",
                "line": line,
                "desc": f"显示 {dw:.0f}x{dh:.0f}(ratio {dw/dh:.2f}) vs 纹理 {tw:.0f}x{th:.0f}(ratio {tw/th:.2f})",
                "dev": dev,
            })
    return findings


def main():
    repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    findings = []
    tscn_files = sorted(glob.glob(os.path.join(repo, "scenes", "**", "*.tscn"), recursive=True))
    for tf in tscn_files:
        findings.extend(parse_tscn(os.path.relpath(tf, repo)))
    gd_files = sorted(glob.glob(os.path.join(repo, "scripts", "**", "*.gd"), recursive=True))
    for gf in gd_files:
        findings.extend(scan_gd(os.path.relpath(gf, repo)))

    findings.sort(key=lambda d: -d["dev"])
    print(f"=== 纹理非等比拉伸嫌疑清单（偏差阈值 {THRESHOLD:.0%}，共 {len(findings)} 处）===")
    for d in findings:
        print(f"[{d['path']}:{d['line']}] {d['name']} ({d['type']}) 偏差 {d['dev']:.0%} | {d['desc']}")
    print()
    print("=== 统计 ===")
    print(f"嫌疑总数 {len(findings)}，分布 {len(set(d['path'] for d in findings))} 个文件")
    c = Counter(d["path"] for d in findings)
    for p, n in c.most_common(10):
        print(f"  {p}: {n} 处")
    print("注：背景/底板/进度条类拉伸可能是设计意图（Scale9/填充），需人工甄别；图标/图案类高优先。")


if __name__ == "__main__":
    main()
