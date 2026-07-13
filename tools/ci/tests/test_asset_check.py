"""asset_check 单元测试（Python unittest，零外部依赖）。

门禁-P1-1（2026-07-11）：复现并守卫 .gd.uid 孤儿检查的路径 bug——
_check_orphan_gd_uids 曾用 assets_root/scripts 定位脚本目录，但 scripts/ 在
项目根（assets 父目录）下，导致从 check_all 传 assets/ 时拼出不存在的
assets/scripts → isdir 否直接 return → 永远报 0 孤儿（门禁假绿）。
"""
from __future__ import annotations

import os
import sys
import tempfile
import unittest

_CI_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _CI_DIR)

import asset_check  # type: ignore  # noqa: E402


class OrphanGdUidTest(unittest.TestCase):
    def test_orphan_detected_when_scripts_at_project_root(self) -> None:
        # 门禁-P1-1：check_all 传 assets/，scripts/ 在项目根（assets 父）下，
        # 孤儿 .gd.uid 必须被检出（修复前拼 assets/scripts 不存在→漏报假绿）。
        with tempfile.TemporaryDirectory() as project_root:
            assets_dir = os.path.join(project_root, "assets")
            scripts_dir = os.path.join(project_root, "scripts", "systems")
            os.makedirs(assets_dir)
            os.makedirs(scripts_dir)
            # 孤儿：.gd.uid 无对应 .gd
            with open(os.path.join(scripts_dir, "ghost.gd.uid"), "w", encoding="utf-8") as handle:
                handle.write('{"path":"res://scripts/systems/ghost.gd"}')
            orphans = asset_check._check_orphan_gd_uids(assets_dir)
            self.assertTrue(
                any("ghost.gd.uid" in o for o in orphans),
                "scripts/ 在项目根时，孤儿 .gd.uid 必须被检出（修复前漏报）",
            )

    def test_no_orphan_when_gd_exists(self) -> None:
        # .gd 与 .gd.uid 配对存在时不报孤儿
        with tempfile.TemporaryDirectory() as project_root:
            assets_dir = os.path.join(project_root, "assets")
            scripts_dir = os.path.join(project_root, "scripts")
            os.makedirs(assets_dir)
            os.makedirs(scripts_dir)
            with open(os.path.join(scripts_dir, "real.gd"), "w", encoding="utf-8") as handle:
                handle.write("extends RefCounted\n")
            with open(os.path.join(scripts_dir, "real.gd.uid"), "w", encoding="utf-8") as handle:
                handle.write('{"path":"res://scripts/real.gd"}')
            self.assertEqual(asset_check._check_orphan_gd_uids(assets_dir), [])

    def test_no_scripts_dir_returns_empty(self) -> None:
        # 无 scripts/ 目录时静默返空（不崩）
        with tempfile.TemporaryDirectory() as project_root:
            assets_dir = os.path.join(project_root, "assets")
            os.makedirs(assets_dir)
            self.assertEqual(asset_check._check_orphan_gd_uids(assets_dir), [])

    def test_orphan_path_relative_to_project_root(self) -> None:
        # 显示路径以项目根为基准（scripts/... 正斜杠归一化），便于定位；
        # 不应残留 assets/../ 前缀
        with tempfile.TemporaryDirectory() as project_root:
            assets_dir = os.path.join(project_root, "assets")
            scripts_dir = os.path.join(project_root, "scripts", "data")
            os.makedirs(assets_dir)
            os.makedirs(scripts_dir)
            with open(os.path.join(scripts_dir, "ghost.gd.uid"), "w", encoding="utf-8") as handle:
                handle.write('{"path":"res://scripts/data/ghost.gd"}')
            orphans = asset_check._check_orphan_gd_uids(assets_dir)
            self.assertEqual(len(orphans), 1)
            self.assertTrue(orphans[0].startswith("scripts/"), f"应以 scripts/ 开头: {orphans[0]}")
            self.assertNotIn("assets", orphans[0])


class RootLevelOrphanImportTest(unittest.TestCase):
    def test_root_orphan_import_detected(self) -> None:
        # P2-3：项目根顶层 .import 无对应资源 → 检出（修复前 asset_check 只扫 assets 漏根）
        with tempfile.TemporaryDirectory() as project_root:
            with open(os.path.join(project_root, "stale.png.import"), "w", encoding="utf-8") as handle:
                handle.write("[remap]\n")
            orphans = asset_check._check_root_level_orphan_imports(project_root)
            self.assertTrue(
                any("stale.png.import" in o for o in orphans),
                "项目根顶层孤儿 .import 必须被检出",
            )

    def test_root_import_with_resource_not_orphan(self) -> None:
        # .import 有对应资源 → 不报
        with tempfile.TemporaryDirectory() as project_root:
            with open(os.path.join(project_root, "real.png"), "w", encoding="utf-8") as handle:
                handle.write("png")
            with open(os.path.join(project_root, "real.png.import"), "w", encoding="utf-8") as handle:
                handle.write("[remap]\n")
            self.assertEqual(asset_check._check_root_level_orphan_imports(project_root), [])

    def test_root_non_recursive(self) -> None:
        # 非递归：子目录的孤儿不扫（assets 子树由 main 的 os.walk 覆盖）
        with tempfile.TemporaryDirectory() as project_root:
            sub = os.path.join(project_root, "sub")
            os.makedirs(sub)
            with open(os.path.join(sub, "deep.png.import"), "w", encoding="utf-8") as handle:
                handle.write("[remap]\n")
            self.assertEqual(asset_check._check_root_level_orphan_imports(project_root), [])


if __name__ == "__main__":
    unittest.main()
