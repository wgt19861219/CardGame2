#!/usr/bin/env python3
"""精确真空壳扫描：.tscn 无任何 texture 类属性 的图片节点，且 .gd 也没 set_texture/texture = 赋值 = 真债。
排除：运行时动态贴图的合规节点。
注意 TextureButton 用 texture_normal/pressed/hover/focused/disabled，不是 texture。"""
import os, re, glob
from pathlib import Path
from collections import defaultdict

IMAGE_NODE_TYPES = {'TextureRect', 'NinePatchRect', 'Sprite2D', 'TextureButton'}

# 所有 texture 类属性（texture / texture_normal / texture_pressed / texture_hover / texture_focused / texture_disabled / texture_click_mask）
TEXTURE_PROPS = [
    'texture =', 'texture_normal', 'texture_pressed', 'texture_hover',
    'texture_focused', 'texture_disabled', 'texture_click_mask',
]
# 1. 收集 .tscn 真空壳节点（无任何 texture 类属性）
shells = defaultdict(list)
for tscn in glob.glob('scenes/**/*.tscn', recursive=True):
    content = Path(tscn).read_text(encoding='utf-8', errors='ignore')
    node_pat = re.compile(r'\[node name="([^"]+)"[^]]*type="([^"]+)"[^]]*\](.*?)((?=\n\[node)|(?=\n\[ext)|(?=\n\[sub)|$)', re.DOTALL)
    for m in node_pat.finditer(content):
        name, ntype, body = m.group(1), m.group(2), m.group(3)
        if ntype not in IMAGE_NODE_TYPES:
            continue
        # 检查是否有任何 texture 类属性赋值（ExtResource/load/preload）
        has_texture = False
        for prop in TEXTURE_PROPS:
            # texture_normal = ExtResource(...) 或 texture = load(...)
            pat = re.compile(r'^\s*' + re.escape(prop) + r'\s*=\s*(ExtResource|load|preload)', re.MULTILINE)
            if pat.search(body):
                has_texture = True
                break
        if not has_texture:
            shells[tscn].append((name, ntype))

# 2. 对每个空壳，检查所有 .gd 是否给它 set_texture / .texture =
# 收集所有 .gd 文本
gd_texts = {}
for gd in glob.glob('scripts/**/*.gd', recursive=True):
    gd_texts[gd] = Path(gd).read_text(encoding='utf-8', errors='ignore')

# 对节点名 X，查 .texture = 或 set_texture 模式是否出现且引用 X
# 简化：节点名出现在 .gd 里 + 附近有 texture 赋值 = 动态贴图（合规）
def is_dynamically_textured(node_name):
    """节点名在 .gd 里出现且同一文件有 texture 赋值/normal_texture 等 = 合规动态贴图。"""
    for gd, text in gd_texts.items():
        if node_name not in text:
            continue
        # 节点名出现，检查是否有 texture 相关赋值（宽松：同文件有即可，Builder 模式常 get_node 后赋值）
        if re.search(r'\.texture\s*=|set_texture|normal_texture|pressed_texture|hover_texture|focus_texture', text):
            return True, gd
    return False, None

real_shells = defaultdict(list)
dynamic_shells = defaultdict(list)
for tscn, nodes in shells.items():
    for name, ntype in nodes:
        dyn, gd = is_dynamically_textured(name)
        if dyn:
            dynamic_shells[tscn].append((name, ntype, gd or ''))
        else:
            real_shells[tscn].append((name, ntype))

total_real = sum(len(v) for v in real_shells.values())
total_dyn = sum(len(v) for v in dynamic_shells.values())
print(f'空壳总数: {total_real + total_dyn}')
print(f'  运行时动态贴图（合规）: {total_dyn}')
print(f'  真空壳（.gd 也没赋贴图，债）: {total_real}')
print()
print('=== 真空壳按文件分布（全部列出）===')
for tscn, nodes in sorted(real_shells.items(), key=lambda x: -len(x[1])):
    print(f'  [{len(nodes)}]  {tscn}')
    for name, ntype in nodes:
        print(f'        {ntype}: {name}')
    print()

print()
print('=== 动态贴图合规空壳 TOP10（仅供对照，非债）===')
for tscn, nodes in sorted(dynamic_shells.items(), key=lambda x: -len(x[1]))[:10]:
    print(f'  [{len(nodes)}]  {tscn}')
    for name, ntype, gd in nodes[:3]:
        print(f'        {ntype}: {name}  <- {Path(gd).name}')
