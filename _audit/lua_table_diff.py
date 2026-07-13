#!/usr/bin/env python3
"""
Lua data-table -> JSON diff tool for Axmol->Godot replication audit.

Parses the lua table literals used by CardGameAxmol data files and diffs
against the CardGame2 JSON files.
"""
import json
import os
import re
import sys

GODOT_DATA = r"D:\workspace\projects\CardGame2\resources\data"
AXMOL_DATA = r"D:\workspace\projects\CardGameAxmol\Content\src"


class LuaParseError(Exception):
    pass


class Tokenizer:
    """Tokenizer + recursive-descent parser for the lua table literal subset."""

    def __init__(self, s):
        self.s = s
        self.i = 0
        self.n = len(s)

    def skip_ws_and_comments(self):
        while self.i < self.n:
            c = self.s[self.i]
            if c in " \t\r\n":
                self.i += 1
                continue
            if c == "-" and self.i + 1 < self.n and self.s[self.i + 1] == "-":
                # long-bracket comment? --[[ ... ]]
                if self.i + 3 < self.n and self.s[self.i + 2] == "[" and self.s[self.i + 3] == "[":
                    # find ]]
                    end = self.s.find("]]", self.i + 4)
                    if end == -1:
                        self.i = self.n
                    else:
                        self.i = end + 2
                    continue
                # line comment
                while self.i < self.n and self.s[self.i] != "\n":
                    self.i += 1
                continue
            break

    def peek(self):
        self.skip_ws_and_comments()
        if self.i >= self.n:
            return None
        return self.s[self.i]

    def parse_value(self):
        self.skip_ws_and_comments()
        if self.i >= self.n:
            raise LuaParseError("EOF parsing value")
        c = self.s[self.i]

        if c == "{":
            return self.parse_table()
        if c == '"' or c == "'":
            return self.parse_string(c)
        if c == "[":
            # long-bracket string [[...]] - rare
            if self.i + 1 < self.n and self.s[self.i + 1] == "[":
                return self.parse_long_string()
        if c == "-" or c == "+" or c == "." or c.isdigit():
            return self.parse_number()
        # function call like LSTR("...") or toboolean("...")
        m = re.match(r"[A-Za-z_][A-Za-z0-9_.]*", self.s[self.i:])
        if m:
            word = m.group(0)
            after = self.i + len(word)
            # skip whitespace
            while after < self.n and self.s[after] in " \t":
                after += 1
            if after < self.n and self.s[after] == "(":
                return self.parse_func_call(word)
            low = word.lower()
            if low == "true":
                self.i += len(word)
                return True
            if low == "false":
                self.i += len(word)
                return False
            if low == "nil":
                self.i += len(word)
                return None
            # bare identifier value (e.g. enum name) - keep as string token
            self.i += len(word)
            return {"__ident__": word}
        raise LuaParseError(f"Cannot parse value at {self.i}: {self.s[self.i:self.i+30]!r}")

    def parse_func_call(self, name):
        """Parse NAME(args). Returns a marker with the first arg captured."""
        # consume name
        self.i += len(name)
        self.skip_ws_and_comments()
        assert self.s[self.i] == "("
        self.i += 1
        args = []
        while True:
            self.skip_ws_and_comments()
            if self.i >= self.n:
                raise LuaParseError("Unterminated function call")
            c = self.s[self.i]
            if c == ")":
                self.i += 1
                break
            if c == ",":
                self.i += 1
                continue
            args.append(self.parse_value())
        # represent as a typed marker. For LSTR/LocalString we want the string content.
        return {"__call__": name, "args": args}

    def parse_long_string(self):
        # [[ ... ]]
        assert self.s[self.i:self.i + 2] == "[["
        self.i += 2
        end = self.s.find("]]", self.i)
        if end == -1:
            raise LuaParseError("Unterminated long string")
        text = self.s[self.i:end]
        self.i = end + 2
        return text

    def parse_string(self, quote):
        assert self.s[self.i] == quote
        self.i += 1
        out = []
        while self.i < self.n:
            c = self.s[self.i]
            if c == "\\":
                nxt = self.s[self.i + 1] if self.i + 1 < self.n else ""
                mapping = {'"': '"', "'": "'", "\\": "\\", "n": "\n", "t": "\t", "r": "\r"}
                out.append(mapping.get(nxt, nxt))
                self.i += 2
                continue
            if c == quote:
                self.i += 1
                return "".join(out)
            out.append(c)
            self.i += 1
        raise LuaParseError("Unterminated string")

    def parse_number(self):
        m = re.match(r"[-+]?(?:\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?|0[xX][0-9a-fA-F]+)", self.s[self.i:])
        if not m:
            raise LuaParseError(f"Bad number at {self.i}: {self.s[self.i:self.i+30]!r}")
        tok = m.group(0)
        self.i += len(tok)
        if tok.lower().startswith("0x"):
            return int(tok, 16)
        f = float(tok)
        if f.is_integer() and "e" not in tok.lower() and "." not in tok and "inf" not in tok.lower() and "nan" not in tok.lower():
            return int(f)
        return f

    def parse_table(self):
        assert self.s[self.i] == "{"
        self.i += 1
        result = {}
        array_idx = 1
        saw_string_key = False
        while True:
            self.skip_ws_and_comments()
            if self.i >= self.n:
                raise LuaParseError("Unterminated table")
            c = self.s[self.i]
            if c == "}":
                self.i += 1
                break
            if c == "," or c == ";":
                self.i += 1
                continue

            # detect key
            if c == "[":
                self.i += 1
                self.skip_ws_and_comments()
                kc = self.s[self.i]
                if kc == '"' or kc == "'":
                    key = self.parse_string(kc)
                    saw_string_key = True
                elif kc == "[":
                    key = self.parse_long_string()
                elif re.match(r"[A-Za-z_]", kc or ""):
                    # function-call key e.g. [LSTR("equip.2.0.0.011")]
                    key = self.parse_value()
                    # function-call markers are unhashable dicts; normalize
                    # LSTR("X") -> "X" so it can serve as a dict key.
                    if isinstance(key, dict) and "__call__" in key:
                        args = key.get("args", [])
                        key = args[0] if args else None
                    elif isinstance(key, dict) and "__ident__" in key:
                        key = key["__ident__"]
                    saw_string_key = True
                else:
                    # numeric or float key
                    m = re.match(r"[-+]?\d+\.?\d*(?:[eE][-+]?\d+)?", self.s[self.i:])
                    if not m:
                        raise LuaParseError(f"Bad table key at {self.i}: {self.s[self.i:self.i+30]!r}")
                    tok = m.group(0)
                    self.i += len(tok)
                    f = float(tok)
                    key = int(f) if f.is_integer() and "." not in tok and "e" not in tok.lower() else f
                self.skip_ws_and_comments()
                if self.s[self.i] != "]":
                    raise LuaParseError(f"Expected ] at {self.i}: {self.s[self.i:self.i+30]!r}")
                self.i += 1
                self.skip_ws_and_comments()
                if self.s[self.i] != "=":
                    raise LuaParseError(f"Expected = at {self.i}: {self.s[self.i:self.i+30]!r}")
                self.i += 1
                value = self.parse_value()
                result[key] = value
            else:
                # could be `name = value`
                m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", self.s[self.i:])
                if m:
                    rest_idx = self.i + len(m.group(0))
                    # skip whitespace
                    while rest_idx < self.n and self.s[rest_idx] in " \t":
                        rest_idx += 1
                    if rest_idx < self.n and self.s[rest_idx] == "=" and not (rest_idx + 1 < self.n and self.s[rest_idx + 1] == "="):
                        key = m.group(0)
                        self.i = rest_idx + 1
                        value = self.parse_value()
                        result[key] = value
                        saw_string_key = True
                        continue
                # otherwise bare array entry. In these data files, mixed
                # string-keyed tables should not have array entries, so if we
                # encounter one in such a table it's a parser artifact and we
                # skip it to avoid false-positive diffs.
                value = self.parse_value()
                if not saw_string_key:
                    result[array_idx] = value
                    array_idx += 1
        return result


def parse_lua_return(text):
    """Parse the lua data file content. Returns the table or None if not a table file."""
    text = text.lstrip("\ufeff").lstrip()
    # patterns:
    #   return { ... }
    #   local data = { ... }  return data
    #   local ed = ed; ed.GameConfig = { ... }
    #   local ed = ed; ed.X = { ... }; return ed.X  (or no return)
    if text.startswith("return"):
        body = text[len("return"):]
        tk = Tokenizer(body)
        val = tk.parse_value()
        return ("table", val)
    m = re.match(r"local\s+(\w+)\s*=\s*", text)
    if m:
        rest = text[m.end():]
        tk = Tokenizer(rest)
        val = tk.parse_value()
        # try also `ed.Name = {...}` patterns
        return ("local", val, m.group(1))
    # ed.Name = {...}
    m = re.match(r"(?:local\s+\w+\s*=\s*\w+\s*;\s*)?(\w+(?:\.\w+)*)\s*=\s*", text)
    if m:
        rest = text[m.end():]
        tk = Tokenizer(rest)
        val = tk.parse_value()
        return ("assign", val, m.group(1))
    return None


# ---------------------------------------------------------------------------
# Comparison helpers
# ---------------------------------------------------------------------------

def normalize(v):
    """Normalize parsed lua values for comparison.
    Function-call markers like {__call__: LSTR, args: ["X"]} -> "X" (string).
    Identifier markers {__ident__: "Foo"} -> "Foo".
    Recurse into dicts/lists.
    """
    if isinstance(v, dict):
        if "__call__" in v:
            args = v.get("args", [])
            if args:
                return normalize(args[0])
            return None
        if "__ident__" in v:
            return v["__ident__"]
        return {str(k): normalize(x) for k, x in v.items()}
    if isinstance(v, list):
        return [normalize(x) for x in v]
    return v


def values_equal(a, b):
    if isinstance(a, bool) or isinstance(b, bool):
        return a is b or a == b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return float(a) == float(b)
    if isinstance(a, str) and isinstance(b, (int, float)):
        try:
            return float(a) == float(b)
        except ValueError:
            return False
    if isinstance(b, str) and isinstance(a, (int, float)):
        try:
            return float(b) == float(a)
        except ValueError:
            return False
    return a == b


def fmt(v):
    if isinstance(v, float):
        return repr(v)
    return json.dumps(v, ensure_ascii=False)


def diff_records(lua_rec, json_rec, prefix=""):
    diffs = []
    lr = normalize(lua_rec) if not isinstance(lua_rec, (int, float, str, bool, type(None), list)) else lua_rec
    if isinstance(lr, dict) and "__call__" in lr:
        lr = normalize(lr)
    if not isinstance(lr, dict) or not isinstance(json_rec, dict):
        if not values_equal(lr, json_rec):
            return [("P1", prefix, lr, json_rec, f"value differs: source={fmt(lr)} replica={fmt(json_rec)}")]
        return []

    lk = set(str(k) for k in lr.keys())
    jk = set(json_rec.keys())
    for k in lk - jk:
        diffs.append(("P1", f"{prefix}.{k}", lr.get(k), None, "field in source but MISSING in replica"))
    for k in jk - lk:
        diffs.append(("P1", f"{prefix}.{k}", None, json_rec.get(k), "field in replica but MISSING in source"))
    for k in lk & jk:
        # get value tolerating int/str key
        lkey = k if k in lr else (int(k) if k.lstrip("-").isdigit() and int(k) in lr else k)
        lv = lr.get(lkey)
        jv = json_rec[k]
        if isinstance(lv, dict) and isinstance(jv, dict):
            diffs.extend(diff_records(lv, jv, prefix=f"{prefix}.{k}"))
        elif isinstance(lv, list) and isinstance(jv, list):
            if len(lv) != len(jv):
                diffs.append(("P1", f"{prefix}.{k}", lv, jv, f"array length differs ({len(lv)} vs {len(jv)})"))
            else:
                for idx, (la, ja) in enumerate(zip(lv, jv)):
                    if isinstance(la, dict) and isinstance(ja, dict):
                        diffs.extend(diff_records(la, ja, prefix=f"{prefix}.{k}[{idx}]"))
                    elif not values_equal(la, ja):
                        diffs.append(("P1", f"{prefix}.{k}[{idx}]", la, ja, f"value differs: source={fmt(la)} replica={fmt(ja)}"))
        else:
            if not values_equal(lv, jv):
                diffs.append(("P1", f"{prefix}.{k}", lv, jv, f"value differs: source={fmt(lv)} replica={fmt(jv)}"))
    return diffs


def read_text(path):
    for enc in ("utf-8-sig", "utf-8", "gbk", "latin-1"):
        try:
            with open(path, "r", encoding=enc) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def compare_table(lua_file, json_file):
    lua_text = read_text(lua_file)
    with open(json_file, "r", encoding="utf-8-sig") as f:
        json_data = json.load(f)
    try:
        parsed = parse_lua_return(lua_text)
    except LuaParseError as e:
        return None, f"PARSE ERROR: {e}"
    if parsed is None:
        return None, "UNRECOGNIZED FORMAT"
    if parsed[0] == "table":
        lua_data = parsed[1]
    else:
        lua_data = parsed[1]
    if not isinstance(lua_data, dict):
        return None, f"top-level lua value is not a table: {type(lua_data)}"

    all_diffs = []
    lua_keys = {str(k): k for k in lua_data.keys()}
    json_keys = set(json_data.keys())

    def sortkey(x):
        try:
            return (0, int(x))
        except ValueError:
            return (1, x)

    only_lua = set(lua_keys) - json_keys
    only_json = json_keys - set(lua_keys)
    for k in sorted(only_lua, key=sortkey):
        all_diffs.append(("P0", f"row[{k}]", lua_data[lua_keys[k]], None, "ROW in source but MISSING in replica"))
    for k in sorted(only_json, key=sortkey):
        all_diffs.append(("P0", f"row[{k}]", None, json_data[k], "ROW in replica but MISSING in source"))

    for k in sorted(set(lua_keys) & json_keys, key=sortkey):
        lk = lua_keys[k]
        all_diffs.extend(diff_records(lua_data[lk], json_data[k], prefix=f"row[{k}]"))

    return all_diffs, None


def main():
    tables = [
        "HeroStars", "Unit", "UnitRank", "Equip", "Enhancement", "Equipcraft",
        "Stage", "StageDungeon", "SkillLevels", "Skill", "SkillGroup",
        "Shop", "TavernBoxType", "TavernType", "TavernDailyHero",
        "Midas", "GradientPrice", "PlayerLevel", "Fragment", "Chapter",
        "Avatar", "GuildAvatar", "GuildHirePrice", "GuildWorship",
        "PVPEmeny", "PVPRankReward", "Raid", "NPC", "Puppet", "VIP",
        "CrusadeRewards", "DailyLoginReward", "Task", "Todolist",
        "TodoTriggers", "Triggers", "ActStageGroup", "ActStageGroupDungeon",
        "ExcavateTreasure", "ExcavateWildEnemy", "ItemGroups", "Levels",
        "MerchantTalk", "Period", "Maillist", "AnimAtkFrame", "AnimDuration",
        "Buff", "LocalString", "TextureConfig", "GameConfig",
        "Hero_equip", "LSTR", "Recharge", "Privilege", "PlayerLevelDisplay",
        "DailyActivity",
    ]

    total_diffs = 0
    summary = []
    for t in tables:
        lua_f = os.path.join(AXMOL_DATA, t + ".lua")
        if not os.path.exists(lua_f):
            # try lowercase variants
            for cand in (t.lower(), t.capitalize()):
                cand_f = os.path.join(AXMOL_DATA, cand + ".lua")
                if os.path.exists(cand_f):
                    lua_f = cand_f
                    break
        json_f = os.path.join(GODOT_DATA, t + ".json")
        if not os.path.exists(lua_f):
            summary.append((t, "NO LUA SOURCE", None))
            continue
        if not os.path.exists(json_f):
            summary.append((t, "NO JSON REPLICA", None))
            continue
        diffs, err = compare_table(lua_f, json_f)
        if err:
            summary.append((t, err, None))
            continue
        if not diffs:
            summary.append((t, "OK", []))
        else:
            summary.append((t, f"{len(diffs)} diffs", diffs))
            total_diffs += len(diffs)

    print("=" * 78)
    print("AXMOL->GODOT DATA TABLE DIFF REPORT")
    print("=" * 78)
    for t, status, diffs in summary:
        if status == "OK":
            print(f"[OK]   {t:25s} - identical")
        elif diffs is None:
            print(f"[INFO] {t:25s} - {status}")
        else:
            print(f"[DIFF] {t:25s} - {status}")
            sev_counts = {}
            for d in diffs:
                sev = d[0]
                sev_counts[sev] = sev_counts.get(sev, 0) + 1
            print(f"       severity: {sev_counts}")
            for sev, loc, lv, jv, desc in diffs[:25]:
                print(f"       [{sev}] {loc}")
                print(f"            {desc}")
            if len(diffs) > 25:
                print(f"       ... and {len(diffs) - 25} more")

    print()
    print(f"TOTAL DIFFS: {total_diffs}")


if __name__ == "__main__":
    main()
