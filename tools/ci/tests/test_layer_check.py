"""分层检查器单元测试（Python unittest，零外部依赖）。"""
from __future__ import annotations

import os
import sys
import tempfile
import unittest

_CI_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _CI_DIR)

import layer_check  # type: ignore
from _gdscript_utils import parse_file  # type: ignore

FIXTURES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")


def _check(rel: str, classes: set[str] | None = None) -> list:
    """对 fixture 跑分层检查，返回违规列表。"""
    tree = parse_file(FIXTURES, rel)
    return layer_check.check_logic_file(rel, tree, classes or set())


class LayerCheckTest(unittest.TestCase):
    def test_logic_ok_no_violation(self) -> None:
        self.assertEqual(_check("logic_ok.gd"), [])

    def test_logic_extends_other_logic_class_ok(self) -> None:
        # extends 自定义 Logic 类（在合法集合内）应放行
        self.assertEqual(_check("logic_ok.gd", classes={"SomeLogicBase"}), [])

    def test_scenes_ref_caught(self) -> None:
        violations = _check("logic_bad_scenes_ref.gd")
        scenes_viol = [v for v in violations if v.rule == layer_check.RULE_SCENES_REF]
        self.assertEqual(len(scenes_viol), 2)

    def test_bad_extends_caught(self) -> None:
        violations = _check("logic_bad_extends_node.gd")
        rules = {v.rule for v in violations}
        self.assertIn(layer_check.RULE_BAD_EXTENDS, rules)

    def test_run_only_scans_logic_dirs(self) -> None:
        """run() 只扫 Logic 层，View 层（scenes/）不被误伤。"""
        with tempfile.TemporaryDirectory() as root:
            sys_dir = os.path.join(root, "scripts", "systems")
            scene_dir = os.path.join(root, "scenes", "hero")
            os.makedirs(sys_dir)
            os.makedirs(scene_dir)
            with open(os.path.join(sys_dir, "bad.gd"), "w", encoding="utf-8") as handle:
                handle.write("extends Control\n")
            with open(os.path.join(scene_dir, "view.gd"), "w", encoding="utf-8") as handle:
                handle.write("extends Control\n")

            violations = layer_check.run(root)
            files = {v.file for v in violations}
            self.assertIn("scripts/systems/bad.gd", files)
            self.assertNotIn("scenes/hero/view.gd", files)


class AllowedLogicBasesDefenseTest(unittest.TestCase):
    """门禁-P2-1：ALLOWED_LOGIC_BASES 显式 Node 系黑名单断言（纵深防御，防误加 Node/Control）。"""

    def test_node_system_not_in_whitelist(self) -> None:
        from _gdscript_utils import ALLOWED_LOGIC_BASES
        # Node 系基类全部不应在 Logic 白名单（View 层专属）
        node_blacklist = {
            "Node", "Node2D", "Node3D", "Control", "CanvasItem",
            "Window", "Viewport", "Sprite2D", "Sprite3D", "TextureRect",
            "Button", "Label", "Panel", "Container", "MarginContainer",
            "HBoxContainer", "VBoxContainer", "ScrollContainer",
        }
        for cls in node_blacklist:
            self.assertNotIn(
                cls, ALLOWED_LOGIC_BASES,
                f"{cls} 是 View 层基类，不应在 ALLOWED_LOGIC_BASES 白名单",
            )

    def test_logic_bases_present(self) -> None:
        from _gdscript_utils import ALLOWED_LOGIC_BASES
        # Logic 层三基类必须在白名单
        for cls in {"RefCounted", "Object", "Resource"}:
            self.assertIn(cls, ALLOWED_LOGIC_BASES, f"{cls} 应在 Logic 白名单")


class Layer003UiViewRefTest(unittest.TestCase):
    """LAYER003（架构体检 2026-09-12）：ui 禁依赖 view（方向恒 view/battle → ui）。"""

    def _check_ui(self, rel: str, view_classes: set[str], whitelist: dict | None = None) -> list:
        tree = parse_file(FIXTURES, rel)
        return layer_check.check_ui_file(rel, tree, view_classes, whitelist)

    def test_ui_ok_no_violation(self) -> None:
        # 引 ui 类/场景资源/注释提 view 类名，均不违规
        self.assertEqual(self._check_ui("ui_ok.gd", {"SomeViewClass"}), [])

    def test_ui_view_class_ref_caught(self) -> None:
        violations = self._check_ui("ui_bad_view_ref.gd", {"BattleFake"})
        class_v = [v for v in violations if v.rule == layer_check.RULE_UI_VIEW_REF and "BattleFake" in v.message]
        self.assertEqual(len(class_v), 1)

    def test_ui_view_path_ref_caught(self) -> None:
        violations = self._check_ui("ui_bad_view_ref.gd", set())
        path_v = [v for v in violations if "scripts/view/" in v.message]
        self.assertEqual(len(path_v), 1)

    def test_ui_whitelisted_class_passes(self) -> None:
        # 白名单内的 view 类引用放行（存量债机制）
        wl = {"ui_whitelist_ref.gd": frozenset({"BattleFake"})}
        self.assertEqual(self._check_ui("ui_whitelist_ref.gd", {"BattleFake"}, wl), [])

    def test_ui_non_whitelisted_class_caught(self) -> None:
        # 白名单未覆盖的 view 类仍 fail（只减不增）
        wl = {"ui_whitelist_ref.gd": frozenset({"OtherClass"})}
        violations = self._check_ui("ui_whitelist_ref.gd", {"BattleFake"}, wl)
        self.assertTrue(any(v.rule == layer_check.RULE_UI_VIEW_REF for v in violations))

    def test_run_scans_ui_layer(self) -> None:
        """run() 集成：ui 文件引 view 类被 LAYER003 抓出。"""
        with tempfile.TemporaryDirectory() as root:
            ui_dir = os.path.join(root, "scripts", "ui")
            view_dir = os.path.join(root, "scripts", "view", "battle")
            os.makedirs(ui_dir)
            os.makedirs(view_dir)
            with open(os.path.join(view_dir, "battle_fake.gd"), "w", encoding="utf-8") as handle:
                handle.write("class_name BattleFake\nextends Node2D\n")
            with open(os.path.join(ui_dir, "panel.gd"), "w", encoding="utf-8") as handle:
                handle.write("extends Control\n\nfunc open() -> void:\n\tvar p := BattleFake.new()\n")

            violations = layer_check.run(root)
            self.assertTrue(
                any(v.rule == layer_check.RULE_UI_VIEW_REF and v.file == "scripts/ui/panel.gd" for v in violations)
            )

    def test_whitelist_only_shrinks_guard(self) -> None:
        """白名单防御：项目白名单键必须真实存在（防拼写漂移致白名单失效成摆设）。"""
        import re

        ci_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        with open(os.path.join(ci_dir, "layer_check.py"), encoding="utf-8") as handle:
            src = handle.read()
        keys = re.findall(r'"(scripts/ui/[a-z0-9_]+\.gd)":', src)
        for key in keys:
            self.assertTrue(
                os.path.isfile(os.path.join(ci_dir, "..", "..", key)),
                f"UI_VIEW_CLASS_WHITELIST 键 {key} 指向不存在的文件，白名单已失效",
            )


if __name__ == "__main__":
    unittest.main()
