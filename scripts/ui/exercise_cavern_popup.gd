class_name ExerciseCavernPopup
extends PopWindow

## 英雄副本聚合子窗（时光之穴）— 照源 exercise.lua degreeWindow.createCavern
## （git 5ea4ba7~1 旧版 :846-997）：3 英雄本按钮（dg5/6/7 → 50005-50007，
## ActStageGroupDungeon Group Name 中文 20 号紫）。点击 → dungeon_selected(gid)
## → 宿主开 Boss×难度矩阵（源 :997 destroy 本窗后 createDungeon 挂回场景等价）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/exercise_cavern_content.tscn")

const CAVERN_KEYS: Array[String] = ["dg5", "dg6", "dg7"]
const LSTR_TITLE: String = "CHAPTER.CAVERNS_OF_TIME"
const LSTR_TITLE_FALLBACK: String = "时光之穴"

var player: PlayerData = null
var _content: Control = null

signal dungeon_selected(group_id: int)
signal close_requested


func setup_panel(p_player: PlayerData) -> void:
	hud_occlude = false   # 挂 exercise_map 链不遮蔽 HUD（degreePopup 族先例）
	player = p_player
	setup()
	register_on_enter(play_scale_in)
	_build_content()


func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	var title: String = String(player.cm.get_lstr(LSTR_TITLE))
	(_content.get_node("%Title") as Label).text = title if title != LSTR_TITLE else LSTR_TITLE_FALLBACK
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close)
	var raw: Dictionary = player.cm.get_raw_table(&"ActStageGroupDungeon")
	for i in range(CAVERN_KEYS.size()):
		var gid: int = int(ExerciseManager.ENTRY_STAGE.get(CAVERN_KEYS[i], 0))
		var gname: String = String(raw.get(str(gid), {}).get(&"Group Name", ""))
		(_content.get_node("%Dg" + str(i + 5) + "Label") as Label).text = _lstr(gname)
		(_content.get_node("%Dg" + str(i + 5) + "Btn") as BaseButton).pressed.connect(
			_on_dungeon_pressed.bind(gid))


func _lstr(lstr_key: String) -> String:
	var t: String = String(player.cm.get_lstr(lstr_key))
	return t if t != lstr_key else lstr_key


func _on_dungeon_pressed(group_id: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	emit_signal("dungeon_selected", group_id)
	_on_close()


func _on_close() -> void:
	emit_signal("close_requested")
	remove_window()
