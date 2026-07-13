#!/usr/bin/env python3
"""Godot MCP HTTP 客户端封装（HTTP/JSON-RPC over streamable-http）。

用法：
    python tools/mcp_call.py <method> [params_json]
例：
    python tools/mcp_call.py tools/list
    python tools/mcp_call.py tools/call '{"name":"take_screenshot","arguments":{}}'
"""
import json
import sys
import urllib.request

ENDPOINT = "http://127.0.0.1:3000/mcp"
_id = [0]


def call(method: str, params: dict | None = None, timeout: float = 30.0):
    _id[0] += 1
    payload: dict = {"jsonrpc": "2.0", "id": _id[0], "method": method}
    if params is not None:
        payload["params"] = params
    req = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read().decode("utf-8", errors="replace")
    # streamable-http 可能回 text/event-stream，data: {...}；也可能直接 JSON
    if body.lstrip().startswith("data:"):
        for line in body.splitlines():
            line = line.strip()
            if line.startswith("data:"):
                return json.loads(line[5:].strip())
    return json.loads(body)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    method = sys.argv[1]
    params = json.loads(sys.argv[2]) if len(sys.argv) > 2 else None
    result = call(method, params)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
