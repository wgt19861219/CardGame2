class_name LichMapPanel
extends PopWindow

## ch203 冰封王座三部曲面板 v6（2026-10-09 八轮：背景铺满框雕花内沿、标题框=远征
## 原版 crusade_title_bg 且横幅文字随切换动态显示当前分卷名、据点按每图错落坐标
## 自由排布+圆点路径连线——照战役地图"路线感"）。
##
## 当前本的场景图铺满背景框；3 个 Boss 地标按每图专属错落坐标摆放（非均匀横排），
## 据点间用自绘圆点路径串联（PathDotsLayer 挂 MapBg 下，换图淡入联动）；左右箭头
## 切换三本（毒蛇神殿/海加尔山/冰冠堡垒），点击 Boss → 四档难度弹窗（复用
## DungeonDegreePopup）→ BattlePreparePanel 选人开战。已通关灰显、前置解锁链照
## DungeonMapPanel 语义；宝箱/迷雾/滚动地图已裁剪（四轮用户指示）。
##
## 入口：main_scene icecrown 建筑（80 级解锁）→ MainSceneEntryRouter.open_lich_map。

const DegreePopup := preload("res://scripts/ui/dungeon_degree_popup.gd")
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/lich_map_content.tscn")

const BOSS_TEX_DIR := "res://assets/ui/lich/boss_"
const MAP_TEX_PATHS: Array[String] = [
	"res://assets/ui/lich/bg_serpent.png",
	"res://assets/ui/lich/bg_hyjal.png",
	"res://assets/ui/lich/bg_icecrown.png",
]
const GROUP_IDS: Array[int] = [50008, 50009, 50010]
const GROUP_NAME_KEYS: Array[String] = [
	"DUNGEON.SERPENTSHRINE", "DUNGEON.HYJAL_SUMMIT", "DUNGEON.ICECROWN_CITADEL",
]
const BOSS_ICON_SIZE := Vector2(72.0, 64.0)
const DUNGEON_DIFF_OFFSET: int = 1000
# MapBg 在 tscn 中的 offset 原点（据点/路径坐标为视口系，转 MapBg 局部用）
const MAP_BG_ORIGIN := Vector2(42.0, 81.0)
# 每图 3 据点错落坐标（视口系，据点中心；手排错落避让框沿/标题横幅，照战役地图路线感）
const BOSS_SPOTS: Array = [
	[Vector2(215, 200), Vector2(410, 330), Vector2(625, 225)],
	[Vector2(190, 310), Vector2(415, 225), Vector2(635, 340)],
	[Vector2(175, 250), Vector2(400, 360), Vector2(620, 220)],
]
# 每图路径入口锚点（视口系；路径=入口→据点1→据点2→据点3 的圆点连线）
const PATH_ENTRIES: Array[Vector2] = [Vector2(110, 240), Vector2(110, 330), Vector2(110, 300)]
# 源 setSpriteGray（resource_manager.lua:871-877）= ccc3(100,100,100)+opacity 180。
const GRAY_MODULATE := Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0)
# 箭头呼吸（照 stage_select_panel ARROW_BOB 常量语义）
const ARROW_BOB_DX := 5.0
const ARROW_BOB_TIME := 0.8
const MAP_FADE_TIME := 0.25
# 获取途径跳转引导（照 stage_select attach_get_way_guide：呼吸圈+手指，常量同源）
const GUIDE_CIRCLE_RES: String = "res://assets/ui/alpha/HVGA/tutorial_circle.png"
const GUIDE_FINGER_RES: String = "res://assets/ui/alpha/HVGA/tutorial_finger.png"
const GUIDE_SCALE_TIME := 0.65
const GUIDE_SCALE_MAX := 1.35
const GUIDE_FINGER_SHIFT := Vector2(17.5, 17.5)

var player: PlayerData = null
var stage_manager: StageManager = null
var rng: BattleRng = null
var bosses: Array = []                 # 9 Boss 平铺（组序=卡序）
var boss_btn_by_idx: Dictionary = {}   # 全局序号 → TextureButton
var _current: int = 0                  # 当前本索引（0-2）
var _active_popup: DungeonDegreePopup = null
var _content: Control = null
var _path_layer: PathDotsLayer = null
var _focus_stage_id: int = 0   # 获取途径跳转定位关（>0 时目标据点叠引导圈+手指，点击即消费）
var _arrows_bobbing := false


func setup_panel(p_player: PlayerData, p_stage_manager: StageManager, p_rng: BattleRng, p_focus_stage_id: int = 0) -> void:
	hud_identity = "lichMap"
	transparent_shade = true
	player = p_player
	stage_manager = p_stage_manager
	rng = p_rng
	_collect_bosses()
	# 手指目标：外部跳转定位关未通关时照源 forGetWay 指向它；否则（含结算返回传入的
	# 刚通关关）指向下一个待通关关（2026-10-10 用户实测反馈原手指停在已通关关）。
	var focus_id: int = p_focus_stage_id
	if focus_id > 0 and ExerciseManager.is_boss_cleared(stage_manager.progress, focus_id):
		focus_id = 0
	if focus_id <= 0:
		focus_id = _next_uncleared_boss_id()
	if focus_id > 0:
		for i in range(bosses.size()):
			if int((bosses[i] as Dictionary)["base_id"]) == focus_id:
				_current = i / 3
				_focus_stage_id = focus_id
				break
	setup()
	_build_content()
	_refresh_current_map(false)
	_start_arrow_bob()


## 下一个待通关 Boss（难度递进序第一个未通关；全通关返 0 不高亮）。
func _next_uncleared_boss_id() -> int:
	for boss in bosses:
		var base_id: int = int((boss as Dictionary)["base_id"])
		if not ExerciseManager.is_boss_cleared(stage_manager.progress, base_id):
			return base_id
	return 0


func _collect_bosses() -> void:
	bosses = []
	var mgr := ExerciseManager.new()
	mgr.setup(stage_manager.config)
	for gid in GROUP_IDS:
		var group: Array = mgr.get_dungeon_bosses(gid)
		for boss in group:
			bosses.append(boss)


func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	(_content.get_node("%PrevArrow") as BaseButton).pressed.connect(_on_prev_map)
	(_content.get_node("%NextArrow") as BaseButton).pressed.connect(_on_next_map)
	# 路径圆点层挂 MapBg 下（属地图元素：绘制序在据点之上前、换图淡入联动）
	var map_bg: TextureRect = _content.get_node("%MapBg") as TextureRect
	_path_layer = PathDotsLayer.new()
	_path_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_path_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_bg.add_child(_path_layer)


## 切换当前本：换地图贴图+横幅分卷名+重建据点/路径+箭头边界隐藏（照 setChapterButtonState:643）。
func _refresh_current_map(animated: bool) -> void:
	var map_bg: TextureRect = _content.get_node("%MapBg") as TextureRect
	var title_label: Label = _content.get_node("%TitleLabel") as Label
	map_bg.texture = _load_tex(MAP_TEX_PATHS[_current]) as Texture2D
	title_label.text = player.cm.get_lstr(GROUP_NAME_KEYS[_current])
	_place_boss_nodes()
	_rebuild_path()
	(_content.get_node("%PrevArrow") as CanvasItem).visible = _current > 0
	(_content.get_node("%NextArrow") as CanvasItem).visible = _current < GROUP_IDS.size() - 1
	if animated:
		map_bg.modulate.a = 0.3
		var tw := create_tween()
		tw.tween_property(map_bg, "modulate:a", 1.0, MAP_FADE_TIME)


## 当前本据点重建（3 个地标小图按每图错落坐标摆放，点击 → 难度弹窗）。
func _place_boss_nodes() -> void:
	boss_btn_by_idx.clear()
	var row: Control = _content.get_node("%BossRow") as Control
	for child in row.get_children():
		child.queue_free()
	for local_idx in range(0, 3):
		var idx: int = _current * 3 + local_idx + 1   # 全局序号（1 基）
		var boss: Dictionary = bosses[idx - 1]
		var base_id: int = int(boss["base_id"])
		var tex: Texture2D = _load_tex(BOSS_TEX_DIR + str(base_id) + ".png") as Texture2D
		if tex == null:
			continue  # 资产缺失静默跳过（守卫测试另守 boss 数据齐全）
		var btn := TextureButton.new()
		btn.texture_normal = tex
		btn.texture_disabled = tex
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.size = BOSS_ICON_SIZE
		var spot: Vector2 = BOSS_SPOTS[_current][local_idx]
		btn.position = spot - BOSS_ICON_SIZE / 2.0
		btn.pressed.connect(Callable(self, "_on_boss_pressed").bind(idx))
		row.add_child(btn)
		boss_btn_by_idx[idx] = btn
		if base_id == _focus_stage_id:
			_attach_focus_guide(row, btn)
	_refresh_boss_states()


## 获取途径跳转引导（照 stage_select attach_get_way_guide :1331-1351）：目标据点叠呼吸圈
## +滑动手指；随 BossRow 子节点重建/销毁自然清理（切分卷即失效）。
func _attach_focus_guide(row: Control, btn: TextureButton) -> void:
	var center: Vector2 = btn.position + btn.size * 0.5
	var circle := TextureRect.new()
	circle.texture = load(GUIDE_CIRCLE_RES) as Texture2D
	circle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var csize: Vector2 = TexDisplaySize.display_size(GUIDE_CIRCLE_RES)
	circle.size = csize
	circle.position = center - csize * 0.5
	circle.pivot_offset = csize * 0.5
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(circle)
	var tw := circle.create_tween().set_loops()
	tw.tween_property(circle, "scale", Vector2(GUIDE_SCALE_MAX, GUIDE_SCALE_MAX), GUIDE_SCALE_TIME)
	tw.tween_property(circle, "scale", Vector2.ONE, GUIDE_SCALE_TIME)
	var finger := TextureRect.new()
	finger.texture = load(GUIDE_FINGER_RES) as Texture2D
	finger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	finger.size = TexDisplaySize.display_size(GUIDE_FINGER_RES)
	var fbase: Vector2 = Vector2(center.x - 4.0, center.y - 4.0)
	finger.position = fbase
	finger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(finger)
	var ftw := finger.create_tween().set_loops()
	ftw.tween_property(finger, "position", fbase + GUIDE_FINGER_SHIFT, GUIDE_SCALE_TIME)
	ftw.tween_property(finger, "position", fbase, GUIDE_SCALE_TIME)


## 当前本路径重建（入口→3 据点的圆点连线，坐标转 MapBg 局部）。
func _rebuild_path() -> void:
	var anchors: Array[Vector2] = [PATH_ENTRIES[_current]]
	for spot in BOSS_SPOTS[_current]:
		anchors.append(spot)
	_path_layer.set_path_anchors(anchors, MAP_BG_ORIGIN)


func _refresh_boss_states() -> void:
	for idx in boss_btn_by_idx:
		var base_id: int = int(bosses[idx - 1]["base_id"])
		var cleared_boss: bool = ExerciseManager.is_boss_cleared(stage_manager.progress, base_id)
		var btn: TextureButton = boss_btn_by_idx[idx]
		if btn != null and is_instance_valid(btn):
			btn.modulate = GRAY_MODULATE if cleared_boss else Color(1, 1, 1)


func _on_prev_map() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_current = maxi(_current - 1, 0)
	_refresh_current_map(true)


func _on_next_map() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_current = mini(_current + 1, GROUP_IDS.size() - 1)
	_refresh_current_map(true)


## 箭头呼吸（照 stage_select _bob_x：position:x ±dx 往返循环）。
func _start_arrow_bob() -> void:
	if _arrows_bobbing or _content == null or not is_instance_valid(_content):
		return
	_arrows_bobbing = true
	_bob_x(_content.get_node_or_null("%PrevArrow") as CanvasItem, -ARROW_BOB_DX)
	_bob_x(_content.get_node_or_null("%NextArrow") as CanvasItem, ARROW_BOB_DX)


func _bob_x(node: CanvasItem, dx: float) -> void:
	if node == null or not node.is_inside_tree():
		return
	var base_x: float = node.position.x
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "position:x", base_x + dx, ARROW_BOB_TIME)
	tw.tween_property(node, "position:x", base_x, ARROW_BOB_TIME)


func _on_boss_pressed(idx: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if int(bosses[idx - 1]["base_id"]) == _focus_stage_id:
		_focus_stage_id = 0   # 引导到点击为止（源 forGetWay 语义）
	if not ExerciseManager.is_boss_unlocked(bosses, stage_manager.progress, idx):
		Toast.show_message("通关前置 Boss 后解锁")
		return
	_open_degree_popup(idx)


func _open_degree_popup(idx: int) -> void:
	_close_degree_popup()
	var boss: Dictionary = bosses[idx - 1]
	var popup: DungeonDegreePopup = DegreePopup.new("dungeonDegree", {})
	# name 是 LSTR 键（StageDungeon Stage Name=DUNGEON.BOSS_*），走翻译显示（旧直传键
	# 显"DUNGEON.BOSS_KARATHESS"原文，存量病 2026-10-10 随换色头像验收撞见顺手修）
	popup.setup_popup(idx, player.cm.get_lstr(String(boss.get("name", ""))), boss.get("difficulties", []), player.team_level)
	popup.degree_selected.connect(_on_degree_selected)
	popup.close_requested.connect(_on_degree_close)
	popup.show_window(self)
	_active_popup = popup


func _close_degree_popup() -> void:
	if _active_popup != null and is_instance_valid(_active_popup):
		_active_popup.remove_window()
	_active_popup = null


func _on_degree_selected(idx: int, diff: Dictionary) -> void:
	_close_degree_popup()
	var boss: Dictionary = bosses[idx - 1]
	var base_id: int = int(boss["base_id"])
	var diff_num: int = int(diff["diff"])
	var lookup_id: int = base_id + (diff_num - 1) * DUNGEON_DIFF_OFFSET
	var panel := BattlePreparePanel.new()
	panel.setup(lookup_id, player, stage_manager, rng, player.cm)
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(panel)


func _on_degree_close() -> void:
	_active_popup = null


static func _load_tex(path: String) -> Variant:
	return load(path) if ResourceLoader.exists(path) else null


## 圆点路径层：沿锚点序列两两连线摆圆点（战役地图"点状路线"感，纯自绘无资产依赖）。
class PathDotsLayer extends Control:
	const DOT_GAP := 26.0
	const DOT_RADIUS := 3.0
	const END_MARGIN := 34.0
	const DOT_COLOR := Color(1.0, 0.92, 0.65, 0.6)

	var _anchors: Array[Vector2] = []
	var _origin := Vector2.ZERO

	func set_path_anchors(anchors: Array[Vector2], origin: Vector2) -> void:
		_anchors = anchors
		_origin = origin
		queue_redraw()

	func _draw() -> void:
		for i in range(_anchors.size() - 1):
			var a: Vector2 = _anchors[i] - _origin
			var b: Vector2 = _anchors[i + 1] - _origin
			var delta: Vector2 = b - a
			var dist: float = delta.length()
			if dist <= END_MARGIN * 2.0:
				continue
			var dir := delta / dist
			var t := END_MARGIN
			while t < dist - END_MARGIN:
				draw_circle(a + dir * t, DOT_RADIUS, DOT_COLOR)
				t += DOT_GAP
