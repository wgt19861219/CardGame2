#!/usr/bin/env python3
"""Lua 配置表 → JSON 转换器（CardGame2 数据层 Phase 0.3 补表用）。

针对本项目源 Lua 表格式：`return { [key] = { ["field"] = value, ... } }`
或 `local data = { ... }; return data`。自包含，不依赖外部库。

用法：python tools/lua_to_json.py <input.lua> [output.json]
不传 output 则 stdout 输出 JSON。

转换规则（照本项目现有 ActStageGroup.json 格式）：
- [数字] = / ["字符串"] = → JSON 对象键（数字键字符串化，与现有表一致）
- 无键数组元素 { a, b, c } → JSON 数组
- LSTR("X") → "X"（去 LSTR 包裹，保留 LSTR key 文本）
- true/false/nil → true/false/null
- 行注释 --... 忽略
"""
import json
import re
import sys


TOKEN_RE = re.compile(
    r"""
      (?P<COMMENT>--[^\n]*)
    | (?P<WS>\s+)
    | (?P<STRING>"(?:[^"\\]|\\.)*")
    | (?P<LSTR>LSTR\("(?:[^"\\]|\\.)*"\))
    | (?P<NUMBER>-?\d+\.\d+(?:[eE][+-]?\d+)?|-?\d+(?:[eE][+-]?\d+)?)
    | (?P<OP>[\[\]{}=,])
    | (?P<IDENT>[a-zA-Z_]\w*)
    """,
    re.VERBOSE,
)


def tokenize(src: str):
    """源码 → token 流 [(kind, text), ...]，跳过注释与空白。"""
    tokens = []
    pos = 0
    while pos < len(src):
        m = TOKEN_RE.match(src, pos)
        if not m:
            raise SyntaxError(f"无法识别字符 @ {pos}: {src[pos:pos+20]!r}")
        pos = m.end()
        kind = m.lastgroup
        text = m.group()
        if kind in ("COMMENT", "WS"):
            continue
        tokens.append((kind, text))
    return tokens


class Parser:
    """递归下降解析 Lua table → Python dict/list。"""

    def __init__(self, tokens):
        self.tokens = tokens
        self.pos = 0

    def peek(self):
        return self.tokens[self.pos] if self.pos < len(self.tokens) else None

    def advance(self):
        t = self.tokens[self.pos]
        self.pos += 1
        return t

    def expect(self, text: str):
        t = self.advance()
        if t[1] != text:
            raise SyntaxError(f"期望 {text!r} 实得 {t!r} @ token#{self.pos - 1}")
        return t

    def parse_value(self):
        t = self.peek()
        if t is None:
            raise SyntaxError("意外 EOF")
        kind, text = t
        if text == "{":
            return self.parse_table()
        if kind == "STRING":
            self.advance()
            return _unescape_lua_string(text[1:-1])
        if kind == "LSTR":
            self.advance()
            inner = text[len("LSTR(") + 1 : -2]  # LSTR("X") -> X（去 LSTR( " 与 " )
            return _unescape_lua_string(inner)
        if kind == "NUMBER":
            self.advance()
            if "." in text or "e" in text or "E" in text:
                return float(text)
            return int(text)
        if kind == "IDENT":
            self.advance()
            if text == "true":
                return True
            if text == "false":
                return False
            if text == "nil":
                return None
            raise SyntaxError(f"未知标识符 {text!r}（本转换器不支持函数/变量引用）")
        raise SyntaxError(f"意外 token {t!r}")

    def parse_table(self):
        """解析 { ... }。区分无键数组 vs 带键对象（本项目约定）。"""
        self.expect("{")
        items = []  # [(key_or_None, value)]
        while True:
            t = self.peek()
            if t is None:
                raise SyntaxError("表未闭合")
            if t[1] == "}":
                self.advance()
                break
            if t[1] == ",":
                self.advance()
                continue
            if t[1] == "[":
                self.advance()
                kt = self.advance()
                if kt[0] == "STRING":
                    key = _unescape_lua_string(kt[1][1:-1])
                elif kt[0] == "NUMBER":
                    key = str(kt[1])  # 数字键字符串化（与现有 ActStageGroup.json 一致）
                else:
                    raise SyntaxError(f"不支持的键 {kt!r}")
                self.expect("]")
                self.expect("=")
                value = self.parse_value()
                items.append((key, value))
            else:
                # 无键数组元素
                items.append((None, self.parse_value()))
        # 决策：全无键 → 数组；否则 → 对象（混合按对象处理，数组部分用 1-based 键）
        if items and all(k is None for k, _ in items):
            return [v for _, v in items]
        result = {}
        arr_idx = 1
        for k, v in items:
            if k is None:
                result[str(arr_idx)] = v
                arr_idx += 1
            else:
                result[k] = v
        return result


def _unescape_lua_string(s: str) -> str:
    """还原 Lua 字符串转义（本项目表基本只用 \" 与 \\）。"""
    return s.replace('\\"', '"').replace("\\\\", "\\")


def _find_table_span(src: str):
    """定位最外层 table 的 { 与匹配 }（跳过字符串内的 {/}），返回 (start, end) 字符索引。

    支持文件含后续代码（如 StageDungeon.lua 的静态表后接 for 循环展开），
    只截取最外层 table 段，避免 tokenize 碰到 Lua 代码符号报错。
    """
    m = re.search(r"(return\s*\{|=\s*\{)", src)
    if not m:
        return None
    start = m.end() - 1  # 指向 {
    depth = 0
    i = start
    in_str = False
    esc = False
    while i < len(src):
        c = src[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return start, i
        i += 1
    return None


def parse_file(path: str):
    """读 Lua 文件，定位最外层 table 并解析（支持文件含后续代码）。"""
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()
    span = _find_table_span(src)
    if span is None:
        raise SyntaxError(f"{path}: 未找到 table（return {{ 或 = {{）")
    start, end = span
    tokens = tokenize(src[start:end + 1])
    parser = Parser(tokens)
    return parser.parse_table()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    src_path = sys.argv[1]
    data = parse_file(src_path)
    out = json.dumps(data, ensure_ascii=False, indent=2)
    if len(sys.argv) >= 3:
        with open(sys.argv[2], "w", encoding="utf-8") as f:
            f.write(out + "\n")
        print(f"{src_path} -> {sys.argv[2]} ({len(data)} 顶层条目)")
    else:
        print(out)


if __name__ == "__main__":
    main()
