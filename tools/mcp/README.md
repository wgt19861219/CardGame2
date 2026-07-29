# Godot Bridge MCP 适配器

把 Godot 项目的运行时 bridge（`mcp_bridge.gd`，TCP 9081）桥接为 ZCode 可调用的 stdio MCP server。
让 agent 像调普通 MCP 工具一样控制**运行中的 Godot 游戏**（读场景树、读写属性、模拟输入、截图）。

> 仅 Phase A（运行时 bridge）。编辑器插件（WebSocket 9090~9094）的适配器未实现，需单独立项。

## 工作原理

```
ZCode agent
   │ stdio (MCP JSON-RPC)
   ▼
tools/mcp/godot_bridge.mjs   ← 本适配器
   │ TCP 9081 + NDJSON（先 auth 握手）
   ▼
mcp_bridge.gd autoload（游戏进程内）
   │
   ▼
运行中的 Godot 游戏场景树
```

适配器 lazy connect：首次工具调用时读 `.godot/mcp_bridge_9081.secret` + 建 TCP 连接 + 发 auth 握手，之后复用连接。bridge 不可达时返回清晰 MCP error（非崩溃），下次调用自动重连。

## 使用

### 1. 启动 Godot（让 bridge 监听 9081）

```bash
# 项目根，后台跑（持久化 secret，避免每次重启换 key）
GODOT_MCP_BRIDGE_PERSISTENT_SECRET=true godot --headless --path . &
```

- `GODOT_MCP_BRIDGE_PERSISTENT_SECRET=true` 让 secret 固定在 `.godot/mcp_bridge_9081.secret`，适配器复用免每次重读。
- 不加该 env 时 bridge 每次启动随机换 secret，适配器靠"连接失败重读"自动适配（不影响功能）。
- 看到日志 `[MCP Bridge] Listening on 127.0.0.1:9081` 即就绪。

### 2. ZCode 注册（项目级配置）

项目根 `.agents/mcp.json`（已随本工具创建，**含本机绝对路径故不入库**，`.gitignore` 已排除）：

```json
{
  "mcpServers": {
    "godot_bridge": {
      "command": "node",
      "args": ["/workspace/worktrees/CardGame2/tools/mcp/godot_bridge.mjs"],
      "env": [
        { "name": "GODOT_BRIDGE_PORT", "value": "9081" },
        { "name": "GODOT_PROJECT_DIR", "value": "/workspace/worktrees/CardGame2" }
      ],
      "timeoutMs": 30000
    }
  }
}
```

> ZCode 配置字段约束：`env` 是 `[{name,value}]` **数组**（不是对象），无 `cwd` 字段（用 `GODOT_PROJECT_DIR` env 指项目根）。`.strict()` 校验，多余字段报错。

### 3. 重启 ZCode 会话生效

ZCode **不监听配置文件变更**，改 `.agents/mcp.json` 后必须**重连工作区或开新会话**才加载。生效后工具列表出现 `mcp__godot_bridge__*` 系列（11 个工具）。

## 暴露的 11 个工具

| 工具 | bridge method | 用途 |
|------|--------------|------|
| `ping` | ping | 连通性 + 当前场景路径 + FPS |
| `get_tree` | get_tree | 完整场景树（debug 必备） |
| `find_nodes` | find_nodes | 按名字/类型/组找节点 |
| `get_node_properties` | get_node_properties | 读节点属性 |
| `get_scene_stats` | get_scene_stats | 场景节点统计（计数 + 类型 TopN） |
| `find_ui_elements` | find_ui_elements | 查找 UI 元素（Control 子树） |
| `call_method` | call_method | 调用节点方法（受 bridge `ALLOWED_METHODS` 白名单约束，默认只读） |
| `click_button` | click_button | 按文本/路径点按钮 |
| `send_key` | send_key | 模拟按键（按下-抬起需调两次） |
| `send_mouse_click` | send_mouse_click | 模拟鼠标点击（按下-抬起需调两次） |
| `take_screenshot` | take_screenshot | 截图到 `user://` |

未暴露的 bridge method（高级功能，按需扩展）：`set_node_property`、`send_mouse_move`、`send_touch`、`send_drag`、`send_text`、`wait_for_node`、`wait_for_property`、`get_performance`、`get_viewport_info`、`recording.*`、`monitor.*`、`watch.*`。每个新增工具只需在 `TOOLS` 数组加一条映射 + 一行 inputSchema。

## 验证（已实测，2026-07-26）

### Layer 1：适配器协议层（不依赖 godot）

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  | node tools/mcp/godot_bridge.mjs
```
返回 serverInfo + 11 个工具清单。

### Layer 2：端到端（经适配器 → bridge → 游戏）

起 godot 后：

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"ping","arguments":{}}}' \
  | node tools/mcp/godot_bridge.mjs
```

实测结果（2026-07-26）：
- `ping` → `pong:true scene:res://scenes/main_menu/main_scene.tscn fps:145`
- `get_scene_stats` → `场景 main_scene.tscn 节点数 354 root MainScene`
- godot 未运行时 → `错误码 -32000 "连接 bridge 失败: connect ECONNREFUSED 127.0.0.1:9081（godot 未运行？...）"`（清晰错误，非崩溃）

## 环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `GODOT_BRIDGE_PORT` | `9081` | bridge TCP 端口 |
| `GODOT_PROJECT_DIR` | `process.cwd()` | 项目根（定位 `.godot/mcp_bridge_<port>.secret`） |

## 已知限制

- **需 godot 在跑**：bridge 是游戏进程内的 autoload，没游戏就没 server。适配器返回清晰错误而非空等。
- **单连接**：适配器维护单条 TCP 连接复用，并发工具调用走同一 socket（bridge 支持 5 peer，单连接够用）。
- **call_method 白名单**：bridge 的 `call_method` 受 `ALLOWED_METHODS` 约束（默认只读：get/has_*/get_meta 等），需写操作要游戏侧设 `GODOT_MCP_BRIDGE_EXTRA_METHODS` env。这是 bridge 的安全设计，非适配器限制。
- **截图路径**：bridge 截图存 `user://`，headless 下是 Godot user data 目录（非项目根），需按需 globalize。
