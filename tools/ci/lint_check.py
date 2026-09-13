"""GDScript lint（原则 2/3 的强制机制）。

  LINT001 禁魔法数字：函数/表达式体内的裸数字（值 ∉ {-1,0,1}，const 定义放行）
  LINT002 强制 var 类型注解（裸 var x / var x=e 违规；var x:T / var x:=e 合规）
  LINT003 强制 func 返回类型（-> void 等；引擎回调放行）
  LINT004 强制 func 参数类型
  LINT005 行数限制（Logic ≤300 行；场景脚本 ≤400 行）

调用：python lint_check.py [项目根]，有违规返回退出码 1。
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _gdscript_utils import (  # type: ignore  # noqa: E402
    LOGIC_DIRS,
    Violation,
    find_gd_files,
    first_name,
    iter_trees,
    node_line,
    parse_file,
)
from lark import Token, Tree  # noqa: E402

# LINT001-004 扫描目录集：Logic 层 + autoload。autoload 是 Logic 入口（含 game_data/player_data
# 等核心），应查类型/魔法数；但其 extends Node/CanvasLayer 是引擎单例，不能进 LOGIC_DIRS（否则
# layer_check 会当 Logic 层误报禁 Node），故 lint 专用此集，layer_check 仍只扫 LOGIC_DIRS。
LINT_TYPE_DIRS: tuple[str, ...] = LOGIC_DIRS + ("scripts/autoload",)

RULE_MAGIC = "LINT001"
RULE_UNTYPED_VAR = "LINT002"
RULE_UNTYPED_FUNC_RET = "LINT003"
RULE_UNTYPED_PARAM = "LINT004"
RULE_TOO_LONG = "LINT005"

MAGIC_WHITELIST: frozenset[float] = frozenset({-1.0, 0.0, 1.0})
LOGIC_MAX_LINES = 300
SCENE_MAX_LINES = 400
# T6 双门槛（审查报告-架构评估与重构方案-2026-08-14 阶段一）：代码行（上方原门槛）之外加总行数
# 门槛（含注释/空行），治注释膨胀压线——battle_scene.gd 曾总 539 行/lint 计数恰 400 压线通过
# （139 行文档注释不计）。定档依据 2026-08-14 实测：全库最大总行 battle_scene.gd 539 /
# player_data.gd 440，全部通过，仅防继续膨胀。
LOGIC_TOTAL_MAX_LINES = 450
SCENE_TOTAL_MAX_LINES = 550
# 这些引擎虚函数回调允许缺省返回类型（约定 -> void，但 body 可空）
# 行数检查扩展目录：scenes/scripts/ui/scripts/view 是 View 层（≤400），
# scripts/autoload 是 Logic 层入口（≤300，含 player_data/game_data 等核心）。
# LINT001-004（类型/魔法数）扫 LINT_TYPE_DIRS（LOGIC_DIRS + autoload，autoload 是 Logic 入口核心，line 32 堵盲区）。
LINE_COUNT_DIRS: tuple[str, ...] = (
    "scenes", "scripts/autoload", "scripts/ui", "scripts/view",
)
# Logic 层目录前缀（行数按 300 严管），其余 LINE_COUNT_DIRS 目录按 View 层 400
_LOGIC_PREFIXES: tuple[str, ...] = (
    "scripts/systems", "scripts/data", "scripts/autoload",
)
# 行数豁免清单：上游/开发工具脚本（非复刻产物，上游更新会覆盖拆分无意义）
# mcp_bridge.gd：godot-mcp-enhanced 插件桥接（TCP+认证+加密+monitor+watch+recording），
# 1460 行单文件属上游设计，拆分后插件更新会覆盖
_LINE_COUNT_EXEMPT: frozenset[str] = frozenset({"mcp_bridge.gd"})

# 无类型 var 声明种类（typed/typed_assgnd/inf 视为合规）
_UNTYPED_VAR_KINDS: frozenset[str] = frozenset(
    {"class_var_empty", "class_var_assigned", "func_var_empty", "func_var_assigned"}
)
# 引擎回调：Godot 约定无返回值，放行缺省返回类型（仍建议显式 -> void）
# 门禁-P2-3：补全 Control 系 GUI 回调（_gui_input/_make_custom_tooltip/_can_drop_data/_drop_data 等）
_ENGINE_VOID_CALLBACKS: frozenset[str] = frozenset(
    {
        # Node 系生命周期
        "_ready", "_enter_tree", "_exit_tree", "_process", "_physics_process",
        "_init", "_notification",
        # 输入系
        "_input", "_unhandled_input", "_input_event", "_unhandled_key_input",
        "_shortcut_input", "_unhandled_shortcut_input",
        # CanvasItem/Control 系绘制
        "_draw",
        # Control 系 GUI 回调（门禁-P2-3 补全）
        "_gui_input", "_make_custom_tooltip", "_get_drag_data",
        "_can_drop_data", "_drop_data",
        # 通用
        "_to_string", "_get_configuration_warning",
    }
)
_FUNC_HEADER_KINDS: frozenset[str] = frozenset({"func_header", "abstract_func_header"})


def _numeric_value(token: Token) -> float | None:
    """尝试把 token 当数字解析（支持十进制/十六/八/二进制/浮点），失败返回 None。"""
    text = token.value.replace("_", "")
    try:
        return float(int(text, 0))
    except ValueError:
        pass
    try:
        return float(text)
    except ValueError:
        return None


def _is_numeric_token(token: Token) -> bool:
    """token 是否为数字字面量（先按类型名，回退按 value 可解析）。"""
    if token.type in ("INT", "FLOAT", "OCT_INT", "BIN_INT", "HEX_INT", "SIGNED_INT", "SIGNED_FLOAT"):
        return True
    return _numeric_value(token) is not None


def collect_magic_numbers(tree: Tree) -> list[tuple[str, int]]:
    """非 const 语句内的裸数字字面量（值不在白名单），返回 (原始文本, 行号)。"""
    hits: list[tuple[str, int]] = []

    def walk(node: object, in_const: bool) -> None:
        if isinstance(node, Token):
            if not in_const and _is_numeric_token(node):
                value = _numeric_value(node)
                if value is not None and value not in MAGIC_WHITELIST:
                    hits.append((node.value, getattr(node, "line", 0)))
        elif isinstance(node, Tree):
            next_const = in_const or node.data == "const_stmt"
            for child in node.children:
                walk(child, next_const)

    walk(tree, False)
    return hits


def collect_untyped_vars(tree: Tree) -> list[tuple[int, str]]:
    """无类型 var 声明：(行号, 变量名)。"""
    hits: list[tuple[int, str]] = []
    for node in iter_trees(tree):
        if node.data in _UNTYPED_VAR_KINDS:
            hits.append((node_line(node), first_name(node)))
    return hits


def collect_untyped_func_returns(tree: Tree) -> list[tuple[int, str]]:
    """缺省返回类型的函数（引擎回调放行）：(行号, 函数名)。"""
    hits: list[tuple[int, str]] = []
    for node in iter_trees(tree):
        if node.data not in _FUNC_HEADER_KINDS:
            continue
        has_ret = any(isinstance(c, Token) and c.type == "TYPE_HINT" for c in node.children)
        if has_ret:
            continue
        name = first_name(node)
        if name in _ENGINE_VOID_CALLBACKS:
            continue
        hits.append((node_line(node), name))
    return hits


def collect_untyped_params(tree: Tree) -> list[tuple[int, str]]:
    """无类型函数参数：(行号, 参数名)。"""
    hits: list[tuple[int, str]] = []
    for node in iter_trees(tree):
        if node.data not in _FUNC_HEADER_KINDS:
            continue
        for child in node.children:
            if isinstance(child, Tree) and child.data == "func_args":
                for arg in child.children:
                    if isinstance(arg, Tree) and arg.data == "func_arg_regular":
                        hits.append((node_line(arg), first_name(arg)))
    return hits


def count_code_lines(root: str, rel: str) -> int:
    """非空、非纯注释的代码行数。"""
    full = os.path.join(root, rel)
    with open(full, "r", encoding="utf-8") as handle:
        lines = handle.readlines()
    count = 0
    for raw in lines:
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        count += 1
    return count


def _max_lines_for(rel: str) -> int:
    """行数上限：Logic 层目录 300，View 层目录（scenes/ui/view）400。

    判定基于路径前缀是否命中 _LOGIC_PREFIXES，避免旧版 "scenes/" 子串匹配
    导致 autoload/ui/view 误走 300 档（标准不一致）。
    """
    normalized = rel.replace("\\", "/")
    for prefix in _LOGIC_PREFIXES:
        if normalized.startswith(prefix):
            return LOGIC_MAX_LINES
    return SCENE_MAX_LINES


def count_total_lines(root: str, rel: str) -> int:
    """文件总行数（含注释与空行；T6 防注释膨胀压线）。"""
    with open(os.path.join(root, rel), "r", encoding="utf-8") as handle:
        return len(handle.readlines())


def _total_max_lines_for(rel: str) -> int:
    """总行数上限：与代码行同源分档（Logic 450 / View 550）。"""
    return LOGIC_TOTAL_MAX_LINES if _max_lines_for(rel) == LOGIC_MAX_LINES else SCENE_TOTAL_MAX_LINES


def _check_line_limits(root: str, rel: str, violations: list[Violation]) -> None:
    """LINT005 双门槛：代码行上限 + 总行数上限（T6）。"""
    actual = count_code_lines(root, rel)
    max_lines = _max_lines_for(rel)
    if actual > max_lines:
        violations.append(Violation(rel, 0, RULE_TOO_LONG, f"代码 {actual} 行超过上限 {max_lines}"))
    total = count_total_lines(root, rel)
    total_max = _total_max_lines_for(rel)
    if total > total_max:
        violations.append(
            Violation(rel, 0, RULE_TOO_LONG, f"总行数 {total} 行超过上限 {total_max}（含注释，防注释膨胀压线）")
        )


NEAR_LIMIT_RATIO = 0.9  # 压线预警阈值（代码行 ≥90% 上限，架构体检 2026-09-12 立）


def collect_near_limit_warnings(root: str) -> list[str]:
    """压线信息性警告：代码行 ≥ NEAR_LIMIT_RATIO × 上限的文件清单（不 fail）。

    LINT005 只拦"超限"，看不见"逼近"——压线债由 check_all 打印曝光，
    供"大功能落入前主动预拆"（fills helper/纯函数下沉）决策用。
    文件集覆盖 run() 行数检查的全部两个来源（LINT_TYPE_DIRS 含 systems/data
    + LINE_COUNT_DIRS 含 scenes/ui/view/autoload，autoload 重叠去重），豁免逻辑一致。
    """
    warnings: list[str] = []
    files = list(dict.fromkeys(
        find_gd_files(root, LINT_TYPE_DIRS)
        + find_gd_files(root, LINE_COUNT_DIRS)
        + _find_root_level_gds(root)
    ))
    for rel in files:
        if os.path.basename(rel.replace("\\", "/")) in _LINE_COUNT_EXEMPT:
            continue
        actual = count_code_lines(root, rel)
        max_lines = _max_lines_for(rel)
        if actual >= max_lines * NEAR_LIMIT_RATIO:
            warnings.append(
                f"{rel}: 代码 {actual}/{max_lines} 行（{actual * 100 // max_lines}%）压线，"
                f"大功能落入前建议预拆（fills helper/纯函数下沉）"
            )
    return warnings


def _find_root_level_gds(root: str) -> list[str]:
    """收集项目根目录（非子目录）下的 .gd 文件相对路径。

    mcp_bridge.gd 等开发工具脚本位于项目根，不在任何 LINE_COUNT_DIRS 子目录内，
    find_gd_files 扫不到。此处显式收集根级 .gd 纳入行数门禁。
    """
    out: list[str] = []
    for name in os.listdir(root):
        if name.endswith(".gd") and os.path.isfile(os.path.join(root, name)):
            out.append(name)
    return sorted(out)


def run(root: str) -> list[Violation]:
    """扫描 Logic 层全部 .gd，返回 lint 违规。"""
    files = find_gd_files(root, LINT_TYPE_DIRS)
    violations: list[Violation] = []
    for rel in files:
        tree = parse_file(root, rel)
        if tree is None:
            continue  # 语法错误由 layer_check 的 PARSE 规则报告，避免重复

        for text, line in collect_magic_numbers(tree):
            violations.append(
                Violation(rel, line, RULE_MAGIC, f"魔法数字 {text}（值应提为常量/数据表）")
            )
        for line, name in collect_untyped_vars(tree):
            violations.append(Violation(rel, line, RULE_UNTYPED_VAR, f"变量 '{name}' 缺少类型注解"))
        for line, name in collect_untyped_func_returns(tree):
            violations.append(Violation(rel, line, RULE_UNTYPED_FUNC_RET, f"函数 '{name}' 缺少返回类型（如 -> void）"))
        for line, name in collect_untyped_params(tree):
            violations.append(Violation(rel, line, RULE_UNTYPED_PARAM, f"参数 '{name}' 缺少类型注解"))

        _check_line_limits(root, rel, violations)
    # P2-4：scenes/autoload 只查 LINT005 行数（UI 胶水层不查类型/魔法数，避噪音）
    # P2-门禁2026：根目录 .gd 也纳入行数扫描（mcp_bridge.gd 曾 1460 行漏报）
    root_level_gds = _find_root_level_gds(root)
    for rel in find_gd_files(root, LINE_COUNT_DIRS) + root_level_gds:
        if os.path.basename(rel.replace("\\", "/")) in _LINE_COUNT_EXEMPT:
            continue  # 上游/开发工具豁免
        _check_line_limits(root, rel, violations)
    return violations


def main(argv: list[str]) -> int:
    root = argv[1] if len(argv) > 1 else os.getcwd()
    violations = run(root)
    for v in violations:
        print(v)
    status = "通过 ✅" if not violations else f"{len(violations)} 个违规 ❌"
    print(f"\nLint 检查：{status}")
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
