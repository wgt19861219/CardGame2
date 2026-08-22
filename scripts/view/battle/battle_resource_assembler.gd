class_name BattleResourceAssembler
extends RefCounted

## 战斗场景资源标记装配（View helper）— 从 BattleScene 拆出控 ≤400。
## static 方法第一参 scene，照 equip_strengthen_anim.gd 静态拆分范式。
## 主类 _create_wave_mark/_create_resource_markers 转发本类。
## add_gold/add_loot_marker 是公开 API（被 BattleActor/BattleHeroPanel 调用），主类留转发桩。
##
## 坐标：原 to_godot(cx,cy)=(cx+80,560-cy) 已换算为 Godot 原生常量（HUD 顶部带 y≈120）。


const WAVE_MARK_POS: Vector2 = Vector2(385.0, 20.0)   # 波次标记：y=20 与金/掉落同高，x 居中画面（用户布局）
const GOLD_MARK_POS: Vector2 = Vector2(20.0, 20.0)   # 金标记贴左上角（用户布局需求）
const LOOT_MARK_POS: Vector2 = Vector2(130.0, 20.0)  # 掉落标记贴左上角（金右侧，金宽100+间距10）
const BG_LAYER_NAME: String = "BackgroundLayer"        # 背景独立 CanvasLayer 节点名
const BG_LAYER_ORDER: int = -1                         # CanvasLayer layer 值：负值 → 渲染在 Node2D 世界画布（layer 0）之下


# 背景图挂独立 CanvasLayer（layer=-1，TextureRect 全屏 cover），不受 Camera2D DRAG_CENTER 偏移影响，
# 且渲染在 Node2D 世界画布（actor/特效）之下，不遮挡人物动画。
# 源 Axmol：CCLayer background_layer + createSprite setAnchorPoint(ccpZero) 原尺寸不缩放，
# 靠 1024×615 > 800×480 自然覆盖。Godot 800×480 屏小于纹理，KEEP_ASPECT_COVERED cover 缩小铺满。
static func create_background(scene) -> void:
	# 清旧背景（兼容历史：先清 background_layer Node2D 残留，再清独立 CanvasLayer）
	for child in scene.background_layer.get_children():
		child.queue_free()
	var old_layer: Node = scene.get_node_or_null(BG_LAYER_NAME)
	if old_layer != null:
		old_layer.queue_free()
	var bg_name := String(scene.battle_info.get("Background Pic", ""))
	if bg_name.is_empty():
		return
	var bg_path := "res://assets/ui/alpha/HVGA/" + bg_name
	if not ResourceLoader.exists(bg_path):
		push_warning("[BattleScene] 背景图缺失: " + bg_path)
		return
	var bg_tex := load(bg_path) as Texture2D
	# 独立 CanvasLayer（layer=-1）：不受 Camera2D 变换影响（CanvasLayer 有独立坐标），
	# 且 layer<0 保证渲染在 Node2D 世界画布（actor）之下。
	var bg_canvas := CanvasLayer.new()
	bg_canvas.name = BG_LAYER_NAME
	bg_canvas.layer = BG_LAYER_ORDER
	scene.add_child(bg_canvas)
	# TextureRect 全屏 cover：PRESET_FULL_RECT + EXPAND_IGNORE_SIZE + KEEP_ASPECT_COVERED
	# → 自动按屏幕(800×480)与纹理(1024×615)比例 cover 缩放铺满。
	var bg_rect := TextureRect.new()
	bg_rect.texture = bg_tex
	bg_rect.flip_h = bool(scene.battle_info.get("H Flip", false))
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_canvas.add_child(bg_rect)


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
	scene.hud.add_to_top_bar(node)
	scene.wave_mark = node


static func create_resource_markers(scene) -> void:
	if scene.gold_marker != null:
		scene.gold_marker.queue_free()
	if scene.loot_marker != null:
		scene.loot_marker.queue_free()
	var gold := BattleResourceMarker.new()
	gold.setup(BattleResourceMarker.Kind.GOLD, GOLD_MARK_POS)
	scene.hud.add_to_top_bar(gold)
	scene.gold_marker = gold
	var loot := BattleResourceMarker.new()
	loot.setup(BattleResourceMarker.Kind.LOOT, LOOT_MARK_POS)
	scene.hud.add_to_top_bar(loot)
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
