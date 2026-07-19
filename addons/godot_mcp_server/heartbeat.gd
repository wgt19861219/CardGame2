extends Node

const PING_INTERVAL := 5.0
const INACTIVITY_TIMEOUT := 30.0

signal timeout_detected(peer_id: int)

# Per-peer activity: pid -> { activity, ping, paused, op_timeout, op_timer }
# security P1#1 fix: paused/op_timer 下沉 per-peer (原全局 _is_paused 致 tick 全局 return, 跳过所有 peer 的 inactivity 检测)
var _peer_activity: Dictionary = {}
var _ping_json: String = JSON.stringify({"jsonrpc": "2.0", "method": "ping", "params": {}})


func reset_activity(peer_id: int = -1) -> void:
	if peer_id == -1:
		for key in _peer_activity:
			_peer_activity[key].activity = 0.0
	else:
		if _peer_activity.has(peer_id):
			_peer_activity[peer_id].activity = 0.0


func remove_peer(peer_id: int) -> void:
	_peer_activity.erase(peer_id)


func _ensure_state(pid: int) -> Dictionary:
	if not _peer_activity.has(pid):
		_peer_activity[pid] = { "activity": 0.0, "ping": 0.0, "paused": false, "op_timeout": 0.0, "op_timer": 0.0 }
	return _peer_activity[pid]


func tick(delta: float, peer: WebSocketPeer) -> void:
	var pid: int = peer.get_instance_id()
	var state: Dictionary = _ensure_state(pid)
	# P1#1 fix: paused per-peer, 只跳过该 peer 检测, 其他 peer 照常累计 activity/触发超时
	if state.paused:
		state.op_timer += delta
		if state.op_timer > state.op_timeout:
			# P1#3 fix (2026-07-06 review): 暂停语义为容忍长操作跑完, 超时后应恢复 normal
			# 心跳检测, 而非 emit timeout_detected 断连(与暂停意图相反)。原实现 op_timer 到顶
			# 反 close peer — operation_start 一旦接线即爆(任何已认证 peer 可触发自损断连)。
			state.paused = false
			state.activity = 0.0
			state.ping = 0.0
		return
	state.activity += delta
	state.ping += delta
	if state.activity > INACTIVITY_TIMEOUT:
		emit_signal("timeout_detected", pid)
		return
	if state.ping >= PING_INTERVAL:
		state.ping = 0.0
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			peer.send_text(_ping_json)


func pause_for_operation(timeout_sec: float, peer_id: int = -1) -> void:
	# P1#1 fix: per-peer pause. peer_id>=0 只暂停目标 peer (其他 peer 检测不受影响)
	if peer_id == -1:
		for key in _peer_activity:
			_apply_pause(_peer_activity[key], timeout_sec)
	else:
		_apply_pause(_ensure_state(peer_id), timeout_sec)


func _apply_pause(state: Dictionary, timeout_sec: float) -> void:
	state.paused = true
	state.op_timeout = min(timeout_sec, 600.0)
	state.op_timer = 0.0


func resume(peer_id: int = -1) -> void:
	# P1#1 fix: per-peer resume. peer_id>=0 只 resume 目标 peer
	if peer_id == -1:
		for key in _peer_activity:
			_reset_peer(_peer_activity[key])
	else:
		if _peer_activity.has(peer_id):
			_reset_peer(_peer_activity[peer_id])


func _reset_peer(state: Dictionary) -> void:
	state.paused = false
	state.activity = 0.0
	state.ping = 0.0
	state.op_timer = 0.0
