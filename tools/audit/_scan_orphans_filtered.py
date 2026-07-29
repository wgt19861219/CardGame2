#!/usr/bin/env python3
"""UI 孤儿资产 - 第二轮：排除单机化废弃功能后，找「本项目有功能但资源没用上」的真缺口。"""
import os, re, glob
from pathlib import Path
from collections import Counter, defaultdict

# AGENTS.md 单机化约束：砍掉的功能（联机/活动/公会/pvp/聊天）
# 这些目录的孤儿属合理废弃，不算缺口
DEPRECATED_DIRS = {
    'activity', 'act',  # 活动（运营活动，单机不需要）
    'chat',  # 聊天（联机功能）
    'connect',  # 联机
    'guild',  # 公会
    'pvp',  # 联机对战
    'lang',  # 多语言切图（本项目用 i18n 文本，不用切图）
}

# 本项目保留的功能（孤儿资源可能是「该接入没接入」的缺口）
KEEP_FEATURE_DIRS = {
    'key_stages': '关卡章节地图',
    'crusade': '远征',
    'excavate': '挖掘',
    'ranklist': '排行榜',
    'midas': '点石成金',
    'mailbox': '邮件',
    'dailylogin': '签到',
    'equipupgrade': '装备强化',
    'stagedetail': '关卡详情',
    'card': '卡牌通用',
    'common': '通用',
    'digits': '数字字体',
    'art': 'art',
    '(root)': 'UI 根目录通用',
}

# 1. 收集引用
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

# 2. 只看 assets/ui/alpha/HVGA/ 下保留功能的孤儿
orphans_by_feature = defaultdict(list)
for p in Path('assets/ui').rglob('*.png'):
    asset = str(p).replace(os.sep, '/')
    name = asset.split('/')[-1]
    if asset in referenced_full or name in referenced_names:
        continue
    # 分类
    parts = asset.split('/')
    if 'HVGA' in parts:
        idx = parts.index('HVGA')
        sub = parts[idx+1] if idx+1 < len(parts)-1 else '(root)'
    else:
        continue  # 非 HVGA 的暂跳过
    if sub in DEPRECATED_DIRS:
        continue
    orphans_by_feature[sub].append((parts[-1], asset))

print('=== 本项目保留功能中「资源存在但没被引用」的孤儿 ===')
print('（排除 activity/chat/connect/guild/pvp/lang 等单机化废弃功能）')
print()
total = 0
for sub in sorted(orphans_by_feature.keys()):
    items = sorted(orphans_by_feature[sub])
    total += len(items)
    desc = KEEP_FEATURE_DIRS.get(sub, '?')
    print(f'## [{sub}] {desc}  ({len(items)} 个孤儿)')
    # 显示全部，因为要看哪些是真缺口
    for name, path in items:
        print(f'    {name}')
    print()

print(f'保留功能孤儿总数: {total}')
