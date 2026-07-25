class_name UnlockAnnounceView
extends PopWindow

## unlock 功能解锁公告（View 层）— 照源 announce.lua create/show/destroy（:59-190）
## + tutorialmaker.createExhibitionLayer（:80-113）+ tutorialres class.<step>（:809-1005）。
## 结构：半透黑底（点击关闭）+ container（scale 弹出/关闭）+ unlock_bg 底图 + lettherebelight 光晕旋转
## + icon 静态图标（icon_res step）/ fca 降级（本项目 Spine 未在 UI 落地，留 TODO）+ 解锁文案。
## 触发：PlayerData.check_unlocks → EventBus.feature_unlocked → main_scene 弹此 View。
##
## 重构（2026-07-18，hero_detail 范式）：bg/light/label 静态节点搬
## scenes/ui/unlock_announce_view_content.tscn（位置/size 编辑器可视化调，offsets 照源公式算）；
## icon/fca 保留 procedural（不同 step 资源/降级路径不同，互斥二选一）。

const ANIM_DURATION: float = 0.2
const LIGHT_ROTATE_TIME: float = 5.0
# 静态节点子场景（%Bg/%Light/%Label 位置/size 固化；icon/fca 留 procedural 挂 _panel）
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/unlock_announce_view_content.tscn")
# fca_res step 的 atlas 静态图（照源 createExhibitionLayer 调 createFcaNode(fca_res) 不传 aniType →
# else LegendAminationEffect → Spine 资源 fallback createStaticSpriteFromSpineAtlas 取最大 region，
# resource_manager.lua:595/548-558）。Spine 动画的正确用途是 main_scene aniType=1 按钮（见 main_scene.gd）。
const SPINE_DIR: String = "res://assets/spine"
# 子节点对齐比例（.tscn offsets 已照源公式算；_light pivot 用 _light.size*HALF 算）
const HALF: float = 0.5
# label 字号（源 createTTF res.label_size）
const FONT_SIZE: int = 20
# Godot TextureRect 默认 KEEP_SIZE 用纹理原始尺寸偏大 1.28，/CS 等价源显示。
const CONTENT_SCALE: float = 1.28125

var _panel: Control = null
var _light: TextureRect = null
var _light_tween: Tween = null


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


# bg/light/label 从 .tscn instantiate（位置/size 可视化），icon/fca 保留 procedural。
func _setup_panel(cfg: Dictionary) -> void:
	setup()  # PopWindow 建 shade + container
	shade_layer.gui_input.connect(_on_shade_input)
	# panel 居中（UnlockContent 根节点 anchors_preset=8 已在 .tscn 设；container 子节点 position=0）
	_panel = CONTENT_SCENE.instantiate() as Control
	container.add_child(_panel)
	# light 旋转中心（源 CCRotateBy 360°/5s 绕 light 中心，.tscn size=300×300 → pivot=size/2）
	_light = _panel.get_node("%Light") as TextureRect
	_light.pivot_offset = _light.size * HALF
	# icon/fca（源 :95-98）：createExhibitionLayer 调 createFcaNode(fca_res) 不传 aniType →
	# else LegendAminationEffect → Spine 资源 fallback createStaticSpriteFromSpineAtlas 最大 region 静态图。
	# icon step 用静态图标。两者互斥（fca step 无 icon）。
	if cfg.has("fca_res"):
		var fca_icon: TextureRect = _make_static_from_atlas(String(cfg["fca_res"]))
		if fca_icon != null:
			# 居中于 light（源 icon_pos = light_pos + light 尺寸偏移）
			fca_icon.position = _light.position + (_light.size - fca_icon.size) * HALF
			_panel.add_child(fca_icon)
	elif cfg.has("icon"):
		var icon: TextureRect = _make_texture(String(cfg["icon"]))
		# 居中于 light（源 icon_pos = light_pos + light 尺寸偏移）
		icon.position = _light.position + (_light.size - icon.size) * HALF
		_panel.add_child(icon)
	# label 解锁文案（源 :107-110，text/fontColor/fontSize 动态 fill；位置/size 在 .tscn 固化）
	var label: Label = _panel.get_node("%Label") as Label
	label.text = String(cfg.get("text", ""))
	label.add_theme_color_override("font_color", TutorialData.UNLOCK_FONT_COLOR)
	label.add_theme_font_size_override("font", FONT_SIZE)


# icon_res step 静态 TextureRect（源 tutorialmaker.lua:96 createSprite 无 fix_size → sprite 显示=texture/CS）
func _make_texture(res_path: String) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	var tex: Texture2D = load(res_path)
	if tex != null:
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.size = TexDisplaySize.display_size(res_path)
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
	# 取最大 region 静态显示（无 fix_size），等价 sprite 显示=texture/CS。
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# atlas region 保留 tex.get_size()/CS：helper _base_size 会 load(resource_path) 得整图 ≠ region 尺寸
	# （resource_path 空时还会 fallback 45×45）。本项目 spine 未移植 → load_atlas 失败 return null，此分支降级死代码。
	# 未来 spine 移植后若需修正 ContentScale，须 helper 增加 display_size_for_tex(tex) 用 region 自身 get_size 做 base。
	rect.size = tex.get_size() / CONTENT_SCALE
	return rect


func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_destroy()


func _destroy() -> void:
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
	if _panel != null:
		var tw: Tween = create_tween()
		tw.tween_property(_panel, "scale", Vector2.ZERO, ANIM_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(remove_window)
	else:
		remove_window()


func _start_light_rotate() -> void:
	if _light == null:
		return
	_light_tween = create_tween().set_loops()
	_light_tween.tween_property(_light, "rotation", TAU, LIGHT_ROTATE_TIME)


# 退出停 tween 防泄漏。
func _exit_tree() -> void:
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
