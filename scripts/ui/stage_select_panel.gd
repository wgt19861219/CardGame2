class_name StageSelectPanel
extends PopWindow

## 关卡选择（View 层）— 照源 stageselect.lua + stageselectres.lua 地图式布局翻译。
## 章节 bg + route 路线 + stage 圆点（locked/current/passed + key_stage boss 图 + 星 + 指针）
## + 三 mode toggle（normal/elite/guild）+ 章节导航 dot + 左右箭头 + frame/title。
## 源 stageselect.lua create(:1573)/createMap(:1359)/createStage(:1212)/getStageRes(:992)/
## doChangeMode(:319)/doChangeChapter(:423)/createDot(:676)/createModeButton(:725)。

const StageSelectBuilder = preload("res://scripts/ui/stage_select_builder.gd")
const StageDetailPanel = preload("res://scripts/ui/stage_detail_panel.gd")
# 源 framework.lua:749 pushScene 场景自动加全屏 bg.jpg（stageselect.lua + main.lua:1351 是 pushScene 独立场景）。
const FRAMEWORK_BG: String = "res://assets/ui/alpha/HVGA/bg.jpg"

var mgr: StageManager = null
var player: PlayerData = null
var rng: BattleRng = null
var _current_chapter: int = 1
var _mode: String = "normal"  # 源 stageselect.lua:319 doChangeMode — normal/elite/guild
var _stage_buttons: Dictionary = {}   # sid -> TextureButton（_refresh_view 重建）


func setup_panel(p_mgr: StageManager, p_player: PlayerData, p_rng: BattleRng) -> void:
	mgr = p_mgr
	player = p_player
	rng = p_rng
	_current_chapter = mgr.get_max_chapter("normal") if mgr != null else 1
	setup()
	_refresh_view()


# 源 createByStage(id)（equipcraft doClickGetWay :83 跳转）：按 stage_id 定位章再 setup。
func setup_by_stage(p_mgr: StageManager, p_player: PlayerData, p_rng: BattleRng, stage_id: int) -> void:
	mgr = p_mgr
	player = p_player
	rng = p_rng
	_current_chapter = _chapter_of_stage(stage_id)
	setup()
	_refresh_view()


# 源 createByStage(:1642-1663) — stage_id → Chapter ID（elite/raid 经 Stage Group 反查）。
func _chapter_of_stage(stage_id: int) -> int:
	var st: Dictionary = player.cm.get_raw_table(&"Stage")
	var sid: int = stage_id
	if stage_id >= 10000:
		sid = int(st.get(str(stage_id), {}).get("Stage Group", stage_id))
	return int(st.get(str(sid), {}).get("Chapter ID", 1))


# 源 framework.lua:749-751 pushScene 场景全屏 bg.jpg（stageselect 源是独立场景）。
func _create_fullscreen_bg() -> void:
	var bg := TextureRect.new()
	bg.texture = load(FRAMEWORK_BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.position = Vector2.ZERO
	bg.size = Vector2(960.0, 640.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)


func _refresh_view() -> void:
	for c in container.get_children():
		c.queue_free()
	_stage_buttons.clear()
	# 源 stageselect.lua + main.lua:1351 pushScene 独立场景（framework.lua:749 自动建全屏 bg.jpg），
	# 本项目单机化 pushScene→PopWindow，故 shade 透明 + 补全屏 bg.jpg 还原源视觉（同 PackagePanel 范式）。
	# _refresh_view 每次切章/mode 会 queue_free 全部子节点，故 bg 需随每次重建补回（保持最底层）。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_fullscreen_bg()
	var cm: Variant = player.cm if player != null else null
	var star_of: Callable = Callable(self, "_get_stage_stars")
	# 源 create(:1617-1622) 顺序：map → frame/title → mode → arrows → dots。
	# close 最后 add（等价源 framework 顶层独立 close，避免被 map/frame 遮挡）。
	var map_layer: Dictionary = StageSelectBuilder.create_map_layer(container, _current_chapter, _mode, cm, star_of)
	_stage_buttons = map_layer["stage_buttons"]
	for sid in _stage_buttons:
		(_stage_buttons[sid] as TextureButton).pressed.connect(_on_stage_clicked.bind(sid))
	StageSelectBuilder.create_frame_and_title(container, _current_chapter, _mode, cm)
	StageSelectBuilder.create_mode_buttons(container, _mode, cm, _on_mode_pressed)
	var max_ch: int = mgr.get_max_chapter(_mode) if mgr != null else _current_chapter
	StageSelectBuilder.create_chapter_arrows(container, _current_chapter > 1, _current_chapter < max_ch, _on_prev_chapter, _on_next_chapter)
	StageSelectBuilder.create_chapter_dots(container, max_ch, _current_chapter, _mode)
	StageSelectBuilder.create_close_button(container, remove_window)


func _get_stage_stars(sid: int) -> int:
	if mgr == null:
		return 0
	return mgr.stage_stars(sid)


# 源 doChangeMode(:319) — 三 mode toggle（normal/elite/guild）。
func _on_mode_pressed(mode: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_mode = mode
	_current_chapter = mgr.get_max_chapter(mode) if mgr != null else 1
	_refresh_view()


# 源 doChangeChapter(:423)/setChapterButtonState(:643) — 章节切换（边界隐藏箭头）。
func _on_prev_chapter() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_current_chapter = maxi(_current_chapter - 1, 1)
	_refresh_view()


func _on_next_chapter() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var max_ch: int = mgr.get_max_chapter(_mode) if mgr != null else StageSelectMap.CHAPTER_MAX
	_current_chapter = mini(_current_chapter + 1, max_ch)
	_refresh_view()


# 源 gotoDetailScene(:214) — 点击 stage 圆点弹关卡详情（照源 stageselect→stagedetail→battle）。
func _on_stage_clicked(sid: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if mgr == null or player == null or rng == null:
		return
	var detail := StageDetailPanel.new("stagedetail", {})
	detail.setup_panel(sid, mgr, player, rng)
	detail.show_window(get_parent())
