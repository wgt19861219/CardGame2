#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""转源 affixcount.lua（英文随机名字词库，return {"Aaran","Aaren",...}）→ AffixCount.json。
照源 bename.lua:9-16 rollName 从 affixcount 表随机取名。
"""
import re
import json

SRC = r"D:\workspace\projects\CardGameAxmol\Content\src\affixcount.lua"
DST = r"D:\workspace\projects\CardGame2\resources\data\AffixCount.json"

text = open(SRC, encoding="utf-8").read()
names = re.findall(r'"([^"]+)"', text)
with open(DST, "w", encoding="utf-8") as f:
    json.dump(names, f, ensure_ascii=False)
print(f"names count: {len(names)} | first: {names[0]} | last: {names[-1]}")
