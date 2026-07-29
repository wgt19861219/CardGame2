#!/usr/bin/env python3
"""聚焦 UI 孤儿资产：只看 assets/ui/ 下没被引用的 png，排除 anim_frames/spine/sound/projectile。"""
import os, re, glob
from pathlib import Path
from collections import Counter, defaultdict

# 1. 收集所有被引用的 assets 路径（含 .gd 动态拼接可能用到的文件名）
ref_pat_tscn = re.compile(r'res://(assets/[^\s"]+)')
ref_pat_gd = re.compile(r'(?:load|preload)\(\s*"res://(assets/[^"]+)"')
# .gd 里可能用字符串拼接引用资源，捕获 assets/ 下出现的文件名片段
ref_pat_gd_str = re.compile(r'["\']([A-Za-z0-9_\-/]+\.(?:png|jpg|jpeg))["\']')

referenced_full = set()  # 完整路径
referenced_names = set()  # 仅文件名（用于动态拼接匹配）
for tscn in glob.glob('scenes/**/*.tscn', recursive=True):
    content = Path(tscn).read_text(encoding='utf-8', errors='ignore')
    for m in ref_pat_tscn.finditer(content):
        referenced_full.add(m.group(1))
        referenced_names.add(m.group(1).split('/')[-1])
for gd in glob.glob('scripts/**/*.gd', recursive=True):
    content = Path(gd).read_text(encoding='utf-8', errors='ignore')
    for m in ref_pat_gd.finditer(content):
        referenced_full.add(m.group(1))
        referenced_names.add(m.group(1).split('/')[-1])
    for m in ref_pat_gd_str.finditer(content):
        referenced_names.add(m.group(1).split('/')[-1])
for tres in glob.glob('resources/**/*.tres', recursive=True):
    content = Path(tres).read_text(encoding='utf-8', errors='ignore')
    for m in ref_pat_tscn.finditer(content):
        referenced_full.add(m.group(1))
        referenced_names.add(m.group(1).split('/')[-1])
# resources/data JSON 可能列资源名
for js in glob.glob('resources/**/*.json', recursive=True):
    content = Path(js).read_text(encoding='utf-8', errors='ignore')
    for m in ref_pat_gd_str.finditer(content):
        referenced_names.add(m.group(1).split('/')[-1])

referenced_full = set(r.lstrip('/') for r in referenced_full)

# 2. 只看 assets/ui/ 下的 png
ui_assets = []
for p in Path('assets/ui').rglob('*.png'):
    ui_assets.append(str(p).replace(os.sep, '/'))
print(f'assets/ui/ 下 png 总数: {len(ui_assets)}')

# 3. 分类
orphans_ui = []
used_ui = []
for asset in ui_assets:
    name = asset.split('/')[-1]
    if asset in referenced_full or name in referenced_names:
        used_ui.append(asset)
    else:
        orphans_ui.append(asset)

print(f'被引用（含动态拼接）: {len(used_ui)}')
print(f'孤儿 UI 资产: {len(orphans_ui)}')
print()

# 4. 按 assets/ui/alpha/HVGA/<子目录> 归类
print('=== 孤儿 UI 资产按子目录分布 ===')
dir_counter = Counter()
dir_samples = defaultdict(list)
for o in orphans_ui:
    # assets/ui/alpha/HVGA/<sub>/file.png -> sub
    parts = o.split('/')
    if 'alpha/HVGA' in o:
        idx = parts.index('HVGA')
        sub = parts[idx+1] if idx+1 < len(parts)-1 else '(root)'
    elif 'ui/HERO' in o:
        sub = 'HERO'
    elif 'ui/ITEM' in o:
        sub = 'ITEM'
    elif 'ui/art' in o:
        sub = 'art'
    elif 'ui/portrait' in o:
        sub = 'portrait'
    else:
        sub = '/'.join(parts[2:-1]) or '(root)'
    dir_counter[sub] += 1
    dir_samples[sub].append(parts[-1])

for d, c in dir_counter.most_common(40):
    print(f'  {c:4d}  {d}')

print()
print('=== 各子目录孤儿样本（前 30 个子目录，每个 8 个文件名）===')
for d in sorted(dir_samples.keys())[:30]:
    samples = sorted(dir_samples[d])[:8]
    print(f'  [{d}]  ({len(dir_samples[d])} 个)')
    for s in samples:
        print(f'      {s}')
