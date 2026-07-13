#!/usr/bin/env python3
"""数据层构建编排（CardGame2 数据层可重现构建入口）。

数据层来源 = 源项目 CardGameAxmol/Content/src/*.lua（105 表）。构建分两类：

  ① 静态字面量表（绝大多数）：lua_to_json.py 直接转，无后处理。
     用法：python tools/lua_to_json.py <src.lua> resources/data/<Table>.json

  ② 含程序生成段的表：lua_to_json.py 转静态部分 + expand_*.py 照源 Lua for 循环
     重新生成动态段（lua_to_json 是静态解析器，不执行 Lua 代码，源里 for 循环
     生成的数据必然丢失，必须用 expand 照源重新生成）。当前两类：
       - StageDungeon：静态 21 关 + diff 2/3/4 变体（源 :761-819 diffConfig）
         → expand_stage_dungeon.py（21 → 84 关，后处理读 lua_to_json 输出展开）
       - Battle：静态段 + dungeon 段 50001-53021（源 :80954-81124 dungeonBosses
         × diffScale；dungeonBosses 是 local 变量字面量不进 data 表，expand 独立持有）
         → expand_battle_dungeon.py（注入 21 base × 4 diff = 84 stage × 3 wave）

这是数据层的固有模式（源用 Lua for 循环生成，静态解析器无法等价），非债。

用法：
  python tools/build_data.py          # 跑两个 expand 后处理（幂等，覆盖式重生成）
  python tools/build_data.py --check  # 仅验证 dungeon 段齐全（只读，CI 用）
"""
import json
import os
import subprocess
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS_DIR = os.path.join(PROJECT_ROOT, "tools")
DATA_DIR = os.path.join(PROJECT_ROOT, "resources", "data")
DUNGEON_RANGE = (50001, 53021)
EXPECTED_DUNGEON_STAGES = 84  # 21 base × 4 diff


def _run(script: str) -> int:
    """跑 tools/<script>，返回退出码。"""
    cmd = [sys.executable, os.path.join(TOOLS_DIR, script)]
    print("$ " + " ".join(cmd))
    return subprocess.run(cmd, cwd=PROJECT_ROOT).returncode


def check_dungeon_segment() -> int:
    """验证 Battle.json dungeon 段齐全（50001-53021 共 84 stage）。"""
    with open(os.path.join(DATA_DIR, "Battle.json"), encoding="utf-8") as f:
        data = json.load(f)
    lo, hi = DUNGEON_RANGE
    count = sum(1 for k in data if k.isdigit() and lo <= int(k) <= hi)
    ok = count == EXPECTED_DUNGEON_STAGES
    flag = "OK" if ok else "FAIL"
    print(f"Battle.json dungeon 段：{count} / {EXPECTED_DUNGEON_STAGES} [{flag}]")
    return 0 if ok else 1


def main() -> int:
    if "--check" in sys.argv:
        return check_dungeon_segment()
    rc = _run("expand_stage_dungeon.py")
    if rc:
        return rc
    rc = _run("expand_battle_dungeon.py")
    if rc:
        return rc
    return check_dungeon_segment()


if __name__ == "__main__":
    sys.exit(main())
