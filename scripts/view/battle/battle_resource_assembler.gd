class_name BattleResourceAssembler
extends RefCounted

## 战斗场景资源标记装配（View helper）— 从 BattleScene 拆出控 ≤400。
## static 方法第一参 scene，照 equip_strengthen_anim.gd 静态拆分范式。
## 主类 _create_wave_mark/_create_resource_markers 转发本类。
## add_gold/add_loot_marker 是公开 API（被 BattleActor/BattleHeroPanel 调用），主类留转发桩。
##
## 坐标：原 to_godot(cx,cy)=(cx+80,560-cy) 已换算为 Godot 原生常量（HUD 顶部带 y≈120）。


const WAVE_MARK_POS: Vector2 = Vector2(460.0, 120.0)  # 原 to_godot(380,440)，波次标记 HUD 原生坐标
const GOLD_MARK_POS: Vector2 = Vector2(190.0, 120.0)  # 原 to_godot(110,440)，金标记 HUD 原生坐标
const LOOT_MARK_POS: Vector2 = Vector2(290.0, 120.0)  # 原 to_godot(210,440)，掉落标记 HUD 原生坐标


static func create_background(scene) -> void:
	for child in scene.background_layer.get_children():
		child.queue_free()
	var bg_name := String(scene.battle_info.get("Background Pic", ""))
	if bg_name.is_empty():
		return
	var bg_path := "res://assets/ui/alpha/HVGA/" + bg_name
	if not ResourceLoader.exists(bg_path):
		push_warning("[BattleScene] 背景图缺失: " + bg_path)
		return
	var bg_tex := load(bg_path) as Texture2D
	var bg_sprite := Sprite2D.new()
	bg_sprite.texture = bg_tex
	bg_sprite.centered = false
	bg_sprite.position = Vector2.ZERO
	bg_sprite.flip_h = bool(scene.battle_info.get("H Flip", false))
	scene.background_layer.add_child(bg_sprite)


static func create_wave_mark(scene) -> void:
	if scene.wave_mark != null:
		scene.wave_mark.queue_free()
	var node := Control.new()
	node.position = WAVE_MARK_POS
	var wave_id: int = int(scene.battle_info.get("Wave ID", 1))
	var lbl := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = 20
	ls.font_color = Color(1.0, 1.0, 1.0)
	lbl.label_settings = ls
	lbl.text = str(wave_id) + "/3"
	node.add_child(lbl)
	scene.hud.add_child(node)
	scene.wave_mark = node


static func create_resource_markers(scene) -> void:
	if scene.gold_marker != null:
		scene.gold_marker.queue_free()
	if scene.loot_marker != null:
		scene.loot_marker.queue_free()
	var gold := BattleResourceMarker.new()
	gold.setup(BattleResourceMarker.Kind.GOLD, GOLD_MARK_POS)
	scene.hud.add_child(gold)
	scene.gold_marker = gold
	var loot := BattleResourceMarker.new()
	loot.setup(BattleResourceMarker.Kind.LOOT, LOOT_MARK_POS)
	scene.hud.add_child(loot)
	scene.loot_marker = loot
	add_gold(scene, 0)
	add_loot_marker(scene, 0)


static func add_gold(scene, num: int) -> void:
	if scene.engine != null:
		scene.engine.gold_count = int(scene.engine.gold_count) + num
	if scene.gold_marker != null:
		var v: int = int(scene.engine.gold_count) if scene.engine != null else 0
		scene.gold_marker.set_value(v)
		if num > 0:
			scene.gold_marker.pulse_gold()


static func add_loot_marker(scene, num: int) -> void:
	if scene.engine != null:
		scene.engine.loot_count = int(scene.engine.loot_count) + num
	if scene.loot_marker != null:
		var v: int = int(scene.engine.loot_count) if scene.engine != null else 0
		scene.loot_marker.set_value(v)
		if num > 0:
			scene.loot_marker.pulse_loot()
