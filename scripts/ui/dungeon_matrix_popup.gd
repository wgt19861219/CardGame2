class_name DungeonMatrixPopup
extends PopWindow

## Boss×难度矩阵弹窗 — 照源 exercise.lua degreeWindow.createDungeon(:789-880) +
## createDungeonDegree(:595-656)：每 boss 一行（名 + 4 难度格 Normal/Elite/Hero/
## Nightmare 分色），锁定整格灰化 + disabled（源 setSpriteGray + checkUnlockLevel）。
##
## 消费方：ExerciseMapPanel（旧版地图 dg1-4 入口与 cavern 子窗，源 :1197-1199 链）。
## 与 DungeonDegreePopup（dungeon_map 样式单 boss 大格）并列：视觉/交互照源旧版矩阵。
## 受控偏离：难度按钮底 act_select_bg→main_vit_tips 名牌（见 content tscn 头注）；
## 名字号 15→18（DungeonVitNumberLabel 复用）；选难度后直进布阵（dungeon 链无
## stagedetail，dungeon_map_panel 同款受控裁剪），等级/体力校验由布阵装配承担。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/dungeon_matrix_content.tscn")
const ROW_SCENE: PackedScene = preload("res://scenes/ui/dungeon_matrix_row.tscn")

const MAX_BOSSES: int = 3
const DIFF_COUNT: int = 4
# 源 oy=290 dy=-95（cocos y 上正）→ godot y=480-290=190 / +95 / +95
const ROW_Y: Array[float] = [190.0, 285.0, 380.0]
# 源 :596-602 难度文字与色（硬英文照源）
const DIFF_NAMES: Array[String] = ["Normal", "Elite", "Hero", "Nightmare"]
const DIFF_COLORS: Array[Color] = [
	Color(100.0 / 255.0, 200.0 / 255.0, 100.0 / 255.0),
	Color(100.0 / 255.0, 150.0 / 255.0, 255.0 / 255.0),
	Color(200.0 / 255.0, 100.0 / 255.0, 255.0 / 255.0),
	Color(255.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0),
]
# 源 setSpriteGray 等价（resource_manager.lua:871-877，dungeon_map_panel 同款）
const GRAY_MODULATE := Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0)
const LSTR_TITLE: String = "DUNGEON.SELECT_BOSS_DIFFICULTY"
const LSTR_TITLE_FALLBACK: String = "选择Boss与难度"

var _content: Control = null
var _rows: Array[Control] = []
var _cm: Variant = null

signal difficulty_selected(base_id: int, diff_data: Dictionary)
signal close_requested


func setup_popup(p_bosses: Array, p_player_level: int, p_cm: Variant) -> void:
	hud_occlude = false   # 挂 exercise_map/dungeon 链不遮蔽 HUD（degreePopup 族先例）
	_cm = p_cm
	setup()
	register_on_enter(play_scale_in)
	_build_content()
	_fill_rows(p_bosses, p_player_level)


func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	var title: String = String(_cm.get_lstr(LSTR_TITLE)) if _cm != null else ""
	(_content.get_node("%Title") as Label).text = title if title != LSTR_TITLE else LSTR_TITLE_FALLBACK
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close)


## boss 行 fill（源 :595-656）：名右对齐 + 4 难度格；锁定（unlock_level > 玩家级）
## 整格 GRAY_MODULATE + disabled；difficulties 数据不足的格隐藏。
func _fill_rows(p_bosses: Array, p_player_level: int) -> void:
	var host: Control = _content.get_node("%RowHost") as Control
	var count: int = mini(p_bosses.size(), MAX_BOSSES)
	for i in range(count):
		var boss: Dictionary = p_bosses[i]
		var row: Control = ROW_SCENE.instantiate() as Control
		row.position = Vector2(0.0, ROW_Y[i])
		host.add_child(row)
		_rows.append(row)
		# 名行走 lstr 中文（StageDungeon Stage Name 为 LSTR key，词条全有）
		(row.get_node("%NameLabel") as Label).text = _lstr(String(boss.get("name", "")))
		var diffs: Array = boss.get("difficulties", [])
		for d in range(DIFF_COUNT):
			var cell: Control = row.get_node("%Cell" + str(d + 1)) as Control
			if d >= diffs.size():
				cell.visible = false
				continue
			_fill_cell(cell, diffs[d], d, p_player_level, boss)


func _fill_cell(p_cell: Control, p_diff: Dictionary, p_diff_idx: int, p_player_level: int, p_boss: Dictionary) -> void:
	# Cell 内 Btn/Txt 为 4 格同名子节点（规范：同名不都开 unique），走相对路径取
	var btn := p_cell.get_node("Btn") as Button
	var txt := p_cell.get_node("Txt") as Label
	txt.text = DIFF_NAMES[p_diff_idx]
	var unlocked: bool = int(p_diff.get("unlock_level", 1)) <= p_player_level
	if unlocked:
		txt.modulate = DIFF_COLORS[p_diff_idx]
	else:
		p_cell.modulate = GRAY_MODULATE
		btn.disabled = true
	btn.pressed.connect(_on_cell_pressed.bind(p_boss, p_diff))


func _on_cell_pressed(p_boss: Dictionary, p_diff: Dictionary) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	emit_signal("difficulty_selected", int(p_boss["base_id"]), p_diff)
	_on_close()


func _lstr(lstr_key: String) -> String:
	if _cm == null:
		return lstr_key
	var t: String = String(_cm.get_lstr(lstr_key))
	return t if t != lstr_key else lstr_key


func _on_close() -> void:
	emit_signal("close_requested")
	remove_window()
