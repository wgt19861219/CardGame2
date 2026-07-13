#!/usr/bin/env python3
"""展开 StageDungeon 难度变体（照源 StageDungeon.lua:761-819 复刻）。

源 StageDungeon.lua = 静态 21 关（baseId 50001-50021, Difficulty=1）
+ for 循环为每关生成 3 个难度变体（diff 2/3/4, newId = baseId + (diff-1)*1000）
= 共 84 关。

本脚本读 lua_to_json.py 转出的静态 21 关 JSON，照源 diffConfig + 字段映射公式
展开生成 63 个难度变体，合并覆盖输出 84 关 JSON（运行时数据驱动，O(1) 查询）。

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
    """对静态 21 关（baseId 50001-50021）各生成 diff 2/3/4 变体。"""
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
    data = expand(data)
    ordered = {k: data[k] for k in sorted(data, key=int)}  # 按 id 排序输出
    with open(path, "w", encoding="utf-8") as f:
        json.dump(ordered, f, ensure_ascii=False, indent=2)
        f.write("\n")
    added = len(ordered) - before
    print(f"{path}: {before} → {len(ordered)} 关（+{added} 难度变体 diff 2/3/4）")


if __name__ == "__main__":
    main()
