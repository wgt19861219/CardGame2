#!/usr/bin/env python3
"""照源 Battle.lua:80954-81124 生成 dungeon 段 Battle 数据（50001-53021），注入 Battle.json。

模式说明（非债，固有）：lua_to_json.py 静态解析 Battle.lua 的 `data = {...}` 字面量，不执行末尾 for 循环
（80985-81124 程序生成的 5xxxx dungeon 段），转换时丢失。本脚本照源 for 逻辑生成 21 base ×
(1 base + 3 diff) × 3 wave = 252 wave 条目，合并入 Battle.json。同 expand_stage_dungeon.py 范式。

源 dungeonBosses 列表（80954-80983）：21 关，每关 {id, bg, boss_tid, monsters[3]}。
生成两段：
  ① base 关 3 wave（80985-81086）：wave1 2 小怪 / wave2 3 小怪 / wave3 boss+3 小怪
  ② diff 2-4 变体（81093-81124）：复制 base wave + diffScale 缩放（HP%/DPS% × scale, Level + offset）

编排：python tools/build_data.py（串联 lua_to_json + expand_*，数据层构建模式文档）
"""
import json
import math
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BATTLE_JSON = os.path.join(PROJECT_ROOT, "resources", "data", "Battle.json")

# 源 Battle.lua:80954-80983 dungeonBosses（21 关：普通副本 50001-12 + 英雄副本 50013-21）
# 注：源 id 50001-50021 是 base 关，对应 StageDungeon 表的 base id（ActStageGroupDungeon.Stages 引用）
DUNGEON_BOSSES = [
    # 普通副本：黑石塔下层（火山主题，小怪：电魂5/火女3/宙斯4）
    {"id": 50001, "bg": "battle_bg/bbg_volcano_throne.jpg", "boss": 29, "m": [5, 3, 4]},
    {"id": 50002, "bg": "battle_bg/bbg_volcano_throne.jpg", "boss": 4,  "m": [5, 3, 4]},
    {"id": 50003, "bg": "battle_bg/bbg_volcano_throne.jpg", "boss": 28, "m": [5, 3, 4]},
    # 普通副本：斯坦索姆废墟（亡灵主题，小怪：骷髅王19/死灵法师20/骨法18）
    {"id": 50004, "bg": "battle_bg/bbg_corridor_ruin.jpg",  "boss": 20, "m": [19, 20, 18]},
    {"id": 50005, "bg": "battle_bg/bbg_corridor_ruin.jpg",  "boss": 14, "m": [19, 20, 18]},
    {"id": 50006, "bg": "battle_bg/bbg_corridor_ruin.jpg",  "boss": 19, "m": [19, 20, 18]},
    # 普通副本：厄运之槌（自然/恶魔主题，小怪：风行11/沉默26/暗牧22）
    {"id": 50007, "bg": "battle_bg/bbg_fall_cityofmage.jpg", "boss": 29, "m": [11, 26, 22]},
    {"id": 50008, "bg": "battle_bg/bbg_fall_cityofmage.jpg", "boss": 23, "m": [11, 26, 22]},
    {"id": 50009, "bg": "battle_bg/bbg_fall_cityofmage.jpg", "boss": 27, "m": [11, 26, 22]},
    # 普通副本：通灵学院（冰霜/暗影主题，小怪：冰女12/巫妖35/影魔25）
    {"id": 50010, "bg": "battle_bg/bbg_snow_castle.jpg",    "boss": 12, "m": [12, 35, 25]},
    {"id": 50011, "bg": "battle_bg/bbg_snow_castle.jpg",    "boss": 25, "m": [12, 35, 25]},
    {"id": 50012, "bg": "battle_bg/bbg_snow_castle.jpg",    "boss": 43, "m": [12, 35, 25]},
    # 英雄副本：纳克萨玛斯（天灾主题，小怪：死亡先知40/死骑42/骨弓17）
    {"id": 50013, "bg": "battle_bg/bbg_underground_hall.jpg", "boss": 6,  "m": [40, 42, 17]},
    {"id": 50014, "bg": "battle_bg/bbg_underground_hall.jpg", "boss": 40, "m": [40, 42, 17]},
    {"id": 50015, "bg": "battle_bg/bbg_underground_hall.jpg", "boss": 35, "m": [40, 42, 17]},
    # 英雄副本：黑翼之巢（龙族主题，小怪：双头龙38/凤凰52/亚龙37）
    {"id": 50016, "bg": "battle_bg/bbg_spring_lair.jpg",    "boss": 52, "m": [38, 52, 37]},
    {"id": 50017, "bg": "battle_bg/bbg_spring_lair.jpg",    "boss": 37, "m": [38, 52, 37]},
    {"id": 50018, "bg": "battle_bg/bbg_spring_lair.jpg",    "boss": 38, "m": [38, 52, 37]},
    # 英雄副本：安其拉废墟（虫族主题，小怪：小娜迦13/大鱼人14/潮汐15）
    {"id": 50019, "bg": "battle_bg/bbg_sand_bone.jpg",      "boss": 53, "m": [13, 14, 15]},
    {"id": 50020, "bg": "battle_bg/bbg_sand_bone.jpg",      "boss": 13, "m": [13, 14, 15]},
    {"id": 50021, "bg": "battle_bg/bbg_sand_bone.jpg",      "boss": 7,  "m": [13, 14, 15]},
]

# 源 Battle.lua:81088-81091 diffScale
DIFF_SCALE = {
    2: {"hp": 1.5, "dps": 1.3, "stars": 3, "level": 10},
    3: {"hp": 2.0, "dps": 1.7, "stars": 4, "level": 20},
    4: {"hp": 3.0, "dps": 2.0, "stars": 5, "level": 30},
}


def _chest(cid: int, cmult: int) -> dict:
    """源每 wave Chest 1-5 模板（仅 Chest 1 有值，其余 0）。"""
    return {
        "Chest 1 ID": cid, "Chest 1 Mult": cmult,
        "Chest 2 ID": 0, "Chest 2 Mult": 0,
        "Chest 3 ID": 0, "Chest 3 Mult": 0,
        "Chest 4 ID": 0, "Chest 4 Mult": 0,
        "Chest 5 ID": 0, "Chest 5 Mult": 0,
    }


def _fd_bonus() -> dict:
    return {"FD Bonus 1": 0, "FD Bonus 2": 0, "FD Bonus 3": 0, "FD Bonus 4": 0, "FD Bonus 5": 0}


def _money() -> dict:
    return {f"Money Reward {i}": 0 for i in range(1, 6)}


def _mp(vals: list) -> dict:
    return {f"MP {i}": vals[i - 1] for i in range(1, 6)}


def gen_wave1(b: dict) -> dict:
    """源 Battle.lua:80988-81016 wave1：2 小怪，HP% 1000，DPS% 100。"""
    w = {
        "Background Pic": b["bg"],
        "Boss DPS%": 0, "Boss HP%": 0, "Boss Position": 0, "BOSS SIZE%": 0,
    }
    w.update(_chest(10288, 20))
    w.update(_fd_bonus())
    w.update({"H Flip": False})
    w.update({"Level 1": 80, "Level 2": 80, "Level 3": 0, "Level 4": 0, "Level 5": 0})
    w.update(_money())
    w.update({"Monster 1 ID": b["m"][0], "Monster 2 ID": b["m"][1],
              "Monster 3 ID": 0, "Monster 4 ID": 0, "Monster 5 ID": 0})
    w.update({"Monster DPS%": 100, "Monster HP%": 1000})
    w.update(_mp([0, 0, 0, 0, 0]))
    w.update({"Raid Wave Weight": 1, "Stage Difficulty": 1, "Stage ID": b["id"],
              "Stage Name": "Dungeon Wave 1", "Stage Type": "dungeon"})
    w.update({"Stars 1": 1, "Stars 2": 1, "Stars 3": 0, "Stars 4": 0, "Stars 5": 0})
    w.update({"Wave ID": 1})
    return w


def gen_wave2(b: dict) -> dict:
    """源 Battle.lua:81018-81046 wave2：3 小怪，HP% 1500，DPS% 110。"""
    w = {
        "Background Pic": b["bg"],
        "Boss DPS%": 0, "Boss HP%": 0, "Boss Position": 0, "BOSS SIZE%": 0,
    }
    w.update(_chest(10288, 30))
    w.update(_fd_bonus())
    w.update({"H Flip": False})
    w.update({"Level 1": 80, "Level 2": 80, "Level 3": 80, "Level 4": 0, "Level 5": 0})
    w.update(_money())
    w.update({"Monster 1 ID": b["m"][0], "Monster 2 ID": b["m"][1], "Monster 3 ID": b["m"][2],
              "Monster 4 ID": 0, "Monster 5 ID": 0})
    w.update({"Monster DPS%": 110, "Monster HP%": 1500})
    w.update(_mp([0, 0, 0, 0, 0]))
    w.update({"Raid Wave Weight": 1, "Stage Difficulty": 1, "Stage ID": b["id"],
              "Stage Name": "Dungeon Wave 2", "Stage Type": "dungeon"})
    w.update({"Stars 1": 1, "Stars 2": 1, "Stars 3": 1, "Stars 4": 0, "Stars 5": 0})
    w.update({"Wave ID": 2})
    return w


def gen_wave3(b: dict) -> dict:
    """源 Battle.lua:81048-81085 wave3：boss（Monster 4）+ 3 小怪，HP% 2000，DPS% 120，Boss HP% 200。"""
    w = {
        "Background Pic": b["bg"],
        "Boss DPS%": 150, "Boss HP%": 200, "Boss Position": 4, "BOSS SIZE%": 0,
    }
    w.update(_chest(10288, 50))
    w.update(_fd_bonus())
    w.update({"H Flip": False})
    w.update({"Level 1": 80, "Level 2": 80, "Level 3": 80, "Level 4": 80, "Level 5": 0})
    w.update(_money())
    w.update({"Monster 1 ID": b["m"][0], "Monster 2 ID": b["m"][1], "Monster 3 ID": b["m"][2],
              "Monster 4 ID": b["boss"], "Monster 5 ID": 0})
    w.update({"Monster DPS%": 120, "Monster HP%": 2000})
    w.update(_mp([0, 0, 0, 400, 0]))
    w.update({"Raid Wave Weight": 2, "Stage Difficulty": 1, "Stage ID": b["id"],
              "Stage Name": "Dungeon Boss", "Stage Type": "dungeon"})
    w.update({"Stars 1": 1, "Stars 2": 1, "Stars 3": 1, "Stars 4": 1, "Stars 5": 0})
    w.update({"Wave ID": 3})
    return w


def gen_base_waves(b: dict) -> dict:
    """源 80985-81086 base 关 3 wave。"""
    return {1: gen_wave1(b), 2: gen_wave2(b), 3: gen_wave3(b)}


def scale_wave(base_wave: dict, diff: int, diff_id: int) -> dict:
    """源 Battle.lua:81093-81124 diff 变体：复制 base wave + diffScale 缩放。"""
    s = DIFF_SCALE[diff]
    w = dict(base_wave)  # 浅拷贝（源 for k,v in pairs(baseWave) do wave[k]=v end）
    w["Stage ID"] = diff_id
    w["Monster HP%"] = math.ceil(base_wave["Monster HP%"] * s["hp"])
    w["Monster DPS%"] = math.ceil(base_wave["Monster DPS%"] * s["dps"])
    if base_wave.get("Boss HP%", 0) > 0:
        w["Boss HP%"] = math.ceil(base_wave["Boss HP%"] * s["hp"])
        w["Boss DPS%"] = math.ceil(base_wave["Boss DPS%"] * s["dps"])
    # 源 81112-81118：Monster i ID > 0 时 Level + offset, Stars = scale.stars
    for i in range(1, 6):
        mid = base_wave.get("Monster %d ID" % i, 0)
        if mid and mid > 0:
            w["Level %d" % i] = base_wave.get("Level %d" % i, 80) + s["level"]
            w["Stars %d" % i] = s["stars"]
    return w


def main() -> None:
    with open(BATTLE_JSON, encoding="utf-8") as f:
        data = json.load(f)
    added = 0
    for b in DUNGEON_BOSSES:
        base_waves = gen_base_waves(b)
        # base 关（50001-50021）
        data[str(b["id"])] = {str(k): v for k, v in base_waves.items()}
        added += 1
        # diff 2-4 变体（51001/52001/53001 等）
        for diff in range(2, 5):
            diff_id = b["id"] + (diff - 1) * 1000
            diff_waves = {}
            for wid in range(1, 4):
                base_wave = base_waves[wid]
                if base_wave:
                    diff_waves[wid] = scale_wave(base_wave, diff, diff_id)
            data[str(diff_id)] = {str(k): v for k, v in diff_waves.items()}
            added += 1
    with open(BATTLE_JSON, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("扩展完成：新增 %d 个 dungeon stage（50001-53021，21 base × 4 diff）" % added)


if __name__ == "__main__":
    main()
