class_name BattleResourceAssembler
extends RefCounted

## 战斗场景资源标记装配（View helper）— 从 BattleScene 拆出控 ≤400。
## static 方法第一参 scene，照 equip_strengthen_anim.gd 静态拆分范式。
## 主类 _create_wave_mark/_create_resource_markers 转发本类。
## add_gold/add_loot_marker 是公开 API（被 BattleActor/BattleHeroPanel 调用），主类留转发桩。


static func create_wave_mark(scene) -> void:
	if scene.wave_mark != null:
		scene.wave_mark.queue_free()
	var node := Control.new()
	node.position = BattleViewCoords.to_godot(380.0, 440.0)
	var wave_id: int = int(scene.battle_info.get("Wave ID", 1))
	var lbl := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = 20
	ls.font_color = Color(1.0, 1.0, 1.0)
	lbl.label_settings = ls
	lbl.text = str(wave_id) + "/3"
	node.add_child(lbl)
	scene.ui_layer.add_child(node)
	scene.wave_mark = node


static func create_resource_markers(scene) -> void:
	if scene.gold_marker != null:
		scene.gold_marker.queue_free()
	if scene.loot_marker != null:
		scene.loot_marker.queue_free()
	var gold := BattleResourceMarker.new()
	gold.setup(BattleResourceMarker.Kind.GOLD, BattleViewCoords.to_godot(110.0, 440.0))
	scene.ui_layer.add_child(gold)
	scene.gold_marker = gold
	var loot := BattleResourceMarker.new()
	loot.setup(BattleResourceMarker.Kind.LOOT, BattleViewCoords.to_godot(210.0, 440.0))
	scene.ui_layer.add_child(loot)
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
