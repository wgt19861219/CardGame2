extends Node

## 一次性自动取证（战斗英雄卡 portrait 补偿验证 2026-08-31）：
## 注入英雄 → assemble_stage_battle → BattleScene 挂 root → dump 卡 1 的
## FrameBtn/Container(桶)/portrait/星/两条 BattleHpBar 真实坐标 + 截图。

const GmManager = preload("res://scripts/systems/gm_manager.gd")
const BattleSceneScript = preload("res://scripts/view/battle/battle_scene.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	if pd == null:
		push_error("QA_AUTO: player null")
		return
	var cm: Variant = pd.cm
	pd.tutorial_manager.skip_all()
	GmManager.execute(pd, cm, {"_get_all_heroes": 1})
	var tids: Array = []
	var unit_table: Dictionary = cm.get_raw_table("Unit")
	for tid_str in unit_table.keys():
		var row: Dictionary = unit_table[tid_str]
		if String(row.get("Unit Type", "")) == "Hero" and row.has("Portrait"):
			tids.append(int(tid_str))
		if tids.size() >= 5:
			break
	var player_tids: Array[int] = []
	for t in tids:
		player_tids.append(int(t))
	var rng := BattleRng.new(12345)
	var asm: Dictionary = pd.stage_manager.assemble_stage_battle(1, pd, player_tids, rng)
	if not bool(asm.get("ok", false)):
		push_error("QA_AUTO: assemble 失败 " + str(asm))
		return
	await get_tree().process_frame   # 脱离 autoload busy 窗口（否则 root.add_child 被拒→hud._ready 不跑）
	var scene: Node = (load("res://scenes/battle/battle_scene.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(scene)   # tscn 实例（hud 固化，真实链路同构）先入树再 setup
	scene.setup(asm["engine"], cm, asm["battle_info"])
	await get_tree().create_timer(2.5).timeout   # 等入场 + hero panel 创建

	var eng2: Variant = asm["engine"]
	print("QA_AUTO: unit_list=", eng2.unit_list.size(), " hud=", scene.hud != null,
		" heroes_panel=", scene.heroes_panel)
	var n_hero: int = 0
	for u in eng2.unit_list:
		if int(u.camp) > 0 and bool(u.is_hero()):
			n_hero += 1
	print("QA_AUTO: player heroes=", n_hero)
	var panels: Dictionary = scene.get("_hero_panels") if scene.get("_hero_panels") != null else {}
	if panels.is_empty():
		print("QA_AUTO: hud.bottom_left=", scene.hud.bottom_left, " hud.children=", scene.hud.get_child_count())
		scene._create_heroes_panel()
		for u in eng2.unit_list:
			if int(u.camp) > 0 and bool(u.is_hero()):
				scene.add_hero_panel(u)
		panels = scene.get("_hero_panels")
		print("QA_AUTO: 手动补建后 panels=", panels.size())
		if panels.is_empty():
			return
	var panel: Control = null
	for k in panels.keys():
		panel = panels[k] as Control
		break
	_dump(panel)
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://qa_battle_hero_panel.png")
	print("QA_AUTO: DONE")


func _dump(panel: Control) -> void:
	if panel == null:
		return
	var frame: TextureButton = panel.find_children("FrameBtn", "TextureButton", true, false)[0] as TextureButton
	var host: Control = frame.get_parent() as Control
	var bucket: Sprite2D = host.get_node_or_null("Container") as Sprite2D
	var portrait: ReadheroIcon = null
	for c in host.get_children():
		if c is ReadheroIcon:
			portrait = c as ReadheroIcon
			break
	print("QA_AUTO: panel.global=", panel.global_position, " size=", panel.size)
	print("QA_AUTO: FrameBtn pos=", frame.position, " size=", frame.size,
		" center_global=", frame.global_position + frame.size * 0.5)
	if bucket != null:
		var bsz: Vector2 = bucket.texture.get_size() * bucket.scale.x
		print("QA_AUTO: Bucket pos=", bucket.position, " scale=", bucket.scale.x,
			" disp_size=", bsz, " center_global=", bucket.global_position)
	if portrait != null:
		var icon: Node2D = portrait.ori_icon
		print("QA_AUTO: Portrait pos=", portrait.position, " icon.local=", icon.position,
			" icon.global=", icon.global_position, " icon.tex_size=", icon.texture.get_size())
		for st in portrait.stars:
			print("QA_AUTO:   star local=", (st as Node2D).position, " global=", (st as Node2D).global_position)
	var bars: Array = panel.find_children("*", "Node2D", true, false)
	for b in bars:
		if b.get("_type") != null:
			var hp: Node2D = b as Node2D
			var bg: Sprite2D = hp.get_node_or_null("Sprite2D") as Sprite2D
			var bg_txt: String = "no-bg"
			if bg == null:
				for c in hp.get_children():
					if c is Sprite2D:
						bg = c as Sprite2D
						break
			if bg != null:
				bg_txt = "bg.scale=" + str(bg.scale) + " bg.global=" + str(bg.global_position) + " disp=" + str(bg.texture.get_size() * bg.scale.x)
			print("QA_AUTO: Bar ", hp.get("_type"), " pos=", hp.position,
				" center_global=", hp.global_position, " ", bg_txt)
	var vc: int = int(Engine.get_process_frames())
	print("QA_AUTO: frame=", vc)
