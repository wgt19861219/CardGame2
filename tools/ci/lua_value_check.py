"""Lua 源 vs JSON 关键数值表深度值对比（P2-2，防转换数值漂移）。

对战斗/经济平衡关键表，复用 lua_to_json.parse_file 重解析 Lua 源，与
resources/data/*.json 深度对比标量值，抓「源 Lua 改数值重生成后门禁全绿
但数值已漂移」的隐性 bug（lua_config_check 只比字段名集合，不比值）。

非关键表保留 lua_config_check 的字段名检查，本工具只覆盖数值敏感表。
用法：python lua_value_check.py [项目根] [Lua源根]
"""
from __future__ import annotations

import json
import os
import sys

# 复用 tools/lua_to_json.py 的 Lua 解析器（tokenize + Parser + parse_file）
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lua_to_json  # type: ignore  # noqa: E402

# 关键数值表（战斗/经济平衡，数值正确性影响游戏）
KEY_TABLES = [
    "Battle", "Skill", "Unit", "Hero_equip", "Stage",
    "Enhancement", "Levels", "VIP", "CrusadeRewards", "PlayerLevel",
]

# 已知差异白名单（差异路径前缀 → 原因）——渐进建立，初版为空
_WHITELIST: dict[str, str] = {}

# 字段级白名单（(表, 字段) → (原因, 预期 lua 值, 预期 json 值)）：批量有意偏离源且涉及
# id 众多（逐条列前缀不现实）时用。值对不匹配仍报差异，防未来源/JSON 意外漂移被掩盖。
_FIELD_WHITELIST: dict[tuple[str, str], tuple[str, object, object]] = {
    # 2026-10-07 用户指示：精英关（ID≥10000，源值全为 3）每日进入次数 3→30（151 关），
    # 有意偏离源。注意：重跑 tools/build_data.py 再生成 Stage.json 会覆盖回 3，需重施。
    ("Stage", "Daily Limit"): ("精英关每日次数 3→30（用户指示，151 关有意偏离源）", 3, 30),
    # 2026-10-08 ch203 冰封王座：PlayerLevel lv80 Unlock 加 Icecrown 键（源缺），
    # 主城入口 80 级门槛（expand_lich_data.py 注入，重跑可再生）。
    ("PlayerLevel", "2"): ("ch203 冰封王座 lv80 Unlock+Icecrown 键（项目新增，仅 缺失→Icecrown 值对命中）", "<缺失>", "Icecrown"),
}

# 2026-10-07 方案 B（用户拍板）：Hero_equip rank 12-23 空槽（源 lua 原生 0）填 2.0 基件
# 8 件轮转（其余 16 件属性全 0 系合成材料不进表，见审查报告-装备进阶图标梳理-2026-10-07）。
# 条件白名单：lua 值为 0 且 json 值在基件集合内才算有意填充；其他值差异仍报漂移。
_HERO_EQUIP_FILL_IDS = frozenset({442, 445, 448, 451, 454, 457, 460, 463})
_HERO_EQUIP_FILL_NAMES = frozenset({
    "equip.2.0.0.113", "equip.2.0.0.118", "equip.2.0.0.123", "equip.2.0.0.128",
    "equip.2.0.0.133", "equip.2.0.0.138", "equip.2.0.0.143", "equip.2.0.0.148",
})


def _is_hero_equip_fill(table: str, path: str, lv: object, jv: object) -> bool:
    """Hero_equip rank≥12 空槽的方案 B 填充判定（tid.rank.field 三段路径）。"""
    if table != "Hero_equip":
        return False
    parts = path.split(".")
    if len(parts) != 3:
        return False
    _tid, rank_s, field = parts
    if not rank_s.isdigit() or int(rank_s) < 12:
        return False
    if field.endswith(" ID"):
        return _scalar_eq(lv, 0) and isinstance(jv, int) and jv in _HERO_EQUIP_FILL_IDS
    if field.startswith("Equip"):
        return lv == "0" and isinstance(jv, str) and jv in _HERO_EQUIP_FILL_NAMES
    return False

# 程序生成段（JSON 由独立工具生成，Lua 源是代码生成非字面 return，parse_file 静态
# 解析不出）——对比前从 JSON 顶层排除匹配 key，避免误报「JSON 有 Lua 无」。
# 这些段的数值正确性由生成工具自身 + build_data --check（段齐全）守，非本工具职责。
_PROGRAM_GENERATED: dict[str, object] = {
    # Battle dungeon 段 stage id 50001+（expand_battle_dungeon.py 从 Battle.lua:80954+ 程序生成）
    "Battle": lambda k: k.isdigit() and int(k) >= 50000,
    # Unit 换皮新角色段 tid 90000+（expand_lich_data.inject_boss_units，Angel 换皮管线产物）
    "Unit": lambda k: k.isdigit() and int(k) >= 90000,
}


def _find_lua(table: str, lua_root: str) -> str | None:
    for name in (table, table.capitalize(), table.lower()):
        path = os.path.join(lua_root, name + ".lua")
        if os.path.isfile(path):
            return path
    return None


def _scalar_eq(a: object, b: object) -> bool:
    """标量相等：数值 int/float 容差（避 5 vs 5.0）；bool 不与 int 混。"""
    a_num = isinstance(a, (int, float)) and not isinstance(a, bool)
    b_num = isinstance(b, (int, float)) and not isinstance(b, bool)
    if a_num and b_num:
        return float(a) == float(b)
    return a == b


def _deep_diff(lua: object, data: object, path: str = "") -> list[tuple[str, object, object]]:
    """递归对比 lua_data vs json_data，返差异列表 [(path, lua_val, json_val)]。"""
    diffs: list[tuple[str, object, object]] = []
    if isinstance(lua, dict) and isinstance(data, dict):
        for k in lua:
            sub = f"{path}.{k}" if path else str(k)
            if k not in data:
                diffs.append((sub, lua[k], "<缺失>"))
            else:
                diffs.extend(_deep_diff(lua[k], data[k], sub))
        for k in data:
            if k not in lua:
                sub = f"{path}.{k}" if path else str(k)
                diffs.append((sub, "<缺失>", data[k]))
    elif isinstance(lua, list) and isinstance(data, list):
        for i in range(max(len(lua), len(data))):
            sub = f"{path}[{i}]"
            if i >= len(lua):
                diffs.append((sub, "<缺失>", data[i]))
            elif i >= len(data):
                diffs.append((sub, lua[i], "<缺失>"))
            else:
                diffs.extend(_deep_diff(lua[i], data[i], sub))
    else:
        if not _scalar_eq(lua, data):
            diffs.append((path, lua, data))
    return diffs


def _is_whitelisted(path: str) -> str | None:
    for prefix, reason in _WHITELIST.items():
        if path == prefix or path.startswith(prefix + ".") or path.startswith(prefix + "["):
            return reason
    return None


def main(argv: list[str]) -> int:
    root = argv[1] if len(argv) > 1 else os.getcwd()
    lua_root = (
        argv[2]
        if len(argv) > 2
        else os.environ.get(
            "CARDGAME_LUA_SRC", r"D:\workspace\projects\CardGameAxmol\Content\src"
        )
    )
    data_dir = os.path.join(root, "resources", "data")

    checked = parse_fail = missing = 0
    real_diffs = 0
    for table in KEY_TABLES:
        json_path = os.path.join(data_dir, table + ".json")
        lua_path = _find_lua(table, lua_root)
        if not os.path.isfile(json_path):
            missing += 1
            print(f"[跳过] {table}: JSON 缺失")
            continue
        if lua_path is None:
            missing += 1
            print(f"[跳过] {table}: Lua 源缺失")
            continue
        try:
            lua_data = lua_to_json.parse_file(lua_path)
        except Exception as exc:  # noqa: BLE001
            parse_fail += 1
            print(f"[解析失败] {table}: {exc}")
            continue
        with open(json_path, encoding="utf-8") as handle:
            json_data = json.load(handle)
        # 排除程序生成段（JSON 有 Lua 无，由独立工具生成）
        gen_pred = _PROGRAM_GENERATED.get(table)
        if gen_pred is not None and isinstance(json_data, dict):
            json_data = {k: v for k, v in json_data.items() if not gen_pred(k)}
        checked += 1
        diffs = _deep_diff(lua_data, json_data)
        wl_count = 0
        new_diffs: list[tuple[str, object, object]] = []
        for path, lv, jv in diffs:
            if _is_hero_equip_fill(table, path, lv, jv):
                wl_count += 1
                continue
            field = path.rsplit(".", 1)[-1].split("[", 1)[0]
            fw = _FIELD_WHITELIST.get((table, field))
            if fw is not None and _scalar_eq(lv, fw[1]) and _scalar_eq(jv, fw[2]):
                wl_count += 1
                continue
            reason = _is_whitelisted(path)
            if reason:
                wl_count += 1
                continue
            new_diffs.append((path, lv, jv))
        if new_diffs:
            real_diffs += len(new_diffs)
            print(f"[差异] {table} ({len(new_diffs)} 处非白名单, {wl_count} 白名单):")
            for path, lv, jv in new_diffs[:20]:
                print(f"  {path}: lua={lv!r} json={jv!r}")
        elif wl_count:
            print(f"[OK] {table}: {wl_count} 处白名单差异")

    print(
        f"\n深度对比 {checked} 关键表，{parse_fail} 解析失败，"
        f"{missing} 缺失，{real_diffs} 处非白名单差异"
    )
    print("通过 ✅" if real_diffs == 0 else f"{real_diffs} 处数值漂移 ❌")
    return 1 if real_diffs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
