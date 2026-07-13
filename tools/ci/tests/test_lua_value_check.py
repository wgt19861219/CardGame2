"""lua_value_check 单元测试（Python unittest，零外部依赖）。

P2-2（2026-07-11）：守卫深度值对比逻辑——_deep_diff 漂移检出 + _scalar_eq
数值容差 + _is_whitelisted 白名单前缀匹配。
"""
from __future__ import annotations

import os
import sys
import unittest

_CI_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _CI_DIR)

import lua_value_check  # type: ignore  # noqa: E402


class DeepDiffTest(unittest.TestCase):
    def test_scalar_diff_detected(self) -> None:
        diffs = lua_value_check._deep_diff({"a": 1}, {"a": 2})
        self.assertEqual(len(diffs), 1)
        self.assertEqual(diffs[0][0], "a")

    def test_scalar_match_no_diff(self) -> None:
        self.assertEqual(lua_value_check._deep_diff({"a": 1, "b": "x"}, {"a": 1, "b": "x"}), [])

    def test_int_float_tolerance(self) -> None:
        # int vs float 同值不算漂移（5 vs 5.0）
        self.assertEqual(lua_value_check._deep_diff({"a": 5}, {"a": 5.0}), [])

    def test_bool_value_diff_detected(self) -> None:
        # True vs False 检出（bool 值不同，Lua true/false ↔ JSON true/false）
        diffs = lua_value_check._deep_diff({"a": True}, {"a": False})
        self.assertEqual(len(diffs), 1)

    def test_missing_key_both_directions(self) -> None:
        diffs = lua_value_check._deep_diff({"a": 1}, {"b": 2})
        paths = {d[0] for d in diffs}
        self.assertIn("a", paths)  # lua 有 json 无
        self.assertIn("b", paths)  # json 有 lua 无

    def test_nested_diff_path(self) -> None:
        diffs = lua_value_check._deep_diff({"x": {"y": 1}}, {"x": {"y": 99}})
        self.assertEqual(len(diffs), 1)
        self.assertEqual(diffs[0][0], "x.y")

    def test_list_element_diff(self) -> None:
        diffs = lua_value_check._deep_diff([1, 2, 3], [1, 2, 4])
        self.assertEqual(len(diffs), 1)
        self.assertEqual(diffs[0][0], "[2]")


class WhitelistTest(unittest.TestCase):
    def test_whitelist_prefix_match(self) -> None:
        lua_value_check._WHITELIST["Stage.description"] = "标点手改"
        try:
            self.assertIsNotNone(lua_value_check._is_whitelisted("Stage.description"))
            self.assertIsNotNone(lua_value_check._is_whitelisted("Stage.description.50001"))
            self.assertIsNone(lua_value_check._is_whitelisted("Stage.Money"))
        finally:
            lua_value_check._WHITELIST.pop("Stage.description", None)


if __name__ == "__main__":
    unittest.main()
