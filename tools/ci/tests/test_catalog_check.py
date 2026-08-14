"""Catalog 校验器单元测试（P1-GUT-2：FeatureCatalog→handler dispatch 链路完整性）。"""
from __future__ import annotations

import os
import sys
import unittest

_CI_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _CI_DIR)

import catalog_check  # type: ignore

# 项目根（tests/ → ci/ → tools/ → 项目根，上三级）
_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


class CatalogCompletenessTest(unittest.TestCase):
    """P1-GUT-2：FeatureCatalog 数据完整性（71 handler 闭合 + 无重叠）。"""

    def test_extract_catalog_returns_data(self) -> None:
        catalog_path = os.path.join(_PROJECT_ROOT, "scripts", "data", "feature_catalog.gd")
        handlers, skipped, renamed, _ = catalog_check.extract_catalog(catalog_path)
        self.assertGreater(len(handlers), 0, "DOMAINS 应有 handler")
        self.assertGreaterEqual(len(skipped), 0)
        self.assertIsInstance(renamed, dict)

    def test_total_handlers_match_source(self) -> None:
        # DOMAINS + SKIPPED = 源 71（catalog_check 核心完整性校验）
        catalog_path = os.path.join(_PROJECT_ROOT, "scripts", "data", "feature_catalog.gd")
        handlers, skipped, _, _ = catalog_check.extract_catalog(catalog_path)
        total = len(handlers) + len(skipped)
        self.assertEqual(total, catalog_check.SOURCE_HANDLER_COUNT, f"handler 总数应为源 {catalog_check.SOURCE_HANDLER_COUNT}")

    def test_no_duplicate_in_domains(self) -> None:
        catalog_path = os.path.join(_PROJECT_ROOT, "scripts", "data", "feature_catalog.gd")
        handlers, _, _, _ = catalog_check.extract_catalog(catalog_path)
        self.assertEqual(len(handlers), len(set(handlers)), "DOMAINS 无重复 handler")

    def test_domains_skipped_no_overlap(self) -> None:
        catalog_path = os.path.join(_PROJECT_ROOT, "scripts", "data", "feature_catalog.gd")
        handlers, skipped, _, _ = catalog_check.extract_catalog(catalog_path)
        overlap = set(handlers) & skipped
        self.assertEqual(overlap, set(), "DOMAINS ∩ SKIPPED 不应重叠")

    def test_run_passes_on_real_project(self) -> None:
        # 实跑 run() 应返回 0（项目 catalog 当前闭合）
        rc = catalog_check.run(_PROJECT_ROOT)
        self.assertEqual(rc, 0, "catalog_check.run 对当前项目应返回 0")


class CatalogDispatchCoverageTest(unittest.TestCase):
    """P1-GUT-2：每个 domain 至少有 handler（dispatch 链路非空）。"""

    def test_all_domains_have_handlers(self) -> None:
        catalog_path = os.path.join(_PROJECT_ROOT, "scripts", "data", "feature_catalog.gd")
        handlers, _, _, _ = catalog_check.extract_catalog(catalog_path)
        self.assertGreater(len(handlers), 40, "DOMAINS handler 数应覆盖主要玩法（>40）")

    def test_known_handlers_present(self) -> None:
        # 关键 handler 必须在 catalog（防误删）
        catalog_path = os.path.join(_PROJECT_ROOT, "scripts", "data", "feature_catalog.gd")
        handlers, _, _, _ = catalog_check.extract_catalog(catalog_path)
        must_have = {
            "enter_stage", "exit_stage", "gm_cmd", "midas",
            "tavern_draw", "wear_equip", "ladder", "excavate",
        }
        missing = must_have - set(handlers)
        self.assertEqual(missing, set(), f"关键 handler 缺失: {missing}")


if __name__ == "__main__":
    unittest.main()
