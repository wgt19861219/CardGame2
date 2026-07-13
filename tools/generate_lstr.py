#!/usr/bin/env python3
"""language/<lang>.lua → LSTR_<lang>.json 生成器（多语言 i18n）。

源 LocalString.lua:74-80 `LSTR(key) = langs[currentLang][key]`，currentLang 默认 zh-CN，
找不到返 key 本身。本项目 LanguageManager.get_lstr(key) 等价：查 LSTR_<current_lang>.json，
找不到返 key。LSTR.json（zh-CN）保留向后兼容 ConfigManager.get_lstr。

支持 7 实际语言包：zh-CN/en-US/de-DE/ko-KR/pt-BR/ru-RU/tr-TR（源 LocalString.lua:26-43，
其余 10 语言 fallback en-US，不单独生成）。

用法：python tools/generate_lstr.py
生成 resources/data/LSTR_<lang>.json ×7 + LSTR.json（zh-CN 默认）。
自包含，不依赖外部库。
"""
import json
import os
import re

LANG_DIR = r"D:\workspace\projects\CardGameAxmol\Content\src\language"
OUT_DIR = r"D:\workspace\projects\CardGame2\resources\data"
# 源 LocalString.lua:26-43 实际语言包（其余 10 fallback en-US，不单独生成）。
LANGUAGES = ["zh-CN", "en-US", "de-DE", "ko-KR", "pt-BR", "ru-RU", "tr-TR"]

# zh-CN.lua 行：	["KEY"] = "value"（value 可含转义 \"）
# key 字符集含 `;` 和 `-`：`;` 少数 key 含分号（Equip.lua:4957 / Stage.lua:10786，如 EQUIP....SHIELD;_A_PLAYER...）；
# `-` 语言代码 key 含连字符（CONFIGURE.LANGUAGE.EN-US/DE-DE/KO-KR/PT-BR/RU-RU/TR-TR 等 16 个语言名）。
# 曾漏 `;`（P2-三轮-4 修）后漏 `-`（2026-07-13 i18n 启动修，致语言名 key 不入 LSTR.json → 切换 UI 显示英文 key）。
LANG_LINE_RE = re.compile(r'\["([A-Za-z0-9_.;-]+)"\]\s*=\s*"((?:[^"\\]|\\.)*)"')


def parse_lang(lang_path):
    with open(lang_path, "r", encoding="utf-8") as f:
        src = f.read()
    out = {}
    for m in LANG_LINE_RE.finditer(src):
        val = m.group(2).replace('\\"', '"').replace("\\\\", "\\")
        out[m.group(1)] = val
    return out


def write_json(out_path, data):
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def main():
    for lang in LANGUAGES:
        lang_path = os.path.join(LANG_DIR, lang + ".lua")
        out_path = os.path.join(OUT_DIR, "LSTR_" + lang + ".json")
        out = parse_lang(lang_path)
        write_json(out_path, out)
        print(lang + ".lua -> " + out_path + " (" + str(len(out)) + " keys)")
    # LSTR.json（zh-CN 默认，向后兼容 ConfigManager.get_lstr）。
    zh_out = os.path.join(OUT_DIR, "LSTR.json")
    zh_data = parse_lang(os.path.join(LANG_DIR, "zh-CN.lua"))
    write_json(zh_out, zh_data)
    print("zh-CN.lua -> " + zh_out + " (" + str(len(zh_data)) + " keys) [默认/向后兼容]")


if __name__ == "__main__":
    main()
