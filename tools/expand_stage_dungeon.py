#!/usr/bin/env python3
"""展开 StageDungeon 难度变体（照源 StageDungeon.lua:761-819 复刻）。

源 StageDungeon.lua = 静态 21 关（baseId 50001-50021, Difficulty=1）
+ for 循环为每关生成 3 个难度变体（diff 2/3/4, newId = baseId + (diff-1)*1000）
= 共 84 关。

本脚本读 lua_to_json.py 转出的静态 21 关 JSON，照源 diffConfig + 字段映射公式
展开生成 63 个难度变体，合并覆盖输出 84 关 JSON（运行时数据驱动，O(1) 查询）。

项目新增段（2026-10-08）：ch203 冰封王座三部曲 9 个 base 关（50022-50030）由
_LICH_BASES 字面量注入后走同一展开公式 = 120 关（30 base × 4 diff）。源无对应，
重跑 lua_to_json 后经本脚本即可再生（数据层构建模式文档）。

用法：python tools/expand_stage_dungeon.py [resources/data/StageDungeon.json]
编排：python tools/build_data.py（串联 lua_to_json + expand_*，数据层构建模式文档）
"""
import json
import math
import sys

# 照源 StageDungeon.lua:761-765 diffConfig（难度加成系数表）
DIFF_CONFIG = {
    2: {"vit_add": 4, "ml_add": 5, "ul_add": 5, "exp_add": 3, "hero_mul": 1.2, "key_cost": 0},
    3: {"vit_add": 8, "ml_add": 10, "ul_add": 10, "exp_add": 6, "hero_mul": 1.4, "key_cost": 1},
    4: {"vit_add": 12, "ml_add": 15, "ul_add": 20, "exp_add": 10, "hero_mul": 1.8, "key_cost": 2},
}

# ── 项目新增段：ch203 冰封王座三部曲（2026-10-08 设计方案，源无对应）─────────────
# 9 个 base 关（50022-50030）= 毒蛇神殿(50008)/海加尔山(50009)/冰冠堡垒(50010) 各 3 关。
# 掉落设计（力度 B）：槽 1=DL85 基件的断点组件、槽 2=对应碎片（60 碎片=1 组件）；
# 巫妖王关(50030) 双槽全万能碎片 335（30 个=自选组件，Fragment 表既有兜底路径接通）。
# 数值锚点照 ch202（50013-50021）：Unlock 80（D4 公式加成后 100 顶格）、Vit 18、
# MonLv 112/114/116 递进（ch202 为 90-100，ch203 高一档）；diff 变体走同一 _build_variant。
_LICH_BASES = [
    # (sid, group, boss 键, 组件槽, 碎片槽, mon_lv, heroexp)
    (50022, 50008, "DUNGEON.BOSS_KARATHESS", 455, 456, 112, 500),  # 深水领主→海神之螺
    (50023, 50008, "DUNGEON.BOSS_MOROGRIM", 452, 453, 112, 500),   # 踏潮者→海洋之心
    (50024, 50008, "DUNGEON.BOSS_VASHJ", 443, 444, 112, 550),      # 瓦丝琪→海军勋章
    (50025, 50009, "DUNGEON.BOSS_RAGE_WINTERCHILL", 446, 447, 114, 550),  # 雷基·冬寒→冥王之眼
    (50026, 50009, "DUNGEON.BOSS_ANETHERON", 449, 450, 114, 550),  # 安纳塞隆→暮光晶体
    (50027, 50009, "DUNGEON.BOSS_ARCHIMONDE", 458, 459, 114, 600), # 阿克蒙德→斯巴达矛尖
    (50028, 50010, "DUNGEON.BOSS_SINDRAGOSA", 461, 462, 116, 600), # 辛达苟萨→九头蛇指爪
    (50029, 50010, "DUNGEON.BOSS_BLOOD_QUEEN", 464, 465, 116, 600),  # 血腥女王→恶魔之血
    (50030, 50010, "DUNGEON.BOSS_LICH_KING", 335, 335, 116, 650),  # 巫妖王→万能碎片×2 槽
]


def _lich_base(sid: int, group: int, boss_key: str, comp: int, frag: int, mon_lv: int, heroexp: int) -> dict:
    """构建 ch203 base 关（字段模板照 50013 纳克萨玛斯逐键对齐）。"""
    entry = {
        "Chapter ID": 203,
        "Chest For FD": False,
        "Daily Limit": 0,
        "Difficulty": 1,
        "Exp Reward": 15,
        "Fail Exp Reward": 7,
        "Heroexp Reward": heroexp,
        "Key Stage": False,
    }
    for i in range(1, 8):
        entry[f"Loot {i} Name"] = 0
    entry["Monster Level"] = mon_lv
    entry["Raid Bonus Amount 1"] = 1
    entry["Raid Bonus Amount 2"] = 1
    entry["Raid Bonus Amount 3"] = 0
    entry["Raid Bonus Amount 4"] = 0
    entry["Raid Bonus ID 1"] = comp
    entry["Raid Bonus ID 2"] = frag
    entry["Raid Bonus Type 1"] = "Equip"
    entry["Raid Bonus Type 2"] = "Equip"
    entry["Raid Bonus Type 3"] = "Item"
    entry["Require Stage"] = 0
    entry["Require Stars"] = 0
    entry["Stage Group"] = group
    entry["Stage ID"] = sid
    entry["Stage Name"] = boss_key
    entry["UI reward1"] = comp
    entry["UI reward1 Max Amount"] = 1
    entry["UI reward1 Min Amount"] = 0
    entry["UI reward2"] = frag
    entry["UI reward2 Max Amount"] = 1
    entry["UI reward2 Min Amount"] = 0
    for i in range(3, 8):
        entry[f"UI reward{i}"] = 0
        entry[f"UI reward{i} Max Amount"] = 0
        entry[f"UI reward{i} Min Amount"] = 0
    entry["Unlock Level"] = 80
    entry["Vit Return"] = 0
    entry["Vitality Cost"] = 18
    entry["Waves"] = 3
    entry["description"] = boss_key.replace("DUNGEON.BOSS_", "DUNGEON.DESC_")
    return entry


def inject_lich_bases(data: dict) -> dict:
    """注入 ch203 9 个 base 关（幂等：覆盖式重写，重跑 build_data 可再生）。"""
    for sid, group, boss_key, comp, frag, mon_lv, heroexp in _LICH_BASES:
        data[str(sid)] = _lich_base(sid, group, boss_key, comp, frag, mon_lv, heroexp)
    return data


def _build_variant(base: dict, base_id: int, diff: int) -> dict:
    """照源 :773-815 构建 diff 变体（newId = baseId + (diff-1)*1000）。"""
    cfg = DIFF_CONFIG[diff]
    new_id = base_id + (diff - 1) * 1000
    entry = {
        "Chapter ID": base["Chapter ID"],
        "Chest For FD": False,
        "Daily Limit": 0,
        "Difficulty": diff,
        "Exp Reward": base["Exp Reward"] + cfg["exp_add"],
        "Fail Exp Reward": base["Fail Exp Reward"] + math.floor(cfg["exp_add"] / 3),
        "Heroexp Reward": math.floor(base["Heroexp Reward"] * cfg["hero_mul"]),
        "Key Cost": cfg["key_cost"],
        "Key Stage": False,
    }
    for i in range(1, 8):
        entry[f"Loot {i} Name"] = 0
    entry["Monster Level"] = base["Monster Level"] + cfg["ml_add"]
    entry["Raid Bonus Amount 1"] = base["Raid Bonus Amount 1"]
    entry["Raid Bonus Amount 2"] = base["Raid Bonus Amount 2"]
    entry["Raid Bonus Amount 3"] = 0
    entry["Raid Bonus Amount 4"] = 0
    entry["Raid Bonus ID 1"] = base["Raid Bonus ID 1"]
    entry["Raid Bonus ID 2"] = base["Raid Bonus ID 2"]
    entry["Raid Bonus ID 3"] = 0
    entry["Raid Bonus ID 4"] = 0
    entry["Raid Bonus Type 1"] = base["Raid Bonus Type 1"]
    entry["Raid Bonus Type 2"] = base["Raid Bonus Type 2"]
    entry["Raid Bonus Type 3"] = "Item"
    entry["Require Stage"] = 0
    entry["Require Stars"] = 0
    entry["Stage Group"] = base["Stage Group"]
    entry["Stage ID"] = new_id
    entry["Stage Name"] = base["Stage Name"]
    entry["UI reward1"] = base["UI reward1"]
    entry["UI reward1 Max Amount"] = base["UI reward1 Max Amount"]
    entry["UI reward1 Min Amount"] = base["UI reward1 Min Amount"]
    entry["UI reward2"] = base["UI reward2"]
    entry["UI reward2 Max Amount"] = base["UI reward2 Max Amount"]
    entry["UI reward2 Min Amount"] = base["UI reward2 Min Amount"]
    for i in range(3, 8):
        entry[f"UI reward{i}"] = 0
        entry[f"UI reward{i} Max Amount"] = 0
        entry[f"UI reward{i} Min Amount"] = 0
    entry["Unlock Level"] = base["Unlock Level"] + cfg["ul_add"]
    entry["Vit Return"] = 0
    entry["Vitality Cost"] = base["Vitality Cost"] + cfg["vit_add"]
    entry["Waves"] = 1
    return entry


def expand(data: dict) -> dict:
    """对静态 21 关 + 项目新增 9 关（baseId 50001-50030）各生成 diff 2/3/4 变体。"""
    base_keys = [k for k in data if int(k) < 51000]  # 仅静态 base 关（排除已展开的）
    for base_key in base_keys:
        base_id = int(base_key)
        base = data[base_key]
        for diff in (2, 3, 4):
            new_id = base_id + (diff - 1) * 1000
            data[str(new_id)] = _build_variant(base, base_id, diff)
    return data


def main():
    path = sys.argv[1] if len(sys.argv) >= 2 else "resources/data/StageDungeon.json"
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    before = len(data)
    data = inject_lich_bases(data)
    data = expand(data)
    ordered = {k: data[k] for k in sorted(data, key=int)}  # 按 id 排序输出
    with open(path, "w", encoding="utf-8") as f:
        json.dump(ordered, f, ensure_ascii=False, indent=2)
        f.write("\n")
    added = len(ordered) - before
    print(f"{path}: {before} → {len(ordered)} 关（ch203 注入 9 base + 难度变体 diff 2/3/4）")


if __name__ == "__main__":
    main()
