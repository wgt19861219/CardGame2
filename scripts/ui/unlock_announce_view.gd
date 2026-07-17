class_name UnlockAnnounceView
extends PopWindow

## unlock 功能解锁公告（View 层）— 照源 announce.lua create/show/destroy（:59-190）
## + tutorialmaker.createExhibitionLayer（:80-113）+ tutorialres class.<step>（:809-1005）。
## 结构：半透黑底（点击关闭）+ container（scale 弹出/关闭）+ unlock_bg 底图 + lettherebelight 光晕旋转
## + icon 静态图标（icon_res step）/ fca 降级（本项目 Spine 未在 UI 落地，留 TODO）+ 解锁文案。
## 触发：PlayerData.check_unlocks → EventBus.feature_unlocked → main_scene 弹此 View。

# 源 announce.lua:130/172 CCScaleTo(0.2, 1/0) + CCEaseBackOut/In
const ANIM_DURATION: float = 0.2
# 源 tutorialmaker.lua:104 CCRotateBy:create(5, 360) 光晕旋转
const LIGHT_ROTATE_TIME: float = 5.0
# 源 createExhibitionLayer 用图（assets 齐）
const RES_BG: String = "res://assets/ui/alpha/HVGA/unlock_bg.png"
const RES_LIGHT: String = "res://assets/ui/alpha/HVGA/lettherebelight.png"
# fca_res step 的 atlas 静态图（照源 createExhibitionLayer 调 createFcaNode(fca_res) 不传 aniType →
# else LegendAminationEffect → Spine 资源 fallback createStaticSpriteFromSpineAtlas 取最大 region，
# resource_manager.lua:595/548-558）。Spine 动画的正确用途是 main_scene aniType=1 按钮（见 main_scene.gd）。
const SPINE_DIR: String = "res://assets/spine"
# panel 子节点相对偏移（源 cocos ccp 布局 → Godot 居中重排，视觉验收校准）
const PANEL_W: int = 500
const LIGHT_OFFSET: Vector2 = Vector2(-150.0, 0.0)
const LABEL_OFFSET: Vector2 = Vector2(60.0, 0.0)
const LABEL_WIDTH: int = 320
# 布局比例/尺寸常量（源 cocos 坐标 → Godot 居中重排）
const HALF: float = 0.5
const LIGHT_X_RATIO: float = 0.3
const FONT_SIZE: int = 20
const LABEL_HEIGHT: int = 40
# 源 hello.lua:311 setContentScaleFactor=1.28125，cocos CCSprite 显示=texture/CS。
# 源 tutorialmaker.lua:84/96/100 createSprite（unlock_bg/icon_res/lettherebelight）全无 fix_size → sprite 显示=tex/CS。
# Godot TextureRect 默认 KEEP_SIZE 用纹理原始尺寸偏大 1.28，/CS 等价源显示。
const CONTENT_SCALE: float = 1.28125

var _panel: Control = null
var _light: TextureRect = null
var _light_tween: Tween = null


## 源 announce.show + createExhibitionLayer：按 step 配置建 panel + 弹出动画。
func show_step(step: StringName, parent: Node) -> void:
	var cfg: Dictionary = TutorialData.get_unlock_config(step)
	if cfg.is_empty():
		push_warning("UnlockAnnounceView: step '%s' 无配置" % String(step))
		queue_free()
		return
	if _panel == null:
		_setup_panel(cfg)
	show_window(parent)
	if _panel != null:
		_panel.scale = Vector2.ZERO
		var tw: Tween = create_tween()
		tw.tween_property(_panel, "scale", Vector2.ONE, ANIM_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_start_light_rotate()


# 源 createExhibitionLayer :80-113：panel(unlock_bg + light + icon + label)。
func _setup_panel(cfg: Dictionary) -> void:
	setup()  # PopWindow 建 shade + container
	shade_layer.gui_input.connect(_on_shade_input)
	# panel 居中（源 CCSprite container 锚点 0.5/0.5），子节点相对屏幕中心偏移
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2.ZERO
	container.add_child(_panel)
	# bg unlock_bg（源 :84-86）
	var bg: TextureRect = _make_texture(RES_BG)
	bg.position = -bg.size * HALF
	_panel.add_child(bg)
	# light lettherebelight 旋转（源 :100-106，所有 step 都显示）
	_light = _make_texture(RES_LIGHT)
	_light.position = bg.position + Vector2(bg.size.x * LIGHT_X_RATIO, bg.size.y * HALF - _light.size.y * HALF) + LIGHT_OFFSET
	_light.pivot_offset = _light.size * HALF
	_panel.add_child(_light)
	# icon/fca（源 :95-98）：createExhibitionLayer 调 createFcaNode(fca_res) 不传 aniType →
	# else LegendAminationEffect → Spine 资源 fallback createStaticSpriteFromSpineAtlas 最大 region 静态图。
	# icon step 用静态图标。两者互斥（fca step 无 icon）。
	if cfg.has("fca_res"):
		var fca_icon: TextureRect = _make_static_from_atlas(String(cfg["fca_res"]))
		if fca_icon != null:
			fca_icon.position = _light.position + (_light.size - fca_icon.size) * HALF
			_panel.add_child(fca_icon)
	elif cfg.has("icon"):
		var icon: TextureRect = _make_texture(String(cfg["icon"]))
		icon.position = _light.position + (_light.size - icon.size) * HALF
		_panel.add_child(icon)
	# label 解锁文案（源 :107-110）
	var label: Label = Label.new()
	label.text = String(cfg.get("text", ""))
	label.add_theme_color_override("font_color", TutorialData.UNLOCK_FONT_COLOR)
	label.add_theme_font_size_override("font", FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size = Vector2(LABEL_WIDTH, LABEL_HEIGHT)
	label.position = bg.position + Vector2(bg.size.x * HALF, bg.size.y * HALF - LABEL_HEIGHT * HALF) + LABEL_OFFSET
	_panel.add_child(label)


func _make_texture(res_path: String) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	var tex: Texture2D = load(res_path)
	if tex != null:
		rect.texture = tex
		# 源 tutorialmaker.lua:84/96 createSprite 无 fix_size → sprite 显示=texture/CS
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.size = tex.get_size() / CONTENT_SCALE
	return rect


# 源 createFcaNode 不传 aniType → else LegendAminationEffect → Spine 资源 fallback
# createStaticSpriteFromSpineAtlas（resource_manager.lua:525-571）：解析 .atlas 取最大 region 显示静态图。
# Shop_Star 本项目 spine/ 无资源（FCA .abc 在 anim_frames/effect/，未移植 LegendAminationEffect）→ load_atlas 失败返 null 降级。
func _make_static_from_atlas(res_name: String) -> TextureRect:
	var atlas := SpineAtlas.new()
	var atlas_path: String = SPINE_DIR + "/" + res_name + "/" + res_name + ".atlas"
	if not atlas.load_atlas(atlas_path):
		push_warning("UnlockAnnounceView: atlas 加载失败（源走 FCA，本项目降级）: " + res_name)
		return null
	var tex: Texture2D = atlas.get_largest_region_texture()
	if tex == null:
		push_warning("UnlockAnnounceView: atlas 无 region: " + res_name)
		return null
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	# 源 createFcaNode 不传 aniType → else LegendAminationEffect → createStaticSpriteFromSpineAtlas
	# 取最大 region 静态显示（无 fix_size），等价 sprite 显示=texture/CS。
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = tex.get_size() / CONTENT_SCALE
	return rect


# 源 announce.lua:104 doMainLayerTouch ended → destroy。
func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_destroy()


# 源 announce.lua:152-189 destroy：scale→0 EASE_BACK_IN + removeFromParent。
func _destroy() -> void:
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
	if _panel != null:
		var tw: Tween = create_tween()
		tw.tween_property(_panel, "scale", Vector2.ZERO, ANIM_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(remove_window)
	else:
		remove_window()


# 源 tutorialmaker.lua:104-106 CCRotateBy 360°/5s 循环。
func _start_light_rotate() -> void:
	if _light == null:
		return
	_light_tween = create_tween().set_loops()
	_light_tween.tween_property(_light, "rotation", TAU, LIGHT_ROTATE_TIME)


# 退出停 tween 防泄漏。
func _exit_tree() -> void:
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
