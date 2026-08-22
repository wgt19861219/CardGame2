# -*- coding: utf-8 -*-
"""patch_margin 口径交叉核对: CG2 tscn NinePatchRect vs 源 lua capInsets。
口径: 源 cap 小数=点单位(CG2 直译即对); 整数=纹理px(CG2 应 ÷CS, 直抄即债)。
用法: python tools/audit/cross_check_patch_margin.py
"""
import re, os, struct, json, sys

CG2 = r"D:\workspace\projects\CardGame2"
SRC = r"D:\workspace\projects\CardGameAxmol\Content\src"
CS = 1.28125

def png_size(path):
    with open(path, "rb") as f:
        head = f.read(26)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    w, h = struct.unpack(">II", head[16:24])
    return w, h

# CG2 资产纹理尺寸缓存(按 basename)
tex_cache = {}
def find_tex_size(basename):
    if basename in tex_cache:
        return tex_cache[basename]
    hit = None
    for root, _, files in os.walk(os.path.join(CG2, "assets")):
        if basename in files:
            hit = png_size(os.path.join(root, basename))
            break
    tex_cache[basename] = hit
    return hit

# ---- 解析源 lua: capInsets + 就近 res ----
src_caps = []  # {file, line, res, cap(x,y,w,h)}
cap_re = re.compile(r"capInsets\s*=\s*(CCRectMake|ed\.DGRectMake)\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)")
res_re = re.compile(r'res\s*=\s*"([^"]+)"')
for root, _, files in os.walk(SRC):
    for fn in files:
        if not fn.endswith(".lua"):
            continue
        p = os.path.join(root, fn)
        try:
            lines = open(p, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            continue
        for i, ln in enumerate(lines):
            m = cap_re.search(ln)
            if not m:
                continue
            dg = m.group(1).endswith("DGRectMake")  # DG 单位 ×0.78125 = CC（readnode.lua:13-16）
            # 向上找最近 res 声明(限 15 行)
            resname = None
            # 双向就近找 res（capInsets 可能在 res 上方或下方, uieditor 两种顺序都有）
            for d in range(0, 31):
                for j in (i - d, i + d):
                    if 0 <= j < len(lines):
                        rm = res_re.search(lines[j])
                        if rm:
                            resname = rm.group(1)
                            break
                if resname:
                    break
            src_caps.append({
                "inline": False,
                "file": os.path.relpath(p, SRC).replace("\\", "/"),
                "line": i + 1,
                "res": resname or "?",
                "cap": tuple(float(x) * (0.78125 if dg else 1.0) for x in m.groups()[1:]),
            })

# inline createScale9Sprite("res", [ed.]DGRectMake/CCRectMake(...)) 调用也入索引
inline_re = re.compile(r'createScale9Sprite\(\s*"[^"]*?([\w./-]+\.png)"\s*,\s*(?:ed\.)?(CCRectMake|DGRectMake)\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)')
for root, _, files in os.walk(SRC):
    for fn in files:
        if not fn.endswith(".lua"):
            continue
        p = os.path.join(root, fn)
        try:
            txt = open(p, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for m in inline_re.finditer(txt):
            vals = tuple(float(x) for x in m.groups()[2:])
            if m.group(2) == "DGRectMake":
                vals = tuple(v * 0.78125 for v in vals)
            src_caps.append({
                "inline": True,
                "file": os.path.relpath(p, SRC).replace("\\", "/"),
                "line": txt[:m.start()].count("\n") + 1,
                "res": m.group(1),
                "cap": vals,
            })

# 源纹理尺寸: 从 CardGameAxmol Content/res 找
AXM_RES = r"D:\workspace\projects\CardGameAxmol\Content\res"
ax_tex_cache = {}
def ax_tex_size(respath):
    key = respath.replace("\\", "/")
    if key in ax_tex_cache:
        return ax_tex_cache[key]
    hit = None
    cand = os.path.join(AXM_RES, key)
    if os.path.isfile(cand):
        hit = png_size(cand)
    else:
        base = os.path.basename(key)
        for root, _, files in os.walk(AXM_RES):
            if base in files:
                hit = png_size(os.path.join(root, base))
                break
    ax_tex_cache[key] = hit
    return hit

def is_int_caps(cap):
    return all(abs(c - round(c)) < 1e-6 for c in cap)

def margins_pts(cap, tw, th):
    """cap=点单位: margin(点)=left=x, bottom=y, right=W_pt-x-w, top=H_pt-y-h"""
    Wpt, Hpt = tw / CS, th / CS
    x, y, w, h = cap
    return (x, th / CS - y - h, Wpt - x - w, y)  # (l, t, r, b)

def margins_px_div(cap, tw, th):
    """cap=px单位: margin(点) = px 值 ÷ CS（源退化 cap 顶/底越界按 0 钳制，如 tip_detail_bg）"""
    x, y, w, h = cap
    return (x / CS, max(0.0, (th - y - h) / CS), (tw - x - w) / CS, y / CS)

def margins_raw_px(cap, tw, th):
    """直抄 px(债形态): margin = px 值原样（越界钳 0）"""
    x, y, w, h = cap
    return (x, max(0.0, th - y - h), tw - x - w, y)

def close(a, b, tol=1.6):
    return all(abs(p - q) <= tol for p, q in zip(a, b))

# ---- 解析 CG2 tscn ----
ext_re = re.compile(r'\[ext_resource type="Texture2D"[^\]]*\]')
attr_path = re.compile(r'path="([^"]+)"')
attr_id = re.compile(r'id="([^"]+)"')
node_re = re.compile(r'\[node name="[^"]+" type="NinePatchRect"')
any_node_re = re.compile(r'\[node ')
patch_re = re.compile(r"patch_margin_(left|top|right|bottom) = (\d+)")
texref_re = re.compile(r'texture = ExtResource\("([^"]+)"\)')

report = []
for root, _, files in os.walk(os.path.join(CG2, "scenes")):
    for fn in files:
        if not fn.endswith(".tscn"):
            continue
        p = os.path.join(root, fn)
        lines = open(p, encoding="utf-8", errors="replace").read().splitlines()
        extmap = {}
        for ln in lines:
            m = ext_re.search(ln)
            if m:
                mp = attr_path.search(ln)
                mi = attr_id.search(ln)
                if mp and mi:
                    extmap[mi.group(1)] = mp.group(1)
        cur = None  # (nodename, {side:val}, texid)
        def flush():
            global cur
            if cur and cur[2] and len(cur[1]) == 4:
                report.append((os.path.relpath(p, CG2).replace("\\", "/"), cur[0], cur[1], extmap.get(cur[2], "")))
        for ln in lines:
            if any_node_re.match(ln):
                flush()
                cur = [None, {}, None] if node_re.match(ln) else None
                if cur is not None:
                    cur[0] = re.search(r'name="([^"]+)"', ln).group(1)
                continue
            if cur is None:
                continue
            pm = patch_re.search(ln)
            if pm:
                cur[1][pm.group(1)] = int(pm.group(2))
                continue
            tm = texref_re.search(ln)
            if tm:
                cur[2] = tm.group(1)
        flush()

print(f"CG2 NinePatchRect 节点数: {len(report)}  源 capInsets 声明数: {len(src_caps)}")
print()

import math
def half_up(v):
    return math.floor(v + 0.5)

FIX = "--fix" in sys.argv
# 重扫带行号, 对 DEBT 节点计算新值
fixes = []  # (scene, rel_path_no, node, side, old, new)
issues = 0
matched = 0
for scene, node, pm, texpath in report:
    base = os.path.basename(texpath)
    if not base:
        continue
    cands = [c for c in src_caps if os.path.basename(c["res"]) == base]
    if not cands:
        continue
    matched += 1
    sz = ax_tex_size(cands[0]["res"]) or find_tex_size(base)
    if not sz:
        continue
    tw, th = sz
    got = (pm["left"], pm["top"], pm["right"], pm["bottom"])
    hit = None
    for c in cands:
        cap = c["cap"]
        pts = margins_pts(cap, tw, th)
        pxdiv = margins_px_div(cap, tw, th)
        raw = margins_raw_px(cap, tw, th)
        if close(got, tuple(round(v) for v in pts)):
            print(f"OK-点单位直译   {scene}::{node} got={got}")
            hit = "ok"
            break
        if close(got, tuple(round(v) for v in pxdiv)):
            print(f"OK-px÷CS        {scene}::{node} got={got}")
            hit = "ok"
            break
        if close(got, tuple(round(v) for v in raw)):
            x, y, w, h = cap
            newv = (half_up(x / CS), half_up((th - y - h) / CS), half_up((tw - x - w) / CS), half_up(y / CS))
            print(f"DEBT-px直抄     {scene}::{node} got={got} -> {newv}  (src {c['file']}:{c['line']} cap={cap} tex={tw}x{th})")
            hit = (c, newv)
            issues += 1
            break
    if hit and hit != "ok" and FIX:
        fixes.append((scene, node, hit[1]))
print()
print(f"纹理可匹配节点: {matched}/{len(report)}  其中 px 直抄嫌疑: {issues}")

if FIX and fixes:
    from_by_scene = {}
    for scene, node, newv in fixes:
        from_by_scene.setdefault(scene, []).append((node, newv))
    for scene, items in from_by_scene.items():
        path = os.path.join(CG2, scene)
        lines = open(path, encoding="utf-8").read().splitlines()
        # 重新定位每个节点块的 patch 行
        out_lines = []
        cur_target = None  # (node, newv, {side: done})
        i = 0
        any_node_re2 = re.compile(r"\[node ")
        npr = re.compile(r'\[node name="([^"]+)" type="NinePatchRect"')
        pr = re.compile(r"patch_margin_(left|top|right|bottom) = (\d+)")
        for ln in lines:
            if any_node_re2.match(ln):
                cur_target = None
                m = npr.match(ln)
                if m:
                    for node, newv in items:
                        if m.group(1) == node:
                            cur_target = (newv, set())
            elif cur_target is not None:
                m = pr.search(ln)
                if m:
                    side = m.group(1)
                    idx = {"left": 0, "top": 1, "right": 2, "bottom": 3}[side]
                    ln = f"patch_margin_{side} = {cur_target[0][idx]}"
                    cur_target[1].add(side)
            out_lines.append(ln)
        open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out_lines) + "\n")
        print(f"FIXED {scene}: {len(items)} nodes")

