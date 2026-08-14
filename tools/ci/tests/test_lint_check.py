"""lint 检查器单元测试（Python unittest，零外部依赖）。"""
from __future__ import annotations

import os
import shutil
import sys
import tempfile
import unittest

_CI_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _CI_DIR)

import lint_check  # type: ignore
from _gdscript_utils import parse_file  # type: ignore

FIXTURES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")


def _run(fn, rel: str) -> list:
    """对 fixture 跑某 lint 收集函数。"""
    tree = parse_file(FIXTURES, rel)
    return fn(tree)


class LintMagicNumberTest(unittest.TestCase):
    def test_caught(self) -> None:
        texts = {t for t, _ in _run(lint_check.collect_magic_numbers, "logic_bad_magic_number.gd")}
        self.assertIn("42", texts)
        self.assertIn("100", texts)

    def test_ok_file_no_magic(self) -> None:
        self.assertEqual(_run(lint_check.collect_magic_numbers, "logic_ok.gd"), [])

    def test_const_whitelisted(self) -> None:
        # logic_ok.gd 的 const MAX_HP: int = 100 不算魔法数字
        texts = {t for t, _ in _run(lint_check.collect_magic_numbers, "logic_ok.gd")}
        self.assertNotIn("100", texts)

    def test_class_var_init_is_magic(self) -> None:
        # var hp = 100 的 100 在非 const 语句内，算魔法数字
        texts = {t for t, _ in _run(lint_check.collect_magic_numbers, "logic_bad_untyped.gd")}
        self.assertIn("100", texts)


class LintTypedVarTest(unittest.TestCase):
    def test_untyped_var_caught(self) -> None:
        names = {n for _, n in _run(lint_check.collect_untyped_vars, "logic_bad_untyped.gd")}
        self.assertIn("hp", names)

    def test_ok_file_no_untyped_var(self) -> None:
        self.assertEqual(_run(lint_check.collect_untyped_vars, "logic_ok.gd"), [])


class LintFuncReturnTest(unittest.TestCase):
    def test_missing_return_caught(self) -> None:
        names = {n for _, n in _run(lint_check.collect_untyped_func_returns, "logic_bad_func_ret.gd")}
        self.assertIn("add", names)

    def test_ok_file_no_missing_return(self) -> None:
        self.assertEqual(_run(lint_check.collect_untyped_func_returns, "logic_ok.gd"), [])


class LintParamTest(unittest.TestCase):
    def test_untyped_param_caught(self) -> None:
        names = {n for _, n in _run(lint_check.collect_untyped_params, "logic_bad_untyped.gd")}
        self.assertIn("a", names)

    def test_ok_file_no_untyped_param(self) -> None:
        self.assertEqual(_run(lint_check.collect_untyped_params, "logic_ok.gd"), [])


class LintLineCountTest(unittest.TestCase):
    def test_too_long_caught(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            sys_dir = os.path.join(root, "scripts", "systems")
            os.makedirs(sys_dir)
            with open(os.path.join(sys_dir, "big.gd"), "w", encoding="utf-8") as handle:
                handle.write("extends RefCounted\n")
                for i in range(305):
                    handle.write(f"const A{i}: int = 0\n")
            rules = {v.rule for v in lint_check.run(root)}
            self.assertIn(lint_check.RULE_TOO_LONG, rules)

    def test_ok_file_not_too_long(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            sys_dir = os.path.join(root, "scripts", "systems")
            os.makedirs(sys_dir)
            shutil.copy(
                os.path.join(FIXTURES, "logic_ok.gd"),
                os.path.join(sys_dir, "ok.gd"),
            )
            self.assertEqual(lint_check.run(root), [])

    def test_max_lines_for_logic_dirs(self) -> None:
        # 门禁-P1-2：_max_lines_for 基于 _LOGIC_PREFIXES 定档，Logic 层 300
        self.assertEqual(lint_check._max_lines_for("scripts/systems/foo.gd"), lint_check.LOGIC_MAX_LINES)
        self.assertEqual(lint_check._max_lines_for("scripts/data/foo.gd"), lint_check.LOGIC_MAX_LINES)
        self.assertEqual(lint_check._max_lines_for("scripts/autoload/foo.gd"), lint_check.LOGIC_MAX_LINES)

    def test_max_lines_for_view_dirs(self) -> None:
        # 门禁-P0-1：scripts/view + scripts/ui 走 View 层 400 档
        self.assertEqual(lint_check._max_lines_for("scripts/view/battle/battle_scene.gd"), lint_check.SCENE_MAX_LINES)
        self.assertEqual(lint_check._max_lines_for("scripts/ui/equip_craft_panel.gd"), lint_check.SCENE_MAX_LINES)
        self.assertEqual(lint_check._max_lines_for("scenes/battle/battle.tscn.gd"), lint_check.SCENE_MAX_LINES)

    def test_view_dir_350_not_too_long(self) -> None:
        # 门禁-P0-1：scripts/view 350 行（< 400）不报，旧版误报（走 300 档）
        with tempfile.TemporaryDirectory() as root:
            view_dir = os.path.join(root, "scripts", "view", "battle")
            os.makedirs(view_dir)
            with open(os.path.join(view_dir, "scene.gd"), "w", encoding="utf-8") as handle:
                handle.write("extends Node2D\n")
                for i in range(350):
                    handle.write(f"const A{i}: int = 0\n")
            rules = {v.rule for v in lint_check.run(root)}
            self.assertNotIn(lint_check.RULE_TOO_LONG, rules, "scripts/view 350 行 < 400 不应报超长")

    def test_view_dir_450_too_long(self) -> None:
        # 门禁-P0-1：scripts/ui 450 行（> 400）应报
        with tempfile.TemporaryDirectory() as root:
            view_dir = os.path.join(root, "scripts", "ui")
            os.makedirs(view_dir)
            with open(os.path.join(view_dir, "panel.gd"), "w", encoding="utf-8") as handle:
                handle.write("extends Control\n")
                for i in range(450):
                    handle.write(f"const A{i}: int = 0\n")
            rules = {v.rule for v in lint_check.run(root)}
            self.assertIn(lint_check.RULE_TOO_LONG, rules, "scripts/ui 450 行 > 400 应报超长")

    def test_root_level_gd_too_long_caught(self) -> None:
        # 门禁-2026-07-10：根目录 .gd 也纳入行数扫描（mcp_bridge.gd 曾漏报）
        with tempfile.TemporaryDirectory() as root:
            with open(os.path.join(root, "dev_tool.gd"), "w", encoding="utf-8") as handle:
                handle.write("extends Node\n")
                for i in range(450):
                    handle.write(f"const A{i}: int = 0\n")
            rules = {v.rule for v in lint_check.run(root)}
            self.assertIn(lint_check.RULE_TOO_LONG, rules, "根目录 .gd 超 400 行应被 LINT005 捕获")

    # ---- T6 双门槛（阶段一）：总行数门槛（含注释，防注释膨胀压线）----

    def test_total_max_lines_for_tiers(self) -> None:
        self.assertEqual(lint_check._total_max_lines_for("scripts/systems/foo.gd"), lint_check.LOGIC_TOTAL_MAX_LINES)
        self.assertEqual(lint_check._total_max_lines_for("scripts/data/foo.gd"), lint_check.LOGIC_TOTAL_MAX_LINES)
        self.assertEqual(lint_check._total_max_lines_for("scripts/ui/foo.gd"), lint_check.SCENE_TOTAL_MAX_LINES)
        self.assertEqual(lint_check._total_max_lines_for("scripts/view/battle/foo.gd"), lint_check.SCENE_TOTAL_MAX_LINES)

    def test_logic_comment_bloat_over_total_limit(self) -> None:
        # T6：Logic 代码行 2（< 300）但注释膨胀总行 451 > 450 应报（battle_scene 压线同型）
        with tempfile.TemporaryDirectory() as root:
            sys_dir = os.path.join(root, "scripts", "systems")
            os.makedirs(sys_dir)
            with open(os.path.join(sys_dir, "fat.gd"), "w", encoding="utf-8") as handle:
                handle.write("extends RefCounted\n")
                for i in range(450):
                    handle.write(f"# 文档注释膨胀行 {i}\n")
            msgs = [v.message for v in lint_check.run(root) if v.rule == lint_check.RULE_TOO_LONG]
            self.assertTrue(any("总行数" in m for m in msgs), f"总行数门槛应触发: {msgs}")
            self.assertFalse(any(m.startswith("代码") for m in msgs), f"代码行未超不应报: {msgs}")

    def test_view_comment_bloat_over_total_limit(self) -> None:
        # T6：View 代码行 1（< 400）但总行 551 > 550 应报
        with tempfile.TemporaryDirectory() as root:
            view_dir = os.path.join(root, "scripts", "ui")
            os.makedirs(view_dir)
            with open(os.path.join(view_dir, "fat_panel.gd"), "w", encoding="utf-8") as handle:
                handle.write("extends Control\n")
                for i in range(550):
                    handle.write(f"# 文档注释膨胀行 {i}\n")
            msgs = [v.message for v in lint_check.run(root) if v.rule == lint_check.RULE_TOO_LONG]
            self.assertTrue(any("总行数" in m for m in msgs), f"总行数门槛应触发: {msgs}")

    def test_battle_scene_current_size_passes(self) -> None:
        # T6 定档依据：当前最大 battle_scene.gd 总 537 行（T5 后）< 550 应通过（防门槛立刻打脸现状）
        self.assertLess(lint_check.SCENE_TOTAL_MAX_LINES, 560)
        self.assertGreaterEqual(lint_check.SCENE_TOTAL_MAX_LINES, 537)

    def test_root_level_exempt_not_caught(self) -> None:
        # 门禁-2026-07-10：豁免清单中的上游/开发工具脚本跳过行数检查
        with tempfile.TemporaryDirectory() as root:
            # 模拟 mcp_bridge.gd（在豁免清单中）
            with open(os.path.join(root, "mcp_bridge.gd"), "w", encoding="utf-8") as handle:
                handle.write("extends Node\n")
                for i in range(500):
                    handle.write(f"const A{i}: int = 0\n")
            rules = {v.rule for v in lint_check.run(root)}
            self.assertNotIn(lint_check.RULE_TOO_LONG, rules, "豁免清单中的 mcp_bridge.gd 不应报超长")


class LintAutoloadScanTest(unittest.TestCase):
    def test_autoload_scanned_for_magic_number(self) -> None:
        # line 32：autoload 也扫 LINT001-004（Logic 入口核心，非 LOGIC_DIRS 但 lint 专用 LINT_TYPE_DIRS）
        with tempfile.TemporaryDirectory() as root:
            autoload_dir = os.path.join(root, "scripts", "autoload")
            os.makedirs(autoload_dir)
            with open(os.path.join(autoload_dir, "bad.gd"), "w", encoding="utf-8") as handle:
                handle.write("extends Node\nvar x: int = 42\n")
            rules = {v.rule for v in lint_check.run(root)}
            self.assertIn(
                lint_check.RULE_MAGIC,
                rules,
                "autoload 应被 LINT001 魔法数扫描（line 32 盲区已堵）",
            )


if __name__ == "__main__":
    unittest.main()
