"""Catalog 校验（P1-2）：FeatureCatalog 数据完整性 + IMPLEMENTATIONS 方法存在性。
  完整性（fail 级）：DOMAINS + SKIPPED = 源 71 handler，无重复，DOMAINS∩SKIPPED 不重叠。
  IMPLEMENTATIONS（fail 级）：每个非 SKIPPED handler 有实现映射 + 映射的 Class 在 scripts/ 存在。
    防"只登记不实现"潜伏（P0-复审-2 buy_skill_stren_point 曾因此漏网）。
  引用探测（warning）：子串匹配作 fallback，信息性不 fail（IMPLEMENTATIONS 表已 fail 级覆盖主校验）。
调用：python catalog_check.py [项目根]，错误返回 1。
"""
from __future__ import annotations

import os
import re
import sys

SOURCE_HANDLER_COUNT: int = 71  # 源 local_server.lua M.handlers.* 总数（grep 核实）


def _extract_block(content: str, start_pattern: str) -> str:
    """提取 const XXX = { ... } 或 [ ... ] 块内容（GDScript 类型注解在 = 前，括号配平）。"""
    m = re.search(start_pattern + r"\b[^=]*=\s*([\{\[])", content)
    if not m:
        return ""
    open_ch = m.group(1)
    close_ch = "}" if open_ch == "{" else "]"
    start = m.end()
    depth = 1
    i = start
    while i < len(content) and depth > 0:
        if content[i] == open_ch:
            depth += 1
        elif content[i] == close_ch:
            depth -= 1
        i += 1
    return content[start:i - 1]


def extract_catalog(catalog_path: str) -> tuple[list[str], set[str], dict[str, str], dict[str, str]]:
    """从 feature_catalog.gd 提取 (domains_handlers, skipped, renamed, implementations)。"""
    with open(catalog_path, "r", encoding="utf-8") as f:
        content = f.read()
    domains_block = _extract_block(content, r"const DOMAINS")
    handlers: list[str] = []
    for arr in re.findall(r"\[([^\]]*)\]", domains_block):
        handlers += re.findall(r'"(\w+)"', arr)
    skipped_block = _extract_block(content, r"const SKIPPED_HANDLERS")
    skipped = set(re.findall(r'"(\w+)"', skipped_block))
    renamed_block = _extract_block(content, r"const RENAMED")
    renamed = dict(re.findall(r'"(\w+)":\s*"(\w+)"', renamed_block))
    impl_block = _extract_block(content, r"const IMPLEMENTATIONS")
    implementations = dict(re.findall(r'"(\w+)":\s*"([^"]+)"', impl_block))
    return handlers, skipped, renamed, implementations


def _find_in_scripts(scripts_dir: str, name: str, exclude: set[str]) -> bool:
    for root, _dirs, files in os.walk(scripts_dir):
        for fn in files:
            if fn.endswith(".gd") and fn not in exclude:
                with open(os.path.join(root, fn), "r", encoding="utf-8") as f:
                    if name in f.read():
                        return True
    return False


def run(root: str) -> int:
    catalog_path = os.path.join(root, "scripts", "server", "feature_catalog.gd")
    if not os.path.isfile(catalog_path):
        print(f"⚠️  feature_catalog.gd 不存在：{catalog_path}（跳过 catalog 校验）")
        return 0
    handlers, skipped, renamed, implementations = extract_catalog(catalog_path)

    # 完整性校验（fail 级）
    errors: list[str] = []
    total = len(handlers) + len(skipped)
    if total != SOURCE_HANDLER_COUNT:
        errors.append(f"handler 总数 {len(handlers)} DOMAINS + {len(skipped)} SKIPPED = {total} ≠ 源 {SOURCE_HANDLER_COUNT}")
    seen: set[str] = set()
    dups: list[str] = []
    for h in handlers:
        if h in seen:
            dups.append(h)
        seen.add(h)
    if dups:
        errors.append(f"DOMAINS 重复 handler: {sorted(set(dups))}")
    overlap = seen & skipped
    if overlap:
        errors.append(f"DOMAINS ∩ SKIPPED 重叠: {sorted(overlap)}")
    if errors:
        print("❌ catalog 完整性校验失败：")
        for e in errors:
            print(f"  - {e}")
        return 1

    # IMPLEMENTATIONS 校验（fail 级）：每个非 SKIPPED handler 必须有实现映射
    impl_errors: list[str] = []
    for h in handlers:
        if h in skipped:
            continue
        if h not in implementations:
            impl_errors.append(f"{h} 缺 IMPLEMENTATIONS 映射")
    if impl_errors:
        print("❌ catalog IMPLEMENTATIONS 校验失败（handler 只登记未映射实现）：")
        for e in impl_errors:
            print(f"  - {e}")
        return 1

    # 方法存在性校验（fail 级）：IMPLEMENTATIONS 映射的 Class 必须在 scripts/ 存在
    scripts_dir = os.path.join(root, "scripts")
    exclude = {"feature_catalog.gd"}
    method_errors: list[str] = []
    for h in handlers:
        if h in skipped:
            continue
        impl = implementations.get(h, "")
        if impl == "stub" or "（" in impl:
            continue  # stub / 分散逻辑跳过方法存在性检查
        class_name = impl.split(".")[0].split("（")[0]
        if class_name and not _find_in_scripts(scripts_dir, f"class_name {class_name}", exclude):
            method_errors.append(f"{h}→{impl}：class_name {class_name} 在 scripts/ 未找到")
    if method_errors:
        print("❌ catalog 方法存在性校验失败：")
        for e in method_errors:
            print(f"  - {e}")
        return 1

    # 实现引用探测（warning，不 fail——单机化分散致假阴性）
    scripts_dir = os.path.join(root, "scripts")
    exclude = {"feature_catalog.gd"}
    missing_refs: list[str] = []
    for h in handlers:
        if h in skipped:
            continue
        name = renamed.get(h, h)
        if not _find_in_scripts(scripts_dir, name, exclude):
            missing_refs.append(h if name == h else f"{h}→{name}")
    if missing_refs:
        print(f"⚠️ catalog 实现引用探测：{len(missing_refs)} 个 handler 在 scripts/ 未直接引用（单机化分散/别名，信息性不 fail）：")
        print("   " + ", ".join(missing_refs))

    print(f"✅ catalog 完整性：{len(handlers)} DOMAINS + {len(skipped)} SKIPPED = {total}（=源 {SOURCE_HANDLER_COUNT}），无重复无重叠")
    return 0


def main(argv: list[str]) -> int:
    root = argv[1] if len(argv) > 1 else os.getcwd()
    return run(root)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
