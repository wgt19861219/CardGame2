#!/usr/bin/env python3
"""提取 stageselectres.lua 的 map 数据 → JSON（照源 stageselect 地图布局）。

源 stageselectres.lua 的 `local map = {}; map.chapterN = {...}; class.map = map`
结构特殊（嵌套 ccp()、id/eid/guildInstanceId/resid 混合字段），lua_to_json.py
不支持函数调用 ccp(x,y)。本脚本专门解析每个 chapter 块，提取布局坐标数据。

照源字段（stageselectres.lua:46-1487 + stageselect.lua createMap/createStage/getStageRes）：
- chapter 块：tag（locked stagecircle_skeleton{tag}.png 用）/ guildInstance（true=公会副本章节）
- bg.res + bg.pos：章节背景图 + 中心（cocos 局部坐标）
- route.res + route.pos：路线图
- stage[]：pos（cocos 局部坐标）/ id（normal 关 id）/ eid（elite 关 id，含 eid 即 key_stage boss 关）
  / guildInstanceId（guild 关 id）/ resid（key_stage boss 图 stage-{resid}.png 的 N，缺省=id）

用法：python tools/extract_stageselect_map.py [resources/data/stageselect_map.json]
源固定读 D:\\workspace\\projects\\CardGameAxmol\\Content\\src\\ui\\parameter\\stageselectres.lua
"""
import json
import re
import sys
from pathlib import Path

SRC = Path(r"D:\workspace\projects\CardGameAxmol\Content\src\ui\parameter\stageselectres.lua")
DEFAULT_OUT = Path(r"D:\workspace\projects\CardGame2\resources\data\stageselect_map.json")

CCP_ARITH_RE = re.compile(r"^[\d\s+\-*/().]+$")


def _eval_num(expr: str):
    """ccp 内表达式求值（仅允许数字与算术运算符，如 '212-20'）。"""
    expr = expr.strip()
    if not CCP_ARITH_RE.match(expr):
        raise ValueError(f"不安全的 ccp 表达式: {expr!r}")
    return eval(expr, {"__builtins__": {}}, {})


def _parse_ccp(text: str):
    """'ccp(400, 212-20)' → [400, 192]。返回 [x, y]（保留 int/float 原型）。"""
    inner = text[text.index("(") + 1:text.rindex(")")]
    parts = [p.strip() for p in inner.split(",")]
    return [_eval_num(p) for p in parts]


def _match_brace(src: str, open_idx: int) -> int:
    """从 src[open_idx]=='{' 起匹配闭合 '}' 索引（跳过字符串）。"""
    depth = 0
    i = open_idx
    in_str = False
    esc = False
    while i < len(src):
        c = src[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return i
        i += 1
    raise SyntaxError("chapter 块 brace 未闭合")


def _find_field(block: str, key: str, pattern: str):
    """块内找 key = value 的 value（单值字段）。"""
    m = re.search(pattern, block)
    return m.group(1) if m else None


def _parse_chapter(num: str, block: str) -> dict:
    """解析单个 chapter 块 → dict。"""
    entry = {}
    tag = _find_field(block, "tag", r"\btag\s*=\s*(\d+)")
    if tag is not None:
        entry["tag"] = int(tag)
    if re.search(r"\bguildInstance\s*=\s*true", block):
        entry["guildInstance"] = True
    # bg / route：res + pos
    for sec in ("bg", "route"):
        m = re.search(r"\b" + sec + r"\s*=\s*\{", block)
        if m:
            sub_open = block.index("{", m.start())
            sub_end = _match_brace(block, sub_open)
            sub = block[sub_open:sub_end + 1]
            res = _find_field(sub, "res", r'res\s*=\s*"([^"]*)"')
            pos_m = re.search(r"pos\s*=\s*ccp\([^)]*\)", sub)
            entry[sec] = {
                "res": res,
                "pos": _parse_ccp(pos_m.group(0)) if pos_m else None,
            }
    # stage[]：每个 { pos = ccp(...), id = N, ... }（单层 brace，非贪婪）
    stages = []
    for sm in re.finditer(r"\{\s*pos\s*=\s*ccp\(([^)]*)\)([^{}]*)\}", block):
        pos_expr = sm.group(1)
        rest = sm.group(2)
        st = {"pos": [_eval_num(p.strip()) for p in pos_expr.split(",")]}
        id_m = re.search(r"\bid\s*=\s*(\d+)", rest)
        if id_m:
            st["id"] = int(id_m.group(1))
        eid_m = re.search(r"\beid\s*=\s*(\d+)", rest)
        if eid_m:
            st["eid"] = int(eid_m.group(1))
        gi_m = re.search(r"\bguildInstanceId\s*=\s*(\d+)", rest)
        if gi_m:
            st["guildInstanceId"] = int(gi_m.group(1))
        resid_m = re.search(r"\bresid\s*=\s*(\d+)", rest)
        if resid_m:
            st["resid"] = int(resid_m.group(1))
        stages.append(st)
    entry["stage"] = stages
    return entry


def main():
    src = SRC.read_text(encoding="utf-8")
    result = {}
    for cm in re.finditer(r"map\.chapter(\d+)\s*=\s*\{", src):
        num = cm.group(1)
        open_idx = src.index("{", cm.start())
        end_idx = _match_brace(src, open_idx)
        block = src[open_idx:end_idx + 1]
        result["chapter" + num] = _parse_chapter(num, block)
    out = Path(sys.argv[1]) if len(sys.argv) >= 2 else DEFAULT_OUT
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    total = sum(len(v.get("stage", [])) for v in result.values())
    print(f"{SRC.name} -> {out} ({len(result)} 章 / {total} stage)")


if __name__ == "__main__":
    main()
