class_name DungeonDegreePopup
extends PopWindow

## 副本难度选择弹窗 — 照源 ui/dungeon_map.lua:316-580 showDegreePopup + popupTouchHandler。
## 单 boss 4 难度（diff 1 普通/2 精英/3 英雄/4 噩梦），点难度 → degree_selected；close/outLayer 关闭。
## 2026-07-18 重构：panel 层（Frame/TitleLabel/CloseBtn/DegreeHost）静态化进
## scenes/ui/dungeon_degree_popup_content.tscn（位置/size 编辑器可视化，照 hero_detail 范式）。
## 难度按钮（数量随 difficulties 变）保留 procedural 挂 %DegreeHost（HBox 容器）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/dungeon_degree_popup_content.tscn")
const FRAME_POS := Vector2(130.0, 170.0)
const FRAME_SIZE := Vector2(700.0, 300.0)
const BTN_SIZE := Vector2(130.0, 120.0)
const ICON_SIZE := Vector2(55.0, 55.0)
const GRAY_MODULATE := Color(0.4, 0.4, 0.4)

const BTN_BG := "res://assets/ui/alpha/HVGA/act/act_select_bg.png"
const BTN_BG_CHOSEN := "res://assets/ui/alpha/HVGA/act/act_select_bg_chosen.png"
const ICON_DIR := "res://assets/ui/alpha/HVGA/act/act_icon_difficulty_"
const VIT_BG_RES := "res://assets/ui/alpha/HVGA/act/act_comment_bg.png"
const VIT_ICON_RES := "res://assets/ui/alpha/HVGA/vitalityicon.png"
const VIT_BG_SIZE := Vector2(60.0, 30.0)
const VIT_ICON_SIZE := Vector2(30.0, 35.0)
const VIT_NUM_COLOR := Color(0.91, 0.84, 0.71)

var boss_idx: int = 0
var _content: Control = null              # .tscn 根（%Frame/TitleLabel/CloseBtn/DegreeHost 持有者）
var _degree_host: HBoxContainer = null    # .tscn %DegreeHost（难度按钮容器）

signal degree_selected(p_boss_idx: int, diff_data: Dictionary)
signal close_requested


func setup_popup(p_boss_idx: int, p_boss_name: String, p_difficulties: Array, p_player_level: int) -> void:
	boss_idx = p_boss_idx
	setup()
	_build_content(p_boss_name)
	_create_degree_buttons(p_difficulties, p_player_level)
	_play_entrance_scale()


# panel 层从 .tscn instantiate（位置/size .tscn 固化）+ fill title + connect close。
func _build_content(boss_name: String) -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	(_content.get_node("%TitleLabel") as Label).text = boss_name
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close)
	_degree_host = _content.get_node("%DegreeHost") as HBoxContainer


func _create_degree_buttons(difficulties: Array, player_level: int) -> void:
	for di in range(difficulties.size()):
		var diff: Dictionary = difficulties[di]
		var diff_num: int = int(diff["diff"])
		var unlocked: bool = int(diff["unlock_level"]) <= player_level
		_degree_host.add_child(_make_degree_button(diff, diff_num, unlocked))


func _make_degree_button(diff: Dictionary, diff_num: int, unlocked: bool) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	var btn := TextureButton.new()
	btn.texture_normal = _load_tex(BTN_BG)
	btn.texture_hover = _load_tex(BTN_BG_CHOSEN)
	btn.texture_disabled = _load_tex(BTN_BG)
	btn.custom_minimum_size = BTN_SIZE
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.modulate = GRAY_MODULATE if not unlocked else Color(1, 1, 1)
	btn.disabled = not unlocked
	btn.pressed.connect(Callable(self, "_on_degree_pressed").bind(diff))
	var icon := TextureRect.new()
	icon.texture = _load_tex(ICON_DIR + str(diff_num) + ".png")
	icon.position = Vector2((BTN_SIZE.x - ICON_SIZE.x) * 0.5, 10)
	icon.size = ICON_SIZE
	icon.ignore_texture_size = true
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	vbox.add_child(btn)
	vbox.add_child(_make_vit_row(diff, unlocked))
	return vbox


## 锁定态颜色由父 btn.modulate=GRAY_MODULATE 统一处理（源 :467-469 setSpriteGray 整 button）。
func _make_vit_row(diff: Dictionary, _unlocked: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	var vit_num := Label.new()
	vit_num.text = str(int(diff["vit"]))
	vit_num.add_theme_color_override("font_color", VIT_NUM_COLOR)
	vit_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vit_num)
	var vit_bg := TextureRect.new()
	vit_bg.texture = _load_tex(VIT_BG_RES)
	vit_bg.custom_minimum_size = VIT_BG_SIZE
	vit_bg.ignore_texture_size = true
	vit_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vit_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vit_bg)
	var vit_icon := TextureRect.new()
	vit_icon.texture = _load_tex(VIT_ICON_RES)
	vit_icon.custom_minimum_size = VIT_ICON_SIZE
	vit_icon.ignore_texture_size = true
	vit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vit_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vit_icon)
	return row


func _play_entrance_scale() -> void:
	if not is_inside_tree():
		return
	container.pivot_offset = FRAME_POS + FRAME_SIZE * 0.5
	container.scale = Vector2(0.001, 0.001)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(container, "scale", Vector2(1, 1), 0.2)


func _on_degree_pressed(diff: Dictionary) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	emit_signal("degree_selected", boss_idx, diff)
	_on_close()


func _on_close() -> void:
	emit_signal("close_requested")
	remove_window()


static func _load_tex(path: String) -> Variant:
	return load(path) if ResourceLoader.exists(path) else null
