extends Node

## 一次性自动取证（关卡选择箭头/星数居中问题 2026-08-31）：
## 注入进度（stage1=3星 passed、stage2=0 current）→ 构造 StageSelectPanel →
## dump pointer/btn/star_bg/star 真实渲染坐标（全局+局部+size）→ 截图。
## 分析用：星相对 star_bg 中心偏移、star_bg 相对 btn 中心偏移、pointer 相对 btn 中心偏移。

const StageSelectPanel = preload("res://scripts/ui/stage_select_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	if pd == null:
		push_error("QA_AUTO: player null")
		return
	pd.tutorial_manager.skip_all()
	# 进度注入（多轮取证）：
	# A/B/复验轮：{1:3, 2:0} —— stage1 key passed 带星 + stage2 current 带 pointer
	# B 轮：{1:3, 2:3, 3:3} —— stage4（eid=10002 key 关）current
	# 四轮（2026-09-01 反证用户「小据点挤」）：{1:3, 2:3, 3:3} —— stage2/3 passed=elite
	# 圆盘，对齐原版全通关截图的存档状态（原版截图 stage2/3 也是圆盘非立绘）
	pd.stage_manager.progress = {1: 3, 2: 3, 3: 3}
	await get_tree().process_frame   # 脱离 autoload busy 窗口

	var rng := BattleRng.new(12345)
	var panel: Control = StageSelectPanel.new("stageselect", {})
	panel.setup_panel(pd.stage_manager, pd, rng)
	panel.show_window(get_tree().root)
	await get_tree().create_timer(1.0).timeout   # 等入场 + pointer bob 启动

	# pointer（当前关指针=用户说的"关卡进度的箭头"）在 clip layer 下，带 bob tween，
	# position 是局部值；读 global_position 一锤定音。TextureButton 不是 TextureRect
	# 子类，纹理与 meta 分开设法（as TextureRect 会得 null）。
	for node in _walk(panel):
		var is_rect: bool = node is TextureRect
		var is_btn: bool = node is TextureButton
		if not (is_rect or is_btn):
			continue
		var ci: CanvasItem = node as CanvasItem
		var tex_path: String = ""
		if is_rect:
			var t: Texture2D = (node as TextureRect).texture
			if t != null and t.resource_path != "":
				tex_path = t.resource_path.get_file()
		else:
			var t2: Texture2D = (node as TextureButton).texture_normal
			if t2 != null and t2.resource_path != "":
				tex_path = t2.resource_path.get_file()
		var meta_keys: Array = []
		for mk in ["ss_pointer", "ss_mask", "ss_bobbed"]:
			if node.has_meta(mk):
				meta_keys.append(mk + "=" + str(node.get_meta(mk)))
		print("QA_AUTO: node=", node.name, " type=", node.get_class(), " tex=", tex_path,
			" size=", snappedf(ci.size.x, 0.01), "x", snappedf(ci.size.y, 0.01),
			" pos_local=", _v2s(ci.position), " gpos=", _v2s(ci.global_position),
			" center_g=", _v2s(ci.global_position + ci.size * 0.5),
			" ", " ".join(meta_keys))
	# stage_buttons meta 里的 info（pos 源坐标）
	var fills: Dictionary = panel.get("_stage_buttons")
	for sid in fills:
		var btn: Control = (fills[sid] as Control)
		var info: Dictionary = btn.get_meta("stage_info")
		print("QA_AUTO: stage btn sid=", sid, " src_pos=", info.get("pos"),
			" btn_size=", _v2s(btn.size), " btn_gcenter=", _v2s(btn.global_position + btn.size * 0.5))
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://qa_stage_select_fix.png")
	print("QA_AUTO: DONE")


func _walk(node: Node) -> Array:
	var out: Array = []
	_collect(node, out)
	return out


func _collect(node: Node, out: Array) -> void:
	for c in node.get_children():
		out.append(c)
		_collect(c, out)


func _v2s(v: Vector2) -> String:
	return "(" + str(snappedf(v.x, 0.1)) + "," + str(snappedf(v.y, 0.1)) + ")"
