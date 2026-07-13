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


if __name__ == "__main__":
    unittest.main()
