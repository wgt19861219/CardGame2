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
# key 字符集含 `;` `-` `\`：`;` 少数 key 含分号（Equip.lua:4957 / Stage.lua:10786，如 EQUIP....SHIELD;_A_PLAYER...）；
# `-` 语言代码 key 含连字符（CONFIGURE.LANGUAGE.EN-US/DE-DE/KO-KR/PT-BR/RU-RU/TR-TR 等 16 个语言名）；
# `\` 少数 key 含 Lua 字面 `\N` 换行占位（Equipstrengthen CLICK_HERE...\N / DIALOG._D_TIMES_\N 等 22 个 zh-CN key，
# 2026-07-16 修，致含反斜杠 key 不入 LSTR.json → get_lstr 返英文 key）。
# 曾漏 `;`（P2-三轮-4 修）后漏 `-`（2026-07-13 i18n 启动修）后漏 `\`（2026-07-16 修）。
LANG_LINE_RE = re.compile(r'\["([A-Za-z0-9_.;\\-]+)"\]\s*=\s*"((?:[^"\\]|\\.)*)"')


def parse_lang(lang_path):
    with open(lang_path, "r", encoding="utf-8") as f:
        src = f.read()
    out = {}
    for m in LANG_LINE_RE.finditer(src):
        # Lua 字符串转义（照 Lua 5.1 manual）：key 内 `\\N` 解析为字面 `\N`（照源 LSTR 查表用解码后 key）；
        # value 内 `\\`→`\`、`\"`→`"`、`\n`→LF、`\t`→TAB、`\r`→CR（消费侧 GDScript Label text 需真实换行符渲染断行）。
        # 用 \x00 占位避免 `\\` 与 `\n` 顺序依赖冲突（`\\n` 应解析为字面 `\n` 而非 LF）。
        key = m.group(1).replace("\\\\", "\\")
        val = (m.group(2)
               .replace("\\\\", "\x00")
               .replace('\\"', '"')
               .replace("\\n", "\n")
               .replace("\\t", "\t")
               .replace("\\r", "\r")
               .replace("\x00", "\\"))
        out[key] = val
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
