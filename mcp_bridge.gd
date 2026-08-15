@tool
extends Node

## MCP Bridge Autoload — TCP + NDJSON protocol
## Install as autoload in project.godot to enable runtime game control via MCP.
## Default port: 9081

const PORT := 9081
const MAX_AUTH_FAILS := 5
const LOCKOUT_BASE_SECONDS := 30.0
const LOCKOUT_MAX_SECONDS := 300.0
const MAX_MESSAGE_SIZE := 1048576  # 1MB
const MAX_PEERS := 5
const PROTOCOL_VERSION := "1.0"
const INACTIVITY_TIMEOUT := 60.0

# ─── Instance Registry (Phase 2b) ─────────────────────────────────────────
const REGISTRY_HEARTBEAT_INTERVAL := 30.0
var _registry_heartbeat_timer: Timer = null
var _registry_file: String = ""
var _instance_id: String = ""

var _server: TCPServer = null
var _peers: Array[StreamPeerTCP] = []
var _peer_buffers: Dictionary = {}
var _authenticated_peers: Dictionary = {}
var _auth_fail_count: Dictionary = {}
var _auth_locked_until: Dictionary = {}
var _secret: String = ""
var _secret_file: String = ""
var _crypto: Crypto = null
var _peer_last_activity: Dictionary = {}

var _recording: bool = false
var _recorded_events: Array = []
var _record_start_time: int = 0

# ─── Per-peer Monitor/Watch states (C-07) ──────────────────────────────────
const MONITOR_MAX_PROPERTIES := 20
const MONITOR_DEFAULT_MAX_SAMPLES := 500
var _monitor_states: Dictionary = {}

const WATCH_DEFAULT_MAX_EVENTS := 1000
var _watch_states: Dictionary = {}

# P3-6 push 模式:watch/monitor 事件产生时主动推送(无需 poll)
# push_enabled 的 peer,事件/样本产生时立即 put_data 推送 notification 消息
# 消息格式:{"jsonrpc":"2.0","method":"bridge/event","params":{"type":"watch|monitor",...}}
# TS 侧常驻 data handler 接收后转发为 MCP notification
var _push_peers: Dictionary = {}  # pid -> true(peer 启用了 push 模式)

# P2-4 确定性 playtest 状态:seed/fixed_delta 锁定 + snapshot 存储 + step pending 队列
# seed 注入全局 RNG(仅覆盖 randi/randf,per-instance RandomNumberGenerator 不受影响)
# fixed_delta 设 physics_ticks_per_second + max_physics_steps_per_frame=1 + jitter_fix=0 三连(不碰 time_scale)
# snapshot 用 _cmd_get_node_properties 序列化器复用(BLOCKED_PROPERTIES 跳过 script/owner 等危险属性)
var _playtest_active: bool = false
var _playtest_snapshot: Dictionary = {}  # {path: {properties: {}, parent: String}}
var _playtest_fixed_delta_saved: Dictionary = {}  # 原值,restore 时还原
var _playtest_step_pending: Array = []  # [{peer: StreamPeerTCP, pid: int, id: Variant, frames: int, coroutine: Callable, result: Dictionary}]
# 2026-08-07 审查 P2 修复：playtest 是独占模式（snapshot/fixed_delta_saved 是全局单例非 per-peer）。
# owner_pid 记录当前持有者，_cleanup_peer_state 只在持有者断开时才还原全局状态，
# 防多 peer 场景下 peer B 断开误清 peer A 的 physics 锁/snapshot。
var _playtest_owner_pid: int = -1
var _last_step_request_id: Variant = null  # step 请求的 id,供 _process_buffer_bytes 取用
# G1 (2026-08-13) control-first satellite 层(附录 F.1):freeze/unfreeze/step_until
# owner_pid 独占(仿 _playtest_owner_pid,防多 peer 误清);step_until 走延迟通道(同 __PLAYTEST_STEP__)
var _control_frozen: bool = false
var _control_owner_pid: int = -1
var _control_step_until_pending: Array = []  # [{peer_id,pid,id,frames_remaining,wall_deadline_ms,conditions,_added_this_frame}]
# 2026-08-14 审查 D-2 修复:freeze/开窗介入前保存游戏自身 paused 原值(游戏代码可能自己
# paused=true,如暂停菜单/回合制),control 层退出(unfreeze/step_until 完成/owner 断线)
# 时还原原值而非硬设 false。saved_valid 防重复 freeze 把维持中的 true 覆盖真实原值
# (不变式:frozen=true -> saved_valid=true)。
var _control_paused_saved: bool = false
var _control_paused_saved_valid: bool = false
var _pending_control_step_until_result: Dictionary = {}  # 临时:_handle_message 存,_process_buffer_bytes 取
# CMP-2 (2026-08-08): runtime error 捕获——game bridge 通道的 OS.add_logger ring buffer。
# 让 AI 能看到游戏运行时 push_error / 脚本 setter 报错,闭环调试(不再只靠 take_screenshot 间接推断)。
var _error_capture: _ErrorCapture = null


const BLOCKED_PROPERTIES := [
	"script", "owner", "process_mode", "process_priority", "process_input",
	"process_unhandled_input", "process_unhandled_key_input", "process_internal",
	"physics_process_mode", "physics_interpolation_mode", "name", "meta",
	"input_event", "ready", "tree_entered", "tree_exited", "tree_exiting",
	"instance",  # I-2 (P2-4 审查 B-1 修复): instance 可注入 ExtResource 实例化恶意场景 _ready,与 script 同级危险。对齐 godot_operations.gd:735 / command_helpers.gd:179。
]

# I-06: get_property_list removed from remote-allowed methods to prevent property enumeration.
# It is still used internally by _get_all_properties() but not exposed to remote callers.
const ALLOWED_METHODS := [
	"get", "get_class", "get_path", "get_children", "get_child", "get_child_count",
	"get_parent", "has_method", "is_class", "get_instance_id",
	"get_meta", "has_meta", "has_signal", "get_signal_list", "get_signal_connection_list",
	"get_incoming_connections", "get_index", "get_groups", "is_in_group",
	"is_inside_tree", "is_part_of_edited_scene", "get_owner",
]

# P1-6 (2026-07-06 RCE 审查): EXTRA_METHODS 危险方法黑名单 — 即使 env GODOT_MCP_BRIDGE_EXTRA_METHODS
# 显式列出也拒绝。这些方法可改变运行时结构/执行任意代码,与 call_method 白名单"只读安全"设计冲突:
# set_script 加载任意脚本(=RCE)、queue_free/free 销毁节点、add_child/remove_child 改树结构、
# call/callv 间接调用任意方法(绕白名单)、emit_signal 触发已连接回调、connect/disconnect 改信号拓扑。
const EXTRA_METHODS_BLOCKLIST := [
	"set_script", "set", "set_indexed", "set_owner", "queue_free", "free", "add_child", "remove_child",  # P2-2 (2026-08-11): set/set_indexed 对称(防 opt-in EXTRA_METHODS 后 node.set("script",...) 绕 set_script)
	"call", "callv", "emit_signal", "connect", "disconnect",
	# A5 (2026-08-11 审查): 间接调用入口与销毁对称——call_deferred/call_thread_safe 可在 args
	# 里带被禁方法名(call_method(method="call_deferred", args=["set_script", ...])绕 BLOCKLIST,
	# 它只查顶层 method 名看不见内层);queue_delete 对称 queue_free。
	# B-2 (2026-08-14): 原写的无下划线拼写(callthreadsafe 连写)是拼写错误——Godot 4 真实
	# 方法名 call_thread_safe(data/godot-classes.json 实证:定义于 Node),错误拼写永不命中。
	# 补 propagate_call(子树递归调用入口)。拼写契约由
	# test/denylist-godot-classes-contract.test.ts 守护。
	"call_deferred", "call_thread_safe", "propagate_call", "queue_delete",
]

# ─── Lifecycle ─────────────────────────────────────────────────────────────

func _ready() -> void:
	# Godot 4.6+: extends 原生类(Node)的虚函数不可调 super()(4.6.2 Parse error "hasn't been defined"),移除 IMP-4 super()。该 convention 仅适用于 extends 自定义基类。
	if Engine.is_editor_hint():
		return
	# CMP-2 (2026-08-08): 注册 runtime error 捕获(在 _start_server 前,确保任何启动错误也被捕)。
	_error_capture = _ErrorCapture.new()
	OS.add_logger(_error_capture)
	# G1 (2026-08-13): PROCESS_MODE_ALWAYS — freeze 设 tree.paused=true 后 bridge _process 必须继续,
	# 否则 TCP 死锁(附录 F.1 BLOCKING)。注意 BLOCKED_PROPERTIES 禁远程 set process_mode,本地 _ready 设不冲突。
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless 也启动 Bridge: run_project 跑 headless 游戏需 Bridge 通信(DisplayServer=headless)。
	# --headless --script 场景若端口被占, _start_server 的 listen() 失败会安全跳过(warning+return)。
	_start_server()


func _exit_tree() -> void:
	# 同 _ready():extends 原生类 Node 的 _exit_tree() 虚函数不可 super()(Godot 4.6+ Parse error)。
	_stop_server()
	# CMP-2: 注销 error 捕获(Logger 是 RefCounted,remove_logger 让引擎 logger 链释放引用,
	# 避免 Node 销毁后 logger 回调访问已失效上下文)。
	if _error_capture:
		OS.remove_logger(_error_capture)
		_error_capture = null


func _process(_delta: float) -> void:
	if _server == null:
		return

	# Accept new connections (Godot 4.6 renamed accept() to take_connection())
	var peer: StreamPeerTCP = _server_take_connection()
	if peer != null:
		if _peers.size() >= MAX_PEERS:
			push_warning("[MCP Bridge] Max peers (%d) reached, rejecting connection" % MAX_PEERS)
			peer.disconnect_from_host()
		else:
			_peers.append(peer)
			_peer_last_activity[peer.get_instance_id()] = Time.get_ticks_msec() / 1000.0
			_peer_buffers["buf_" + str(peer.get_instance_id())] = PackedByteArray()

	# Process each peer
	var to_remove: Array[int] = []
	for i in range(_peers.size()):
		var p: StreamPeerTCP = _peers[i]
		p.poll()
		if p.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			to_remove.append(i)
			continue
		# Idle timeout check
		var pid_act := p.get_instance_id()
		if _peer_last_activity.has(pid_act):
			var elapsed: float = Time.get_ticks_msec() / 1000.0 - float(_peer_last_activity[pid_act])
			if elapsed > INACTIVITY_TIMEOUT:
				push_warning("[MCP Bridge] Peer %d idle for %.0fs, disconnecting" % [pid_act, elapsed])
				p.disconnect_from_host()
				to_remove.append(i)
				continue
		if p.get_available_bytes() > 0:
			_peer_last_activity[pid_act] = Time.get_ticks_msec() / 1000.0
			var byte_count := p.get_available_bytes()
			var result := p.get_data(byte_count)
			if result[0] == OK:
				var raw_data: PackedByteArray = result[1]
				if raw_data.size() > 0:
					var pid := p.get_instance_id()
					var key := "buf_" + str(pid)
					var existing: PackedByteArray = _peer_buffers.get(key, PackedByteArray()) as PackedByteArray
					var combined: PackedByteArray = existing + raw_data
					if combined.size() > MAX_MESSAGE_SIZE:
						push_warning("[MCP Bridge] Peer %d buffer exceeded %d bytes, disconnecting" % [pid, MAX_MESSAGE_SIZE])
						p.disconnect_from_host()
						to_remove.append(i)
						continue
					_peer_buffers[key] = combined
					if _process_buffer_bytes(p, pid):
						to_remove.append(i)

	# Remove disconnected peers (reverse order to preserve indices)
	for idx in range(to_remove.size() - 1, -1, -1):
		var i: int = to_remove[idx]
		var pid := _peers[i].get_instance_id()
		_peer_buffers.erase("buf_" + str(pid))
		_authenticated_peers.erase(pid)
		_peer_last_activity.erase(pid)
		# C-07: cleanup per-peer monitor/watch state on disconnect
		_cleanup_peer_state(pid)
		# I-9: 清除断开 peer 的 per-peer 锁定/失败记录。per-peer 隔离是有意设计(非全局)——
		# 全局计数会让单个失败源锁死所有合法客户端(DoS), 详见 _process_buffer_bytes 处 I-9 论证。
		# 断开即清零是 per-peer 的预期行为(peer id 每连接不同), LOCKOUT 仅减速带, 非主防线。
		_auth_fail_count.erase(pid)
		_auth_locked_until.erase(pid)
		_peers.remove_at(i)

	# ─── P2-4 playtest.step pending:每帧递减 frames_remaining,到 0 时 push 响应 ──
	# step 语义:推进 N 帧后返回。_process 每帧调一次,递减计数即"推进"。
	# I-2 修复(P2-4 审查):刚加入的 entry(_added_this_frame=true)本帧不递减,
	# 否则 frames=1 在同一 _process tick 立即完成,physics_frame 未推进 → 拿到 pre-step 状态。
	# 下一帧 _added_this_frame 清 false 后才开始递减计数。
	if _playtest_step_pending.size() > 0:
		var completed: Array = []
		for idx in range(_playtest_step_pending.size()):
			var entry: Dictionary = _playtest_step_pending[idx]
			if bool(entry.get("_added_this_frame", false)):
				entry["_added_this_frame"] = false  # 下一帧开始递减
				continue
			entry["frames_remaining"] = int(entry["frames_remaining"]) - 1
			if int(entry["frames_remaining"]) <= 0:
				completed.append(idx)
		# 倒序处理完成的(避免索引漂移)
		completed.reverse()
		for idx in completed:
			var entry: Dictionary = _playtest_step_pending[idx]
			_playtest_step_pending.remove_at(idx)
			var peer_id: int = int(entry["peer_id"])
			# 找到对应 peer(peer 可能已断开)
			var target_peer: StreamPeerTCP = null
			for p in _peers:
				if p.get_instance_id() == peer_id:
					target_peer = p
					break
			if target_peer == null:
				continue  # peer 已断开,丢响应
			var step_result := JSON.stringify({
				"id": entry["id"],
				"result": {
					"success": true,
					"frames_stepped": true,
					"frame_count": Engine.get_process_frames(),
					"nodes": get_tree().root.get_child_count(),
				}
			})
			target_peer.put_data((step_result + "\n").to_utf8_buffer())

	# ─── G1 (2026-08-13) control-first: freeze 维持 + step_until 轮询 ──
	# freeze 维持:每帧重设 paused(防游戏代码 WHEN_PAUSED 解 pause)。step_until 时 _control_frozen=false
	# (临时解开,让游戏跑),此块自然跳过;step_until 完成 refreeze 后恢复 _control_frozen=true。
	if _control_frozen:
		get_tree().paused = true
	# step_until 轮询:每帧递减 frames_remaining + 求值 conditions[](AND 全满足即停)
	if _control_step_until_pending.size() > 0:
		var su_completed: Array = []
		var now_ms := Time.get_ticks_msec()
		for su_idx in range(_control_step_until_pending.size()):
			var su_entry: Dictionary = _control_step_until_pending[su_idx]
			if bool(su_entry.get("_added_this_frame", false)):
				su_entry["_added_this_frame"] = false
				continue
			su_entry["frames_remaining"] = int(su_entry["frames_remaining"]) - 1
			var cond_error := ""
			var all_met := true
			var conds: Array = su_entry["conditions"]
			for cond in conds:
				var cdict: Dictionary = cond
				var node_path := str(cdict["path"])
				var n := get_node_or_null(node_path)
				if n == null or not is_instance_valid(n):
					cond_error = "node not found/freed: %s" % node_path
					all_met = false
					break
				var prop := str(cdict["property"])
				if not (prop in n):
					cond_error = "property not found: %s.%s" % [node_path, prop]
					all_met = false
					break
				var nget: Variant = n.get(prop)
				if not _compare_values(nget, str(cdict["op"]), cdict["value"]):
					all_met = false
			if cond_error != "" or all_met or int(su_entry["frames_remaining"]) <= 0 or now_ms > int(su_entry["wall_deadline_ms"]):
				if cond_error != "":
					su_entry["_error"] = cond_error
				su_entry["_met"] = all_met and cond_error == ""
				su_completed.append(su_idx)
		su_completed.reverse()
		for su_idx in su_completed:
			var su_entry: Dictionary = _control_step_until_pending[su_idx]
			_control_step_until_pending.remove_at(su_idx)
			# refreeze:若 step_until 前 frozen,完成时恢复 freeze
			if bool(su_entry.get("refreeze", false)):
				_control_frozen = true
				get_tree().paused = true  # freeze 维持(游戏原值仍由 _control_paused_saved 持有,unfreeze 时还原)
			elif _control_step_until_pending.is_empty() and not _control_frozen:
				# 2026-08-14 审查 D-2 修复:最后一个开窗 entry 完成且无冻结,游戏回归自身
				# paused 原值(而非硬设 false)。pending 非空/冻结中不还原(后续 entry 仍需
				# 开窗推进,或由 freeze 维持、unfreeze/断线还原点统一处理)。
				get_tree().paused = _control_paused_saved
				_control_paused_saved = false
				_control_paused_saved_valid = false
			var peer_id: int = int(su_entry["peer_id"])
			var target_peer: StreamPeerTCP = null
			for p in _peers:
				if p.get_instance_id() == peer_id:
					target_peer = p
					break
			if target_peer == null:
				continue
			var su_result := JSON.stringify({
				"id": su_entry["id"],
				"result": {
					"success": true,
					"predicate_met": bool(su_entry.get("_met", false)),
					"frames_elapsed": int(su_entry["max_frames"]) - int(su_entry["frames_remaining"]),
					"wall_exceeded": now_ms > int(su_entry["wall_deadline_ms"]),
					"error": str(su_entry.get("_error", "")),
				}
			})
			target_peer.put_data((su_result + "\n").to_utf8_buffer())

	# ─── Property monitor sampling (C-07: per-peer) ─────────────────────────
	var dead_monitors: Array = []
	for peer_id in _monitor_states:
		var ms: Dictionary = _monitor_states[peer_id]
		if not ms.get("active", false):
			continue
		ms["frame_counter"] = int(ms["frame_counter"]) + 1
		if int(ms["frame_counter"]) < int(ms["interval_frames"]):
			continue
		ms["frame_counter"] = 0
		var node := get_node_or_null(str(ms["node_path"]))
		if node == null:
			ms["active"] = false
			(ms["samples"] as Array).append({"frame": Engine.get_process_frames(), "time": Time.get_ticks_msec() / 1000.0, "error": "node_lost", "stopped_reason": "node_lost"})
		else:
			var values: Dictionary = {}
			for prop in (ms["properties"] as Array):
				values[prop] = _jsonify(node.get(prop))
			var sample_dict := {
				"frame": Engine.get_process_frames(),
				"time": Time.get_ticks_msec() / 1000.0,
				"values": values
			}
			(ms["samples"] as Array).append(sample_dict)
			# P3-6: push 模式下立即推送采样(不等 poll)
			_push_event_to_peer(peer_id, "monitor", {
				"node_path": str(ms["node_path"]),
				"sample": sample_dict
			})
			if (ms["samples"] as Array).size() >= int(ms["max_samples"]):
				(ms["samples"] as Array)[-1]["stopped_reason"] = "max_samples_reached"
				ms["active"] = false
		if not ms.get("active", false):
			dead_monitors.append(peer_id)
	for pid_key in dead_monitors:
		_monitor_states.erase(pid_key)


# ─── Server management ─────────────────────────────────────────────────────

func _start_server() -> void:
	_crypto = Crypto.new()
	_secret = _generate_secret()
	if _secret.length() < 32:
		push_error("[MCP Bridge][SECURITY] Secret generation failed — Bridge server not started")
		_secret = ""
		return
	_server = TCPServer.new()
	var err := _server.listen(PORT, "127.0.0.1")
	if err != OK:
		push_warning("[MCP Bridge] Failed to listen on port %d: %d" % [PORT, err])
		_server = null
		return
	print("[MCP Bridge] Listening on 127.0.0.1:%d" % PORT)
	# C-01: Secret file MUST be in project .godot/ — never fall back to tmpdir.
	# Writing to tmpdir (globally readable on Linux) allows local privilege escalation.
	var proj_dir := _get_project_dir()
	if proj_dir == "":
		push_error("[MCP Bridge][SECURITY] Cannot determine project directory — aborting Bridge startup")
		_server.stop()
		_server = null
		return
	var godot_dir := proj_dir + "/.godot"
	if not DirAccess.dir_exists_absolute(godot_dir):
		DirAccess.make_dir_recursive_absolute(godot_dir)
	_secret_file = godot_dir + "/mcp_bridge_%d.secret" % PORT
	# S4 (2026-06-23): 固定 secret 模式(本地测试,env GODOT_MCP_BRIDGE_PERSISTENT_SECRET=true)。
	# secret 文件存在且有效则复用,跳过重生+写入,打破"重生→_restrict 收紧只读→下次写失败
	# abort→_exit_tree 删除→MCP 端 5min TTL 缓存不同步"的死循环。默认 false 保持每次重生(安全)。
	var _persistent_secret := OS.get_environment("GODOT_MCP_BRIDGE_PERSISTENT_SECRET").to_lower() == "true"
	var _secret_reused := false
	if _persistent_secret and FileAccess.file_exists(_secret_file):
		var _existing := FileAccess.get_file_as_string(_secret_file)
		if _existing.length() >= 32:
			_secret = _existing
			_secret_reused = true
			print("[MCP Bridge] Reusing persistent secret (GODOT_MCP_BRIDGE_PERSISTENT_SECRET=true)")
	if not _secret_reused and not _write_secret_to_file(_secret_file):
		push_error("[MCP Bridge][SECURITY] Failed to write secret to %s — aborting Bridge startup. Check directory permissions." % _secret_file)
		_server.stop()
		_server = null
		return
	# Instance registry heartbeat (Phase 2b)
	_start_registry_heartbeat()

## Compat: Godot 4.6 renamed TCPServer.accept() to take_connection()
func _server_take_connection() -> StreamPeerTCP:
	if _server.has_method("take_connection"):
		return _server.take_connection()
	return _server.accept()


# DUPLICATE: Keep in sync with addons/godot_mcp_server/websocket_server.gd:_constant_time_compare
# Cannot share because editor plugin and game autoload have separate script contexts.
# C-05: Fixed-length comparison (always 32 bytes) to prevent timing side-channel.
func _constant_time_compare(a: String, b: String) -> bool:
	# IMPORTANT: SECRET_LEN must match the token length generated by the MCP server's
	# secret generation logic. If token generation changes, update this constant.
	const SECRET_LEN := 32
	# Reject early if lengths differ — avoids leaking length info through
	# branch-prediction timing inside the loop.
	if a.length() != SECRET_LEN or b.length() != SECRET_LEN:
		return false
	var result := 0
	for i in range(SECRET_LEN):
		result = result | (ord(a[i]) ^ ord(b[i]))
	return result == 0

# DUPLICATE: Keep in sync with addons/godot_mcp_server/websocket_server.gd:_generate_secret
# Cannot share because editor plugin and game autoload have separate script contexts.
func _generate_secret() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result := ""
	var rng_bytes: PackedByteArray = _crypto.generate_random_bytes(64)
	var idx := 0
	while result.length() < 32 and idx < rng_bytes.size():
		var b: int = rng_bytes[idx]
		idx += 1
		# Rejection sampling: skip bytes causing modulo bias (256 % 62 = 8, skip >= 248)
		if b >= 256 - (256 % chars.length()):
			continue
		result += chars[b % chars.length()]
	# Fallback: if rejection sampling exhausted bytes, generate more (max 10 attempts)
	var fallback_attempts := 0
	while result.length() < 32 and fallback_attempts < 10:
		rng_bytes = _crypto.generate_random_bytes(64)
		idx = 0
		fallback_attempts += 1
		while result.length() < 32 and idx < rng_bytes.size():
			var b2: int = rng_bytes[idx]
			idx += 1
			if b2 >= 256 - (256 % chars.length()):
				continue
			result += chars[b2 % chars.length()]
	if result.length() < 32:
		push_error("[MCP Bridge] Failed to generate 32-char secret after 11 attempts — refusing to start with weak key")
		return ""
	return result

func _get_project_dir() -> String:
	var res_root: String = ProjectSettings.globalize_path("res://")
	if res_root != "":
		return res_root.rstrip("/")
	return ""



func _write_secret_to_file(path: String) -> bool:
	# I-3/I-8 SECURITY: secret 明文写入,Godot FileAccess 无权限参数。
	# I-8: 写完后用 OS.execute 收紧权限(与 TS 端/websocket_server.gd 对齐)。
	# Safe save 规避(Godot #40366): Windows FileAccess.close 走 atomic rename,杀软拦 → 红字
	# (非致命但误导)。改用 PowerShell WriteAllText 直接写绕开;secret 经环境变量传递(见 I-3)。
	# 配合 _restrict_secret_permissions 用 USERNAME:M(Modify)+ inheritance:r,PowerShell 能覆盖 M key。
	# Linux/macOS 的 FileAccess.close 不走 atomic,直接用。
	# SEC-P2-2 (2026-08-09 审查): 写前 symlink 预检。攻击者预置 secret 文件为 symlink 指向任意
	# 文件,WriteAllText/FileAccess.open 均 follow symlink 覆盖目标。读方 game-bridge.ts 已有
	# lstatSync 兜底,此处写方对称加固。与 addons/godot_mcp_server/websocket_server.gd DUPLICATE 同步。
	var write_ok := false
	if OS.get_name() == "Windows":
		OS.set_environment("_MCP_SECRET_TMP", _secret)
		OS.set_environment("_MCP_SECRET_PATH", path)
		# F-1(2026-07-04 审查): path 经 env 传递($env:_MCP_SECRET_PATH),不字面拼接进 PowerShell
		# 单引号字符串(项目目录名含 ' 即可逃逸注入)。env 值不解析为命令语法,注入消失。
		# F-2(2026-07-04 审查): OS.execute 去 blocking=false,ec 为真实 exit code(原 non-blocking 返回
		# fork 启动状态,write_ok=(ec==OK) 乐观判断可能误报成功)。与 websocket_server.gd 同步。
		# SEC-P2-2: exit 3 = symlink 拒写(WriteAllText 不执行);Test-Path 守 Get-Item 防首次生成不存在时抛错。
		var ps_args := PackedStringArray(["-NoProfile", "-Command", "if (Test-Path $env:_MCP_SECRET_PATH) { if ((Get-Item -LiteralPath $env:_MCP_SECRET_PATH -Force).LinkType) { exit 3 } }; [IO.File]::WriteAllText($env:_MCP_SECRET_PATH, $env:_MCP_SECRET_TMP)"])
		var ec := OS.execute("powershell", ps_args, [])
		OS.unset_environment("_MCP_SECRET_TMP")
		OS.unset_environment("_MCP_SECRET_PATH")
		if ec == 3:
			# symlink 命中:不 fallback FileAccess(同样 follow symlink),返 false 让调用方处理
			push_warning("[MCP Bridge] %s is a symlink — refusing to write bridge secret" % path)
			return false
		write_ok = (ec == OK)
		if not write_ok:
			push_warning("[MCP Bridge] PowerShell write failed (exit %d), fallback to FileAccess" % ec)
	else:
		# SEC-P2-2: readlink 成功(exit 0)= 是 symlink;失败(非零)= 普通文件或不存在。
		# GD 无原生 symlink 检测 API(FileAccess/DirAccess 均无 LinkType 等价),借 readlink。
		if FileAccess.file_exists(path):
			var rl_ec := OS.execute("readlink", PackedStringArray([path]), [])
			if rl_ec == OK:
				push_warning("[MCP Bridge] %s is a symlink — refusing to write bridge secret" % path)
				return false
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(_secret)
			f.close()
			write_ok = true
	if write_ok:
		_restrict_secret_permissions(path)
		return true
	# Windows 末级 fallback: FileAccess(会触发 Safe save 红字但 key 写成功)
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	if f2:
		f2.store_string(_secret)
		f2.close()
		_restrict_secret_permissions(path)
		return true
	return false

# I-8: 收紧 secret 文件权限(Godot FileAccess 无 chmod 参数,用 OS.execute 绕过)。
# I-2: TS 端用 os.userInfo().username 防环境变量伪造(C-ARC-01);Godot OS API 无等价 getUserInfo,
#      此处退回 get_environment("USERNAME")。威胁有限:攻击者需本机代码执行权限,而本机可执行即可直读 secret。
# I-1: OS.execute 退出码非零时 push_warning,避免权限收紧失败静默(可能 world-readable)。
# DUPLICATE: 与 addons/godot_mcp_server/websocket_server.gd:_restrict_secret_permissions 保持同步。
func _restrict_secret_permissions(path: String) -> void:
	var os_name := OS.get_name()
	var exit_code := 0  # I-1: 捕获 OS.execute 退出码,非零告警(避免权限收紧失败静默)
	if os_name == "Windows":
		var username := OS.get_environment("USERNAME")
		if username.is_empty():
			username = OS.get_environment("USER")
		if username.is_empty() or not RegEx.create_from_string("^[A-Za-z0-9_-]+$").search(username):
			push_warning("[MCP Bridge] Cannot restrict secret permissions: username '%s' has unexpected chars" % username)
			return
		# USERNAME:M(Modify) + /inheritance:r(其他用户无 ACE)。原 USERNAME:R 是 anti-pattern
		# (bridge 以 USERNAME 身份运行却要覆盖自己只读的 key → 靠 FileAccess atomic rename 绕 ACL
		# → Safe save 红字, Godot #40366)。M 让 _write_secret_to_file 的 PowerShell 能直接覆盖,
		# 其他用户仍无权限(比 R 更严)。与 websocket_server.gd:_restrict_secret_permissions 同步。
		exit_code = OS.execute("icacls", PackedStringArray([path, "/inheritance:r", "/grant:r", "%s:M" % username]), [])
		if exit_code != 0:
			push_warning("[MCP Bridge] icacls failed (exit %d), secret may keep default permissions: %s" % [exit_code, path])
	elif os_name in ["Linux", "FreeBSD", "macOS"]:
		exit_code = OS.execute("chmod", PackedStringArray(["600", path]), [])
		if exit_code != 0:
			push_warning("[MCP Bridge] chmod failed (exit %d), secret may keep default permissions: %s" % [exit_code, path])


# ─── Instance Registry (Phase 2b) ─────────────────────────────────────────


func _start_registry_heartbeat() -> void:
	_instance_id = str(OS.get_process_id()) + "_" + str(Time.get_ticks_msec())
	# Machine-level registry
	var machine_dir: String = OS.get_data_dir().get_base_dir().get_base_dir().path_join(".godot-mcp").path_join("instances")
	# Project-level registry
	var project_dir: String = ProjectSettings.globalize_path("user://").path_join(".godot").path_join("mcp-instances")
	_dir_ensure(machine_dir)
	_dir_ensure(project_dir)
	# Write to project-level (machine-level is optional for later)
	_registry_file = project_dir.path_join(_instance_id + ".json")
	_write_registry_entry()
	# Timer
	_registry_heartbeat_timer = Timer.new()
	_registry_heartbeat_timer.wait_time = REGISTRY_HEARTBEAT_INTERVAL
	_registry_heartbeat_timer.one_shot = false
	_registry_heartbeat_timer.autostart = true
	_registry_heartbeat_timer.timeout.connect(_write_registry_entry)
	add_child(_registry_heartbeat_timer)


func _write_registry_entry() -> void:
	if _registry_file == "":
		return
	var entry: Dictionary = {
		"id": _instance_id,
		"projectPath": ProjectSettings.globalize_path("res://"),
		"projectName": ProjectSettings.get_setting("application/config/name"),
		"port": PORT,
		"pid": OS.get_process_id(),
		"lastSeen": Time.get_datetime_string_from_system(),
		"godotVersion": Engine.get_version_info().get("string", "unknown"),
		"capabilities": ["registry-heartbeat"],
	}
	var json: String = JSON.stringify(entry, "	")
	# Atomic write: temp file -> rename
	var tmp_file: String = _registry_file + ".tmp"
	var f: FileAccess = FileAccess.open(tmp_file, FileAccess.WRITE)
	if f == null:
		push_warning("[MCP Bridge] Failed to write registry entry: %s" % FileAccess.get_open_error())
		return
	f.store_string(json)
	f.close()
	DirAccess.rename_absolute(tmp_file, _registry_file)


func _stop_registry_heartbeat() -> void:
	if _registry_heartbeat_timer != null:
		_registry_heartbeat_timer.stop()
		_registry_heartbeat_timer.queue_free()
		_registry_heartbeat_timer = null
	# Clean up registry file on exit
	if _registry_file != "" and FileAccess.file_exists(_registry_file):
		DirAccess.remove_absolute(_registry_file)
	_registry_file = ""


func _dir_ensure(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

func _stop_server() -> void:
	_stop_registry_heartbeat()
	for p in _peers:
		if p.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			p.disconnect_from_host()
	_peers.clear()
	_authenticated_peers.clear()
	_peer_last_activity.clear()
	_auth_fail_count.clear()
	_auth_locked_until.clear()
	if _server:
		_server.stop()
		# S4 (2026-06-23): 固定 secret 模式不删除(持久化供下次启动复用 + 与 MCP 端 TTL 缓存保持同步)
		var _persistent_secret := OS.get_environment("GODOT_MCP_BRIDGE_PERSISTENT_SECRET").to_lower() == "true"
		if not _persistent_secret and _secret_file != "" and FileAccess.file_exists(_secret_file):
			DirAccess.remove_absolute(_secret_file)
		_server = null


# ─── Protocol handling ─────────────────────────────────────────────────────

func _process_buffer_bytes(peer: StreamPeerTCP, pid: int) -> bool:
	var key := "buf_" + str(pid)
	var raw: PackedByteArray = _peer_buffers.get(key, PackedByteArray()) as PackedByteArray
	while true:
		var nl_idx := raw.find(0x0A)
		if nl_idx == -1:
			break
		var line_bytes: PackedByteArray = raw.slice(0, nl_idx)
		raw = raw.slice(nl_idx + 1)
		if line_bytes.size() == 0:
			continue
		var line := line_bytes.get_string_from_utf8()
		if line == "" and line_bytes.size() > 0:
			push_warning("[MCP Bridge] Invalid UTF-8 in message from peer %d, disconnecting" % pid)
			peer.disconnect_from_host()
			_peer_buffers[key] = raw
			return true
		if not _authenticated_peers.has(pid):
			# I-9: per-peer lockout —— 用 pid(peer_id) 隔离失败计数与锁定, 而非全局。
			# 全局键会导致单个失败源(错误客户端/攻击者) 5 次失败锁死所有合法客户端 300s(DoS);
			# per-peer 下失败连接自己被锁, 不影响其他客户端。
			# secret 为 256-bit 随机, 暴力不可行, LOCKOUT 仅减速带(非主防线), per-peer 可接受。
			if _auth_locked_until.has(pid):
				var locked_until: float = _auth_locked_until[pid]
				if Time.get_ticks_msec() / 1000.0 < locked_until:
					peer.put_data((JSON.stringify({"id": null, "error": {"code": -32002, "message": "Too many auth failures, temporarily locked"}}) + "\n").to_utf8_buffer())
					peer.disconnect_from_host()
					_peer_buffers[key] = raw
					return true
				else:
					_auth_locked_until.erase(pid)
					_auth_fail_count[pid] = 0
			var parsed: Variant = JSON.parse_string(line)
			var incoming_secret: String = ""
			if parsed is Dictionary and parsed.get("params") is Dictionary:
				incoming_secret = str(parsed["params"].get("secret", ""))
			if parsed is Dictionary and parsed.get("method") == "auth" and _constant_time_compare(incoming_secret, _secret):
				_authenticated_peers[pid] = true
				_auth_fail_count.erase(pid)
				peer.put_data((JSON.stringify({"id": parsed.get("id"), "result": {"authenticated": true}}) + "\n").to_utf8_buffer())
				continue
			else:
				var fails: int = int(_auth_fail_count.get(pid, 0)) + 1
				_auth_fail_count[pid] = fails
				if fails >= MAX_AUTH_FAILS:
					var lockout_time := minf(LOCKOUT_BASE_SECONDS * pow(2.0, (float(fails) / MAX_AUTH_FAILS) - 1.0), LOCKOUT_MAX_SECONDS)
					_auth_locked_until[pid] = Time.get_ticks_msec() / 1000.0 + lockout_time
				peer.put_data((JSON.stringify({"id": null, "error": {"code": -32001, "message": "Authentication required"}}) + "\n").to_utf8_buffer())
				peer.disconnect_from_host()
				_peer_buffers[key] = raw
				return true
		var response := _handle_message(line, pid)
		# P2-4: playtest.step 返回特殊标记 —— 存 pending 延迟 push,不立即 put_data
		# _process 末尾递减 frames_remaining(I-2:加入帧不递减),到 0 时 push 响应(计数器轮询,非 coroutine)
		if response.begins_with("__PLAYTEST_STEP__"):
			var frames := int(response.split("__")[2])
			_playtest_step_pending.append({
				"peer_id": peer.get_instance_id(),
				"pid": pid,
				"id": _last_step_request_id,
				"frames_remaining": frames,
				"_added_this_frame": true,  # I-2 修复:本帧不递减,下一帧才开始计帧
			})
		elif response.begins_with("__PLAYTEST_CONTROL_STEP_UNTIL__"):
			# G1: 从临时变量取 step_until 完整 params 存 pending(_process 轮询 conditions)
			var su_payload: Dictionary = _pending_control_step_until_result
			_pending_control_step_until_result = {}
			_control_step_until_pending.append({
				"peer_id": peer.get_instance_id(),
				"pid": pid,
				"id": _last_step_request_id,
				"frames_remaining": int(su_payload["max_frames"]),
				"max_frames": int(su_payload["max_frames"]),
				"wall_deadline_ms": Time.get_ticks_msec() + int(su_payload["wall_budget_ms"]),
				"conditions": su_payload["conditions"],
				"refreeze": bool(su_payload.get("refreeze", false)),
				"_added_this_frame": true,
			})
		else:
			peer.put_data((response + "\n").to_utf8_buffer())
	_peer_buffers[key] = raw
	return false

func _handle_message(raw: String, pid: int) -> String:
	var parsed: Variant
	parsed = JSON.parse_string(raw)
	if parsed == null or not (parsed is Dictionary):
		return JSON.stringify({"id": null, "error": {"code": -32700, "message": "Parse error"}})

	var msg: Dictionary = parsed
	var id: Variant = msg.get("id", null)
	var method: String = str(msg.get("method", ""))
	var params: Dictionary = {}
	if msg.get("params") is Dictionary:
		params = msg["params"]

	var result: Variant = null
	var error: Dictionary = {}

	match method:
		"ping":
			result = _cmd_ping()
		"get_tree":
			result = _cmd_get_tree(params)
		"get_scene_stats":
			result = _cmd_get_scene_stats(params)
		"find_nodes":
			result = _cmd_find_nodes(params)
		"get_node_properties":
			result = _cmd_get_node_properties(params)
		"get_node_layout":
			result = _cmd_get_node_layout(params)
		"set_node_property":
			result = _cmd_set_node_property(params)
		"call_method":
			result = _cmd_call_method(params)
		"send_key":
			result = _cmd_send_key(params)
		"send_mouse_click":
			result = _cmd_send_mouse_click(params)
		"send_mouse_move":
			result = _cmd_send_mouse_move(params)
		"send_touch":
			result = _cmd_send_touch(params)
		"send_drag":
			result = _cmd_send_drag(params)
		"send_text":
			result = _cmd_send_text(params)
		"wait_for_node":
			result = _cmd_wait_for_node(params)
		"wait_for_property":
			result = _cmd_wait_for_property(params)
		"take_screenshot":
			result = _cmd_take_screenshot(params)
		"get_performance":
			result = _cmd_get_performance()
		"get_viewport_info":
			result = _cmd_get_viewport_info()
		# CMP-2 (2026-08-08): runtime error 捕获——查询/清除游戏运行时错误
		"get_errors":
			result = _cmd_get_errors(params)
		"clear_errors":
			result = _cmd_clear_errors()
		"recording.start":
			result = _cmd_recording_start()
		"recording.stop":
			result = _cmd_recording_stop()
		"monitor.start":
			result = _cmd_monitor_start(params, pid)
		"monitor.stop":
			result = _cmd_monitor_stop(pid)
		"monitor.poll":
			result = _cmd_monitor_poll(pid)
		"watch.start":
			result = _cmd_watch_start(params, pid)
		"watch.stop":
			result = _cmd_watch_stop(pid)
		"watch.poll":
			result = _cmd_watch_poll(pid)
		"find_ui_elements":
			result = _cmd_find_ui_elements(params)
		"click_button":
			result = _cmd_click_button(params)
		# P2-4 确定性 playtest 四原语(seed/fixed_delta/snapshot/restore 同步;step 走 coroutine)
		"playtest.seed":
			result = _cmd_playtest_seed(params, pid)
		"playtest.fixed_delta":
			result = _cmd_playtest_fixed_delta(params, pid)
		"playtest.snapshot":
			result = _cmd_playtest_snapshot(params, pid)
		"playtest.restore":
			result = _cmd_playtest_restore(params, pid)
		"playtest.step":
			result = _cmd_playtest_step(params)
		# G1 (2026-08-13) control-first satellite 层(附录 F.1)
		"playtest.freeze":
			result = _cmd_control_freeze(params, pid)
		"playtest.unfreeze":
			result = _cmd_control_unfreeze(params, pid)
		"playtest.step_until":
			result = _cmd_control_step_until(params, pid)
		_:
			error = {"code": -32601, "message": "Method not found: %s. 若为新增 method（如 get_node_layout），项目根 mcp_bridge.gd 可能版本过旧，请重新 game_bridge_install 或同步上游 src/scripts/mcp_bridge.gd。" % method}

	# Promote command-level errors to top-level so TS client sees them.
	# TS sendToBridge only checks resp.error (top-level), never result.error.
	if error.is_empty() and result is Dictionary and result.has("error"):
		error = result["error"]
		result = null
	# P2-4: playtest.step 特殊处理 —— 返回哨兵字符串,让 _process_buffer_bytes 启动 coroutine
	if error.is_empty() and result is Dictionary and result.has("__playtest_step__"):
		_last_step_request_id = id
		return "__PLAYTEST_STEP__%d__" % int(result["frames"])
	# G1: step_until 同款哨兵(延迟通道)。完整 result 存临时变量,_process_buffer_bytes 取用存 pending。
	if error.is_empty() and result is Dictionary and result.has("__playtest_control_step_until__"):
		_last_step_request_id = id
		_pending_control_step_until_result = result
		return "__PLAYTEST_CONTROL_STEP_UNTIL__"
	if error.is_empty():
		return JSON.stringify({"id": id, "result": result})
	else:
		return JSON.stringify({"id": id, "error": error})


# ─── Command implementations ────────────────────────────────────────────────

func _cmd_ping() -> Dictionary:
	var scene_path := ""
	if get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path
	return {"pong": true, "version": PROTOCOL_VERSION, "scene": scene_path, "fps": Engine.get_frames_per_second()}


func _cmd_get_tree(params: Dictionary) -> Variant:
	var max_depth: int = int(params.get("max_depth", 10))
	var root_node := get_tree().root
	if root_node == null:
		return {"tree": [], "scene": ""}
	var scene_path := ""
	if get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path
	var counter := [0]
	return {"tree": [_serialize_node(root_node, max_depth, 0, counter)], "scene": scene_path}


# 批 2 readScene：基于 current_scene 的场景统计（迭代单遍 stack DFS，无爆栈）。只聚合不传树。
# TYPE_WINDOW: typeTopN 字典维护窗口（>2000 停维护字典省内存，nodeCount 仍准确）
# HARD_STOP: OOM 硬停止（nodeCount 绝对上限）。独立于 _serialize_node max_nodes（序列化上限）。
const TYPE_WINDOW: int = 2000
const HARD_STOP: int = 50000

func _cmd_get_scene_stats(_params: Dictionary) -> Variant:
	var scene := get_tree().current_scene
	if scene == null:
		return {"stats": null}  # no current_scene → TS 透传 null 降级
	var node_count: int = 0
	var type_count: Dictionary = {}
	var truncated: bool = false
	# 批 2 M2：Godot 场景树不变量保证无环（节点不能是自己的祖先），stack DFS 不会无限循环；HARD_STOP 兜底防 OOM
	var stack: Array = [scene]
	while stack.size() > 0:
		if node_count >= HARD_STOP:
			truncated = true
			break
		var node: Node = stack.pop_back()
		node_count += 1
		if node_count <= TYPE_WINDOW:
			var cls: String = node.get_class()
			type_count[cls] = int(type_count.get(cls, 0)) + 1
		for c in node.get_children():
			stack.push_back(c)
	var type_top_n: Variant = null
	if node_count <= TYPE_WINDOW:
		var entries: Array = []
		for key in type_count.keys():
			entries.append({"type": key, "n": int(type_count[key])})
		entries.sort_custom(func(a, b): return int(a["n"]) > int(b["n"]))
		type_top_n = entries.slice(0, 5)
	return {
		"stats": {
			"path": scene.scene_file_path,
			"root": scene.name,
			"nodeCount": node_count,
			"typeTopN": type_top_n,
			"truncated": truncated,
		}
	}


func _serialize_node(node: Node, max_depth: int, depth: int, counter: Array, max_nodes: int = 2000) -> Dictionary:
	if counter[0] >= max_nodes:
		return _node_info(node)
	counter[0] += 1
	var info := _node_info(node)
	if depth < max_depth:
		var children: Array = []
		for child in node.get_children():
			if counter[0] >= max_nodes:
				break
			children.append(_serialize_node(child, max_depth, depth + 1, counter, max_nodes))
		if children.size() > 0:
			info["children"] = children
	return info


func _node_info(node: Node) -> Dictionary:
	var info := {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}
	if node is CanvasItem:
		info["visible"] = node.visible
	if node is Node2D:
		info["position"] = {"x": node.position.x, "y": node.position.y}
	if node is Node3D:
		info["position"] = {"x": node.position.x, "y": node.position.y, "z": node.position.z}
	return info


func _cmd_find_nodes(params: Dictionary) -> Dictionary:
	var pattern: String = str(params.get("pattern", ""))
	var type_filter: String = str(params.get("type", ""))
	var group: String = str(params.get("group", ""))
	var max_results: int = int(params.get("limit", 100))
	if max_results > 500:
		max_results = 500
	var results: Array = _traverse_tree(
		func(node: Node) -> bool:
			if pattern != "" and not node.name.match(pattern):
				return false
			if type_filter != "" and not node.is_class(type_filter):
				return false
			if group != "" and not node.is_in_group(group):
				return false
			return true,
		{"max_results": max_results}
	)
	var serialized: Array = []
	for node in results:
		serialized.append(_node_info(node))
	return {"nodes": serialized, "count": serialized.size()}





func _cmd_get_node_properties(params: Dictionary) -> Variant:
	var path: String = str(params.get("path", ""))
	var node := get_node_or_null(path)
	if node == null:
		return {"error": {"code": -1, "message": "Node not found: %s" % path}}
	var props: Dictionary = {}
	for prop in node.get_property_list():
		var name: String = prop["name"]
		if name.begins_with("_") or name.begins_with("theme_override") or name in BLOCKED_PROPERTIES:
			continue
		var val: Variant = node.get(name)
		if val is Resource:
			val = {"type": val.get_class(), "path": val.resource_path if val.resource_path else ""}
		elif val is Node:
			val = str(val.get_path())
		# 2026-08-07 审查 P2 修复：非 Resource 非 Node 的 Object 子类（如 EditorInterface、
		# 自定义 RefCounted）进 props dict 会致 JSON.stringify 整体失败或泄露对象内部表示。
		# 对齐 :881/:1119 的 _is_safe_value 守卫模式（读取场景用 continue 跳过，非 reject）。
		if not _is_safe_value(val):
			continue
		props[name] = val
	return {"properties": props, "node": path}


func _cmd_get_node_layout(params: Dictionary) -> Variant:
	var path: String = str(params.get("path", ""))
	var node := get_node_or_null(path)
	if not is_instance_valid(node):
		return {"error": {"code": -1, "message": "Node not found: %s" % path}}
	var data: Dictionary = {}
	data["type"] = node.get_class()
	# visible 横切（P1）：CanvasItem 与 Node3D 各自定义 visible
	if node is CanvasItem or node is Node3D:
		data["visible"] = node.visible
	if node is CanvasItem:
		data["z_index"] = node.z_index
	# 变换字段（P2）：Node2D/Control 各自定义，读取代码相同合并；Node3D 在下面用 Vector3 覆盖。
	if node is Node2D or node is Control:
		data["position"] = _jsonify(node.position)
		data["global_position"] = _jsonify(node.global_position)
		data["rotation"] = _jsonify(node.rotation)
		data["scale"] = _jsonify(node.scale)
	if node is Control:
		data["size"] = _jsonify(node.size)
		data["rect"] = _jsonify(node.get_rect())
		data["anchor_left"] = node.anchor_left
		data["anchor_right"] = node.anchor_right
		data["anchor_top"] = node.anchor_top
		data["anchor_bottom"] = node.anchor_bottom
		data["offset_left"] = node.offset_left
		data["offset_right"] = node.offset_right
		data["offset_top"] = node.offset_top
		data["offset_bottom"] = node.offset_bottom
		data["pivot_offset"] = _jsonify(node.pivot_offset)
	# 独立 if 非 elif（P3）：Sprite2D 同时命中上面的 Node2D 变换层 + 这里的专属层
	if node is Sprite2D:
		data["centered"] = node.centered
		data["offset"] = _jsonify(node.offset)
	if node is Node3D:
		data["position"] = _jsonify(node.position)
		data["global_position"] = _jsonify(node.global_position)
		data["rotation"] = _jsonify(node.rotation)
		data["scale"] = _jsonify(node.scale)
	# 注：global_position 节点未入树时引擎静默返 ZERO，调用方须警惕未入树场景。
	return {"layout": data, "node": path}


func _cmd_set_node_property(params: Dictionary) -> Variant:
	var path: String = str(params.get("path", ""))
	var prop: String = str(params.get("property", ""))
	if not params.has("value"):
		return {"error": {"code": -6, "message": "Missing required parameter: value"}}
	var value: Variant = params["value"]
	var node := get_node_or_null(path)
	if node == null:
		return {"error": {"code": -1, "message": "Node not found: %s" % path}}
	if _is_blocked_property(prop):
		return {"error": {"code": -2, "message": "Blocked property: %s" % prop}}
	if not _is_safe_value(value):
		var type_info: String = "null" if value == null else value.get_class()
		return {"error": {"code": -3, "message": "Value type not allowed: %s" % type_info}}
	node.set(prop, value)
	return {"success": true, "node": path, "property": prop}


func _cmd_call_method(params: Dictionary) -> Variant:
	var path: String = str(params.get("path", ""))
	var method: String = str(params.get("method", ""))
	var args: Array = []
	if params.get("args") is Array:
		args = params["args"]
	var node := get_node_or_null(path)
	if node == null:
		return {"error": {"code": -1, "message": "Node not found: %s" % path}}
	# S5 (2026-06-23): env GODOT_MCP_BRIDGE_EXTRA_METHODS 扩展白名单(opt-in,默认只读安全)。
	# ALLOWED_METHODS 设计为只读(get/has_*/get_meta 等),防 call_method 任意执行;信任环境
	# 可显式加方法(如 emit_signal)用此 env。注意 emit_signal 会触发已连接的任意回调,慎用。
	# CMP-9-B (2026-08-08): 同一 env 也覆盖写/副作用方法(take_damage/add_velocity 等),
	# 对标竞品 runtime.call。EXTRA_METHODS_BLOCKLIST 仍是不可覆盖硬底线。
	var _extra_env := OS.get_environment("GODOT_MCP_BRIDGE_EXTRA_METHODS")
	var _extra_ok := false
	if _extra_env != "":
		for _m in _extra_env.split(","):
			if (_m as String).strip_edges() == method:
				_extra_ok = true
				break
	# P1-6: EXTRA_METHODS 即使显式列出,危险方法仍拒绝(防 env 误设致 RCE/运行时结构破坏)
	if _extra_ok and method in EXTRA_METHODS_BLOCKLIST:
		# B-2 (2026-08-14): 内层检查——间接调用入口(args[0]=内层方法名)命中 BLOCKLIST 时,
		# 若 args[0] 也是 BLOCKLIST 方法(如 call_thread_safe + set_script),拒绝信息一并标注
		# 内外两层(纵深防御 + 诊断增强)。仅 BLOCKLIST 命中分支内检查,正常方法不受影响。
		var _inner_note := ""
		if args.size() > 0 and args[0] is String and args[0] in EXTRA_METHODS_BLOCKLIST:
			_inner_note = " Inner method '%s' is also blocked." % args[0]
		return {"error": {"code": -6, "message": "Method blocked even with GODOT_MCP_BRIDGE_EXTRA_METHODS (dangerous, changes runtime structure): %s%s" % [method, _inner_note]}}
	if not method in ALLOWED_METHODS and not _extra_ok:
		return {"error": {"code": -2, "message": "Method not allowed: %s (set env GODOT_MCP_BRIDGE_EXTRA_METHODS to allow)" % method}}
	if not node.has_method(method):
		# CMP-9-B: did-you-mean(对标竞品 + editor call_method 一致体验),降 AI 重试成本
		var _suggestion := _suggest_bridge_method(node, method)
		var _hint := "Allowed methods: see ALLOWED_METHODS or set GODOT_MCP_BRIDGE_EXTRA_METHODS."
		if _suggestion != "":
			_hint = "Did you mean '%s'? %s" % [_suggestion, _hint]
		return {"error": {"code": -3, "message": "Method not found: %s. %s" % [method, _hint]}}
	if args.size() > 8:
		return {"error": {"code": -4, "message": "Too many arguments (max 8)"}}
	if method == "get" and args.size() > 0 and args[0] is String:
		if _is_blocked_property(args[0]):
			return {"error": {"code": -5, "message": "Blocked property via get(): %s" % args[0]}}
	# CMP-9-B: args 类型强转(对标竞品 coerce_call_args + editor call_method 一致)。
	# 按 ClassDB method 声明类型强转,防 Vector3 传单值/Array 静默变零值(Godot callv 不自动转)。
	var _coerced := _coerce_bridge_args(node, method, args)
	var result: Variant = node.callv(method, _coerced)
	# CMP-9-B: undoable=false 显式声明(call 不可 undo,对标竞品 + editor call_method 一致)
	return {"result": _jsonify(result), "undoable": false}


func _jsonify(val: Variant) -> Variant:
	if val is Vector2:
		return {"x": val.x, "y": val.y}
	if val is Vector2i:
		return {"x": val.x, "y": val.y}
	if val is Vector3:
		return {"x": val.x, "y": val.y, "z": val.z}
	if val is Vector3i:
		return {"x": val.x, "y": val.y, "z": val.z}
	if val is Color:
		return {"r": val.r, "g": val.g, "b": val.b, "a": val.a}
	if val is Rect2:
		return {"x": val.position.x, "y": val.position.y, "w": val.size.x, "h": val.size.y}
	if val is Rect2i:
		return {"x": val.position.x, "y": val.position.y, "w": val.size.x, "h": val.size.y}
	if val is Transform2D:
		return {"x": val.origin.x, "y": val.origin.y}
	if val is Transform3D:
		return {"x": val.origin.x, "y": val.origin.y, "z": val.origin.z}
	if val is Resource:
		return {"type": val.get_class(), "path": val.resource_path if val.resource_path else ""}
	if val is Node:
		return str(val.get_path())
	if val is Object:
		# B4 (2026-08-11 审查): 非 Node/非 Resource 的 Object(InputEvent/RegExMatch 等)对齐
		# editor 侧 engine_commands.gd _serialize_return_value 的 Object 分支,返 {type, instance_id}。
		# 原 return val 原样——JSON.stringify 对裸 Object 可能失败或返不可读 str(),
		# bridge/editor 两通道返回结构不一致,AI 跨通道比对踩坑。
		return {"type": val.get_class(), "instance_id": val.get_instance_id()}
	return val


# CMP-9-B (2026-08-08): did-you-mean — 方法不存在时给最接近建议(对标竞品 + editor call_method 一致)。
# String.similarity > 0.6 取最高分。限制扫 node.get_method_list()(已在 line 937 has_method 检查后调用)。
func _suggest_bridge_method(node: Node, target: String) -> String:
	var best := ""
	var best_score := 0.6
	for m in node.get_method_list():
		if m is Dictionary and m.has("name"):
			var name_: String = m["name"]
			var score: float = target.similarity(name_)
			if score > best_score:
				best_score = score
				best = name_
	return best


# CMP-9-B (2026-08-08): args 类型强转(对标竞品 coerce_call_args + editor call_method 一致)。
# 按 ClassDB method 声明类型强转,防 Vector3 传 Array [1,2,3] 或 String "(1,2,3)" 静默变零值。
# 取不到 method info(动态方法)→ 不强转透传(Godot callv 自己处理)。
func _coerce_bridge_args(node: Node, method: String, raw_args: Array) -> Array:
	var methods: Array = node.get_method_list()
	var method_info: Dictionary = {}
	for m in methods:
		if m is Dictionary and m.get("name", "") == method:
			method_info = m
			break
	if method_info.is_empty() or not method_info.has("args"):
		return raw_args
	var declared_args: Array = method_info["args"]
	var coerced: Array = []
	for i in range(raw_args.size()):
		var raw: Variant = raw_args[i]
		if i < declared_args.size() and declared_args[i] is Dictionary:
			var declared_type: int = int(declared_args[i].get("type", TYPE_NIL))
			coerced.append(_coerce_bridge_single(raw, declared_type))
		else:
			coerced.append(raw)
	return coerced


# CMP-9-B: 单个参数强转(与 editor engine_commands.gd _coerce_single_arg 同款逻辑)。
func _coerce_bridge_single(raw: Variant, declared_type: int) -> Variant:
	match declared_type:
		TYPE_VECTOR2:
			if raw is Array and raw.size() >= 2:
				return Vector2(float(raw[0]), float(raw[1]))
			if raw is String:
				return Vector2(raw)
		TYPE_VECTOR2I:
			if raw is Array and raw.size() >= 2:
				return Vector2i(int(raw[0]), int(raw[1]))
		TYPE_VECTOR3:
			if raw is Array and raw.size() >= 3:
				return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
			if raw is String:
				return Vector3(raw)
		TYPE_VECTOR3I:
			if raw is Array and raw.size() >= 3:
				return Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))
		TYPE_VECTOR4:
			if raw is Array and raw.size() >= 4:
				return Vector4(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
		TYPE_COLOR:
			if raw is Array and raw.size() >= 3:
				var a: float = float(raw[3]) if raw.size() > 3 else 1.0
				return Color(float(raw[0]), float(raw[1]), float(raw[2]), a)
		TYPE_BOOL:
			if raw is String:
				return raw.to_lower() == "true"
			if raw is float or raw is int:
				return bool(raw)
		TYPE_INT:
			if raw is String:
				return int(raw)
			if raw is float:
				return int(raw)
		TYPE_FLOAT:
			if raw is String:
				return float(raw)
			if raw is int:
				return float(raw)
		TYPE_STRING:
			return str(raw)
		TYPE_NODE_PATH:
			return NodePath(str(raw))
	return raw


# ─── Shared tree traversal ──────────────────────────────────────────────────
# Callback receives each node; return true to include in results.
func _traverse_tree(callback: Callable, opts: Dictionary = {}) -> Array:
	var root_node: Node = opts.get("root", get_tree().root) as Node
	var max_results: int = int(opts.get("max_results", 500))
	var max_visited: int = int(opts.get("max_visited", 5000))
	if root_node == null:
		return []
	var results: Array = []
	var stack: Array[Node] = [root_node]
	var visited: int = 0
	while stack.size() > 0 and results.size() < max_results and visited < max_visited:
		var node: Node = stack.pop_back()
		if node == null:
			continue
		visited += 1
		if callback.call(node):
			results.append(node)
		var children := node.get_children()
		for i in range(children.size() - 1, -1, -1):
			stack.append(children[i])
	return results




func _is_blocked_property(prop: String) -> bool:
	if prop.begins_with("_"):
		return true
	if prop.begins_with("theme_override"):
		return true
	if prop in BLOCKED_PROPERTIES:
		return true
	if "." in prop:
		for segment in prop.split("."):
			if segment == "" or segment.begins_with("_") or segment in BLOCKED_PROPERTIES:
				return true
	if ":" in prop or "/" in prop:
		return true
	return false


# ─── Input simulation ──────────────────────────────────────────────────────

func _cmd_send_key(params: Dictionary) -> Variant:
	var key: String = str(params.get("key", ""))
	var pressed: bool = params.get("pressed", true)
	var keycode: int = _key_from_string(key)
	if keycode == 0:
		return {"error": {"code": -1, "message": "Unknown key: %s" % key}}
	var event := InputEventKey.new()
	event.keycode = keycode
	# S6 (2026-06-23): 同时设 physical_keycode,触发用物理键码映射的 input action。
	# Godot 4 推荐 physical_keycode 映射;只设 keycode 在 physical 映射项目里不触发 ui_action。
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	return {"success": true, "key": key}


func _key_from_string(key: String) -> int:
	var mapping := {
		"enter": KEY_ENTER, "escape": KEY_ESCAPE, "space": KEY_SPACE,
		"tab": KEY_TAB, "shift": KEY_SHIFT, "ctrl": KEY_CTRL, "alt": KEY_ALT,
		"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
		"a": KEY_A, "b": KEY_B, "c": KEY_C, "d": KEY_D, "e": KEY_E,
		"f": KEY_F, "g": KEY_G, "h": KEY_H, "i": KEY_I, "j": KEY_J,
		"k": KEY_K, "l": KEY_L, "m": KEY_M, "n": KEY_N, "o": KEY_O,
		"p": KEY_P, "q": KEY_Q, "r": KEY_R, "s": KEY_S, "t": KEY_T,
		"u": KEY_U, "v": KEY_V, "w": KEY_W, "x": KEY_X, "y": KEY_Y, "z": KEY_Z,
		"0": KEY_0, "1": KEY_1, "2": KEY_2, "3": KEY_3, "4": KEY_4,
		"5": KEY_5, "6": KEY_6, "7": KEY_7, "8": KEY_8, "9": KEY_9,
	}
	var upper := key.to_lower()
	if mapping.has(upper):
		return mapping[upper]
	return 0


func _cmd_send_mouse_click(params: Dictionary) -> Variant:
	var x: float = float(params.get("x", 0))
	var y: float = float(params.get("y", 0))
	var button: int = int(params.get("button", 1))
	var pressed: bool = params.get("pressed", true)
	var event := InputEventMouseButton.new()
	event.position = Vector2(x, y)
	event.button_index = button
	event.pressed = pressed
	event.global_position = Vector2(x, y)
	Input.parse_input_event(event)
	return {"success": true, "x": x, "y": y, "button": button}


func _cmd_send_mouse_move(params: Dictionary) -> Variant:
	var x: float = float(params.get("x", 0))
	var y: float = float(params.get("y", 0))
	var event := InputEventMouseMotion.new()
	event.position = Vector2(x, y)
	event.global_position = Vector2(x, y)
	Input.parse_input_event(event)
	return {"success": true, "x": x, "y": y}


# 阶段2b IMP-11: 触摸事件注入(对齐 recording_commands.gd :197 + recording.ts touch 回放契约)
func _cmd_send_touch(params: Dictionary) -> Variant:
	var x: float = float(params.get("x", 0))
	var y: float = float(params.get("y", 0))
	var pressed: bool = params.get("pressed", true)
	var index: int = int(params.get("index", 0))
	var event := InputEventScreenTouch.new()
	event.position = Vector2(x, y)
	event.pressed = pressed
	event.index = index
	Input.parse_input_event(event)
	return {"success": true, "x": x, "y": y, "pressed": pressed, "index": index}


# IMP-11 补全: 触屏拖拽回放载体(对齐 _cmd_send_touch;speed best-effort,Godot 内部可能重算覆盖)
func _cmd_send_drag(params: Dictionary) -> Variant:
	var x: float = float(params.get("x", 0))
	var y: float = float(params.get("y", 0))
	var index: int = int(params.get("index", 0))
	var relative: Array = params.get("relative", [0.0, 0.0])
	if not (relative is Array):
		relative = [0.0, 0.0]
	var speed: Array = params.get("speed", [0.0, 0.0])
	if not (speed is Array):
		speed = [0.0, 0.0]
	var event := InputEventScreenDrag.new()
	event.position = Vector2(x, y)
	event.index = index
	event.relative = Vector2(float(relative[0]) if relative.size() > 0 else 0.0, float(relative[1]) if relative.size() > 1 else 0.0)
	event.speed = Vector2(float(speed[0]) if speed.size() > 0 else 0.0, float(speed[1]) if speed.size() > 1 else 0.0)
	Input.parse_input_event(event)
	return {"success": true, "x": x, "y": y, "index": index, "relative": relative, "speed": speed}


func _cmd_send_text(params: Dictionary) -> Variant:
	var text: String = str(params.get("text", ""))
	if text.length() > 1000:
		return {"error": {"code": -1, "message": "Text too long: %d chars (max 1000)" % text.length()}}
	for ch in text:
		var event := InputEventKey.new()
		event.unicode = ch.unicode_at(0)
		event.pressed = true
		Input.parse_input_event(event)
		event.pressed = false
		Input.parse_input_event(event)
	return {"success": true, "characters": text.length()}


# ─── Wait commands (sync check, not async) ──────────────────────────────────

func _cmd_wait_for_node(params: Dictionary) -> Variant:
	var path: String = str(params.get("path", ""))
	var node := get_node_or_null(path)
	return {"exists": node != null, "path": path}


func _cmd_wait_for_property(params: Dictionary) -> Variant:
	var path: String = str(params.get("path", ""))
	var prop: String = str(params.get("property", ""))
	var expected: Variant = params.get("value")
	var node := get_node_or_null(path)
	if node == null:
		return {"error": {"code": -1, "message": "Node not found: %s" % path}}
	if _is_blocked_property(prop):
		return {"error": {"code": -2, "message": "Blocked property: %s" % prop}}
	var current: Variant = node.get(prop)
	# I-07: Safety check on read value to prevent leaking complex types (Resource, Script, etc.)
	if not _is_safe_value(current):
		return {"match": false, "property": prop, "current": "<unsupported type>", "expected": _jsonify(expected)}
	var match_result: bool = str(current) == str(expected)
	return {"match": match_result, "property": prop, "current": _jsonify(current), "expected": _jsonify(expected)}


# ─── Visual ─────────────────────────────────────────────────────────────────

func _cmd_take_screenshot(params: Dictionary) -> Variant:
	var path: String = str(params.get("path", "user://mcp_screenshot.png"))
	# Normalize and check traversal
	var clean_path: String = path.replace("\\", "/").uri_decode()
	if not clean_path.begins_with("user://"):
		return {"error": {"code": -1, "message": "Screenshot path must start with user://"}}
	# Check each segment for traversal
	for segment in clean_path.substr(8).split("/"):
		if segment == ".." or segment == ".":
			return {"error": {"code": -1, "message": "Screenshot path contains directory traversal"}}
	var viewport := get_viewport()
	if viewport == null:
		return {"error": {"code": -3, "message": "No active viewport available for screenshot"}}
	var tex := viewport.get_texture()
	if tex == null:
		return {"error": {"code": -3, "message": "Viewport has no render texture (window not yet rendered or headless backend)"}}
	var img := tex.get_image()
	if img == null:
		return {"error": {"code": -3, "message": "Failed to capture viewport image (GPU not ready or window minimized/backgrounded)"}}
	var err := img.save_png(clean_path)
	if err != OK:
		return {"error": {"code": -2, "message": "Failed to save screenshot: error %d" % err}}
	return {"success": true, "path": clean_path, "size": {"x": img.get_width(), "y": img.get_height()}}


func _cmd_get_performance() -> Dictionary:
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"frame_time": Performance.get_monitor(Performance.TIME_PROCESS),
		"physics_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	}


func _cmd_get_viewport_info() -> Dictionary:
	var vp := get_viewport()
	return {
		"size": {"x": vp.get_visible_rect().size.x, "y": vp.get_visible_rect().size.y},
	}


# ─── CMP-2: runtime error 捕获 (2026-08-08) ──────────────────────────────────

func _cmd_get_errors(params: Dictionary) -> Dictionary:
	if _error_capture == null:
		return {"error": {"code": -32003, "message": "Error capture not initialized"}}
	var since_seq := int(params.get("since_seq", 0))
	var clear := bool(params.get("clear", false))
	return _error_capture.poll(since_seq, clear)


func _cmd_clear_errors() -> Dictionary:
	if _error_capture == null:
		return {"error": {"code": -32003, "message": "Error capture not initialized"}}
	_error_capture.clear()
	return {"status": "ok", "cleared": true}


# ─── Recording ───────────────────────────────────────────────────────────────

func _cmd_recording_start() -> Variant:
	if _recording:
		return {"error": {"code": -1, "message": "Recording already in progress"}}
	_recording = true
	_recorded_events = []
	_record_start_time = Time.get_ticks_msec()
	return {"status": "recording", "message": "Input events are being captured"}


func _cmd_recording_stop() -> Variant:
	if not _recording:
		return {"error": {"code": -1, "message": "No recording in progress"}}
	_recording = false
	var duration_ms: int = Time.get_ticks_msec() - _record_start_time
	var events: Array = _recorded_events.duplicate()
	_recorded_events = []
	return {"version": 1, "duration_ms": duration_ms, "events": events, "event_count": events.size()}


# ─── Monitor commands ───────────────────────────────────────────────────

func _cmd_monitor_start(params: Dictionary, pid: int) -> Variant:
	var node_path: String = str(params.get("node_path", ""))
	var properties = params.get("properties", [])
	var interval: int = int(params.get("interval_frames", 10))

	if node_path == "":
		return {"error": {"code": -1, "message": "node_path is required"}}
	if not properties is Array or properties.size() == 0:
		return {"error": {"code": -2, "message": "properties must be a non-empty array"}}
	if properties.size() > MONITOR_MAX_PROPERTIES:
		return {"error": {"code": -6, "message": "Too many properties (%d, max %d)" % [properties.size(), MONITOR_MAX_PROPERTIES]}}
	if interval < 1:
		interval = 1
	if interval > 300:
		interval = 300

	var node := get_node_or_null(node_path)
	if node == null:
		return {"error": {"code": -3, "message": "Node not found: %s" % node_path}}

	# I-11: filter out blocked property names
	var filtered_props: Array = []
	for prop in properties:
		if not _is_blocked_property(str(prop)):
			filtered_props.append(prop)
	if filtered_props.size() == 0:
		return {"error": {"code": -7, "message": "All requested properties are blocked"}}

	var previous_samples: Array = []
	if _monitor_states.has(pid) and _monitor_states[pid].get("active", false):
		previous_samples = (_monitor_states[pid]["samples"] as Array).duplicate(true)

	_monitor_states[pid] = {
		"active": true,
		"node_path": node_path,
		"properties": filtered_props,
		"interval_frames": interval,
		"frame_counter": 0,
		"samples": [],
		"max_samples": MONITOR_DEFAULT_MAX_SAMPLES,
	}
	# P3-6: push 模式注册(monitor.start 带 push:true 时启用主动推送)
	if bool(params.get("push", false)):
		_push_peers[pid] = true

	var result_dict: Dictionary = {
		"monitoring": true,
		"node_path": node_path,
		"properties": properties,
		"interval_frames": interval,
	}
	if previous_samples.size() > 0:
		result_dict["previous_samples"] = previous_samples
	return result_dict


func _cmd_monitor_stop(pid: int) -> Variant:
	if not _monitor_states.has(pid):
		return {"monitoring": false, "samples": [], "sample_count": 0, "message": "No active monitor for this peer"}
	var ms: Dictionary = _monitor_states[pid]
	if not ms.get("active", false):
		# I-03: monitor may have auto-stopped; return reason + samples
		var old_samples := (ms["samples"] as Array).duplicate(true)
		var reason := ""
		if old_samples.size() > 0:
			var last: Dictionary = old_samples[-1]
			if last.has("stopped_reason"):
				reason = last["stopped_reason"]
		var msg := "No active monitor"
		if reason != "":
			msg = "Monitor stopped: %s" % reason
		_monitor_states.erase(pid)
		return {"monitoring": false, "samples": old_samples, "sample_count": old_samples.size(), "stopped_reason": reason, "message": msg}
	ms["active"] = false
	var samples := (ms["samples"] as Array).duplicate(true)
	var duration := 0.0
	if samples.size() > 0:
		duration = samples[samples.size() - 1].get("time", 0.0) - samples[0].get("time", 0.0)
	# I-03: extract stopped_reason from last sample
	var stopped_reason: String = ""
	if samples.size() > 0:
		var last: Dictionary = samples[-1]
		if last.has("stopped_reason"):
			stopped_reason = last["stopped_reason"]
	var result_dict: Dictionary = {
		"monitoring": false,
		"samples": samples,
		"sample_count": samples.size(),
		"total_frames": Engine.get_process_frames(),
		"duration_seconds": duration,
	}
	if stopped_reason != "":
		result_dict["stopped_reason"] = stopped_reason
	_monitor_states.erase(pid)
	return result_dict


func _cmd_monitor_poll(pid: int) -> Variant:
	if not _monitor_states.has(pid):
		return {"monitoring": false, "samples": [], "message": "No active monitor for this peer"}
	var ms: Dictionary = _monitor_states[pid]
	if not ms.get("active", false):
		# I-03: return last stopped_reason
		var last_reason: String = ""
		if (ms["samples"] as Array).size() > 0:
			var last: Dictionary = (ms["samples"] as Array)[-1]
			if last.has("stopped_reason"):
				last_reason = last["stopped_reason"]
		var msg := "No active monitor"
		if last_reason != "":
			msg = "Monitor stopped: %s" % last_reason
		return {"monitoring": false, "samples": [], "stopped_reason": last_reason, "message": msg}
	var samples := (ms["samples"] as Array).duplicate(true)
	return {
		"monitoring": true,
		"node_path": str(ms["node_path"]),
		"samples": samples,
		"sample_count": samples.size(),
	}


# --- Signal watch commands (C-07: per-peer) ---

# P3-6: 向启用了 push 模式的 peer 主动推送事件(无需等 poll)
# type: "watch" | "monitor";payload: 事件数据(单个 sample 或 event)
func _push_event_to_peer(pid: int, event_type: String, payload: Dictionary) -> void:
	if not _push_peers.get(pid, false):
		return
	# 找到对应的 peer StreamPeerTCP
	var target_peer: StreamPeerTCP = null
	for p in _peers:
		if p.get_instance_id() == pid:
			target_peer = p
			break
	if target_peer == null:
		return
	if target_peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var msg := JSON.stringify({
		"jsonrpc": "2.0",
		"method": "bridge/event",
		"params": {"type": event_type, "data": payload}
	}) + "\n"
	target_peer.put_data(msg.to_utf8_buffer())


func _on_watched_signal_0(pid: int) -> void:
	_record_watch_event([], pid)

func _on_watched_signal_1(arg0: Variant, pid: int) -> void:
	_record_watch_event([arg0], pid)

func _on_watched_signal_2(arg0: Variant, arg1: Variant, pid: int) -> void:
	_record_watch_event([arg0, arg1], pid)

func _on_watched_signal_3(arg0: Variant, arg1: Variant, arg2: Variant, pid: int) -> void:
	_record_watch_event([arg0, arg1, arg2], pid)

func _on_watched_signal_4(arg0: Variant, arg1: Variant, arg2: Variant, arg3: Variant, pid: int) -> void:
	_record_watch_event([arg0, arg1, arg2, arg3], pid)


func _record_watch_event(raw_args: Array, peer_id: int) -> void:
	if not _watch_states.has(peer_id):
		return
	var ws: Dictionary = _watch_states[peer_id]
	if not ws.get("active", false):
		return
	var safe_args: Array = []
	for arg in raw_args:
		safe_args.append(_jsonify(arg))
	var event_dict := {
		"frame": Engine.get_process_frames(),
		"time": Time.get_ticks_msec() / 1000.0,
		"args": safe_args,
	}
	(ws["events"] as Array).append(event_dict)
	# P3-6: push 模式下立即推送(不等 poll)
	_push_event_to_peer(peer_id, "watch", {
		"node_path": str(ws.get("node_path", "")),
		"signal_name": str(ws.get("signal_name", "")),
		"event": event_dict
	})
	if (ws["events"] as Array).size() >= int(ws["max_events"]):
		_do_watch_disconnect(peer_id)
		ws["active"] = false


func _do_watch_disconnect(peer_id: int) -> void:
	if not _watch_states.has(peer_id):
		return
	var ws: Dictionary = _watch_states[peer_id]
	if not ws.get("connected", false):
		return
	var node := get_node_or_null(str(ws.get("node_path", "")))
	if node != null:
		var callable := _get_watch_callable(peer_id)
		var signal_name: String = str(ws.get("signal_name", ""))
		if node.has_signal(signal_name) and node.is_connected(signal_name, callable):
			node.disconnect(signal_name, callable)
	ws["connected"] = false


func _get_watch_callable(peer_id: int) -> Callable:
	var ws: Dictionary = _watch_states.get(peer_id, {})
	var sig_list := []
	var node := get_node_or_null(str(ws.get("node_path", "")))
	var signal_name: String = str(ws.get("signal_name", ""))
	if node != null and node.has_signal(signal_name):
		sig_list = node.get_signal_list()
	for sig_info in sig_list:
		if sig_info.get("name", "") == signal_name:
			var arg_count: int = sig_info.get("args", []).size()
			match arg_count:
				0: return _on_watched_signal_0.bind(peer_id)
				1: return _on_watched_signal_1.bind(peer_id)
				2: return _on_watched_signal_2.bind(peer_id)
				3: return _on_watched_signal_3.bind(peer_id)
				4: return _on_watched_signal_4.bind(peer_id)
				_: return _on_watched_signal_0.bind(peer_id)
	return _on_watched_signal_0.bind(peer_id)


func _cmd_watch_start(params: Dictionary, pid: int) -> Variant:
	var node_path: String = str(params.get("node_path", ""))
	var signal_name: String = str(params.get("signal_name", ""))
	var max_events: int = int(params.get("max_events", 1000))

	if node_path == "":
		return {"error": {"code": -1, "message": "node_path is required"}}
	if signal_name == "":
		return {"error": {"code": -2, "message": "signal_name is required"}}
	if max_events < 1:
		max_events = 1
	if max_events > 5000:
		max_events = 5000

	var node := get_node_or_null(node_path)
	if node == null:
		return {"error": {"code": -3, "message": "Node not found: %s" % node_path}}
	if not node.has_signal(signal_name):
		return {"error": {"code": -4, "message": "Signal not found: %s on %s" % [signal_name, node_path]}}

	# If this peer already watching, disconnect first
	if _watch_states.has(pid) and _watch_states[pid].get("active", false):
		_do_watch_disconnect(pid)

	var previous_events: Array = []
	if _watch_states.has(pid) and (_watch_states[pid].get("events") as Array).size() > 0:
		previous_events = (_watch_states[pid]["events"] as Array).duplicate(true)

	# Set state before resolving callable
	_watch_states[pid] = {
		"active": false,
		"node_path": node_path,
		"signal_name": signal_name,
		"events": [],
		"max_events": max_events,
		"connected": false,
	}
	# P3-6: push 模式注册(watch.start 带 push:true 时启用主动推送)
	if bool(params.get("push", false)):
		_push_peers[pid] = true

	var callable := _get_watch_callable(pid)
	var err := node.connect(signal_name, callable)
	if err != OK:
		_watch_states.erase(pid)
		return {"error": {"code": -5, "message": "Failed to connect signal: %s (error %d)" % [signal_name, err]}}

	_watch_states[pid]["active"] = true
	_watch_states[pid]["connected"] = true

	var result_dict: Dictionary = {
		"watching": true,
		"node_path": node_path,
		"signal_name": signal_name,
		"max_events": max_events,
	}
	if previous_events.size() > 0:
		result_dict["previous_events"] = previous_events
	return result_dict


func _cmd_watch_stop(pid: int) -> Variant:
	if not _watch_states.has(pid):
		return {"watching": false, "events": [], "event_count": 0, "message": "No active watch for this peer"}
	var ws: Dictionary = _watch_states[pid]
	_do_watch_disconnect(pid)
	ws["active"] = false
	var events := (ws["events"] as Array).duplicate(true)
	var duration := 0.0
	if events.size() > 0:
		duration = events[events.size() - 1].get("time", 0.0) - events[0].get("time", 0.0)
	var result_dict: Dictionary = {
		"watching": false,
		"events": events,
		"event_count": events.size(),
		"node_path": str(ws.get("node_path", "")),
		"signal_name": str(ws.get("signal_name", "")),
		"duration_seconds": duration,
	}
	_watch_states.erase(pid)
	return result_dict


func _cmd_watch_poll(pid: int) -> Variant:
	if not _watch_states.has(pid) or not _watch_states[pid].get("active", false):
		return {"watching": false, "events": [], "message": "No active watch for this peer"}
	var ws: Dictionary = _watch_states[pid]
	var events := (ws["events"] as Array).duplicate(true)
	return {
		"watching": true,
		"node_path": str(ws.get("node_path", "")),
		"signal_name": str(ws.get("signal_name", "")),
		"events": events,
		"event_count": events.size(),
	}


# C-07: cleanup per-peer state on disconnect
func _cleanup_peer_state(pid: int) -> void:
	if _watch_states.has(pid):
		_do_watch_disconnect(pid)
		_watch_states.erase(pid)
	if _monitor_states.has(pid):
		_monitor_states.erase(pid)
	# P3-6: 清理 push 模式注册
	_push_peers.erase(pid)
	# 2026-08-06 审查 P1 修复：playtest physics 锁 peer 断线时必须 restore，否则
	# Engine.physics_ticks_per_second 等全局值永久停留在测试值（游戏变慢到测试 hz 无法恢复）。
	# 2026-08-07 审查 P2 修复：多 peer 场景下只在该 pid 是 playtest 持有者时才还原全局状态，
	# 否则 peer B 断开会误清 peer A 的 physics 锁/snapshot（_playtest_owner_pid 在
	# _cmd_playtest_seed/_cmd_playtest_fixed_delta 时赋值）。
	if pid == _playtest_owner_pid:
		if not _playtest_fixed_delta_saved.is_empty():
			Engine.physics_ticks_per_second = int(_playtest_fixed_delta_saved["physics_ticks_per_second"])
			Engine.max_physics_steps_per_frame = int(_playtest_fixed_delta_saved["max_physics_steps_per_frame"])
			Engine.physics_jitter_fix = float(_playtest_fixed_delta_saved["physics_jitter_fix"])
			_playtest_fixed_delta_saved.clear()
		# 2026-08-07 审查 P1 修复：snapshot 同属 playtest 全局状态，peer 断开必须同步 clear。
		# 否则：(1) _playtest_snapshot（可达 50000 节点×N 属性，数十 MB）永久驻留内存（泄漏）；
		# (2) 后续新 peer 调 playtest.restore 误读到这份陈旧快照，场景已变 → 节点状态损坏。
		if not _playtest_snapshot.is_empty():
			_playtest_snapshot.clear()
		# 2026-08-14 审查 D-4 修复：_playtest_active 复位移出 fixed_delta 分支（与 snapshot.clear
		# 同级）——seed-only/snapshot-only 周期同样要复位。残留 true 会令 _input 跳过录制，
		# recording.start 表面成功但录不到任何事件（静默失效）。
		_playtest_active = false
		_playtest_owner_pid = -1
	# G1 (2026-08-13) control-first:持有者断开时还原 freeze(防游戏永久暂停)+ 清 step_until pending
	if pid == _control_owner_pid:
		_control_frozen = false
		_control_owner_pid = -1
		# 2026-08-14 审查 D-2 修复:还原游戏自身 paused 原值(freeze/开窗介入前保存),
		# 而非硬设 false——覆盖 step_until 开窗中(owner 持有但非 frozen)断线的场景。
		get_tree().paused = _control_paused_saved
		_control_paused_saved = false
		_control_paused_saved_valid = false
		_control_step_until_pending.clear()
	# 清理断线 peer 的 pending step entries（防 _process 继续递减无效 frames_remaining）
	if _playtest_step_pending.size() > 0:
		var i: int = _playtest_step_pending.size() - 1
		while i >= 0:
			var entry: Dictionary = _playtest_step_pending[i]
			if int(entry.get("pid", -1)) == pid:
				_playtest_step_pending.remove_at(i)
			i -= 1


# ─── UI discovery commands ──────────────────────────────────────────────

func _extract_ui_data(ctrl: Control) -> Dictionary:
	var data: Dictionary = {
		"path": str(ctrl.get_path()),
		"type": ctrl.get_class(),
		"visible": ctrl.visible,
		"position": {"x": ctrl.position.x, "y": ctrl.position.y},
		"size": {"x": ctrl.size.x, "y": ctrl.size.y},
		"center": {"x": ctrl.position.x + ctrl.size.x / 2.0, "y": ctrl.position.y + ctrl.size.y / 2.0},
	}
	if ctrl is BaseButton:
		data["text"] = str(ctrl.get("text")) if ctrl.get("text") != null else ""
		data["disabled"] = ctrl.disabled
	elif ctrl is Label:
		data["text"] = ctrl.text
	elif ctrl is Range:
		data["value"] = ctrl.value
		data["min_value"] = ctrl.min_value
		data["max_value"] = ctrl.max_value
		if ctrl is SpinBox:
			data["editable"] = ctrl.editable
	elif ctrl is LineEdit:
		data["text"] = ctrl.text
		data["editable"] = ctrl.editable
		data["max_length"] = ctrl.max_length
	elif ctrl is OptionButton:
		data["text"] = ctrl.text
		data["item_count"] = ctrl.item_count
		var items: Array = []
		for i in range(ctrl.item_count):
			items.append(ctrl.get_item_text(i))
		data["items"] = items
	elif ctrl is ItemList:
		data["item_count"] = ctrl.item_count
	return data


func _cmd_find_ui_elements(params: Dictionary) -> Variant:
	var pattern: String = str(params.get("pattern", ""))
	var type_filter: String = str(params.get("type", ""))
	var visible_only: bool = params.get("visible_only", true)
	var max_results: int = int(params.get("limit", 200))
	if max_results > 500:
		max_results = 500

	# A-06: 复用 _traverse_tree + callback 过滤
	var results: Array = _traverse_tree(
		func(node: Node) -> bool:
			if not node is Control:
				return false
			var ctrl: Control = node as Control
			if visible_only and not ctrl.visible:
				return false
			if pattern != "":
				var text_to_match := ""
				if "text" in ctrl:
					text_to_match = str(ctrl.get("text"))
				if not ctrl.name.match(pattern) and not text_to_match.match(pattern):
					return false
			if type_filter != "" and not ctrl.is_class(type_filter):
				return false
			return true,
		{"max_results": max_results, "max_visited": 5000}
	)

	var extracted: Array = []
	for node in results:
		extracted.append(_extract_ui_data(node as Control))
	return {"elements": extracted, "count": extracted.size()}


func _cmd_click_button(params: Dictionary) -> Variant:
	var text: String = str(params.get("text", ""))
	var path: String = str(params.get("path", ""))

	var target: BaseButton = null

	if path != "":
		var node := get_node_or_null(path)
		if node == null:
			return {"error": {"code": -1, "message": "Node not found: %s" % path}}
		if not node is BaseButton:
			return {"error": {"code": -2, "message": "Node is not a Button: %s (type: %s)" % [path, node.get_class()]}}
		target = node as BaseButton
	elif text != "":
		var _tree = get_tree()
		if _tree == null:
			return {"error": {"code": -1, "message": "Scene tree not available"}}
		var stack: Array = [_tree.root]
		while stack.size() > 0:
			var node: Node = stack.pop_back()
			# Traverse children first so disabled parents don't block child discovery
			for child in node.get_children():
				stack.append(child)
			if node is BaseButton:
				var btn: BaseButton = node as BaseButton
				if btn.disabled:
					continue  # I-02: skip disabled buttons
				var btn_text := str(btn.get("text")) if btn.get("text") != null else ""
				if btn_text == text and btn.visible:
					target = btn
					break
		if target == null:
			return {"error": {"code": -3, "message": "No visible Button with text \"%s\" found" % text}}
	else:
		return {"error": {"code": -4, "message": "Either text or path is required"}}

	# I-02: skip disabled buttons
	if target.disabled:
		return {"error": {"code": -5, "message": "Button is disabled: %s" % str(target.get_path())}}

	target.emit_signal("pressed")
	return {
		"clicked": true,
		"button_path": str(target.get_path()),
		"button_text": str(target.get("text")) if target.get("text") != null else "",
	}


# ─── P2-4 确定性 playtest 四原语 ─────────────────────────────────────────────
# seed/fixed_delta/snapshot/restore 同步(不需 await 帧);
# step 走 coroutine(await get_tree().physics_frame),响应延迟 push(见 _process 末尾)。
# 5 个 accept 限制(spec):① 不保信号连接运行时拓扑 ② Resource 用 resource_path ③ 不复活已 free 节点
# ④ 不保 RigidBody 物理速度(靠 seed+fixed_delta 重放) ⑤ monitor samples 不在 snapshot 范围

func _cmd_playtest_seed(params: Dictionary, pid: int) -> Variant:
	# 2026-08-14 审查 D-3 修复：owner 互斥（对齐 freeze :2076-2078）——其他 peer 已持有
	# playtest 时拒绝，防 peer B 静默抢占 owner 覆盖全局 RNG 破坏 peer A 的确定性重放。
	if _playtest_owner_pid != -1 and _playtest_owner_pid != pid:
		return {"error": {"code": -1, "message": "playtest session held by another session (owner_pid=%d)" % _playtest_owner_pid}}
	var seed_value: int = int(params.get("seed", 0))
	seed(seed_value)  # @GlobalScope.seed,影响全局 randi/randf
	_playtest_active = true
	# 2026-08-07 审查 P2 修复：记录 playtest 持有者，_cleanup_peer_state 只在 owner 断开时还原
	_playtest_owner_pid = pid
	return {"success": true, "seed": seed_value, "note": "global RNG seeded (per-instance RandomNumberGenerator unaffected)"}

func _cmd_playtest_fixed_delta(params: Dictionary, pid: int) -> Variant:
	# 2026-08-14 审查 D-3 修复：owner 互斥（同 _cmd_playtest_seed，防抢占 physics 锁）
	if _playtest_owner_pid != -1 and _playtest_owner_pid != pid:
		return {"error": {"code": -1, "message": "playtest session held by another session (owner_pid=%d)" % _playtest_owner_pid}}
	var hz: int = int(params.get("hz", 60))
	if hz < 1 or hz > 1000:
		return {"error": {"code": -1, "message": "hz must be 1-1000, got %d" % hz}}
	# 保存原值(restore 时还原)
	if _playtest_fixed_delta_saved.is_empty():
		_playtest_fixed_delta_saved = {
			"physics_ticks_per_second": Engine.physics_ticks_per_second,
			"max_physics_steps_per_frame": Engine.max_physics_steps_per_frame,
			"physics_jitter_fix": Engine.physics_jitter_fix,
		}
	# 三连:固定 tick 率 + 单帧单步 + 关 jitter(每帧恰好 1 个 physics tick,delta = 1/hz)
	Engine.physics_ticks_per_second = hz
	Engine.max_physics_steps_per_frame = 1
	Engine.physics_jitter_fix = 0.0
	_playtest_active = true
	# 2026-08-07 审查 P2 修复：记录 playtest 持有者（同 _cmd_playtest_seed）
	_playtest_owner_pid = pid
	return {"success": true, "hz": hz, "delta": 1.0 / float(hz)}

const PLAYTEST_SNAPSHOT_HARD_STOP: int = 50000  # 对齐 _cmd_get_scene_stats 上限，防大场景 OOM/栈溢

func _cmd_playtest_snapshot(params: Dictionary, pid: int) -> Variant:
	# 2026-08-14 审查 D-3 修复：snapshot-only peer 也登记 owner（首个 playtest 操作者语义）。
	# 此前 snapshot 不登记 → snapshot-only peer 断线走不到 `pid == _playtest_owner_pid`
	# 清理分支 → 数十 MB 快照永久驻留 + 陈旧快照被新 peer restore 写坏场景。
	if _playtest_owner_pid == -1:
		_playtest_owner_pid = pid
	# 复用 _cmd_get_node_properties 序列化器:遍历场景树,每个节点存 {properties, parent}
	_playtest_snapshot.clear()
	var root := get_tree().root
	_collect_node_snapshot(root, "")
	var truncated: bool = _playtest_snapshot.size() >= PLAYTEST_SNAPSHOT_HARD_STOP
	return {"success": true, "nodes": _playtest_snapshot.size(), "truncated": truncated, "note": "snapshot saved (signals/physics/freed nodes not preserved)"}

func _collect_node_snapshot(node: Node, parent_path: String) -> void:
	# 2026-08-06 审查 P1 修复：节点数上限守卫，防大场景递归栈溢出/OOM
	# （对齐 _cmd_get_scene_stats HARD_STOP=50000 模式）
	if _playtest_snapshot.size() >= PLAYTEST_SNAPSHOT_HARD_STOP:
		push_warning("[mcp_bridge] playtest snapshot hit HARD_STOP=%d, truncating (large scene may OOM)" % PLAYTEST_SNAPSHOT_HARD_STOP)
		return
	var path: String = str(node.get_path())
	var props: Dictionary = {}
	for prop in node.get_property_list():
		var name: String = prop["name"]
		if name.begins_with("_") or name.begins_with("theme_override") or name in BLOCKED_PROPERTIES:
			continue
		var val: Variant = node.get(name)
		if val is Resource:
			val = {"type": val.get_class(), "path": val.resource_path if val.resource_path else ""}
		elif val is Node:
			val = str(val.get_path())
		# 2026-08-07 审查 P2 修复：同 _cmd_get_node_properties(:823)，非安全 Object 子类
		# 进 snapshot dict 会致后续 JSON.stringify 整体失败。读取场景用 continue 跳过。
		if not _is_safe_value(val):
			continue
		props[name] = val
	_playtest_snapshot[path] = {"properties": props, "parent": parent_path}
	for child in node.get_children():
		_collect_node_snapshot(child, path)

func _cmd_playtest_restore(params: Dictionary, pid: int) -> Variant:
	# 2026-08-14 审查 D-3 修复：restore 受 owner 互斥约束（全局快照属 owner，防任意 peer
	# 抢先 restore 把他人快照写进场景）。
	if _playtest_owner_pid != -1 and _playtest_owner_pid != pid:
		return {"error": {"code": -1, "message": "playtest session held by another session (owner_pid=%d)" % _playtest_owner_pid}}
	if _playtest_snapshot.is_empty():
		return {"error": {"code": -1, "message": "No snapshot saved. Call playtest_snapshot first."}}
	var restored: int = 0
	var skipped_freed: int = 0
	for path in _playtest_snapshot.keys():
		var entry: Dictionary = _playtest_snapshot[path]
		var node := get_node_or_null(path)
		if node == null:
			skipped_freed += 1  # 限制 ③:不复活已 free 节点
			continue
		var props: Dictionary = entry["properties"]
		for prop_name in props.keys():
			if prop_name in BLOCKED_PROPERTIES:
				continue  # 安全命脉:restore 跳过 BLOCKED_PROPERTIES(防 script 注入 RCE)
			# 2026-08-07 审查 P1 修复：snapshot 时 _collect_node_snapshot(:1718-1721) 把
			# Resource 转成 {"type":..,"path":..} 字典、Node 转成路径 String。restore 必须
			# 反向转换，否则字典/字符串原样 set 给 Resource/Node 类型属性 → 类型不匹配 →
			# 节点 invisible / mesh 缺失 / 状态损坏（playtest restore 对真实场景基本不可用）。
			var val: Variant = props[prop_name]
			if val is Dictionary and val.has("type") and val.has("path"):
				# Resource 占位：按 resource_path load 回来；空 path 或 load 失败则跳过不损坏
				var res_path: String = String(val["path"])
				if res_path.is_empty():
					continue
				var r: Resource = load(res_path)
				if r != null:
					val = r
				else:
					continue  # Resource load 失败（路径变/资源删），跳过不损坏原属性
			elif val is String and String(val).begins_with("/root/"):
				# Node 引用占位：跨 restore 无法复活（原节点可能已 free/路径变），跳过不损坏
				continue
			node.set(prop_name, val)
		restored += 1
	# 还原 fixed_delta 原值
	if not _playtest_fixed_delta_saved.is_empty():
		Engine.physics_ticks_per_second = int(_playtest_fixed_delta_saved["physics_ticks_per_second"])
		Engine.max_physics_steps_per_frame = int(_playtest_fixed_delta_saved["max_physics_steps_per_frame"])
		Engine.physics_jitter_fix = float(_playtest_fixed_delta_saved["physics_jitter_fix"])
		_playtest_fixed_delta_saved.clear()
	# 2026-08-14 审查 D-4 修复：restore 完成 = playtest 周期结束，复位 _playtest_active。
	# 此前 seed→restore 后残留 true → _input 持续跳过录制 → recording.start 静默失效。
	_playtest_active = false
	return {"success": true, "restored": restored, "skipped_freed": skipped_freed}

func _cmd_playtest_step(params: Dictionary) -> Dictionary:
	# 2026-08-14 审查 D-6 修复：frozen 守卫——冻结中 step 的帧递减不感知 paused，
	# 游戏未推进却返 success（假成功）。入口明确报错，引导先 unfreeze。
	if _control_frozen:
		return {"error": {"code": -1, "message": "game is frozen; unfreeze before stepping"}}
	# step 走延迟响应:_handle_message 返回哨兵字符串,_process_buffer_bytes 存 pending,
	# _process 每帧递减 frames_remaining(I-2 修复:加入帧不递减,下一帧起计),到 0 时 push 响应。
	# 非真 await physics_frame coroutine(bridge TCP 同步模型不支持),而是 _process 计数器轮询,
	# 每个递减对应一次 _process 调用 ≈ 推进一帧(physics 在 _process 前由引擎跑)。
	var frames: int = int(params.get("frames", 1))
	if frames < 1 or frames > 60:
		return {"error": {"code": -1, "message": "frames must be 1-60, got %d" % frames}}
	return {"__playtest_step__": true, "frames": frames}


# ─── G1 (2026-08-13) control-first satellite 层(附录 F.1)─────────────────
# freeze/unfreeze/step_until:借鉴 satellite mcp_game_bridge.gd,叠加到 enhanced determinism-first。
# process_mode=PROCESS_MODE_ALWAYS(_ready 设)保证 freeze 时 bridge _process 继续。
# step_until 用结构化条件 {path,property,op,value}[](AND),不引入 Expression(规避白名单绕过 + RCE)。
const _CONTROL_MAX_FRAMES := 600  # step_until 帧上限(~10s@60fps)
const _CONTROL_DEFAULT_WALL_BUDGET_MS := 30000  # wall 兜底(防 time_scale=0/暂停饿死)
const _CONTROL_ALLOWED_OPS := ["==", "!=", "<", ">", "<=", ">="]

func _cmd_control_freeze(params: Dictionary, pid: int) -> Dictionary:
	# owner 独占:已有其他 owner 持有 → 拒(防多 peer 冲突)
	if _control_owner_pid != -1 and _control_owner_pid != pid:
		return {"error": {"code": -1, "message": "control layer held by another session (owner_pid=%d)" % _control_owner_pid}}
	_control_owner_pid = pid
	# 2026-08-14 审查 D-2 修复:freeze 前保存游戏自身 paused 原值(在置 true 之前)。
	# saved_valid 防"冻结中重复 freeze"把维持中的 true 覆盖真实原值。
	if not _control_paused_saved_valid:
		_control_paused_saved = get_tree().paused
		_control_paused_saved_valid = true
	_control_frozen = true
	get_tree().paused = true  # freeze:每帧 _process 重设(防游戏代码解 pause)
	return {"success": true, "frozen": true}

func _cmd_control_unfreeze(params: Dictionary, pid: int) -> Dictionary:
	# 仅 owner 可 unfreeze(防 peer B 误清 peer A 的 freeze)
	if _control_owner_pid != -1 and _control_owner_pid != pid:
		return {"error": {"code": -1, "message": "control layer held by another session (owner_pid=%d)" % _control_owner_pid}}
	_control_frozen = false
	_control_owner_pid = -1
	# 2026-08-14 审查 D-1 (P1) 修复:unfreeze 即放弃控制,必须清 step_until pending。
	# 否则残留 pending 完成时会 refreeze(重新置 frozen+paused)而 owner 已=-1,
	# 游戏永久暂停无人能解(owner 断线路径 _cleanup_peer_state 已有 clear,此路径
	# 此前漏了,两路径不对称)。
	_control_step_until_pending.clear()
	# 2026-08-14 审查 D-2 修复:还原游戏自身 paused 原值,而非硬设 false
	# (防游戏暂停菜单/回合制自身暂停状态被清——菜单开着但游戏在跑)。
	# Nit-A (2026-08-14 审查补修):仅 saved_valid 时才还原 paused——(a) 从未 freeze
	# (owner=-1 放行)直接 unfreeze;(b) 非 refreeze step_until 完成已清 S/V 后 owner
	# 空转持有期间游戏自行 paused。两种边缘下无有效原值,无条件还原会把游戏自暂停
	# 清成过期的 false。S/V 清除不受守卫影响(无论是否还原都要清)。
	if _control_paused_saved_valid:
		get_tree().paused = _control_paused_saved
	_control_paused_saved = false
	_control_paused_saved_valid = false
	return {"success": true, "frozen": false}

func _cmd_control_step_until(params: Dictionary, pid: int) -> Dictionary:
	# owner 独占
	if _control_owner_pid != -1 and _control_owner_pid != pid:
		return {"error": {"code": -1, "message": "control layer held by another session (owner_pid=%d)" % _control_owner_pid}}
	var conditions: Variant = params.get("conditions", [])
	if not (conditions is Array) or conditions.size() == 0:
		return {"error": {"code": -1, "message": "conditions must be a non-empty array of {path,property,op,value}"}}
	# 校验每个 condition(结构化,不引入 Expression)
	var validated: Array = []
	for cond in conditions:
		if not (cond is Dictionary):
			return {"error": {"code": -1, "message": "each condition must be an object {path,property,op,value}"}}
		var cdict: Dictionary = cond
		if not (cdict.has("path") and cdict.has("property") and cdict.has("op") and cdict.has("value")):
			return {"error": {"code": -1, "message": "condition missing required key (path/property/op/value)"}}
		var op := str(cdict["op"])
		if not _CONTROL_ALLOWED_OPS.has(op):
			return {"error": {"code": -1, "message": "op must be one of %s, got %s" % [str(_CONTROL_ALLOWED_OPS), op]}}
		if not _is_safe_value(cdict["value"]):
			return {"error": {"code": -1, "message": "condition value failed _is_safe_value (几何/标量/PackedArray only)"}}
		validated.append(cdict)
	var max_frames: int = int(params.get("max_frames", _CONTROL_MAX_FRAMES))
	if max_frames < 1 or max_frames > _CONTROL_MAX_FRAMES:
		return {"error": {"code": -1, "message": "max_frames must be 1-%d, got %d" % [_CONTROL_MAX_FRAMES, max_frames]}}
	var wall_budget_ms: int = int(params.get("wall_budget_ms", _CONTROL_DEFAULT_WALL_BUDGET_MS))
	# 2026-08-14 审查 D-5 修复：上限压 50s（clamp）。等待期 bridge 无字节往来，60s 会被
	# 同文件 INACTIVITY_TIMEOUT=60.0 idle 断连切断（响应丢失+状态突变），压到 50s 留 10s 余量。
	wall_budget_ms = clampi(wall_budget_ms, 1000, 50000)
	# step_until:临时解 pause 开窗让游戏跑(若原 frozen,记 refreeze 完成时恢复)。
	# _process 每帧求值 conditions,满足/帧尽/wall 超时 → push 响应 + (若 refreeze)re-freeze。
	var refreeze: bool = _control_frozen
	_control_owner_pid = pid
	# 2026-08-14 审查 D-2 修复:开窗前若无有效保存则记录当前 paused(refreeze 周期已由
	# freeze 保存;非 refreeze 周期此处保存的即游戏自身原值),供完成/断线还原点恢复。
	if not _control_paused_saved_valid:
		_control_paused_saved = get_tree().paused
		_control_paused_saved_valid = true
	_control_frozen = false  # 临时解:让 _process 不维持 paused,游戏跑
	get_tree().paused = false  # 开窗
	return {"__playtest_control_step_until__": true, "conditions": validated, "max_frames": max_frames, "wall_budget_ms": wall_budget_ms, "refreeze": refreeze}

# 结构化条件求值:actual op target(标量/String/Vector,不引入 Expression)
func _compare_values(actual: Variant, op: String, target: Variant) -> bool:
	if actual is float or actual is int:
		var a: float = float(actual)
		var t: float = float(target)
		match op:
			"==": return is_equal_approx(a, t)
			"!=": return not is_equal_approx(a, t)
			"<": return a < t
			">": return a > t
			"<=": return a <= t
			">=": return a >= t
	if actual is String or actual is bool:
		match op:
			"==": return str(actual) == str(target)
			"!=": return str(actual) != str(target)
			"<": return str(actual) < str(target)
			">": return str(actual) > str(target)
			"<=": return str(actual) <= str(target)
			">=": return str(actual) >= str(target)
	if actual is Vector2 or actual is Vector3:
		# N-1 修复(审查):Vector 属性 value 必须是标量(按 length 比)或 Vector,否则 return false
		# (防 Array/Dict value 经 float() 静默转 0.0 致条件永不满足、静默耗尽帧/wall)
		if not (target is int or target is float or target is Vector2 or target is Vector3):
			return false
		var len_a: float = 0.0
		var len_t: float = 0.0
		if actual is Vector2:
			len_a = (actual as Vector2).length()
			len_t = float(target) if not (target is Vector2) else (target as Vector2).length()
		else:
			len_a = (actual as Vector3).length()
			len_t = float(target) if not (target is Vector3) else (target as Vector3).length()
		match op:
			"==": return is_equal_approx(len_a, len_t)
			"!=": return not is_equal_approx(len_a, len_t)
			"<": return len_a < len_t
			">": return len_a > len_t
			"<=": return len_a <= len_t
			">=": return len_a >= len_t
	# 其他类型(Color/Rect 等):仅 == / !=(str 比较)
	match op:
		"==": return str(actual) == str(target)
		"!=": return str(actual) != str(target)
		_: return false  # 不支持 < > 等于非标量/Vector


func _input(event: InputEvent) -> void:
	if not _recording:
		return
	# P2-4: playtest 激活时跳过录制,避免 playtest 注入的输入污染录制序列
	if _playtest_active:
		return
	# Note: field is 'time_offset' (renamed from 'time_ms' in v0.18.0).
	# Existing recordings with 'time_ms' field are incompatible.
	var time_ms: int = Time.get_ticks_msec() - _record_start_time
	if event is InputEventKey:
		_recorded_events.append({"type": "key", "keycode": event.keycode, "pressed": event.pressed, "shift": event.shift_pressed, "ctrl": event.ctrl_pressed, "alt": event.alt_pressed, "time_offset": time_ms})
	elif event is InputEventMouseButton:
		_recorded_events.append({"type": "mouse_click", "position": [event.position.x, event.position.y], "button": event.button_index, "pressed": event.pressed, "time_offset": time_ms})
	elif event is InputEventMouseMotion:
		_recorded_events.append({"type": "mouse_move", "position": [event.position.x, event.position.y], "time_offset": time_ms})
	elif event is InputEventScreenTouch:  # IMP-11: 触摸事件录制(对齐 recording_commands.gd :46 + _cmd_send_touch 契约)
		_recorded_events.append({"type": "touch", "position": [event.position.x, event.position.y], "pressed": event.pressed, "index": event.index, "time_offset": time_ms})
	elif event is InputEventScreenDrag:  # IMP-11 补全: 拖拽录制(对齐 recording_commands.gd + _cmd_send_drag 契约)
		_recorded_events.append({"type": "touch_drag", "position": [event.position.x, event.position.y], "index": event.index, "relative": [event.relative.x, event.relative.y], "speed": [event.speed.x, event.speed.y], "time_offset": time_ms})


## 内联安全类型检查（替代 SafeValues 类引用，autoload 环境无法引用 safe_values.gd）
## C-03: Keep in sync with src/scripts/safe_values.gd — that is the canonical source.
## 覆盖 JSON 反序列化可产生的类型 + StringName（GDScript 内部调用）
const _MAX_SAFE_DEPTH := 10

func _is_safe_value(value: Variant, depth: int = 0) -> bool:
	if value == null:
		return true
	if value is bool or value is int or value is float or value is String or value is StringName:
		return true
	# Keep in sync with safe_values.gd — geometric + PackedArray types
	if value is Vector2 or value is Vector2i or value is Vector3 or value is Vector3i:
		return true
	if value is Color or value is Rect2 or value is Rect2i:
		return true
	if value is Transform2D or value is Transform3D or value is Basis or value is Quaternion:
		return true
	if value is Plane or value is AABB:
		return true
	if value is PackedByteArray or value is PackedInt32Array or value is PackedInt64Array:
		return true
	if value is PackedFloat32Array or value is PackedFloat64Array or value is PackedStringArray:
		return true
	if value is PackedVector2Array or value is PackedVector3Array or value is PackedColorArray:
		return true
	if depth >= _MAX_SAFE_DEPTH:
		return false
	if value is Array:
		for item in value:
			if not _is_safe_value(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not _is_safe_value(key, depth + 1) or not _is_safe_value(value[key], depth + 1):
				return false
		return true
	return false


# ─── CMP-2 (2026-08-08): runtime error 捕获 Logger 子类 ──────────────────────
# 竞品 game_error_log.gd 验证过的设计:re-entrancy guard 防 error storm 递归、
# rationale 优先于 code(Godot 把错误文本拆两段)、ring buffer pop_front、
# 只捕 SCRIPT/SHADER/WARNING 放过普通 print。
# 不放 backtrace 深栈:Godot 4 _script_backtraces 是扁平字符串数组解析不可靠,
# 首帧(function/file/line)已在 _log_error 参数,够用。
class _ErrorCapture extends Logger:
	const MAX_ENTRIES := 200
	const MAX_TEXT_LEN := 4096  # NIT-4: 截断超长 message/code/function/file 防撑爆 MAX_MESSAGE_SIZE

	var _entries: Array[Dictionary] = []
	var _seq := 0
	var _in_log := false  # re-entrancy guard:push_error 递归触发 logger 再触发 error 会卡死

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		if _in_log:
			return
		# 捕获全部 4 种错误类型(ERROR/SCRIPT/SHADER/WARNING)。
		# NIT-1 (2026-08-08 第三方审查): 补 ERROR_TYPE_ERROR 覆盖引擎层运行时错误
		# (null 解引用/API 误用/FileAccess 失败/callv 参数错误),超越竞品只捕 SCRIPT/SHADER/WARNING。
		# 注意:_log_error 不被普通 print() 触发(走 _log_message),这里不会收到 print。
		if error_type != ERROR_TYPE_ERROR and error_type != ERROR_TYPE_SCRIPT and error_type != ERROR_TYPE_SHADER and error_type != ERROR_TYPE_WARNING:
			return
		# GD-R2/IPC-R7 (2026-08-08): GDScript 无 try/finally,引擎错误绕过控制流。
		# 把所有有风险操作(substr/append/pop_front)集中到 _capture_entry 辅助方法,
		# 主方法 _log_error 用两行明确控制 _in_log——除非 _capture_entry 内部引擎错误
		# (绕过 GDScript 控制流,此时整个 capture 子系统已失效,与现状无异),
		# 否则 _in_log = false 必达。消除"GDScript 可达的提前退出路径致 _in_log 卡死 true"。
		_in_log = true
		_capture_entry(function, file, line, code, rationale, error_type)
		_in_log = false

	# GD-R2/IPC-R7: 辅助方法——集中所有有风险操作(substr/append/pop_front)。
	# 普通方法正常情况必然返回(GDScript 无异常机制);构建 entry 全程用局部变量,
	# 仅成功构建后才 append 到 _entries,最小化副作用。
	func _capture_entry(function: String, file: String, line: int, code: String, rationale: String, error_type: int) -> void:
		_seq += 1
		var kind := "warning"
		if error_type == ERROR_TYPE_ERROR:
			kind = "error"
		elif error_type == ERROR_TYPE_SCRIPT:
			kind = "script"
		elif error_type == ERROR_TYPE_SHADER:
			kind = "shader"
		# rationale 是引擎错误的人话描述,code 是 push_error 的原始文本;前者更可读。
		# NIT-4 (2026-08-08 第三方审查): 截断防超长文本撑爆 MAX_MESSAGE_SIZE。
		var msg := (rationale if rationale != "" else code).substr(0, MAX_TEXT_LEN)
		var code_clipped := code.substr(0, MAX_TEXT_LEN)
		_entries.append({
			"seq": _seq,
			"kind": kind,
			"message": msg,
			"code": code_clipped,
			"function": function.substr(0, MAX_TEXT_LEN),
			"file": file.substr(0, MAX_TEXT_LEN),
			"line": line,
		})
		if _entries.size() > MAX_ENTRIES:
			_entries.pop_front()

	# 增量查询:返回 seq > since_seq 的条目 + 下次查询用的 next_seq 游标。
	# clear=true 在查询后清空 buffer(读即焚,适合 AI 确认已处理完旧错误)。
	func poll(since_seq: int, clear: bool) -> Dictionary:
		var out: Array = []
		for e in _entries:
			if int(e["seq"]) > since_seq:
				out.append(e)
		var next := _seq
		if clear:
			_entries.clear()
		return {"errors": out, "next_seq": next}

	func clear() -> void:
		_entries.clear()
