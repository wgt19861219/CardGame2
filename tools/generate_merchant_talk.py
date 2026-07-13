#!/usr/bin/env python3
"""MerchantTalk.lua + zh-CN.lua → MerchantTalk.json 生成器（shop NPC 对话数据）。

源 MerchantTalk.lua 是 LSTR key 表（["Talk 1"] = LSTR("MERCHANTTALK.DEAL")），
本项目 LSTR 查表未集成，故生成时直接内嵌中文文案（从 zh-CN.lua 查 LSTR key 的中文值），
等价源 UI 层 T(LSTR(key)) 在中文环境的显示结果。忠实源语言包，非自设计文案。

用法：python tools/generate_merchant_talk.py [merchant_talk.lua] [zh-CN.lua] [output.json]
不传参数用默认绝对路径。复用 lua_to_json 的 Parser（嵌套表 + LSTR 去包裹）。

边角处理：源 MerchantTalk.lua:267 LSTR(LSTR("X")) 双 LSTR 笔误 → 预处理规整为 LSTR("X")。
"""
import json
import os
import re
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lua_to_json  # 复用 tokenize/Parser/_find_table_span

DEFAULT_MT = r"D:\workspace\projects\CardGameAxmol\Content\src\MerchantTalk.lua"
DEFAULT_ZH = r"D:\workspace\projects\CardGameAxmol\Content\src\language\zh-CN.lua"
DEFAULT_OUT = r"D:\workspace\projects\CardGame2\resources\data\MerchantTalk.json"

NESTED_LSTR_RE = re.compile(r'LSTR\(LSTR\(("(?:[^"\\]|\\.)*")\)\)')
# zh-CN.lua 行：	["KEY"] = "value"（value 可含转义）
LANG_LINE_RE = re.compile(r'\["([A-Za-z0-9_.]+)"\]\s*=\s*"((?:[^"\\]|\\.)*)"')


def load_lang(path):
    """解析 zh-CN.lua 所有 ["KEY"] = "value" → {KEY: 中文}。"""
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()
    out = {}
    for m in LANG_LINE_RE.finditer(src):
        val = m.group(2).replace('\\"', '"').replace("\\\\", "\\")
        out[m.group(1)] = val
    return out


def parse_merchant_talk(mt_path):
    """读 MerchantTalk.lua，预处理嵌套 LSTR，复用 lua_to_json 解析为结构（LSTR key 文本）。"""
    with open(mt_path, "r", encoding="utf-8") as f:
        src = f.read()
    src = NESTED_LSTR_RE.sub(r'LSTR(\1)', src)  # LSTR(LSTR("X")) → LSTR("X")
    # 裸标识符 key → 字符串 key（MerchantTalk 的 Event 名 Welcome/Purchase/... = {，lua_to_json 仅认 ["k"]=）
    src = re.sub(r'(?m)^(\s+)([A-Za-z_]\w*)\s*=', r'\1["\2"] =', src)
    # 写临时文件复用 lua_to_json.parse_file（其定位最外层 table + tokenize）
    with tempfile.NamedTemporaryFile(mode="w", suffix=".lua", delete=False, encoding="utf-8") as tf:
        tf.write(src)
        tmp_path = tf.name
    try:
        return lua_to_json.parse_file(tmp_path)
    finally:
        os.unlink(tmp_path)


def localize(value, lang, misses):
    """递归把 LSTR key 字符串替换为中文（找不到记入 misses 保留 key）。"""
    if isinstance(value, str):
        if value in lang:
            return lang[value]
        # 仅对疑似 LSTR key（大写+点/下划线）记 miss，普通值（如 "Welcome" Event 名）忽略
        if re.match(r"^[A-Z][A-Z0-9_.]*$", value):
            misses.add(value)
        return value
    if isinstance(value, dict):
        return {k: localize(v, lang, misses) for k, v in value.items()}
    if isinstance(value, list):
        return [localize(v, lang, misses) for v in value]
    return value


def main():
    mt_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_MT
    zh_path = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_ZH
    out_path = sys.argv[3] if len(sys.argv) > 3 else DEFAULT_OUT

    lang = load_lang(zh_path)
    data = parse_merchant_talk(mt_path)
    misses = set()
    data = localize(data, lang, misses)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(f"{os.path.basename(mt_path)} + {os.path.basename(zh_path)} -> {out_path} ({len(data)} 店)")
    for k in sorted(misses):
        print(f"  [warn] zh-CN 未命中 LSTR key: {k}", file=sys.stderr)


if __name__ == "__main__":
    main()
