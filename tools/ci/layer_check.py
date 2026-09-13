"""分层依赖检查器（原则 1 的强制机制）。

Logic 层（scripts/systems、scripts/data）铁律：
  LAYER001 禁止引用 scenes/ 资源（preload/load 的 res://scenes/ 字符串）
  LAYER002 extends 必须是 RefCounted/Object/Resource 或同属 Logic 的自定义类
           （禁 extends Node/Control 等 View 基类）

View 子域方向（架构体检 2026-09-12 立）：
  LAYER003 scripts/ui 禁止依赖 scripts/view（依赖方向恒 view/battle → ui）：
           ① 禁 preload/load 的 res://scripts/view/ 路径字符串
           ② 禁引用 view 层 class_name（注释不算；存量债进 UI_VIEW_CLASS_WHITELIST，只减不增）

调用：python layer_check.py [项目根]，有违规返回退出码 1。
"""
from __future__ import annotations

import os
import sys
from typing import Iterator

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
from lark import Token  # type: ignore  # noqa: E402

RULE_SCENES_REF = "LAYER001"
RULE_BAD_EXTENDS = "LAYER002"
RULE_UI_VIEW_REF = "LAYER003"
_RESOURCE_SUFFIXES = (".gd", ".tscn", ".tres")

# View 子域目录（LAYER003）：ui 是跨域通用层，view（含 battle）是专属域
UI_DIRS: tuple[str, ...] = ("scripts/ui",)
VIEW_DIRS: tuple[str, ...] = ("scripts/view",)

# LAYER003 存量白名单（架构体检 2026-09-12 登记）：ui 引 view 类的既有债，只减不增——
# 新增反向依赖一律 fail；存量修复（类归位 ui/ 或调用方改造）后删对应条目。
UI_VIEW_CLASS_WHITELIST: dict[str, frozenset[str]] = {
    # 战役/关卡详情面板弹战斗准备与奖励弹窗（battle 前置流程被多域调用，归属待专项评估）
    "scripts/ui/crusade_panel.gd": frozenset({"BattlePreparePanel", "BattleRewardPopup"}),
    "scripts/ui/stage_detail_panel.gd": frozenset({"BattlePreparePanel"}),
    # e0fba4b 范式：走全局 class_name 实例化消 preload 路径依赖（见该文件头注释）
    "scripts/ui/excavate_history_panel.gd": frozenset({"ExcavateBattleReportPanel"}),
}


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


def collect_class_names(root: str, files: list[str]) -> set[str]:
    """收集一组文件的 class_name（LAYER003 用；语法错误文件按无 class_name 处理，
    其引用者不会级联误报——view 类缺失只意味着少拦，不会误拦）。"""
    names: set[str] = set()
    for rel in files:
        tree = parse_file(root, rel)
        if tree is not None:
            cn = get_class_name(tree)
            if cn:
                names.add(cn)
    return names


def iter_name_tokens(tree) -> Iterator[tuple[str, int]]:
    """遍历 AST 所有 NAME token：(名字, 行号)。注释不进 AST，天然排除注释误报。"""
    for sub in tree.iter_subtrees():
        for child in sub.children:
            if isinstance(child, Token) and child.type == "NAME":
                yield child.value, getattr(child, "line", 0)


def check_ui_file(
    rel: str,
    tree,
    view_only_classes: set[str],
    whitelist: dict[str, frozenset[str]] | None = None,
) -> list[Violation]:
    """LAYER003：对单个 ui 文件检查对 view 层的依赖，返回违规列表。tree 为 None 则标 PARSE。"""
    if tree is None:
        return [Violation(rel, 0, "PARSE", "GDScript 语法错误，无法解析")]
    violations: list[Violation] = []
    allowed = (whitelist or UI_VIEW_CLASS_WHITELIST).get(rel, frozenset())

    # ① 禁 preload/load 的 view/ 路径
    for value, line in get_string_literals(tree):
        if value.startswith("res://scripts/view/") or "/scripts/view/" in value:
            violations.append(
                Violation(rel, line, RULE_UI_VIEW_REF, f"ui 层禁止引用 scripts/view/ 资源：{value}")
            )

    # ② 禁引 view 层 class_name（去重同名同行，避免一行多 token 重复报）
    seen: set[tuple[str, int]] = set()
    for name, line in iter_name_tokens(tree):
        if name in view_only_classes and name not in allowed and (name, line) not in seen:
            seen.add((name, line))
            violations.append(
                Violation(
                    rel,
                    line,
                    RULE_UI_VIEW_REF,
                    f"ui 层禁止引用 view 层类 {name}（方向恒 view/battle → ui；"
                    f"存量债登记于 UI_VIEW_CLASS_WHITELIST，只减不增）",
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

    # LAYER003：ui 禁依赖 view（view_only = view 定义且 ui 未同名定义的类，防撞名误伤）
    ui_files = find_gd_files(root, UI_DIRS)
    view_classes = collect_class_names(root, find_gd_files(root, VIEW_DIRS))
    ui_classes = collect_class_names(root, ui_files)
    view_only_classes = view_classes - ui_classes
    for rel in ui_files:
        tree = parse_file(root, rel)
        all_violations.extend(check_ui_file(rel, tree, view_only_classes))

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
