#!/usr/bin/env python3
"""第三轮精确分析：把 75 真空壳节点 与 孤儿 assets 资源 配对，
产出「空壳节点 + 对应可用孤儿资源」的可执行修复清单。

输出按场景分组的修复建议，每个建议含：
- 场景/文件
- 空壳节点（type, name）
- 候选孤儿资源（按文件名相关性排序）
- 推荐度（高/中/低）
"""
import os, re, glob
from pathlib import Path
from collections import defaultdict

IMAGE_NODE_TYPES = {'TextureRect', 'NinePatchRect', 'Sprite2D', 'TextureButton'}
TEXTURE_PROPS = ['texture =', 'texture_normal', 'texture_pressed', 'texture_hover',
                 'texture_focused', 'texture_disabled', 'texture_click_mask']

# ===== 1. 收集真空壳 =====
shells = []
for tscn in glob.glob('scenes/**/*.tscn', recursive=True):
    content = Path(tscn).read_text(encoding='utf-8', errors='ignore')
    node_pat = re.compile(r'\[node name="([^"]+)"[^]]*type="([^"]+)"[^]]*\](.*?)((?=\n\[node)|(?=\n\[ext)|(?=\n\[sub)|$)', re.DOTALL)
    for m in node_pat.finditer(content):
        name, ntype, body = m.group(1), m.group(2), m.group(3)
        if ntype not in IMAGE_NODE_TYPES:
            continue
        has_texture = False
        for prop in TEXTURE_PROPS:
            pat = re.compile(r'^\s*' + re.escape(prop) + r'\s*=\s*(ExtResource|load|preload)', re.MULTILINE)
            if pat.search(body):
                has_texture = True
                break
        if not has_texture:
            shells.append((tscn, name, ntype))

# ===== 2. 收集被引用集（用于判定孤儿）=====
ref_pat_tscn = re.compile(r'res://(assets/[^\s"]+)')
ref_pat_gd = re.compile(r'(?:load|preload)\(\s*"res://(assets/[^"]+)"')
ref_pat_str = re.compile(r'["\']([A-Za-z0-9_\-/]+\.(?:png|jpg|jpeg))["\']')
referenced_full = set()
referenced_names = set()
for f in glob.glob('scenes/**/*.tscn', recursive=True) + glob.glob('resources/**/*.tres', recursive=True):
    content = Path(f).read_text(encoding='utf-8', errors='ignore')
    for m in ref_pat_tscn.finditer(content):
        referenced_full.add(m.group(1).lstrip('/'))
        referenced_names.add(m.group(1).split('/')[-1])
for gd in glob.glob('scripts/**/*.gd', recursive=True):
    content = Path(gd).read_text(encoding='utf-8', errors='ignore')
    for m in ref_pat_gd.finditer(content):
        referenced_full.add(m.group(1).lstrip('/'))
        referenced_names.add(m.group(1).split('/')[-1])
    for m in ref_pat_str.finditer(content):
        referenced_names.add(m.group(1).split('/')[-1])
for js in glob.glob('resources/**/*.json', recursive=True):
    content = Path(js).read_text(encoding='utf-8', errors='ignore')
    for m in ref_pat_str.finditer(content):
        referenced_names.add(m.group(1).split('/')[-1])

# ===== 3. 收集孤儿 assets（assets/ui 下）=====
orphans = {}  # name -> path
for p in Path('assets/ui').rglob('*.png'):
    asset = str(p).replace(os.sep, '/')
    name = p.name
    if asset in referenced_full or name in referenced_names:
        continue
    orphans[name] = asset

# ===== 4. 配对：对每个真空壳，按文件名关键词找候选孤儿 =====
def keywords(node_name):
    # StarGrey2 -> ['star', 'grey', 'stargrey', 'stargrey2']
    # EquipSlot3 -> ['equip', 'slot', 'equipslot', 'equipslot3']
    # Skill1Icon -> ['skill', 'icon', 'skill1', 'skill1icon']
    clean = re.sub(r'([a-z])([A-Z])', r'\1_\2', node_name).lower()
    clean = re.sub(r'([a-zA-Z])(\d)', r'\1_\2', clean)
    parts = [w for w in re.split(r'[_\s]+', clean) if w]
    # 合并连续字母+数字
    merged = node_name.lower()
    return parts, merged

def score_match(node_name, orphan_name):
    """打分：文件名相关性。"""
    n_parts, n_merged = keywords(node_name)
    o = orphan_name.lower().replace('.png','').replace('.jpg','')
    o_parts = [w for w in re.split(r'[_\s\-]+', o) if w]
    score = 0
    # 完全合并匹配（stargrey2 == herodetail_star_grey 不直接等，但部分）
    # 部分匹配：节点的每个 part 在孤儿名里出现
    for np in n_parts:
        if len(np) <= 1:
            continue
        for op in o_parts:
            if np == op or np in op or op in np:
                score += 2
    # 节点名整体在孤儿名里
    if n_merged.replace('_','') in o.replace('_',''):
        score += 3
    # 去掉数字后匹配（StarGrey2 vs star_grey）
    n_no_num = re.sub(r'\d+$', '', n_merged).replace('_','')
    if len(n_no_num) >= 3 and n_no_num in o.replace('_',''):
        score += 4
    return score

# 排除明显废弃功能目录的孤儿（活动/聊天/联机/公会/pvp/语言）
DEPRECATED = {'activity','act','chat','connect','guild','pvp','lang'}
def is_deprecated(path):
    return any(d in path for d in DEPRECATED)

print('=' * 70)
print(f'真空壳总数: {len(shells)}   孤儿资源总数: {len(orphans)}')
print('=' * 70)
print()

# 按场景文件分组
by_scene = defaultdict(list)
for tscn, name, ntype in shells:
    # 简化场景名
    scene = tscn.replace('\\','/').replace('scenes/ui/','').replace('scenes/battle/','').replace('_content.tscn','').replace('.tscn','')
    by_scene[scene].append((name, ntype, tscn))

for scene in sorted(by_scene.keys()):
    nodes = by_scene[scene]
    print(f'## [{scene}]  {len(nodes)} 个真空壳')
    for name, ntype, tscn in nodes:
        # 找 top3 候选孤儿
        scored = []
        for oname, opath in orphans.items():
            if is_deprecated(opath):
                continue
            s = score_match(name, oname)
            if s > 0:
                scored.append((s, oname, opath))
        scored.sort(key=lambda x: -x[0])
        top = scored[:3]
        if top:
            cands = ' | '.join(f'{on}({s})' for s,on,op in top)
            print(f'    {ntype:14s} {name:18s} -> 候选: {cands}')
        else:
            print(f'    {ntype:14s} {name:18s} -> 无匹配孤儿（可能需 procedural 或新增资源）')
    print()
