#!/usr/bin/env python3
"""【已废弃】SkillGroup.lua -> SkillGroup.json 一次性迁移（已完成，SkillGroup.json 已生成）。
保留作历史记录，不应再运行。数据维护用 lua_to_json.py + build_data.py。

原用途：SkillGroup.lua -> SkillGroup.json 一次性迁移。

SkillGroup 是英雄->技能组映射 + 技能等级成长(Growth)的唯一来源，
旧版 CardGame 与本项目均未迁移（Glob 确认无 SkillGroup.json）。
结构：caster_id(英雄) -> slot(技能槽 1-4) -> {Skill Group ID, Growth X Field/Value, CD, Unlock, ...}

转换规则（套用 Skill.lua->Skill.json 已验证的模式）：
  LSTR("X")      -> "X"        （保留本地化 key）
  [N] =          -> "N":       （数字 key 加引号）
  ["Key"] =      -> "Key":     （字符串 key 去括号）
  行尾 -- 注释    -> 删除
  尾随逗号        -> 删除
转换后用 json.loads 验证合法性，失败则报错位置上下文。
"""
import json
import re
import sys
from pathlib import Path

SRC = Path(r"D:\workspace\projects\CardGameAxmol\Content\src\SkillGroup.lua")
DST = Path(r"D:\workspace\projects\CardGame2\resources\data\SkillGroup.json")


def lua_table_to_json(text: str) -> str:
    s = text.strip()
    s = re.sub(r"^\s*return\s+", "", s)                 # 去 return 前缀
    s = re.sub(r"--[^\n]*", "", s)                       # 去行注释
    s = re.sub(r"^[ \t]*\d+[ \t]*,[ \t]*$", "", s, flags=re.MULTILINE)  # 删 Lua 数组部分裸数字行（slot 占位 0）
    s = re.sub(r'LSTR\(\s*"((?:[^"\\]|\\.)*)"\s*\)', r'"\1"', s)  # LSTR("X") -> "X"
    s = re.sub(r"\[\s*(-?\d+)\s*\]\s*=", r'"\1": ', s)          # [N] = -> "N":
    s = re.sub(r'\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=', r'"\1": ', s)  # ["K"] = -> "K":
    s = re.sub(r",(\s*[}\]])", r"\1", s)                 # 尾随逗号
    return s


def main() -> int:
    text = SRC.read_text(encoding="utf-8")
    converted = lua_table_to_json(text)
    try:
        data = json.loads(converted)
    except json.JSONDecodeError as e:
        pos = e.pos
        ctx = converted[max(0, pos - 80):pos + 80]
        print(f"JSON 解析失败 @ 行{e.lineno}:列{e.colno}: {e.msg}")
        print(f"上下文: ...{ctx}...")
        return 1
    DST.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    casters = len(data)
    slots = sum(len(v) for v in data.values())
    print(f"迁移成功: {casters} 个英雄(caster), {slots} 个技能组(slot) -> {DST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
