# -*- coding: utf-8 -*-
"""CardGame2 剧情表转换：源 Axmol lua → Godot resources/data/StoryTable.json。

源：D:\\workspace\\projects\\CardGameAxmol\\Content\\src\\gametable\\storytableconfig.lua
  KeyName = { Content = { { monsterIndex|playIndex = N, position = "left|right",
                            text = T(LSTR("STORYTABLECONFIG.XXX")) }, ... },
              ShowOnce = bool }
产出：resources/data/StoryTable.json
  { "KeyName": { "show_once": bool,
                 "content": [ { "monster_index"|"play_index": N,
                                "position": "...", "text_key": "STORYTABLECONFIG.XXX" } ] } }
text 存 LSTR key（运行时经 ConfigManager.get_lstr 按当前语言翻译，保多语言）。
lua 重复 key 后者覆盖（lua 语义），WinBackToSelect74 源内即重复。
用法：python tools/convert_storytable.py
"""
import io
import json
import re
import sys

SRC = r"D:\workspace\projects\CardGameAxmol\Content\src\gametable\storytableconfig.lua"
DST = r"resources\data\StoryTable.json"
LSTR = r"resources\data\LSTR.json"

HEAD_RE = re.compile(r"^([A-Za-z0-9_]+)\s*=\s*\{")
FIELD_RE = re.compile(
    r"(monsterIndex|playIndex|position|text|icon|name)\s*=\s*(?:\"([^\"]*)\"|T\(LSTR\(\"([^\"]+)\"\)\)|(-?\d+)|(\w+))")


def convert() -> dict:
    lines = io.open(SRC, encoding="utf-8").read().splitlines()
    out: dict = {}
    key = None
    section = None   # 当前 Content 子项 dict
    for raw in lines:
        line = raw.strip()
        # 顶层 key 定义顶格无缩进；Content = { / ShowOnce = 等内部字段带缩进
        m = HEAD_RE.match(raw) if not raw[:1].isspace() else None
        if m:
            key = m.group(1)
            out[key] = {"show_once": False, "content": []}
            continue
        if key is None:
            continue
        if line.rstrip(",") == "{":
            section = {}
            continue
        if line.rstrip(",") == "}":
            if section is not None:
                out[key]["content"].append(section)
                section = None
            continue
        if line.startswith("ShowOnce"):
            out[key]["show_once"] = line.rstrip(",").endswith("true")
            continue
        fm = FIELD_RE.search(line)
        if fm and section is not None:
            name, s_val, lstr_val, n_val = fm.group(1), fm.group(2), fm.group(3), fm.group(4)
            if name == "position":
                section["position"] = s_val
            elif name == "text":
                section["text_key"] = lstr_val
            elif name == "monsterIndex":
                section["monster_index"] = int(n_val)
            elif name == "playIndex":
                section["play_index"] = int(n_val)
            elif name == "icon":
                section["icon"] = s_val
            elif name == "name":
                section["name_key"] = lstr_val
    return out


def main() -> int:
    table = convert()
    lstr = json.load(io.open(LSTR, encoding="utf-8"))
    bad_pos, empty = [], []
    missing_lstr = []   # 源 LSTR 本就缺失的 key（运行时 get_lstr 返回 key 本身兜底，与源一致）
    for k, v in table.items():
        if not v["content"]:
            empty.append(k)
        for sec in v["content"]:
            if sec.get("text_key") not in lstr:
                missing_lstr.append("%s:%s" % (k, sec.get("text_key")))
            if sec.get("position") not in ("left", "right"):
                bad_pos.append("%s:%s" % (k, sec.get("position")))
    n_sections = sum(len(v["content"]) for v in table.values())
    n_icons = sum(1 for v in table.values() for s in v["content"] if "icon" in s)
    n_names = sum(1 for v in table.values() for s in v["content"] if "name_key" in s)
    print("keys=%d sections=%d show_once=%d icons=%d names=%d" % (
        len(table), n_sections, sum(1 for v in table.values() if v["show_once"]), n_icons, n_names))
    if empty:
        print("EMPTY CONTENT:", empty)
    if bad_pos:
        print("BAD POSITION:", bad_pos[:5])
    if empty or bad_pos:
        return 1
    if missing_lstr:
        print("WARN text_key 源 LSTR 本缺（保 key 运行时兜底）:", missing_lstr)
    with io.open(DST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(table, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print("written:", DST)
    return 0


if __name__ == "__main__":
    sys.exit(main())
