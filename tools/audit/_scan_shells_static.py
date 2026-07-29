#!/usr/bin/env python3
"""空壳节点 + 静态 procedural 残留综合扫描。

空壳节点：.tscn 里的 TextureRect/NinePatchRect/Sprite2D/TextureButton 但无 texture = ExtResource 行。
静态 procedural：.gd 里在 _ready/_init 阶段 .new() 建的节点（非动态列表项）。
"""
import os, re, glob
from pathlib import Path
from collections import defaultdict

# ========== Part 1: 空壳节点扫描 ==========
print('=' * 70)
print('Part 1: 空壳节点扫描（有图片类节点但无 texture）')
print('=' * 70)

IMAGE_NODE_TYPES = {'TextureRect', 'NinePatchRect', 'Sprite2D', 'TextureButton'}
shells = defaultdict(list)  # tscn -> [节点名]

for tscn in glob.glob('scenes/**/*.tscn', recursive=True):
    content = Path(tscn).read_text(encoding='utf-8', errors='ignore')
    # 按节点块分割
    # [node name="X" type="TextureRect" ...] 到下一个 [node 或文件尾
    node_pat = re.compile(r'\[node name="([^"]+)"[^]]*type="([^"]+)"[^]]*\](.*?)((?=\n\[node)|(?=\n\[ext)|(?=\n\[sub)|$)', re.DOTALL)
    for m in node_pat.finditer(content):
        name, ntype, body = m.group(1), m.group(2), m.group(3)
        if ntype in IMAGE_NODE_TYPES:
            # 检查是否有 texture = ExtResource(...) 或 texture = load(...)
            if 'texture = ExtResource' not in body and 'texture = load' not in body and 'texture = preload' not in body:
                # 可能是子节点继承，看是否有 placeholder
                shells[tscn].append((name, ntype))

total_shells = sum(len(v) for v in shells.values())
print(f'空壳图片节点总数: {total_shells}')
print()
if shells:
    print('=== 按文件分布（前 25）===')
    for tscn, nodes in sorted(shells.items(), key=lambda x: -len(x[1]))[:25]:
        print(f'  [{len(nodes):2d}]  {tscn}')
        for name, ntype in nodes[:5]:
            print(f'        {ntype}: {name}')
        if len(nodes) > 5:
            print(f'        ... +{len(nodes)-5} more')

print()
print('=' * 70)
print('Part 2: 静态 procedural 残留分析')
print('=' * 70)
print('（区分动态列表项 builder = 合规 vs _ready 静态建节点 = 债）')
print()

# Part 2: 静态 procedural
# 动态列表项 builder 文件命名特征：*_builder.gd, *_row*.gd, *_item*.gd, pop_*.gd
# 以及函数特征：build_xxx / create_xxx 返回节点给外部 add_child
# 静态残留特征：在 _ready() 里 var x = Xxx.new(); add_child(x)
BUILDER_PATTERN = re.compile(r'(builder|row|item|pop|factory|renderer|_icon|attribs|tabs|slots|tree)', re.I)

static_procedural = defaultdict(list)
builder_procedural = defaultdict(list)

for gd in glob.glob('scripts/**/*.gd', recursive=True):
    if '/test' in gd or '\\test' in gd:
        continue
    content = Path(gd).read_text(encoding='utf-8', errors='ignore')
    fname = Path(gd).name
    is_builder = bool(BUILDER_PATTERN.search(fname))

    # 找 _ready 函数体内的 .new()
    # 简化：找 _ready() 到下一个 func 之间的 .new()
    ready_match = re.search(r'func\s+_ready\s*\(\)(.*?)(?=\nfunc\s|\Z)', content, re.DOTALL)
    if ready_match:
        ready_body = ready_match.group(1)
        new_pat = re.compile(r'(\w+)\s*[:=]\s*=?\s*(\w+)\.new\(\)')
        for nm in new_pat.finditer(ready_body):
            var_name, node_type = nm.group(1), nm.group(2)
            if node_type in {'TextureRect','Label','Button','Panel','Sprite2D','ColorRect','NinePatchRect',
                             'MarginContainer','VBoxContainer','HBoxContainer','GridContainer','ScrollContainer',
                             'ProgressBar','TextureButton','Control','PanelContainer'}:
                if is_builder:
                    builder_procedural[gd].append((node_type, var_name, 'in _ready'))
                else:
                    static_procedural[gd].append((node_type, var_name, 'in _ready'))

total_static = sum(len(v) for v in static_procedural.values())
total_builder = sum(len(v) for v in builder_procedural.values())
print(f'_ready() 内静态建节点（非 builder 文件，疑似债）: {total_static}')
print(f'_ready() 内建节点（builder 文件，需个案判断）: {total_builder}')
print()

if static_procedural:
    print('=== 疑似静态 procedural 残留（非 builder 文件的 _ready 内建节点）===')
    for gd, nodes in sorted(static_procedural.items(), key=lambda x: -len(x[1])):
        print(f'  [{len(nodes)}]  {gd}')
        for ntype, vname, ctx in nodes[:8]:
            print(f'        {ntype}.new() -> {vname}  ({ctx})')

print()
print('=== builder 文件 _ready 内建节点（合规候选，需看是否纯函数式 builder）===')
for gd, nodes in sorted(builder_procedural.items(), key=lambda x: -len(x[1]))[:15]:
    print(f'  [{len(nodes)}]  {gd}')
    for ntype, vname, ctx in nodes[:4]:
        print(f'        {ntype}.new() -> {vname}')
