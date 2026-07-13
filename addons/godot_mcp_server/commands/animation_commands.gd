extends Node

var _plugin: EditorPlugin
var _undo_manager: Node

func setup(plugin: EditorPlugin, undo_manager: Node = null) -> void:
	_plugin = plugin
	_undo_manager = undo_manager

# ─── animation_track ────────────────────────────────────────────────────────

func handle_animation_track(params: Dictionary, request_id: int = 0) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_path: String = params.get("node_path", "")
	var player = CommandHelpers.find_node(root, node_path)
	if player == null:
		return {"error": {"code": -32002, "message": "AnimationPlayer not found: " + node_path}}
	if not (player is AnimationPlayer):
		return {"error": {"code": -32004, "message": "Node is not an AnimationPlayer: " + node_path}}

	var anim_name: String = params.get("animation_name", "")
	var anim = player.get_animation(anim_name) if anim_name != "" else null
	if anim == null:
		return {"error": {"code": -32004, "message": "Animation not found: " + anim_name}}

	var action: String = params.get("action", "")

	match action:
		"add":
			var track_type: String = params.get("track_type", "value")
			var type_map = {
				"value": Animation.TYPE_VALUE,
				"position_3d": Animation.TYPE_POSITION_3D,
				"rotation_3d": Animation.TYPE_ROTATION_3D,
				"scale_3d": Animation.TYPE_SCALE_3D,
				"blend_shape": Animation.TYPE_BLEND_SHAPE,
				"method": Animation.TYPE_METHOD,
				"bezier": Animation.TYPE_BEZIER,
				"audio": Animation.TYPE_AUDIO,
				"animation": Animation.TYPE_ANIMATION,
			}
			if not type_map.has(track_type):
				return {"error": {"code": -32004, "message": "Invalid track_type: " + track_type}}
			var track_path: String = params.get("track_path", "")
			var idx = anim.get_track_count()  # 新轨道将追加到此索引
			var insert_at = params.get("insert_at")

			if _undo_manager != null:
				# Issue 7: 完整捕获 track add 的 do/undo
				var do_ops: Array = [
					{"type": "method", "target": anim, "method": "add_track", "args": [type_map[track_type]]},
				]
				if track_path != "":
					do_ops.append({"type": "method", "target": anim, "method": "track_set_path", "args": [idx, NodePath(track_path)]})
				if insert_at != null and int(insert_at) >= 0 and int(insert_at) < anim.get_track_count() + 1:
					do_ops.append({"type": "method", "target": anim, "method": "move_track", "args": [idx, int(insert_at)]})
					idx = int(insert_at)
				_undo_manager.create_action_mixed("Add Track (req:%d)" % request_id, do_ops, [
					{"type": "method", "target": anim, "method": "remove_track", "args": [idx]}
				])
			else:
				idx = anim.add_track(type_map[track_type])
				if track_path != "":
					anim.track_set_path(idx, track_path)
				if insert_at != null and int(insert_at) >= 0 and int(insert_at) < anim.get_track_count():
					anim.move_track(idx, int(insert_at))

			return {"result": {"animation": anim_name, "track_index": idx, "type": track_type, "status": "track_added"}}
		"remove":
			var track_index = params.get("track_index")
			if track_index == null:
				return {"error": {"code": -32004, "message": "track_index is required for remove"}}
			var ti = int(track_index)
			if ti < 0 or ti >= anim.get_track_count():
				return {"error": {"code": -32004, "message": "track_index out of range: " + str(ti)}}

			if _undo_manager != null:
				# Issue 7: 完整捕获旧轨道数据（类型、路径、位置、所有关键帧）
				var old_type: int = anim.track_get_type(ti)
				var old_path: NodePath = anim.track_get_path(ti)
				# 捕获所有关键帧
				var old_keys: Array = []
				for k in anim.track_get_key_count(ti):
					old_keys.append({
						"time": anim.track_get_key_time(ti, k),
						"value": anim.track_get_key_value(ti, k),
						"transition": anim.track_get_key_transition(ti, k),
					})
				# undo: add_track + set_path + insert keys + move_track 恢复位置
				var undo_ops: Array = [
					{"type": "method", "target": anim, "method": "add_track", "args": [old_type]},
				]
				# remove 执行后 count=N-1, add_track 追加到末尾索引=N-1
				# 但 remove 在 do 阶段执行，undo 时 track 已被移除，add_track 后索引 = get_track_count()-1
				var new_idx: int = anim.get_track_count() - 1
				if old_path:
					undo_ops.append({"type": "method", "target": anim, "method": "track_set_path", "args": [new_idx, old_path]})
				for key in old_keys:
					undo_ops.append({"type": "method", "target": anim, "method": "track_insert_key", "args": [new_idx, key.time, key.value, key.transition]})
				if new_idx != ti:
					undo_ops.append({"type": "method", "target": anim, "method": "move_track", "args": [new_idx, ti]})

				_undo_manager.create_action_mixed("Remove Track (req:%d)" % request_id, [
					{"type": "method", "target": anim, "method": "remove_track", "args": [ti]},
				], undo_ops)
			else:
				anim.remove_track(ti)

			return {"result": {"animation": anim_name, "track_index": ti, "status": "track_removed"}}
		_:
			return {"error": {"code": -32004, "message": "Invalid action: " + action + ". Must be: add, remove"}}

# ─── animation_keyframe ─────────────────────────────────────────────────────

func handle_animation_keyframe(params: Dictionary, request_id: int = 0) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_path: String = params.get("node_path", "")
	var player = CommandHelpers.find_node(root, node_path)
	if player == null:
		return {"error": {"code": -32002, "message": "AnimationPlayer not found: " + node_path}}
	if not (player is AnimationPlayer):
		return {"error": {"code": -32004, "message": "Node is not an AnimationPlayer: " + node_path}}

	var anim_name: String = params.get("animation_name", "")
	var anim = player.get_animation(anim_name) if anim_name != "" else null
	if anim == null:
		return {"error": {"code": -32004, "message": "Animation not found: " + anim_name}}

	var track_index = params.get("track_index")
	if track_index == null:
		return {"error": {"code": -32004, "message": "track_index is required"}}
	var ti = int(track_index)
	if ti < 0 or ti >= anim.get_track_count():
		return {"error": {"code": -32004, "message": "track_index out of range: " + str(ti)}}

	var action: String = params.get("action", "")

	match action:
		"add":
			var time = params.get("time")
			if time == null:
				return {"error": {"code": -32004, "message": "time is required for add"}}
			var value = params.get("value")
			var transition = params.get("transition")
			var trans_val = float(transition) if transition != null else 1.0
			var key_idx: int

			if _undo_manager != null:
				# Issue 2: 使用 _find_key_at_time 检查是否已存在关键帧
				var existing_idx = _find_key_at_time(anim, ti, float(time))
				if existing_idx >= 0:
					# upsert: 更新现有关键帧
					var old_val = anim.track_get_key_value(ti, existing_idx)
					var old_trans = anim.track_get_key_transition(ti, existing_idx)
					_undo_manager.create_action_mixed("Upsert Keyframe (req:%d)" % request_id, [
						{"type": "method", "target": anim, "method": "track_set_key_value", "args": [ti, existing_idx, value]},
						{"type": "method", "target": anim, "method": "track_set_key_transition", "args": [ti, existing_idx, trans_val]},
					], [
						{"type": "method", "target": anim, "method": "track_set_key_value", "args": [ti, existing_idx, old_val]},
						{"type": "method", "target": anim, "method": "track_set_key_transition", "args": [ti, existing_idx, old_trans]},
					])
					key_idx = existing_idx
				else:
					# 新增关键帧
					_undo_manager.create_action_mixed("Insert Keyframe (req:%d)" % request_id, [
						{"type": "method", "target": anim, "method": "track_insert_key", "args": [ti, float(time), value, trans_val]},
					], [
						# Issue 2 fix: undo 用 track_remove_key_at_time 而非错误的索引
						{"type": "method", "target": anim, "method": "track_remove_key_at_time", "args": [ti, float(time)]},
					])
					key_idx = _find_key_at_time(anim, ti, float(time))
			else:
				key_idx = anim.track_insert_key(ti, float(time), value, trans_val)

			return {"result": {"animation": anim_name, "track_index": ti, "keyframe_index": key_idx, "time": float(time), "status": "keyframe_added"}}
		"remove":
			var keyframe_index = params.get("keyframe_index")
			if keyframe_index == null:
				return {"error": {"code": -32004, "message": "keyframe_index is required for remove"}}
			var ki = int(keyframe_index)

			if _undo_manager != null:
				# 捕获旧关键帧数据用于 undo
				var old_time: float = anim.track_get_key_time(ti, ki)
				var old_val = anim.track_get_key_value(ti, ki)
				var old_trans: float = anim.track_get_key_transition(ti, ki)
				_undo_manager.create_action_mixed("Remove Keyframe (req:%d)" % request_id, [
					{"type": "method", "target": anim, "method": "track_remove_key", "args": [ti, ki]},
				], [
					{"type": "method", "target": anim, "method": "track_insert_key", "args": [ti, old_time, old_val, old_trans]},
				])
			else:
				anim.track_remove_key(ti, ki)

			return {"result": {"animation": anim_name, "track_index": ti, "keyframe_index": ki, "status": "keyframe_removed"}}
		"update":
			var keyframe_index = params.get("keyframe_index")
			if keyframe_index == null:
				return {"error": {"code": -32004, "message": "keyframe_index is required for update"}}
			var ki = int(keyframe_index)

			if _undo_manager != null:
				var old_val = anim.track_get_key_value(ti, ki)
				var old_trans: float = anim.track_get_key_transition(ti, ki)
				var old_time: float = anim.track_get_key_time(ti, ki)
				var do_ops: Array = []
				var undo_ops: Array = []
				var value = params.get("value")
				if value != null:
					do_ops.append({"type": "method", "target": anim, "method": "track_set_key_value", "args": [ti, ki, value]})
					undo_ops.append({"type": "method", "target": anim, "method": "track_set_key_value", "args": [ti, ki, old_val]})
				var transition = params.get("transition")
				if transition != null:
					do_ops.append({"type": "method", "target": anim, "method": "track_set_key_transition", "args": [ti, ki, float(transition)]})
					undo_ops.append({"type": "method", "target": anim, "method": "track_set_key_transition", "args": [ti, ki, old_trans]})
				var time = params.get("time")
				if time != null:
					do_ops.append({"type": "method", "target": anim, "method": "track_set_key_time", "args": [ti, ki, float(time)]})
					undo_ops.append({"type": "method", "target": anim, "method": "track_set_key_time", "args": [ti, ki, old_time]})
				if do_ops.size() > 0:
					_undo_manager.create_action_mixed("Update Keyframe (req:%d)" % request_id, do_ops, undo_ops)
			else:
				var value = params.get("value")
				if value != null:
					anim.track_set_key_value(ti, ki, value)
				var transition = params.get("transition")
				if transition != null:
					anim.track_set_key_transition(ti, ki, float(transition))
				var time = params.get("time")
				if time != null:
					anim.track_set_key_time(ti, ki, float(time))

			return {"result": {"animation": anim_name, "track_index": ti, "keyframe_index": ki, "status": "keyframe_updated"}}
		_:
			return {"error": {"code": -32004, "message": "Invalid action: " + action + ". Must be: add, remove, update"}}

# ─── animation_curve ────────────────────────────────────────────────────────
# Issue 3: 补充 UndoRedo

func handle_animation_curve(params: Dictionary, request_id: int = 0) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_path: String = params.get("node_path", "")
	var player = CommandHelpers.find_node(root, node_path)
	if player == null:
		return {"error": {"code": -32002, "message": "AnimationPlayer not found: " + node_path}}
	if not (player is AnimationPlayer):
		return {"error": {"code": -32004, "message": "Node is not an AnimationPlayer: " + node_path}}

	var anim_name: String = params.get("animation_name", "")
	var anim = player.get_animation(anim_name) if anim_name != "" else null
	if anim == null:
		return {"error": {"code": -32004, "message": "Animation not found: " + anim_name}}

	var track_index = params.get("track_index")
	var keyframe_index = params.get("keyframe_index")
	if track_index == null or keyframe_index == null:
		return {"error": {"code": -32004, "message": "track_index and keyframe_index are required"}}

	var ti = int(track_index)
	var ki = int(keyframe_index)
	if ti < 0 or ti >= anim.get_track_count():
		return {"error": {"code": -32004, "message": "track_index out of range: " + str(ti)}}
	if anim.track_get_type(ti) != Animation.TYPE_BEZIER:
		return {"error": {"code": -32004, "message": "Track is not a bezier track. Curve handles only apply to bezier tracks."}}

	# Issue 3: 捕获旧 curve handles 用于 undo
	var old_in = anim.track_get_key_in_handle(ti, ki)
	var old_out = anim.track_get_key_out_handle(ti, ki)
	var do_ops: Array = []
	var undo_ops: Array = []
	var updated: Array = []

	var in_handle = params.get("in_handle")
	if in_handle != null and in_handle is Dictionary:
		var in_vec = Vector2(float(in_handle.get("x", 0.0)), float(in_handle.get("y", 0.0)))
		do_ops.append({"type": "method", "target": anim, "method": "track_set_key_in_handle", "args": [ti, ki, in_vec]})
		undo_ops.append({"type": "method", "target": anim, "method": "track_set_key_in_handle", "args": [ti, ki, old_in]})
		updated.append("in_handle")

	var out_handle = params.get("out_handle")
	if out_handle != null and out_handle is Dictionary:
		var out_vec = Vector2(float(out_handle.get("x", 0.0)), float(out_handle.get("y", 0.0)))
		do_ops.append({"type": "method", "target": anim, "method": "track_set_key_out_handle", "args": [ti, ki, out_vec]})
		undo_ops.append({"type": "method", "target": anim, "method": "track_set_key_out_handle", "args": [ti, ki, old_out]})
		updated.append("out_handle")

	if _undo_manager != null and do_ops.size() > 0:
		_undo_manager.create_action_mixed("Set Curve Handle (req:%d)" % request_id, do_ops, undo_ops)
	else:
		# 无 undo_manager 时的回退逻辑
		if in_handle != null and in_handle is Dictionary:
			var in_vec = Vector2(float(in_handle.get("x", 0.0)), float(in_handle.get("y", 0.0)))
			anim.track_set_key_in_handle(ti, ki, in_vec)
		if out_handle != null and out_handle is Dictionary:
			var out_vec = Vector2(float(out_handle.get("x", 0.0)), float(out_handle.get("y", 0.0)))
			anim.track_set_key_out_handle(ti, ki, out_vec)

	return {"result": {"animation": anim_name, "track_index": ti, "keyframe_index": ki, "updated": updated, "status": "curve_set"}}

# ─── animation_blend ────────────────────────────────────────────────────────

func handle_animation_blend(params: Dictionary, request_id: int = 0) -> Dictionary:
	var root = CommandHelpers.get_edited_scene_root(_plugin)
	if root == null:
		return {"error": {"code": -32003, "message": "No scene currently open in editor"}}

	var node_path: String = params.get("node_path", "")
	var player = CommandHelpers.find_node(root, node_path)
	if player == null:
		return {"error": {"code": -32002, "message": "AnimationPlayer not found: " + node_path}}
	if not (player is AnimationPlayer):
		return {"error": {"code": -32004, "message": "Node is not an AnimationPlayer: " + node_path}}

	var anim_name: String = params.get("animation_name", "")
	if anim_name == "":
		return {"error": {"code": -32004, "message": "animation_name is required"}}

	var blend_time = params.get("blend_time")
	if blend_time == null:
		return {"error": {"code": -32004, "message": "blend_time is required"}}

	var speed = params.get("speed")
	var speed_val = float(speed) if speed != null else 1.0

	var ap: AnimationPlayer = player
	ap.play(anim_name, float(blend_time), speed_val, false)

	return {"result": {"animation": anim_name, "blend_time": float(blend_time), "speed": speed_val, "status": "blending"}}

# ─── Helpers ─────────────────────────────────────────────────────────────────

## Issue 2: 精确查找指定时间点的关键帧索引
func _find_key_at_time(anim: Animation, track_index: int, time: float) -> int:
	for key_index: int in anim.track_get_key_count(track_index):
		if is_equal_approx(anim.track_get_key_time(track_index, key_index), time):
			return key_index
	return -1
