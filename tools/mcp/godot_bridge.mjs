// Godot 运行时 Bridge stdio MCP 适配器
//
// 把 ZCode 的 stdio JSON-RPC (MCP 协议) 转译为 Godot MCPBridge autoload 的 TCP NDJSON 协议。
// 让 agent 像调普通 MCP 工具一样控制运行中的 Godot 游戏（读场景树、读写属性、模拟输入、截图）。
//
// 用法（ZCode 注册后自动调用；手动测试见文末）：
//   1. 先启动游戏让 MCPBridge autoload 监听 9081：
//      GODOT_MCP_BRIDGE_PERSISTENT_SECRET=true godot --headless --path .
//      （persistent secret 让 secret 固定在 .godot/mcp_bridge_9081.secret，适配器复用免每次重读）
//   2. 本适配器作为 stdio 子进程：stdin 读 MCP JSON-RPC，stdout 写响应。
//
// 协议：
//   - stdin/stdout：标准 MCP（JSON-RPC 2.0，每行一条，stdout 仅写协议消息，日志走 stderr）
//   - TCP 9081：bridge 的 NDJSON，需先发 {method:"auth", params:{secret}} 握手
//
// 失败语义：godot 未运行 / secret 缺失 / 连接被拒 → 返回 MCP error（非崩溃），错误消息含启动指引。

import net from 'node:net';
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';

const PORT = parseInt(process.env.GODOT_BRIDGE_PORT || '9081', 10);
// 项目根：默认 cwd，可用 GODOT_PROJECT_DIR 覆盖（适配器被 ZCode 拉起时 cwd 可能不是项目根）
const PROJECT_DIR = process.env.GODOT_PROJECT_DIR || process.cwd();
const SECRET_FILE = path.join(PROJECT_DIR, '.godot', `mcp_bridge_${PORT}.secret`);
const PROTOCOL_VERSION = '2024-11-05'; // MCP 协议版本

// ─── bridge 连接管理（lazy connect + 复用 + 自动重连）──────────────────────
let bridge = null; // { socket, buffer, pending: Map<id, {resolve, reject}>, nextId, authed }

function bridgeError(code, message) {
	return { jsonrpc: '2.0', id: null, error: { code, message } };
}

async function readSecret() {
	// 不缓存：godot 非 persistent 模式每次重启换 secret，stale secret 会持续握手失败。
	try {
		return (await fs.promises.readFile(SECRET_FILE, 'utf8')).trim();
	} catch (e) {
		throw new Error(
			`读取 bridge secret 失败: ${SECRET_FILE}\n` +
			`请确认 godot 已启动且 MCPBridge autoload 在跑（项目根跑 ` +
			`GODOT_MCP_BRIDGE_PERSISTENT_SECRET=true godot --headless --path .）。`
		);
	}
}

function connect() {
	return new Promise((resolve, reject) => {
		const socket = net.connect(PORT, '127.0.0.1');
		const state = { socket, buffer: '', pending: new Map(), nextId: 1, authed: false };
		const setupTimeout = setTimeout(() => {
			socket.destroy();
			reject(new Error(`连接 bridge 127.0.0.1:${PORT} 超时（godot 未运行或端口未监听）`));
		}, 3000);

		socket.on('connect', async () => {
			clearTimeout(setupTimeout);
			try {
				const secret = await readSecret();
				// auth 握手：发 method=auth，等 {"result":{"authenticated":true}}
				const authId = state.nextId++;
				const authLine = JSON.stringify({ jsonrpc: '2.0', id: authId, method: 'auth', params: { secret } }) + '\n';
				// pending Map 的 key 统一字符串（GDScript JSON 把 id 序列化成浮点 1.0，
				// 用 String(msg.id) 查找，set 时也必须用 String(authId) 才匹配）
				state.pending.set(String(authId), { resolve: () => { state.authed = true; resolve(state); }, reject });
				socket.write(authLine);
			} catch (e) {
				socket.destroy();
				reject(e);
			}
		});

		socket.on('data', (chunk) => {
			state.buffer += chunk.toString('utf8');
			let nl;
			while ((nl = state.buffer.indexOf('\n')) !== -1) {
				const line = state.buffer.slice(0, nl);
				state.buffer = state.buffer.slice(nl + 1);
				if (!line.trim()) continue;
				let msg;
				try { msg = JSON.parse(line); } catch { continue; /* bridge 偶发非 JSON 警告行，忽略 */ }
				// auth 响应可能是浮点 id（GDScript JSON.stringify 把整数键浮点化），用字符串比
				const pendKey = msg.id !== undefined ? String(msg.id) : null;
				const waiter = pendKey !== null ? state.pending.get(pendKey) : null;
				if (waiter) {
					state.pending.delete(pendKey);
					if (msg.error) waiter.reject(new Error(msg.error.message || 'bridge error'));
					else waiter.resolve(msg.result);
				}
			}
		});

		socket.on('error', (e) => {
			clearTimeout(setupTimeout);
			reject(new Error(`连接 bridge 失败: ${e.message}（godot 未运行？项目根跑 godot --headless --path .）`));
		});
		socket.on('close', () => { bridge = null; });
	});
}

async function ensureBridge() {
	if (bridge && bridge.socket.writable) return bridge;
	bridge = await connect();
	return bridge;
}

async function callBridge(method, params = {}) {
	const state = await ensureBridge();
	return new Promise((resolve, reject) => {
		const id = state.nextId++;
		const line = JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n';
		state.pending.set(String(id), { resolve, reject });
		state.socket.write(line, (e) => { if (e) reject(new Error(`写入 bridge 失败: ${e.message}`)); });
		// 超时防永久挂起（bridge 偶尔卡）
		setTimeout(() => {
			if (state.pending.has(String(id))) {
				state.pending.delete(String(id));
				reject(new Error(`bridge 调用 ${method} 超时（10s）`));
			}
		}, 10000);
	});
}

// ─── MCP tool 定义（精选 11 个 bridge method）──────────────────────────────
const TOOLS = [
	{
		name: 'ping', description: '连通性检查，返回当前场景路径与 FPS',
		inputSchema: { type: 'object', properties: {} },
	},
	{
		name: 'get_tree', description: '读取完整场景树（debug 必备，默认深度 10）',
		inputSchema: { type: 'object', properties: { max_depth: { type: 'integer', default: 10, description: '最大递归深度' } } },
	},
	{
		name: 'find_nodes', description: '按名字/类型/组查找节点',
		inputSchema: {
			type: 'object',
			properties: {
				pattern: { type: 'string', description: '名字 glob（Godot match 语法，如 "Main*"）' },
				type: { type: 'string', description: '类型过滤（如 "Button"）' },
				group: { type: 'string', description: '组过滤' },
				limit: { type: 'integer', default: 100, description: '上限（最大 500）' },
			},
		},
	},
	{
		name: 'get_node_properties', description: '读取指定节点的属性',
		inputSchema: { type: 'object', properties: { path: { type: 'string', description: '节点路径（如 /root/Main/Btn）' } }, required: ['path'] },
	},
	{
		name: 'get_scene_stats', description: '当前场景节点统计（计数 + 类型 TopN）',
		inputSchema: { type: 'object', properties: {} },
	},
	{
		name: 'find_ui_elements', description: '查找 UI 元素（Control 子树）',
		inputSchema: {
			type: 'object',
			properties: {
				pattern: { type: 'string' }, type: { type: 'string' },
				visible_only: { type: 'boolean', default: true }, limit: { type: 'integer', default: 200 },
			},
		},
	},
	{
		name: 'call_method', description: '调用节点方法（受 bridge ALLOWED_METHODS 白名单约束，默认只读）',
		inputSchema: {
			type: 'object',
			properties: {
				path: { type: 'string', description: '节点路径' },
				method: { type: 'string', description: '方法名（如 "get"/"has_signal"）' },
				args: { type: 'array', items: {}, description: '参数（最多 8 个）' },
			},
			required: ['path', 'method'],
		},
	},
	{
		name: 'click_button', description: '按文本或路径点击按钮',
		inputSchema: {
			type: 'object',
			properties: {
				text: { type: 'string', description: '按钮文本（与 path 二选一）' },
				path: { type: 'string', description: '按钮节点路径' },
			},
		},
	},
	{
		name: 'send_key', description: '模拟按键（按下-抬起需调两次：pressed=true/false）',
		inputSchema: {
			type: 'object',
			properties: {
				key: { type: 'string', description: '键名（enter/escape/space/a/0...）' },
				pressed: { type: 'boolean', default: true },
			},
			required: ['key'],
		},
	},
	{
		name: 'send_mouse_click', description: '模拟鼠标点击（按下-抬起需调两次）',
		inputSchema: {
			type: 'object',
			properties: {
				x: { type: 'number' }, y: { type: 'number' },
				button: { type: 'integer', default: 1, description: '1=左键 2=右键' },
				pressed: { type: 'boolean', default: true },
			},
			required: ['x', 'y'],
		},
	},
	{
		name: 'take_screenshot', description: '截图保存到 user://（返回路径）',
		inputSchema: { type: 'object', properties: { path: { type: 'string', default: 'user://mcp_screenshot.png', description: '保存路径' } } },
	},
];

// ─── MCP stdio 协议处理 ──────────────────────────────────────────────────
const rl = readline.createInterface({ input: process.stdin, terminal: false });

function send(obj) {
	process.stdout.write(JSON.stringify(obj) + '\n');
}

function ok(id, result) { send({ jsonrpc: '2.0', id, result }); }
function err(id, code, message) { send({ jsonrpc: '2.0', id, error: { code, message } }); }

rl.on('line', async (line) => {
	if (!line.trim()) return;
	let req;
	try { req = JSON.parse(line); } catch { return; /* 静默丢解析失败，MCP 客户端会重试 */ }

	const { id } = req;
	try {
		if (req.method === 'initialize') {
			ok(id, {
				protocolVersion: PROTOCOL_VERSION,
				capabilities: { tools: {} },
				serverInfo: { name: 'godot-bridge', version: '0.1.0' },
			});
		} else if (req.method === 'notifications/initialized') {
			// 无响应（MCP 通知）
		} else if (req.method === 'tools/list') {
			ok(id, { tools: TOOLS });
		} else if (req.method === 'tools/call') {
			activeCalls++;
			const { name, arguments: args = {} } = req.params;
			const tool = TOOLS.find((t) => t.name === name);
			if (!tool) { err(id, -32601, `未知工具: ${name}`); activeCalls--; maybeExit(); return; }
			try {
				// tool 名即 bridge method 名（一一对应），直接转发
				const result = await callBridge(name, args);
				ok(id, { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] });
			} finally {
				activeCalls--;
				maybeExit();
			}
		} else if (req.method === 'ping') {
			// MCP 自身的 ping（与 godot bridge 的 ping 区分，这里直接回空）
			ok(id, {});
		} else {
			err(id, -32601, `未知方法: ${req.method}`);
		}
	} catch (e) {
		// bridge 不可达等错误：返回清晰 MCP error（不崩进程，下次调用自动重连）
		err(id, -32000, e.message);
	}
});

// 兜底：stdin 关闭后，等所有活跃工具调用完成再退出。
// 竞态：readline 的 line 事件触发 async handler 是异步的，stdin EOF（close）可能在
// handler 执行到 activeCalls++ 之前到达，导致 maybeExit 误判 activeCalls==0 提前退出。
// 解法：close 后先等 500ms grace 让排队 handler 启动注册 activeCalls，再开始检查；
// 之后 activeCalls 归零即退；15s 硬超时兜底防 bridge 卡死。
let activeCalls = 0;
let stdinClosed = false;
let hardExitTimer = null;
let graceTimer = null;
function maybeExit() {
	if (!stdinClosed) return;
	if (graceTimer) return; // grace 期内不退，等 handler 注册
	if (activeCalls > 0) return;
	if (hardExitTimer) { clearTimeout(hardExitTimer); hardExitTimer = null; }
	if (bridge) bridge.socket.destroy();
	process.exit(0);
}
rl.on('close', () => {
	stdinClosed = true;
	hardExitTimer = setTimeout(() => { // 硬超时兜底
		if (bridge) bridge.socket.destroy();
		process.exit(0);
	}, 15000);
	// grace：让已排队的 line handler 有机会执行 activeCalls++
	graceTimer = setTimeout(() => {
		graceTimer = null;
		maybeExit();
	}, 500);
});

// 手动测试：node godot_bridge.mjs --self-test
// 会打印 tools/list 的 11 个工具名，验证适配器协议层无依赖 godot 也能跑
if (process.argv.includes('--self-test')) {
	rl.close();
	(async () => {
		const rsp = TOOLS;
		console.error(`[self-test] ${rsp.length} tools: ${rsp.map(t => t.name).join(', ')}`);
		process.exit(0);
	})();
}

process.stderr.write(`[godot-bridge] ready (port ${PORT}, project ${PROJECT_DIR})\n`);
