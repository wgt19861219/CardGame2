class_name DungeonDegreePopup
extends PopWindow

## 副本难度选择弹窗 — 照源 ui/dungeon_map.lua:316-580 showDegreePopup + popupTouchHandler。
## 单 boss 4 难度（diff 1 普通/2 精英/3 英雄/4 噩梦），点难度 → degree_selected；close/outLayer 关闭。
## 源 Scale9Sprite frame + 多 Sprite 重建 → Panel frame + TextureButton(含 icon/vit 子节点)。

const FRAME_POS := Vector2(130.0, 170.0)
const FRAME_SIZE := Vector2(700.0, 300.0)
const CLOSE_BTN_POS := Vector2(830.0, 360.0)
const BTN_SIZE := Vector2(130.0, 120.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const ICON_SIZE := Vector2(55.0, 55.0)
const SEPARATION: int = 50
const TITLE_COLOR := Color(0.91, 0.81, 0.07)               # 源 :382 ccc3(231,206,19)
const GRAY_MODULATE := Color(0.4, 0.4, 0.4)                # 源 :467-469 setSpriteGray 近似

const BTN_BG := "res://assets/ui/alpha/HVGA/act/act_select_bg.png"
const BTN_BG_CHOSEN := "res://assets/ui/alpha/HVGA/act/act_select_bg_chosen.png"
const ICON_DIR := "res://assets/ui/alpha/HVGA/act/act_icon_difficulty_"
# 源 dungeon_map.lua:427-460 vit 行（vit_bg + vit_number + vit_icon）
const VIT_BG_RES := "res://assets/ui/alpha/HVGA/act/act_comment_bg.png"  # 源 :431
const VIT_ICON_RES := "res://assets/ui/alpha/HVGA/vitalityicon.png"   # 源 :453
const VIT_BG_SIZE := Vector2(60.0, 30.0)
const VIT_ICON_SIZE := Vector2(30.0, 35.0)   # 源 :459 fix_height=35
const VIT_NUM_COLOR := Color(0.91, 0.84, 0.71)  # 源 :447 ccc3(233,214,181)

var boss_idx: int = 0

signal degree_selected(p_boss_idx: int, diff_data: Dictionary)
signal close_requested


func setup_popup(p_boss_idx: int, p_boss_name: String, p_difficulties: Array, p_player_level: int) -> void:
	boss_idx = p_boss_idx
	setup()
	_create_frame(p_boss_name)
	_create_close_button()
	_create_degree_buttons(p_difficulties, p_player_level)
	_play_entrance_scale()  # 源 :486-489 container setScale(0)→CCScaleTo(0.2,1)+CCEaseBackOut


func _create_frame(boss_name: String) -> void:
	var frame := Panel.new()
	frame.position = FRAME_POS
	frame.size = FRAME_SIZE
	container.add_child(frame)
	# 源 :376-382 text = boss.name or ""（无 fallback；boss_name 由 StageDungeon["Stage Name"] 提供）。
	var title := Label.new()
	title.text = boss_name
	title.position = Vector2(0, 15)
	title.size = Vector2(FRAME_SIZE.x, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", TITLE_COLOR)
	frame.add_child(title)


func _create_close_button() -> void:
	var btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_BTN_POS)
	btn.pressed.connect(_on_close)
	container.add_child(btn)


## 源 dungeon_map.lua:388-477 4 难度按钮（act_select_bg + icon + vit 子节点叠加）。
func _create_degree_buttons(difficulties: Array, player_level: int) -> void:
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(FRAME_POS.x + 70, FRAME_POS.y + 80)
	hbox.size = Vector2(FRAME_SIZE.x - 140, 180)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", SEPARATION)
	container.add_child(hbox)
	for di in range(difficulties.size()):
		var diff: Dictionary = difficulties[di]
		var diff_num: int = int(diff["diff"])
		var unlocked: bool = int(diff["unlock_level"]) <= player_level
		hbox.add_child(_make_degree_button(diff, diff_num, unlocked))


## 源 :388-477 难度按钮（act_select_bg + icon）+ vit 行（vit_number+vit_bg+vit_icon）。
## 源按钮无难度名 Label（仅 icon + vit），难度区分由 icon 图标承担；setSpriteGray 锁定。
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
	btn.modulate = GRAY_MODULATE if not unlocked else Color(1, 1, 1)  # 源 :467-469 setSpriteGray
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
	# 源 :427-460 vit 行（vit_number + vit_bg + vit_icon）
	vbox.add_child(_make_vit_row(diff, unlocked))
	return vbox


## 源 dungeon_map.lua:427-460 vit_number(体力数) + vit_bg(act_comment_bg) + vit_icon(vitalityicon)。
## 锁定态颜色由父 btn.modulate=GRAY_MODULATE 统一处理（源 :467-469 setSpriteGray 整 button）。
func _make_vit_row(diff: Dictionary, _unlocked: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	var vit_num := Label.new()
	vit_num.text = str(int(diff["vit"]))
	vit_num.add_theme_color_override("font_color", VIT_NUM_COLOR)  # 源 :447 ccc3(233,214,181)
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


## 源 :486-489 container setScale(0)→CCScaleTo(0.2,1)+CCEaseBackOut；不在树内跳过（单测路径）。
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
	AudioPlayer.play_sfx("common_click_feedback")  # 源 exerciselsr.clickDegree（sound_res 无 exercise 段，common_* 适配）
	emit_signal("degree_selected", boss_idx, diff)
	_on_close()


func _on_close() -> void:
	emit_signal("close_requested")
	remove_window()


static func _load_tex(path: String) -> Variant:
	return load(path) if ResourceLoader.exists(path) else null
