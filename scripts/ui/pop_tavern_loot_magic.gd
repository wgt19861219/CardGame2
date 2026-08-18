class_name PopTavernLootMagic
extends RefCounted

## PopTavernLoot magic 圆阵 / 阴影 / loot 名字 Label helper（View 层）— 从 pop_tavern_loot.gd 拆出控 ≤400。
## 静态方法第一参 panel，照 EquipCraftInfoBtn / EquipCraftTree 静态拆分范式。
## 源 poptavernloot.lua:378-405 createMatrixContainerAnim + createMatrixAnim（圆阵呼吸）
## + :430-461 playMagicLootShadeAnim（magic 阴影 scale/move/fade）
## + :629-636 createLootAnim 尾部（loot 名字 Label 飞完后显）。

# ── P0 magic 圆阵（源 :378-405）──
const MAGIC_MATRIX_COCOS: Vector2 = Vector2(400.0, 230.0)
const MAGIC_MATRIX_SCALE: Vector2 = Vector2(1.2, 0.6)
const MAGIC_MATRIX_ROT_DEG: float = 30.0
const MAGIC_CIRCLE_1_RES: String = "res://assets/ui/alpha/HVGA/tavern_magicsoul_circle_1.png"
const MAGIC_CIRCLE_2_RES: String = "res://assets/ui/alpha/HVGA/tavern_magicsoul_circle_2.png"
const MAGIC_CIRCLE_2_OFFSET: Vector2 = Vector2(0.0, 60.0)
const MAGIC_MATRIX_FADEIN_SEC: float = 0.2
const MAGIC_MATRIX_BREATH_LOW: float = 100.0 / 255.0
const MAGIC_MATRIX_BREATH_HIGH: float = 1.0
const MAGIC_MATRIX_BREATH_SEC: float = 2.0
# ── P0 magic 阴影（源 :430-461）──
const MAGIC_SHADE_RES: String = "res://assets/ui/alpha/HVGA/tavern_magicsoul_item_bg.png"
const MAGIC_SHADE_DROP_OFFSET: Vector2 = Vector2(0.0, -60.0)
const MAGIC_SHADE_SEC: float = 0.2
const MAGIC_SHADE_FADE_SEC: float = 1.0
# ── P0 loot 名字（源 :629-636）──
const LOOT_NAME_FONT: int = 18
const LOOT_NAME_OFFSET: Vector2 = Vector2(0.0, -45.0)
const LOOT_NAME_MAX_W: float = 100.0
const LOOT_NAME_STROKE: Color = Color.BLACK
const LOOT_NAME_STROKE_SIZE: int = 2
const HERO_ID_MAX: int = 100
const DEFAULT_CIRCLE_SIZE: Vector2 = Vector2(200.0, 200.0)
const DEFAULT_SHADE_SIZE: Vector2 = Vector2(70.0, 70.0)


# 源 createMatrixContainerAnim: matrixContainer(ccp 400,230 scale 1.2,0.6) > circle_1(rot 30) + circle_2(rot 30 pos 0,60 hidden)。
# 淡入 0.2 后启呼吸（circle_1 fadeTo 100/255 循环 2s）。loot 飞圆阵之上。
# panel 提供 _loot_host（挂点）/ _g（坐标转换）/ create_tween（需在树内）。
static func create_matrix_container_anim(panel) -> void:
	if not ResourceLoader.exists(MAGIC_CIRCLE_1_RES):
		return
	var container := Control.new()
	container.position = panel._g(MAGIC_MATRIX_COCOS)
	container.scale = MAGIC_MATRIX_SCALE
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.modulate.a = 0.0
	panel._loot_host.add_child(container)
	var circle_1 := TextureRect.new()
	circle_1.texture = load(MAGIC_CIRCLE_1_RES) as Texture2D
	circle_1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	circle_1.size = TexDisplaySize.display_size(MAGIC_CIRCLE_1_RES) if circle_1.texture != null else DEFAULT_CIRCLE_SIZE
	circle_1.pivot_offset = circle_1.size * 0.5
	circle_1.position = -circle_1.size * 0.5
	circle_1.rotation = deg_to_rad(MAGIC_MATRIX_ROT_DEG)
	circle_1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(circle_1)
	# circle_2（star）源 :389-393 pos(0,60) rot 30 hidden（装饰，源未在 createMatrixAnim 显式 setVisible true，
	# 故保持源 hidden 不显——忠实源；如未来需 star 闪烁再补）。
	if ResourceLoader.exists(MAGIC_CIRCLE_2_RES):
		container.add_child(_make_circle_2())
	# 淡入后启呼吸（源 :395-403 sequence fin 0.2 → createMatrixAnim）。
	var tw: Tween = panel.create_tween()
	tw.tween_property(container, "modulate:a", 1.0, MAGIC_MATRIX_FADEIN_SEC)
	tw.tween_callback(start_matrix_breath.bind(panel, circle_1))


static func _make_circle_2() -> TextureRect:
	var circle_2 := TextureRect.new()
	circle_2.texture = load(MAGIC_CIRCLE_2_RES) as Texture2D
	circle_2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	circle_2.size = TexDisplaySize.display_size(MAGIC_CIRCLE_2_RES) if circle_2.texture != null else DEFAULT_CIRCLE_SIZE
	circle_2.pivot_offset = circle_2.size * 0.5
	# 源 y-up 60 → Godot y-down -60；anchor(0.5,0.5) → 中心定位偏移。
	circle_2.position = Vector2(-circle_2.size.x * 0.5, MAGIC_CIRCLE_2_OFFSET.y - circle_2.size.y * 0.5)
	circle_2.rotation = deg_to_rad(MAGIC_MATRIX_ROT_DEG)
	circle_2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle_2.visible = false
	return circle_2


# 源 createMatrixAnim: circle_1 fadeTo(2,100/255) ↔ fadeTo(2,255) 循环（呼吸）。
# static + panel 参：tween 需在树内 panel 上 create，bind circle_1 入 callback。
static func start_matrix_breath(panel, circle_1: TextureRect) -> void:
	if not is_instance_valid(circle_1) or not circle_1.is_inside_tree():
		return
	var tw: Tween = circle_1.create_tween().set_loops()
	tw.tween_property(circle_1, "modulate:a", MAGIC_MATRIX_BREATH_LOW, MAGIC_MATRIX_BREATH_SEC)
	tw.tween_property(circle_1, "modulate:a", MAGIC_MATRIX_BREATH_HIGH, MAGIC_MATRIX_BREATH_SEC)


# 源 playMagicLootShadeAnim: tavern_magicsoul_item_bg.png scale 0→1（0.2 SineIn）+ move drop→up 60px（0.2 SineOut）+ fadeout 1s。
# drop = loot_pos - 60；up = loot_pos。挂在 _loot_host（与 icon 同层，icon 飞其上）。
static func play_magic_loot_shade_anim(panel, index: int) -> void:
	if not ResourceLoader.exists(MAGIC_SHADE_RES) or index >= panel._loot_targets.size():
		return
	var up: Vector2 = panel._loot_targets[index]
	var dp: Vector2 = up + MAGIC_SHADE_DROP_OFFSET
	var shade := TextureRect.new()
	shade.texture = load(MAGIC_SHADE_RES) as Texture2D
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var sz: Vector2 = TexDisplaySize.display_size(MAGIC_SHADE_RES) if shade.texture != null else DEFAULT_SHADE_SIZE
	shade.size = sz
	shade.pivot_offset = sz * 0.5
	shade.position = dp - sz * 0.5
	shade.scale = Vector2.ZERO
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._loot_host.add_child(shade)
	var tw: Tween = panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(shade, "scale", Vector2.ONE, MAGIC_SHADE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(shade, "position", up - sz * 0.5, MAGIC_SHADE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# chain fadeout（源 :443 CCFadeOut 1s 后 removeFromParent）。
	var chain: Tween = panel.create_tween()
	chain.tween_property(shade, "modulate:a", 0.0, MAGIC_SHADE_FADE_SEC)
	chain.tween_callback(shade.queue_free)


# 源 createLootAnim 尾部 callback: hero→Unit[Display Name] / equip→Equip[Name]，pos loot_pos + (0,-45)，字号 18，描边黑 2。
# name 宽 > 100 → scale 100/w（源 :633-636）。挂 _loot_host（与 icon 同层）。
static func add_loot_name_label(panel, index: int) -> void:
	if index >= panel._loot_data.size() or index >= panel._loot_targets.size() or panel._cm == null:
		return
	var loot: Dictionary = panel._loot_data[index]
	var lid: int = int(loot.get("id", 0))
	var name_text: String = _lookup_name(panel._cm, lid)
	if name_text.is_empty():
		return
	var lbl := Label.new()
	lbl.text = name_text
	lbl.add_theme_font_size_override("font_size", LOOT_NAME_FONT)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", LOOT_NAME_STROKE)
	lbl.add_theme_constant_override("outline_size", LOOT_NAME_STROKE_SIZE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._loot_host.add_child(lbl)
	# 源 anchor(0.5,0.5) pos loot_pos + (0,-45) y-up → Godot y-down +45 偏移（loot 上方显名）。
	var min_size: Vector2 = lbl.get_minimum_size()
	lbl.pivot_offset = min_size * 0.5
	lbl.position = panel._loot_targets[index] + Vector2(LOOT_NAME_OFFSET.x, -LOOT_NAME_OFFSET.y) - min_size * 0.5
	# 源 :633-636 宽 > 100 → scale 100/w。
	if min_size.x > LOOT_NAME_MAX_W:
		lbl.scale = Vector2(LOOT_NAME_MAX_W / min_size.x, LOOT_NAME_MAX_W / min_size.x)


# hero: Unit[lid]["Display Name"] 经 LSTR（源表存 key、源运行时加载即翻译，同 ofbuy name 口径）；
# equip: Equip[lid].Name 经 LSTR（源 :580，多为 LSTR key）。
static func _lookup_name(cm: Variant, lid: int) -> String:
	if lid < HERO_ID_MAX:
		var display: String = str(cm.get_raw_table(&"Unit").get(str(lid), {}).get(&"Display Name", ""))
		if display != "" and cm.has_method("get_lstr"):
			return str(cm.get_lstr(display))   # 查无时 get_lstr 返回 key 本身 = 原值
		return display
	var raw_name: String = str(cm.get_raw_table(&"Equip").get(str(lid), {}).get(&"Name", ""))
	if not cm.has_method("get_lstr"):
		return raw_name
	var resolved: String = str(cm.get_lstr(raw_name))
	return resolved if resolved != raw_name else raw_name
