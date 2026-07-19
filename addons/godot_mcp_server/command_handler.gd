extends Node

var _scene_commands: Node
var _node_commands: Node
var _test_commands: Node
var _export_commands: Node
var _particle_commands: Node
var _nav_commands: Node
var _animtree_commands: Node
var _sync_commands: Node
var _undo_manager: Node
var _editor_guards: Node
var _animation_commands: Node
var _recording_commands: Node
var _ui_commands: Node
var _asset_commands: Node

func setup(plugin: EditorPlugin) -> void:
	_undo_manager = preload("undo_manager.gd").new()
	_undo_manager.setup(plugin)
	add_child(_undo_manager)

	_editor_guards = preload("editor_guards.gd").new()
	_editor_guards.setup(plugin)
	add_child(_editor_guards)

	_scene_commands = preload("commands/scene_commands.gd").new()
	_scene_commands.setup(plugin, _undo_manager, _editor_guards)
	add_child(_scene_commands)

	_node_commands = preload("commands/node_commands.gd").new()
	_node_commands.setup(plugin, _undo_manager)
	add_child(_node_commands)

	_test_commands = preload("commands/test_commands.gd").new()
	_test_commands.setup(plugin)
	add_child(_test_commands)

	_export_commands = preload("commands/export_commands.gd").new()
	_export_commands.setup(plugin)
	add_child(_export_commands)

	_particle_commands = preload("commands/particle_commands.gd").new()
	_particle_commands.setup(plugin, _undo_manager)
	add_child(_particle_commands)

	_nav_commands = preload("commands/nav_commands.gd").new()
	_nav_commands.setup(plugin, _undo_manager)
	add_child(_nav_commands)

	_animtree_commands = preload("commands/animtree_commands.gd").new()
	_animtree_commands.setup(plugin, _undo_manager)
	add_child(_animtree_commands)

	_sync_commands = preload("commands/sync_commands.gd").new()
	_sync_commands.setup(self, plugin)
	add_child(_sync_commands)

	_animation_commands = preload("commands/animation_commands.gd").new()
	_animation_commands.setup(plugin, _undo_manager)
	add_child(_animation_commands)

	_recording_commands = preload("commands/recording_commands.gd").new()
	_recording_commands.setup(plugin)
	add_child(_recording_commands)

	_ui_commands = preload("commands/ui_commands.gd").new()
	_ui_commands.setup(plugin, _undo_manager)
	add_child(_ui_commands)

	_asset_commands = preload("commands/asset/asset_commands.gd").new()
	_asset_commands.setup(plugin, _undo_manager)
	add_child(_asset_commands)

func cleanup() -> void:
	var modules = [
		_sync_commands, _recording_commands, _animation_commands,
		_ui_commands, _asset_commands, _scene_commands, _node_commands,
		_test_commands, _export_commands, _particle_commands,
		_nav_commands, _animtree_commands, _undo_manager,
	]
	for node in modules:
		if node:
			if node.has_method("cleanup"):
				node.cleanup()
			node.queue_free()
	_sync_commands = null
	_recording_commands = null
	_animation_commands = null
	_ui_commands = null
	_asset_commands = null
	_scene_commands = null
	_node_commands = null
	_test_commands = null
	_export_commands = null
	_particle_commands = null
	_nav_commands = null
	_animtree_commands = null
	_undo_manager = null
	if _editor_guards:
		_editor_guards.queue_free()
		_editor_guards = null

func handle(method: String, params: Dictionary, request_id: int) -> Dictionary:
	match method:
		"open_scene":
			return _scene_commands.handle_open_scene(params)
		"save_scene":
			return _scene_commands.handle_save_scene(params)
		"instance_scene":
			return _scene_commands.handle_instance_scene(params)
		"set_instance_property":
			return _scene_commands.handle_set_instance_property(params, request_id)
		"add_node":
			return _node_commands.handle_add_node(params, request_id)
		"remove_node":
			return _node_commands.handle_remove_node(params, request_id)
		# editor-version-tear §5: edit_node / batch_add_nodes 经 editor-method-map 登记,
		# editor 连接时直走 node_commands handler（per-property undo / 批量 UndoRedo，改内存），
		# 不再 fallback headless spawnGodot 改盘（致磁盘/内存版本撕裂）
		"edit_node":
			return _node_commands.handle_edit_node(params, request_id)
		"batch_add_nodes":
			return _node_commands.handle_batch_add_nodes(params, request_id)
		"test_assert":
			return _test_commands.handle_test_assert(params)
		"export_list_presets":
			return _export_commands.handle_export_list_presets(params)
		"export_get_preset":
			return _export_commands.handle_export_get_preset(params)
		"export_build":
			return _export_commands.handle_export_build(params)
		"particles_create":
			return _particle_commands.handle_particles_create(params, request_id)
		"particles_set_emission":
			return _particle_commands.handle_particles_set_emission(params, request_id)
		"particles_set_process":
			return _particle_commands.handle_particles_set_process(params, request_id)
		"particles_load_preset":
			return _particle_commands.handle_particles_load_preset(params, request_id)
		"particles_set_material":
			return _particle_commands.handle_particles_set_material(params, request_id)
		"nav_create_region":
			return _nav_commands.handle_nav_create_region(params, request_id)
		"nav_bake_mesh":
			return _nav_commands.handle_nav_bake_mesh(params)
		"nav_create_agent":
			return _nav_commands.handle_nav_create_agent(params, request_id)
		"nav_set_params":
			return _nav_commands.handle_nav_set_params(params)
		"nav_create_link":
			return _nav_commands.handle_nav_create_link(params, request_id)
		"animtree_create":
			return _animtree_commands.handle_animtree_create(params, request_id)
		"animtree_add_state":
			return _animtree_commands.handle_animtree_add_state(params)
		"animtree_add_transition":
			return _animtree_commands.handle_animtree_add_transition(params)
		"animtree_set_blend":
			return _animtree_commands.handle_animtree_set_blend(params)
		"animtree_play":
			return _animtree_commands.handle_animtree_play(params)
		"editor_sync_start":
			return _sync_commands.start_sync()
		"editor_sync_stop":
			return _sync_commands.stop_sync()
		"editor_get_scene_tree":
			return _sync_commands.get_scene_tree()
		"editor_get_scene_stats":
			return _sync_commands.get_scene_stats()
		# --- animation ------------------------------------------------
		"animation_track":
			return _animation_commands.handle_animation_track(params, request_id)
		"animation_keyframe":
			return _animation_commands.handle_animation_keyframe(params, request_id)
		"animation_curve":
			return _animation_commands.handle_animation_curve(params, request_id)
		"animation_blend":
			return _animation_commands.handle_animation_blend(params, request_id)
		# --- recording ------------------------------------------------
		"recording_start":
			return _recording_commands.handle_recording_start(params)
		"recording_stop":
			return _recording_commands.handle_recording_stop(params)
		"recording_play":
			return _recording_commands.handle_recording_play(params)
		# --- ui -------------------------------------------------------
		"ui_create_control":
			return _ui_commands.handle_ui_create_control(params, request_id)
		"ui_set_layout":
			return _ui_commands.handle_ui_set_layout(params, request_id)
		"ui_get_layout":
			return _ui_commands.handle_ui_get_layout(params)
		"ui_anchor_preset":
			return _ui_commands.handle_ui_anchor_preset(params, request_id)
		"ui_set_theme":
			return _ui_commands.handle_ui_set_theme(params)
		"ui_container_add":
			return _ui_commands.handle_ui_container_add(params, request_id)
		"theme_create":
			return _ui_commands.handle_theme_create(params)
		"theme_set_property":
			return _ui_commands.handle_theme_set_property(params)
		# --- asset -----------------------------------------------------
		"asset_create":
			return _asset_commands.handle_create(params, request_id)
		"asset_path":
			return _asset_commands.handle_path(params, request_id)
		"asset_batch":
			return _asset_commands.handle_batch(params, request_id)
		"asset_undo":
			return _asset_commands.handle_undo(params, request_id)
		"asset_save":
			return _asset_commands.handle_save(params, request_id)
		# Tools NOT routed here (headless-only via TS/GDScript executor):
		#   animation (play/stop/seek/list_players) - runtime AnimationPlayer control
		#   recording_save / recording_load - file I/O handled by TS side
		#   ui_draw_recipe / ui_build_layout - complex declarative ops via GDScript exec
		# I-01: 文本资源写入守卫（TS 侧写入脚本/着色器前调用）
		"guard_text_resource_write":
			if _editor_guards == null:
				return {"error": {"code": -32003, "message": "Editor guards not available"}}
			var guard_path: String = params.get("path", "")
			# P1-7 (2026-07-06 RCE 审查): 忽略客户端 force — 防已认证 WS 客户端直传 force=true
			# 绕过文本资源写守卫。force 仅供服务端内部逻辑（如未来经 confirm_and_execute
			# 校验 confirm token 后才设 true），客户端 force 永远视为 false。
			var guard_result = _editor_guards.guard_text_resource_write(guard_path, false)
			if guard_result.is_empty():
				return {"result": {"status": "ok", "path": guard_path}}
			return guard_result
		# P1-2 (2026-07-06 review): 场景离线保存守卫 — TS 侧 scene save 写前调,
		# 防覆盖编辑器中打开的场景致磁盘/内存版本撕裂(与 guard_text_resource_write 对称)
		"guard_offline_scene_save":
			if _editor_guards == null:
				return {"error": {"code": -32003, "message": "Editor guards not available"}}
			var scene_guard_path: String = params.get("path", "")
			var scene_guard_result = _editor_guards.guard_offline_scene_save(scene_guard_path)
			if scene_guard_result.is_empty():
				return {"result": {"status": "ok", "path": scene_guard_path}}
			return scene_guard_result
		_:
			return {"error": {"code": -32601, "message": "Unknown method: %s" % method}}


func send_notification(method: String, params: Dictionary) -> void:
	# Forward to plugin's WebSocket/TCP notification channel
	var plugin = get_parent()
	if plugin and plugin.has_method("send_mcp_notification"):
		plugin.send_mcp_notification(method, params)

