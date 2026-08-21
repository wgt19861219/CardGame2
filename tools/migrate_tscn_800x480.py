# -*- coding: utf-8 -*-
"""tscn 屏幕坐标批量迁移 960x640 → 800x480（viewport 迁移 Task 4）

背景（2026-08-21 计划 docs/superpowers/plans/2026-08-21-viewport-800x480-ui-align.md）：
viewport 960x640 → 800x480（=源 Cocos 设计空间 1:1）。tscn 静态坐标是 960x640 时代
复刻摆放值，实测存在三种坐标语义（依据源 lua ccp 对照验证，见 task-4-report.md）：

  A. shift   平移式（旧 to_godot (x+80, 560-y) 产物，占绝大多数弹窗/面板）：
             x_new = x_old - 80, y_new = y_old - 80（差值等值迁移，与 gd 侧 Task 3 配对）
  B. fit12   等比拉满式（x*1.2 / (480-y)*1.333，stage_done 三星/标题精确验证）：
             x_new = x_old / 1.2, y_new = 480 - (640 - y_old) / 1.3333
  C. scale13 中心缩放式（SC=1.3333 全屏 pushScene 面板，handbook BackBtn (70,428)
             数学验证）：x_new = (x_old + 53.33) / 1.3333, y_new = 480 - (640 - y_old) / 1.3333

不动体系（白名单）：
  - scenes/main_menu/（Task 2 已完成）
  - item/cell/小组件场景（根即条目，被 gd 动态定位，内部为条目局部布局 = 体系 C）
  - 锚定自适应场景（battle_hud / battle_pause_layer：ap=2/8/10 锚定语义）
  - shortcut_content（Task 3 已运行时覆盖 shade/tag，其余 gd 动态定位）
  - 深层节点（面板框/滚动容器/列表行内 = 体系 C 局部布局）：只迁根直挂 +
    "透明全铺层"（Control ap=15 无显式 rect）下的屏幕绝对层

特改规则：
  - FrameworkBg（offset 0,0→960,640 的全屏背景，bg.jpg 源语义 ccp(400,240) 铺满）
    → 重设 0,0→800,480（-80 会露 80px 边）
  - 贴角惯例节点（CloseBtn 20,15 类，相对视口角语义）→ 白名单不动
  - Sprite2D position：fit12/scale13 文件中挂屏幕层的 Sprite2D position 一并迁移；
    shift 文件的 Sprite2D 均在组件内部（体系 C），审计列出不动

安全约束（CLAUDE.md 反模式）：
  - 只改纯数值行（offset_left/top/right/bottom、Sprite2D position = Vector2(x, y)）
  - 禁碰结构行（[node/[ext_resource/[sub_resource/uid/load_steps/连接声明）
  - 默认 --dry-run 预览；输出每文件改动计数与出屏审计
"""
import os
import re
import sys

# ---------------------------------------------------------------------------
# 常量与规则表
# ---------------------------------------------------------------------------
OLD_W, OLD_H = 960.0, 640.0
NEW_W, NEW_H = 800.0, 480.0

SHIFT = 80.0
FIT12_X, SCALE_Y = 1.2, 4.0 / 3.0  # 1.3333
SC = 4.0 / 3.0
SC_OFF = 400.0 * SC - 480.0  # 53.33（handbook 旧 OFFSET_X = -SC_OFF）


def inv_shift(x, y):
    return x - SHIFT, y - SHIFT


def inv_fit12(x, y):
    return x / FIT12_X, NEW_H - (OLD_H - y) / SCALE_Y


def inv_scale13(x, y):
    return (x + SC_OFF) / SC, NEW_H - (OLD_H - y) / SC


# 文件级模式表（dry-run 审计 + 源 lua 对照后人工审定，依据见 task-4-report.md §2）
FILE_MODE = {}
for _f in [
    'scenes/battle/stage_done_scene.tscn',
    'scenes/battle/stage_failed_content.tscn',
    'scenes/ui/battle_prepare_content.tscn',
]:
    FILE_MODE[_f] = 'fit12'
for _f in [
    'scenes/ui/handbook_content.tscn',
]:
    FILE_MODE[_f] = 'scale13'

# 整文件白名单（不迁，依据见报告 §2.3）
SKIP_FILES = {
    # item/cell/小组件（根即条目，gd 动态定位，内部局部布局）
    'scenes/ui/avatar_title_item.tscn',
    'scenes/ui/daily_login_cell.tscn',
    'scenes/ui/dungeon_degree_item.tscn',
    'scenes/ui/eatexp_item.tscn',
    'scenes/ui/equipdetail_item_cell.tscn',
    'scenes/ui/excavate_battle_player_item.tscn',
    'scenes/ui/excavate_history_item.tscn',
    'scenes/ui/hero_package_list_line.tscn',
    'scenes/ui/mail_currency_item.tscn',
    'scenes/ui/mail_item.tscn',
    'scenes/ui/midas_history_item.tscn',
    'scenes/ui/shop_item.tscn',
    'scenes/ui/star_shop_item.tscn',
    'scenes/ui/stone_detail_getway_item.tscn',
    'scenes/ui/hero_package_item_content.tscn',
    'scenes/battle/battle_auto_button_content.tscn',
    'scenes/battle/battle_hero_panel_content.tscn',
    'scenes/battle/battle_resource_marker_content.tscn',
    'scenes/battle/battle_speed_button_content.tscn',
    'scenes/battle/battle_timer_content.tscn',
    # 锚定自适应（ap=2/8/10 锚定语义，随 viewport 自适应）
    'scenes/battle/battle_hud.tscn',
    'scenes/battle/battle_pause_layer_content.tscn',
    # gd 运行时全覆盖（Task 3 报告 §5.2/§5.3：shade/tag 运行时覆盖，其余动态定位）
    'scenes/ui/shortcut_content.tscn',
}

# 节点级白名单（文件内特定节点不迁）：
#   - 贴角惯例（相对视口角语义，viewport 变化语义自洽；源 back 直译另案人工处理）
#   - 地图层/超宽滚动层（地图逻辑尺寸非屏幕坐标，体系 C）
# 节点级白名单（按 文件+节点 精确匹配，不迁；全局按名字匹配贴角惯例）
NODE_SKIP_EXACT = {
    ('scenes/ui/crusade_content.tscn', 'SkipBtn'): 'x-80/y 保持（贴顶），事后手工',
    ('scenes/ui/crusade_content.tscn', 'EnemyPreviewHost'): 'x 不动/y-160（贴左贴底），事后手工',
    ('scenes/ui/crusade_content.tscn', 'ResultLabel'): 'x 不动/y-160（贴左贴底），事后手工',
    ('scenes/ui/tutorial_guide_view_content.tscn', 'SkipBtn'): 'x-80/y 保持（贴顶贴右），事后手工',
    ('scenes/ui/hero_detail_content.tscn', 'CloseBtn'): '右上贴角（889~940 贴 960 右），事后手工 (749,22→800,73)',
    # task 的 Main/Daily 双 scroll 系当年自定"拉满 640 高"布局，-80 平移会整体出屏；
    # 事后手工按等比 y 压缩（×480/640）处理，依据见报告 §4
    ('scenes/ui/task_content.tscn', 'MainTitleLabel'): '自定拉满布局，事后手工等比压缩',
    ('scenes/ui/task_content.tscn', 'MainScroll'): '自定拉满布局，事后手工等比压缩',
    ('scenes/ui/task_content.tscn', 'DailyTitleLabel'): '自定拉满布局，事后手工等比压缩',
    ('scenes/ui/task_content.tscn', 'DailyScroll'): '自定拉满布局，事后手工等比压缩',
}
# 贴角惯例（名字 + 左上角值域 L<40/T<40）：相对视口角语义，viewport 变化语义自洽不迁。
# scale13（handbook）模式不豁免——其 BackBtn 是缩放式产物必须逆缩放。
CORNER_NAMES = {'CloseBtn', 'BackBtn', 'BackButton'}

# 容器类型：其子节点为容器管理（体系 C），自身显式 rect 仍迁
CONTAINER_TYPES = {'ScrollContainer', 'GridContainer', 'VBoxContainer', 'HBoxContainer',
                   'VSeparator', 'HSeparator'}
# 透明全铺层：无纹理无显式 rect 的 Control/ColorRect——其子节点仍是屏幕绝对层
PASSTHROUGH_TYPES = {'Control', 'ColorRect'}

BASE = os.path.join(os.path.dirname(__file__), '..')
VIEW_TOL = 4.0  # 出屏审计容差（px）


# ---------------------------------------------------------------------------
# tscn 解析
# ---------------------------------------------------------------------------
NODE_RE = re.compile(r'^\[node name="([^"]+)"(?: type="([^"]*)")?(?: parent="([^"]+)")?')


class Node:
    __slots__ = ('name', 'ntype', 'parent', 'start', 'end', 'offsets', 'pos2d', 'ap')

    def __init__(self, name, ntype, parent, start):
        self.name = name
        self.ntype = ntype or 'Control'  # tscn 省略 type 时继承场景根脚本类型，按 Control 处理
        self.parent = parent  # None = 根
        self.start = start
        self.end = start
        self.offsets = {}  # {'offset_left': (line_idx, value), ...}
        self.pos2d = None   # (line_idx, x, y)  Sprite2D position
        self.ap = None

    def rect(self):
        """(L, T, R, B) 或 None。缺省 left/top 按 0（Godot 锚定 0 时缺省即 0）；
        至少有 right/bottom 之一才视为显式 rect。"""
        o = self.offsets
        if not ('offset_right' in o or 'offset_bottom' in o):
            return None
        return (
            o.get('offset_left', (0, 0.0))[1],
            o.get('offset_top', (0, 0.0))[1],
            o.get('offset_right', (0, 0.0))[1],
            o.get('offset_bottom', (0, 0.0))[1],
        )

    def is_fullrect_passthrough(self):
        return (self.ntype in PASSTHROUGH_TYPES and not self.offsets
                and self.ap in ('15', None))


def parse_tscn(text):
    """解析节点块（行索引）。返回 nodes 列表（文档序）。"""
    lines = text.splitlines()
    nodes = []
    cur = None
    for i, line in enumerate(lines):
        m = NODE_RE.match(line)
        if m:
            if cur:
                cur.end = i
            cur = Node(m.group(1), m.group(2), m.group(3), i)
            nodes.append(cur)
            continue
        if cur is None:
            continue
        if line.startswith('['):
            cur.end = i
            cur = None
            continue
        s = line.strip()
        if s.startswith('offset_'):
            km = re.match(r'(offset_\w+) = (-?[\d.]+)', s)
            if km:
                cur.offsets[km.group(1)] = (i, float(km.group(2)))
        elif s.startswith('position = Vector2('):
            pm = re.match(r'position = Vector2\((-?[\d.e+-]+), (-?[\d.e+-]+)\)', s)
            if pm:
                cur.pos2d = (i, float(pm.group(1)), float(pm.group(2)))
        elif s.startswith('anchors_preset = '):
            cur.ap = s.split('=', 1)[1].strip()
    if cur:
        cur.end = len(lines)
    return nodes, lines


# ---------------------------------------------------------------------------
# 迁移决策
# ---------------------------------------------------------------------------
def build_screen_layer(nodes):
    """标记屏幕绝对层节点集合（shift 模式）：根 + 透明全铺层链。
    注意 tscn parent="A/B/C" 的直接父是末段 C（完整祖先链相对根）。"""
    by_name = {}
    for n in nodes:  # 文档序：同名节点后者覆盖（与 tscn 引用就近语义近似，歧义由审计兜底）
        by_name[n.name] = n
    screen = set()
    root = nodes[0]
    screen.add(root.name)
    changed = True
    while changed:
        changed = False
        for n in nodes[1:]:
            if n.name in screen:
                continue
            parent_name = n.parent if n.parent else None
            if parent_name == '.':
                parent_node = root
            elif parent_name is None:
                continue
            else:
                parent_node = by_name.get(parent_name.split('/')[-1])
            if parent_node and parent_node.name in screen and parent_node.is_fullrect_passthrough():
                screen.add(n.name)
                changed = True
    return screen


def migrate_file(path, rel, dry_run, report):
    text = open(path, encoding='utf-8').read()
    if 'offset_' not in text and 'position = Vector2(' not in text:
        return
    mode = FILE_MODE.get(rel)
    if rel in SKIP_FILES:
        report['skipped'].append(rel)
        return
    mode = mode or 'shift'
    nodes, lines = parse_tscn(text)

    edits = {}  # line_idx -> new line content
    counts = {'offset': 0, 'position': 0, 'bg_reset': 0}
    audit = []  # (node, old_rect/new_pos, new_rect, note)
    offscreen = []

    if mode == 'shift':
        screen_names = build_screen_layer(nodes)
    else:
        screen_names = None  # fit12/scale13 文件：只处理根直挂（深层为局部）+ 根 rect

    by_name = {n.name: n for n in nodes}
    root = nodes[0]

    for n in nodes[1:]:
        # 挂载层判定：screen_names 集合语义 = "该节点的子节点仍是屏幕绝对层"
        # （root + 透明全铺层链；实际框/容器下的节点不在集合中 → 体系 C 局部）
        if mode == 'shift':
            on_screen = n.name in screen_names
        else:
            on_screen = (n.parent == '.' or n.parent is None)
        if not on_screen:
            continue
        # 节点级白名单
        skip_reason = NODE_SKIP_EXACT.get((rel, n.name))
        if not skip_reason and mode != 'scale13' and n.name in CORNER_NAMES:
            r0 = n.rect()
            if r0 and r0[0] < 40.0 and r0[1] < 40.0:
                skip_reason = '贴角惯例(左上)'
        if skip_reason:
            audit.append((n, n.rect(), None, skip_reason))
            continue
        # 锚定自适应（ap=2/8/10 等）：offset 是相对锚边距离语义，不动
        if n.ap in ('2', '8', '10') and n.offsets:
            audit.append((n, n.rect(), None, '锚定自适应不动'))
            continue
        # 值域守卫：超宽地图层（>1100 宽）非屏幕坐标，不动
        r = n.rect()
        if r and (r[2] - r[0]) > 1100.0:
            audit.append((n, r, None, '超宽地图层不动'))
            continue
        # 全 0 rect 且 ap=15：全铺装饰 Label/容器（相对父全铺语义），不动
        if r and n.ap == '15' and all(abs(v) < 1e-6 for v in r):
            continue
        inv = inv_shift if mode == 'shift' else (inv_fit12 if mode == 'fit12' else inv_scale13)
        # FrameworkBg 特改：0,0→960,640 → 0,0→800,480
        if (r and n.name == 'FrameworkBg' and abs(r[0]) < 1e-6 and abs(r[1]) < 1e-6
                and abs(r[2] - OLD_W) < 1e-6 and abs(r[3] - OLD_H) < 1e-6):
            li_v = n.offsets['offset_right']
            edits[li_v[0]] = 'offset_right = %s' % _fmt(NEW_W)
            li_v = n.offsets['offset_bottom']
            edits[li_v[0]] = 'offset_bottom = %s' % _fmt(NEW_H)
            counts['bg_reset'] += 1
            audit.append((n, r, (0.0, 0.0, NEW_W, NEW_H), 'FrameworkBg 铺满'))
            continue
        if r is None and n.pos2d is None:
            continue
        # rect 四键不齐（缺省 left/top=0 是锚定语义）：平移会产生 (0,0,R-80,B-80) 错位 → 跳过审计
        # （FrameworkBg 960/640 型已在前面的特改分支处理）
        if r is not None and not all(k in n.offsets for k in
                                     ('offset_left', 'offset_top', 'offset_right', 'offset_bottom')):
            audit.append((n, r, None, 'rect 四键不齐跳过'))
            continue
        # 迁移 offset 四元组
        if r is not None:
            new_rect = inv(r[0], r[1]) + inv(r[2], r[3])
            for key, val in zip(('offset_left', 'offset_top', 'offset_right', 'offset_bottom'), new_rect):
                if key in n.offsets:
                    li, _old = n.offsets[key]
                    edits[li] = '%s = %s' % (key, _fmt(val))
            counts['offset'] += 1
            # 出屏审计（迁后与 [0,800]x[0,480] 的越界量）
            over = max(0.0, -new_rect[0], new_rect[2] - NEW_W) + max(0.0, -new_rect[1], new_rect[3] - NEW_H)
            if over > VIEW_TOL:
                offscreen.append((n, r, new_rect, over))
        # 迁移 Sprite2D position（仅 fit12/scale13；shift 文件 Sprite2D 在组件内不迁）
        if n.pos2d is not None and mode != 'shift':
            li, px, py = n.pos2d
            nx, ny = inv(px, py)
            edits[li] = 'position = Vector2(%s, %s)' % (_fmt(nx), _fmt(ny))
            counts['position'] += 1
            over = max(0.0, -nx, nx - NEW_W) + max(0.0, -ny, ny - NEW_H)
            if over > VIEW_TOL:
                offscreen.append((n, (px, py), (nx, ny), over))
        elif n.pos2d is not None:
            audit.append((n, n.pos2d[1:], None, 'shift 文件 Sprite2D position 审计不动'))

    # 根 rect（fit12/scale13 文件根自带 960x640 rect → 800x480）
    if mode != 'shift':
        rr = root.rect()
        if rr and (abs(rr[2] - OLD_W) < 1e-6 and abs(rr[3] - OLD_H) < 1e-6):
            edits[root.offsets['offset_right'][0]] = 'offset_right = %s' % _fmt(NEW_W)
            edits[root.offsets['offset_bottom'][0]] = 'offset_bottom = %s' % _fmt(NEW_H)
            counts['bg_reset'] += 1

    if not edits:
        report['nochange'].append(rel)
        return
    report['migrated'].append((rel, mode, dict(counts), len(offscreen)))
    for entry in offscreen:
        n, old, new, over = entry
        report['offscreen'].append((rel, n.name, old, new, over))
    if not dry_run:
        out_lines = [edits.get(i, ln) for i, ln in enumerate(lines)]
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(out_lines) + '\n')


def _fmt(v):
    """整数化显示（Godot tscn 数值无尾零惯例：80.0 而非 80.000001）"""
    v = round(v, 4)
    if v == int(v):
        return '%s.0' % int(v)
    s = ('%g' % v)
    return s


def main():
    dry_run = '--dry-run' in sys.argv
    only = None
    for a in sys.argv[1:]:
        if a.startswith('--only='):
            only = a.split('=', 1)[1]
    report = {'migrated': [], 'skipped': [], 'nochange': [], 'offscreen': []}
    scenes_dir = os.path.join(BASE, 'scenes')
    for root_dir, _dirs, files in os.walk(scenes_dir):
        for fn in sorted(files):
            if not fn.endswith('.tscn'):
                continue
            full = os.path.join(root_dir, fn).replace('\\', '/')
            rel = os.path.relpath(full, BASE).replace('\\', '/')
            if only and only not in rel:
                continue
            migrate_file(full, rel, dry_run, report)

    print('== 模式汇总 ==')
    for rel, mode, counts, noff in report['migrated']:
        c = ' off=%d pos=%d bg=%d' % (counts['offset'], counts['position'], counts['bg_reset'])
        flag = '  <-- 出屏 %d' % noff if noff else ''
        print('  [%s] %-70s%s%s' % (mode, rel, c, flag))
    print('\n== 白名单跳过 %d 个 ==' % len(report['skipped']))
    for rel in report['skipped']:
        print('  skip %s' % rel)
    print('\n== 无改动 %d 个 ==' % len(report['nochange']))
    for rel in report['nochange']:
        print('  none %s' % rel)
    print('\n== 出屏审计 %d 项（容差 %gpx，需人工复核） ==' % (len(report['offscreen']), VIEW_TOL))
    for rel, name, old, new, over in report['offscreen']:
        print('  OVER+%-6.1f %-46s %-18s %s -> %s' % (over, rel, name, old, new))
    total_off = sum(c for _r, _m, c, _n in report['migrated'] for c in [c['offset'] + c['position'] + c['bg_reset']])
    print('\n合计: 迁移文件 %d | 白名单 %d | 无改动 %d | 数值行改动 %d | 出屏 %d' % (
        len(report['migrated']), len(report['skipped']), len(report['nochange']),
        total_off, len(report['offscreen'])))
    print('模式: %s' % ('DRY-RUN（未写盘）' if dry_run else '已写盘'))


if __name__ == '__main__':
    main()
