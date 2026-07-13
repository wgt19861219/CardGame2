"""Lua 源 vs JSON 配置表字段对照校验（Step 0.3 任务3）。

对 resources/data/*.json 每张表，在 Lua 源根找对应 .lua，提取字段名集合对比，
报告 Lua 有/JSON 缺（转换丢失）、JSON 有/Lua 无（转换多加）字段。
抓蓝图所说 Compose Count vs Fragment Count 类字段命名/完整性错误。

用法：python lua_config_check.py [项目根] [Lua源根]
"""
from __future__ import annotations

import json
import os
import re
import sys

# Lua 字段名：["字段名"] =  或 ['字段名'] = （方括号 key，支持双/单引号）
_LUA_FIELD_RE = re.compile(r'\[["\']([^"\']+)["\']\]\s*=')
# Lua 裸标识符 key：  字段名 =  （无引号，如 Move = { / ID = 0 / Welcome = {）
# 匹配行首（允许缩进）的合法标识符后跟 =，用于抓裸 key 表（AnimAtkFrame/AnimDuration 等）。
_LUA_BAREKEY_RE = re.compile(r'^\s*([A-Za-z_]\w*)\s*=\s*[^=]')
# Lua 关键字/语句，裸 key 正则可能误抓，需排除
_LUA_KEYWORDS = {
    "return", "local", "function", "end", "if", "then", "else", "elseif",
    "for", "do", "while", "repeat", "until", "break", "and", "or", "not",
    "nil", "true", "false", "in",
}


def extract_lua_fields(lua_path: str) -> set[str]:
    """提取 Lua 表所有字段名（排除纯数字嵌套 key 如 ['1']）。

    支持两种 key 格式：① ["带引号"] 方括号 key（PHP 导出统一格式）
    ② 裸标识符 key（如 Move = { / ID = 0，AnimAtkFrame/AnimDuration 等表用）。
    编码容错（部分 Lua 含 GBK 中文）。逐行处理，跳过注释行（-- 开头），
    避免误抓被注释掉的字段（如 VIP.lua 的 Excavate Treasure Amount 16 处全注释）。
    排除 Lua 关键字（return/local/function 等被裸 key 正则误抓）。
    """
    with open(lua_path, encoding="utf-8", errors="replace") as handle:
        lines = handle.readlines()
    fields: set[str] = set()
    for line in lines:
        stripped = line.lstrip()
        if stripped.startswith("--"):
            continue
        # 带引号方括号 key
        for m in _LUA_FIELD_RE.findall(line):
            if not m.isdigit():
                fields.add(m)
        # 裸标识符 key（排除关键字）
        for m in _LUA_BAREKEY_RE.findall(line):
            if m not in _LUA_KEYWORDS and not m.isdigit():
                fields.add(m)
    return fields


def _collect_field_names(obj: object, fields: set[str], depth: int = 0) -> None:
    """递归收集所有"非数字 key"作为字段名（与 Lua 源正则语义对齐）。

    Lua 源用 ["字段名"] = 提取字段，[1] = 数字 key 被排除。
    JSON 端同样：遍历所有层，收集非数字 key 作为字段名候选，
    无论其值是标量还是 dict（字段值可能是子表/映射如 Trigger ID → {1:..,2:..}）。
    数字 key（含负数）视为 id/索引，跳过。
    depth 防御极端深层（>5 层视为异常截断）。
    """
    if depth > 5 or not isinstance(obj, dict):
        return
    for key, value in obj.items():
        key_str = str(key)
        # 排除数字 key（整数 id）和浮点数 key（动画帧时间戳如 0.5375）
        if not key_str.lstrip("-").isdigit() and not _is_float_key(key_str):
            fields.add(key_str)
        if isinstance(value, dict):
            _collect_field_names(value, fields, depth + 1)


def _is_float_key(s: str) -> bool:
    """判断字符串是否为浮点数 key（如 '0.5375' '1.25'），这类是数据索引不是字段名。"""
    if "." not in s:
        return False
    parts = s.split(".")
    return len(parts) == 2 and all(p.lstrip("-").isdigit() for p in parts)


def extract_json_fields(json_path: str) -> set[str]:
    """提取 JSON 字段名并集；递归自适应行式/列式/三层混合结构。

    旧版用 all(k.isdigit()) 判行式/列式，对混合结构（数字 id + 字符串别名）
    和三层嵌套（{id:{星级:{字段}}}）误判，把数字 id 当字段返回。
    新版统一递归收集"值为标量的 key"，与 Lua 源正则提取语义对齐。
    """
    with open(json_path, encoding="utf-8") as handle:
        text = handle.read().strip()
    if not text or text == "{}":
        return set()
    data = json.loads(text)
    if not data:
        return set()
    fields: set[str] = set()
    _collect_field_names(data, fields)
    return fields


def find_lua(table: str, lua_root: str) -> str | None:
    """按原大小写、首字母大写、全小写顺序找对应 Lua 源。"""
    for name in (table, table.capitalize(), table.lower()):
        path = os.path.join(lua_root, name + ".lua")
        if os.path.isfile(path):
            return path
    return None


# 已知结构性差异白名单：字段名集合对比无法对齐，但数值已由精确 diff 确认无丢失
# （首页「54 JSON 0 数值差异」+ 子代理逐表机械对比）。这些表从失败计数排除，
# 保留信息输出供人工审查。新增条目必须标注根因。
_KNOWN_STRUCT_DIFF: dict[str, str] = {
    # lua_to_json 转换工具生成的资源映射 key（EQUIP.xxx / equip.2.0.0.xxx），Lua 源无
    "Equip": "转换工具生成的资源映射 key，非字段丢失",
    # Lua 源含游戏配置脚本逻辑（MaxChapter 等），JSON 为空 {} —— 配置走常量/逻辑非表
    "GameConfig": "Lua 是脚本配置非纯数据表，JSON 空 {} 合理",
    # 语言包走 LSTR.json（4842 keys，Phase 1 已迁移），此表保持空 {}
    "LocalString": "语言包已迁移至 LSTR.json，此表空 {} 合理",
}


def main(argv: list[str]) -> int:
    root = argv[1] if len(argv) > 1 else os.getcwd()
    # P2-门禁-4：Lua 源根优先环境变量 CARDGAME_LUA_SRC，其次命令行参数，最后硬编码默认值
    lua_root = (
        argv[2]
        if len(argv) > 2
        else os.environ.get(
            "CARDGAME_LUA_SRC", r"D:\workspace\projects\CardGameAxmol\Content\src"
        )
    )
    data_dir = os.path.join(root, "resources", "data")
    tables = sorted(f for f in os.listdir(data_dir) if f.endswith(".json"))

    checked = 0
    diff_tables = 0
    missing_lua: list[str] = []
    for tf in tables:
        table = tf[:-5]
        json_path = os.path.join(data_dir, tf)
        lua_path = find_lua(table, lua_root)
        if lua_path is None:
            missing_lua.append(table)
            continue
        json_fields = extract_json_fields(json_path)
        lua_fields = extract_lua_fields(lua_path)
        checked += 1
        only_lua = lua_fields - json_fields  # 转换丢失
        only_json = json_fields - lua_fields  # 转换多加
        if only_lua or only_json:
            if table in _KNOWN_STRUCT_DIFF:
                # 已知结构性差异：信息输出但不计入失败
                print(f"[已知差异-白名单] {table}: {_KNOWN_STRUCT_DIFF[table]}")
            else:
                diff_tables += 1
                print(f"[差异] {table} (Lua: {os.path.basename(lua_path)})")
                if only_lua:
                    print(f"  Lua 有 / JSON 缺（转换丢失？）: {sorted(only_lua)}")
                if only_json:
                    print(f"  JSON 有 / Lua 无（转换多加？）: {sorted(only_json)}")

    empty_tables = [t for t in tables if extract_json_fields(os.path.join(data_dir, t)) == set()]
    print(
        f"\n对照 {checked} 张（有 Lua 源），{diff_tables} 张有字段差异，"
        f"{len(missing_lua)} 张无 Lua 源"
    )
    if missing_lua:
        print(f"无 Lua 源（顶层未找到，可能子目录或异名）: {missing_lua}")
    if empty_tables:
        print(f"空表（需从 Lua 补全）: {[t[:-5] for t in empty_tables]}")
    print("通过 ✅" if diff_tables == 0 else f"{diff_tables} 张字段差异 ❌")
    return 1 if diff_tables else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
