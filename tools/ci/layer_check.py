"""分层依赖检查器（原则 1 的强制机制）。

Logic 层（scripts/systems、scripts/data）铁律：
  LAYER001 禁止引用 scenes/ 资源（preload/load 的 res://scenes/ 字符串）
  LAYER002 extends 必须是 RefCounted/Object/Resource 或同属 Logic 的自定义类
           （禁 extends Node/Control 等 View 基类）

调用：python layer_check.py [项目根]，有违规返回退出码 1。
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _gdscript_utils import (  # type: ignore  # noqa: E402
    ALLOWED_LOGIC_BASES,
    LOGIC_DIRS,
    Violation,
    find_gd_files,
    get_class_name,
    get_extends_target,
    get_string_literals,
    parse_file,
)

RULE_SCENES_REF = "LAYER001"
RULE_BAD_EXTENDS = "LAYER002"
_RESOURCE_SUFFIXES = (".gd", ".tscn", ".tres")


def _has_scenes_segment(value: str) -> bool:
    """门禁-P2-4：路径段匹配 scenes/ 目录，避免误判 my_scenes/ 等含子串的目录名。

    匹配 res://scenes/ 或任意 /scenes/ 路径段（斜杠定界）。
    旧版 `SCENE_DIR_TOKEN in value` 会误判 res://scripts/my_scenes/x.gd。
    """
    return value.startswith("res://scenes/") or "/scenes/" in value


def collect_logic_class_names(root: str, files: list[str]) -> set[str]:
    """第一遍扫描：收集所有 Logic 层 class_name，作为 extends 合法目标。

    门禁-P2-2：语法错误的文件（tree is None）用正则兜底提取 class_name，
    避免引用该类的其他文件被级联误报 LAYER002（语法错误已由 PARSE 规则单独报告）。
    """
    names: set[str] = set()
    for rel in files:
        tree = parse_file(root, rel)
        if tree is not None:
            cn = get_class_name(tree)
            if cn:
                names.add(cn)
        else:
            # 语法错误兜底：正则提取 class_name（避免级联误报）
            cn = _regex_class_name(os.path.join(root, rel))
            if cn:
                names.add(cn)
    return names


def _regex_class_name(path: str) -> str | None:
    """门禁-P2-2：语法错误文件的正则兜底 class_name 提取。"""
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                stripped = line.lstrip()
                if stripped.startswith("class_name"):
                    parts = stripped.split()
                    if len(parts) >= 2:
                        name = parts[1].rstrip()
                        name = name.split("(")[0].split("<")[0].strip()
                        return name
    except OSError:
        pass
    return None


def check_logic_file(rel: str, tree, logic_classes: set[str]) -> list[Violation]:
    """对单个 Logic 文件跑两条规则，返回违规列表。tree 为 None 则标 PARSE。"""
    if tree is None:
        return [Violation(rel, 0, "PARSE", "GDScript 语法错误，无法解析")]
    violations: list[Violation] = []

    # LAYER001：禁引用 scenes/ 资源
    # 门禁-P2-4：收紧为路径段匹配（"/scenes/"），避免误判 my_scenes/ 等含子串的目录名
    for value, line in get_string_literals(tree):
        looks_like_path = value.startswith("res://") or value.endswith(_RESOURCE_SUFFIXES)
        if looks_like_path and _has_scenes_segment(value):
            violations.append(
                Violation(rel, line, RULE_SCENES_REF, f"Logic 层禁止引用 scenes/ 资源：{value}")
            )

    # LAYER002：禁 extends Node/Control 系（白名单 = 引擎 Logic 基类 ∪ Logic 自定义类）
    target = get_extends_target(tree)
    if target is not None and target not in (ALLOWED_LOGIC_BASES | logic_classes):
        violations.append(
            Violation(
                rel,
                0,
                RULE_BAD_EXTENDS,
                f"Logic 层 extends 必须是 RefCounted/Object/Resource 或 Logic 类，"
                f"禁止 extends {target}",
            )
        )

    return violations


def run(root: str) -> list[Violation]:
    """扫描项目所有 Logic 层 .gd，返回全部违规。"""
    files = find_gd_files(root, LOGIC_DIRS)
    logic_classes = collect_logic_class_names(root, files)
    all_violations: list[Violation] = []
    for rel in files:
        tree = parse_file(root, rel)
        all_violations.extend(check_logic_file(rel, tree, logic_classes))
    return all_violations


def main(argv: list[str]) -> int:
    root = argv[1] if len(argv) > 1 else os.getcwd()
    violations = run(root)
    for v in violations:
        print(v)
    status = "通过 ✅" if not violations else f"{len(violations)} 个违规 ❌"
    print(f"\n分层检查：{status}")
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
