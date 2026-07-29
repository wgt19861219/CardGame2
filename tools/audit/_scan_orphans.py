#!/usr/bin/env python3
"""孤儿资产扫描：assets 下存在但没被任何 .tscn/.gd/.tres 引用的图片。"""
import os, re, glob
from pathlib import Path
from collections import Counter

root = Path('.')

# 1. 收集所有被引用的 assets 路径
ref_pat_tscn = re.compile(r'res://(assets/[^\s"]+)')
ref_pat_gd = re.compile(r'(?:load|preload)\(\s*"res://(assets/[^"]+)"')

referenced = set()
for tscn in glob.glob('scenes/**/*.tscn', recursive=True):
    content = Path(tscn).read_text(encoding='utf-8', errors='ignore')
    for m in ref_pat_tscn.finditer(content):
        referenced.add(m.group(1))
for gd in glob.glob('scripts/**/*.gd', recursive=True):
    content = Path(gd).read_text(encoding='utf-8', errors='ignore')
    for m in ref_pat_gd.finditer(content):
        referenced.add(m.group(1))
for tres in glob.glob('resources/**/*.tres', recursive=True):
    content = Path(tres).read_text(encoding='utf-8', errors='ignore')
    for m in ref_pat_tscn.finditer(content):
        referenced.add(m.group(1))

print(f'被引用的 assets 路径数（去重）: {len(referenced)}')

# 2. 列出 assets 下所有 png/jpg 文件
all_assets = []
for ext in ['png', 'jpg', 'jpeg']:
    for p in Path('assets').rglob('*.' + ext):
        all_assets.append(str(p).replace(os.sep, '/'))
print(f'assets 下图片文件总数: {len(all_assets)}')

# 3. 匹配
ref_normalized = set(r.lstrip('/') for r in referenced)
orphans = []
used = []
for asset in all_assets:
    if asset in ref_normalized:
        used.append(asset)
    else:
        orphans.append(asset)

print(f'被引用: {len(used)}')
print(f'孤儿（存在但没被引用）: {len(orphans)}')
print()

# 4. 孤儿按目录归类
print('=== 孤儿资产按目录分布（TOP 25）===')
dir_counter = Counter()
for o in orphans:
    parts = o.split('/')
    key = '/'.join(parts[:4]) if len(parts) >= 4 else '/'.join(parts[:-1])
    dir_counter[key] += 1
for d, c in dir_counter.most_common(25):
    print(f'  {c:4d}  {d}')

print()
print('=== 孤儿资产按子目录抽样（前 30 个目录，每个 5 个文件名）===')
dir_samples = {}
for o in orphans:
    parts = o.split('/')
    key = '/'.join(parts[:4]) if len(parts) >= 4 else '/'.join(parts[:-1])
    dir_samples.setdefault(key, []).append(parts[-1])
for d in sorted(dir_samples.keys())[:30]:
    samples = dir_samples[d][:5]
    print(f'  {d}  ({len(dir_samples[d])} 个)')
    for s in samples:
        print(f'      {s}')
