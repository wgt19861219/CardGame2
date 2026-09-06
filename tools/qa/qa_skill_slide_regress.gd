extends Node

## 2026-09-06 技能加点「侧滑又出来了」回归取证（十一轮判例：先取证定位是哪个动画）。
## 链路复刻 hero_package_panel.gd:228-231 真实接线（perform_upgrade_skill → refresh_content()）。
## push_input 点击不分发（判例第四次印证），改契约方法直调；等级/金币注入保证升级成功。
## 手段：升级瞬间全树 global_position 逐帧快照 diff（过滤 parallax 背景噪音，子随父动只报根）
## + 活动 tween 计数；移动节点去重汇总放输出尾部（debug 缓冲只留尾部）。任何滑动都会现形。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")

const WAIT_BOOT_SEC: float = 1.5
const WAIT_TAB_SEC: float = 1.2
const WAIT_SAMPLE_SEC: float = 1.0
const BASELINE_FRAMES: int = 3
const SKILL_POINTS_INJECT: int = 10
const HERO_LEVEL_INJECT: int = 5
const GOLD_INJECT: int = 100000
const MOVE_EPS: float = 0.5


class QADetail extends HeroDetailPanel:
	pass


var _frame_no: int = 0
var _prev_pos: Dictionary = {}
var _sampling: bool = false
var _moved_roots: Dictionary = {}   # path -> [count, first_pos, last_pos]


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(WAIT_BOOT_SEC).timeout

	# 注入：等级抬高（过 cur>=level 上限）+ 金币 + 技能点
	var hero: Variant = pd.hero_manager.heroes.values()[0]
	hero.level = HERO_LEVEL_INJECT
	pd.hero_manager.gold = GOLD_INJECT
	pd.skill_points = SKILL_POINTS_INJECT

	var host: Node = get_tree().current_scene
	var dp: QADetail = QADetail.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.shade_close_on_click = false
	dp.upgrade_skill_requested.connect(func(idx: int) -> void:
		if dp.perform_upgrade_skill(idx):
			dp.refresh_content())   # 与 hero_package 真实接线一字不差（2026-09-06 滑入退役，重建全静止）
	dp.show_window(host)
	HudOverlay.set_status_visible(false)
	await get_tree().create_timer(WAIT_TAB_SEC).timeout

	# 契约方法直调（按钮 pressed 即连此）；点 tab 路径 animate=true 是源行为
	dp._on_tab_pressed("skill")
	await get_tree().create_timer(WAIT_TAB_SEC).timeout
	print("QAS state: tab=", dp._current_tab, " skill_lv=", hero.skill_levels[0],
		" hero_lv=", hero.level, " gold=", pd.hero_manager.gold, " points=", pd.skill_points)

	# 开采样 → baseline → 直调升级链（等价点 %+Btn 的信号全链）
	_sampling = true
	_frame_no = 0
	await get_tree().create_timer(BASELINE_FRAMES / 60.0).timeout
	print("QAS >>> upgrade_skill_requested.emit(0) 链开始")
	dp.upgrade_skill_requested.emit(0)
	await get_tree().create_timer(WAIT_SAMPLE_SEC).timeout
	_sampling = false

	# ---- 汇总（输出尾部，防缓冲截断）----
	print("QAS ==== SUMMARY ====")
	print("QAS result skill_levels[0]=", hero.skill_levels[0], " points=", pd.skill_points,
		" moved_roots=", _moved_roots.size())
	for path: String in _moved_roots:
		var info: Array = _moved_roots[path]
		print("QAS MOVED ", path, " count=", info[0], " first=", info[1], " last=", info[2])
	print("QAS DONE")


func _process(_d: float) -> void:
	if not _sampling:
		return
	_frame_no += 1
	var cur: Dictionary = {}
	_collect(get_tree().current_scene, cur)
	var moved: Array = []
	for path: String in cur:
		var prev_v: Vector2 = _prev_pos.get(path, cur[path]) as Vector2
		if prev_v.distance_to(cur[path] as Vector2) > MOVE_EPS:
			moved.append(path)
	moved.sort()
	for path: String in moved:
		var has_moving_ancestor: bool = false
		for other: String in moved:
			if path != other and path.begins_with(other + "/"):
				has_moving_ancestor = true
				break
		if has_moving_ancestor:
			continue
		if not _moved_roots.has(path):
			_moved_roots[path] = [0, _prev_pos.get(path, cur[path]), cur[path]]
		var info: Array = _moved_roots[path]
		info[0] = int(info[0]) + 1
		info[2] = cur[path]
	_prev_pos = cur


func _collect(node: Node, out: Dictionary) -> void:
	if "parallax" in String(node.name).to_lower():
		return   # 主场景背景视差恒动，无关噪音整枝剪掉
	if node is CanvasItem:
		out[String(node.get_path())] = (node as CanvasItem).get_global_transform().origin
	for c: Node in node.get_children():
		_collect(c, out)
