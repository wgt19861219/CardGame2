"""本地门禁串联入口：分层检查 + lint + 资源/数据完整性（Python 侧）。

GUT 单测（Godot headless）由 check.sh 单独调用，本脚本只负责 Python 门禁。
串联五项：① 分层（layer_check）② lint（lint_check）③ catalog handler 引用
（catalog_check）④ Lua↔JSON 字段对照（lua_config_check）⑤ 资源完整性
（asset_check）⑥ 数据段完整性（build_data --check）。
调用：python check_all.py [项目根]，有违规返回退出码 1。
"""
from __future__ import annotations

import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import layer_check  # type: ignore  # noqa: E402
import lint_check  # type: ignore  # noqa: E402
import catalog_check  # type: ignore  # noqa: E402
import lua_config_check  # type: ignore  # noqa: E402
import asset_check  # type: ignore  # noqa: E402
import lua_value_check  # type: ignore  # noqa: E402


def main(argv: list[str]) -> int:
    root = argv[1] if len(argv) > 1 else os.getcwd()
    has_failure = False

    # ① + ② 分层 + lint
    violations = layer_check.run(root) + lint_check.run(root)
    for v in violations:
        print(v)
    status = "通过 ✅" if not violations else f"{len(violations)} 个违规 ❌"
    print(f"\n分层 + Lint：{status}")
    if violations:
        has_failure = True

    # 压线信息性警告（架构体检 2026-09-12 立，不 fail）：代码行 ≥90% 上限的文件清单，
    # 供"大功能落入前主动预拆"决策——LINT005 只拦超限看不见逼近。
    near_warnings = lint_check.collect_near_limit_warnings(root)
    if near_warnings:
        print(f"\n压线警告（{len(near_warnings)} 个文件 ≥90% 上限，不 fail，预拆候选）：")
        for w in near_warnings:
            print(f"⚠️ {w}")

    # ③ catalog handler 实现引用校验（防借单机化偷裁）
    print("\nCatalog handler 引用校验：")
    if catalog_check.run(root):
        has_failure = True

    # ④ Lua 源 vs JSON 配置字段对照
    print("\nLua ↔ JSON 字段对照：")
    if lua_config_check.main([os.path.basename(__file__), root]):
        has_failure = True

    # ⑤ 资源完整性（.import 配对）
    print("\n资源完整性：")
    assets_dir = os.path.join(root, "assets")
    if asset_check.main([os.path.basename(__file__), assets_dir]):
        has_failure = True

    # ⑥ 数据段完整性（Battle.json dungeon 段齐全）
    print("\n数据段完整性：")
    build_data = os.path.join(root, "tools", "build_data.py")
    rc = subprocess.run(
        [sys.executable, build_data, "--check"], cwd=root
    ).returncode
    if rc:
        has_failure = True

    # ⑦ gate 工具自测（pytest 回归网，防 catalog/layer/lint/asset 静默回归）
    # 门禁-P1-2（2026-07-11）：gate 工具自测曾只在本地手跑，check.sh/check_all
    # 全不调 pytest → catalog 解包等回归静默丢失（recall catalog-test-unpack-stale）。
    print("\nGate 工具自测（pytest）：")
    tests_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tests")
    rc = subprocess.run(
        [sys.executable, "-m", "pytest", tests_dir, "-q"],
        cwd=root, env={**os.environ, "PYTHONUTF8": "1"},
    ).returncode
    if rc:
        has_failure = True

    # ⑧ 关键表数值漂移守卫（P2-2：lua_value_check 深度对比 10 数值敏感表，
    # 防「源 Lua 改数值重生成后门禁全绿但数值已漂移」）
    print("\n关键表数值漂移守卫：")
    if lua_value_check.main([os.path.basename(__file__), root]):
        has_failure = True

    print("\n" + ("✅ 全部 Python 门禁通过" if not has_failure else "❌ Python 门禁有失败"))
    return 1 if has_failure else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
