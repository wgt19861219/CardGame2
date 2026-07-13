"""共享：GDScript 文件发现 + AST 解析 + 信号提取。

分层检查器与 lint 共用本模块。基于 gdtoolkit 的 lark AST。
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Optional

from gdtoolkit.parser import parser as gd_parser
from lark import Token, Tree

# Logic 层目录（相对项目根），分层检查器只扫这里
LOGIC_DIRS: tuple[str, ...] = ("scripts/systems", "scripts/data", "scripts/server")
# scenes/ 资源标识，Logic 层引用即违规
SCENE_DIR_TOKEN: str = "scenes/"
# Logic 层允许的 extends 基类（Node/Control 系一律禁止）
ALLOWED_LOGIC_BASES: frozenset[str] = frozenset({"RefCounted", "Object", "Resource"})


@dataclass
class Violation:
    """一条门禁违规。"""

    file: str
    line: int
    rule: str
    message: str

    def __str__(self) -> str:
        loc = f"{self.file}:{self.line}" if self.line else self.file
        return f"{loc}: [{self.rule}] {self.message}"


def find_gd_files(root: str, subdirs: tuple[str, ...]) -> list[str]:
    """递归收集 root/subdirs 下所有 .gd 文件，返回正斜杠相对项目根的路径。"""
    out: list[str] = []
    for sub in subdirs:
        base = os.path.join(root, sub)
        if not os.path.isdir(base):
            continue
        for dirpath, _dirs, files in os.walk(base):
            for name in files:
                if name.endswith(".gd"):
                    rel = os.path.relpath(os.path.join(dirpath, name), root)
                    out.append(rel.replace("\\", "/"))
    return sorted(out)


def parse_file(root: str, rel_path: str) -> Optional[Tree]:
    """解析 .gd 返回 lark Tree（带行号元数据）；语法错误返回 None。"""
    full = os.path.join(root, rel_path)
    try:
        with open(full, "r", encoding="utf-8") as handle:
            code = handle.read()
        return gd_parser.parse(code, gather_metadata=True)
    except Exception:  # noqa: BLE001 - 语法错误等，交给调用方标记 PARSE 违规
        return None


def iter_trees(tree: Tree) -> list[Tree]:
    """前序遍历所有 Tree 节点（含自身）。"""
    result: list[Tree] = []
    stack: list[Tree] = [tree]
    while stack:
        node = stack.pop()
        result.append(node)
        for child in reversed(node.children):
            if isinstance(child, Tree):
                stack.append(child)
    return result


def _unquote(raw: str) -> str:
    """去掉字符串字面量的首尾引号。"""
    if len(raw) >= 2 and raw[0] in "\"'" and raw[-1] == raw[0]:
        return raw[1:-1]
    return raw


def get_class_name(tree: Tree) -> Optional[str]:
    """提取 class_name，无则 None。"""
    for node in iter_trees(tree):
        if node.data == "classname_stmt":
            for child in node.children:
                if isinstance(child, Token) and child.type == "NAME":
                    return child.value
    return None


def get_extends_target(tree: Tree) -> Optional[str]:
    """提取 extends 基类名（兼容 extends_stmt 与 classname_extends_stmt）。"""
    for node in iter_trees(tree):
        if node.data == "extends_stmt":
            for child in node.children:
                if isinstance(child, Token) and child.type == "NAME":
                    return child.value
                if isinstance(child, Token) and "STRING" in child.type:
                    return _unquote(child.value)
        elif node.data == "classname_extends_stmt":
            names = [c.value for c in node.children if isinstance(c, Token) and c.type == "NAME"]
            strs = [c for c in node.children if isinstance(c, Token) and "STRING" in c.type]
            # 第一个 NAME 是 class_name，基类是第二个 NAME 或 string
            if len(names) >= 2:
                return names[1]
            if strs:
                return _unquote(strs[0].value)
            if len(names) == 1:
                return names[0]
    return None


def get_string_literals(tree: Tree) -> list[tuple[str, int]]:
    """所有字符串字面量：(去引号值, 行号)。"""
    out: list[tuple[str, int]] = []

    def walk(node: object) -> None:
        if isinstance(node, Token):
            if "STRING" in node.type:
                out.append((_unquote(node.value), getattr(node, "line", 0)))
        elif isinstance(node, Tree):
            for child in node.children:
                walk(child)

    walk(tree)
    return out


def node_line(node: Tree) -> int:
    """取 Tree 节点起始行号（先 meta.line，回退到子树首个 token）。"""
    meta = getattr(node, "meta", None)
    if meta is not None and getattr(meta, "line", 0):
        return meta.line
    for sub in node.iter_subtrees():
        for child in sub.children:
            if isinstance(child, Token) and getattr(child, "line", 0):
                return child.line
    return 0


def first_name(node: Tree) -> str:
    """节点内首个 NAME token 的值。"""
    for child in node.children:
        if isinstance(child, Token) and child.type == "NAME":
            return child.value
    return "?"
