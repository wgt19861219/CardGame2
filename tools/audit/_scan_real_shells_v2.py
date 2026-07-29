#!/usr/bin/env python3
"""真空壳扫描 v2：修正 v1 的节点 body 捕获 bug。

v1 bug：正则 body 捕获组用 re.DOTALL 非贪婪，但边界 (?=\n\[node) 在某些情况下
让 body 在 texture 行之前就被截断，导致大量误报（把已有贴图的节点判为空壳）。

v2 修法：按行分割，[node 开始一个节点块，累积到下一个 [ 开头的行（[node/[ext/[sub/[gd_scene/[connection 等）。
对每个节点块检查是否有 texture 类属性。
"""
import os, re, glob
from pathlib import Path
from collections import defaultdict

IMAGE_NODE_TYPES = {'TextureRect', 'NinePatchRect', 'Sprite2D', 'TextureButton'}
# 所有 texture 类属性前缀（注意 texture_click_mask 也算）
TEXTURE_ATTR_RE = re.compile(r'^(texture|texture_normal|texture_pressed|texture_hover|texture_focused|texture_disabled|texture_click_mask)\s*=\s*(ExtResource|load|preload)', re.MULTILINE)

def parse_tscn_nodes(content):
    """返回 [(node_name, node_type, body_text), ...]。body 是节点声明到下一个 [ 之间的全部文本。"""
    nodes = []
    lines = content.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]
        # 匹配 [node name="X" type="Y" ...]
        m = re.match(r'\[node name="([^"]+)"[^]]*type="([^"]+)"', line)
        if m:
            name, ntype = m.group(1), m.group(2)
            # 收集 body：从下一行开始，直到遇到下一个 [ 开头的行
            body_lines = []
            j = i + 1
            while j < len(lines):
                bl = lines[j]
                if bl.startswith('['):
                    break
                body_lines.append(bl)
                j += 1
            body = '\n'.join(body_lines)
            nodes.append((name, ntype, body))
            i = j
        else:
            i += 1
    return nodes

# 1. 收集真空壳（无任何 texture 类属性赋值的图片节点）
shells = []
total_image_nodes = 0
for tscn in glob.glob('scenes/**/*.tscn', recursive=True):
    content = Path(tscn).read_text(encoding='utf-8', errors='ignore')
    for name, ntype, body in parse_tscn_nodes(content):
        if ntype in IMAGE_NODE_TYPES:
            total_image_nodes += 1
            if not TEXTURE_ATTR_RE.search(body):
                shells.append((tscn, name, ntype, body))

print(f'扫描 .tscn 数: {len(glob.glob("scenes/**/*.tscn", recursive=True))}')
print(f'图片类节点总数: {total_image_nodes}')
print(f'真空壳节点（无 texture 类属性）: {len(shells)}')
print()

# 2. 按文件分组
by_file = defaultdict(list)
for tscn, name, ntype, body in shells:
    by_file[tscn].append((name, ntype))

print('=== 真空壳按文件分布（全部）===')
for tscn, nodes in sorted(by_file.items(), key=lambda x: -len(x[1])):
    scene = tscn.replace('\\','/').split('/')[-1]
    print(f'  [{len(nodes):2d}]  {scene}')
    for name, ntype in sorted(nodes):
        print(f'        {ntype:14s} {name}')
    print()
