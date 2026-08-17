class_name ShortcutPanel
extends Control

## 快捷栏抽屉（View 层）— 照源 ui/shortcut.lua（button_info + createButtons + createBoard）
## + framework.lua:42-65 doShortcut / :378-554 popBoard·pushBoard 动画 / :556-658 路由 翻译。
## 屏幕右侧竖排 5 按钮（heroPackage/package/fragment/task/todoList）+ 切换按钮（down/up）+ 抽屉板。
## 收起（板高 40，按钮叠在切换钮位置 opacity=0）/ 展开（板高 460，按钮竖排 opacity=255）。
## Tween 动画 0.12s（源 shortcut_board_pop_time），展开后 shade 点 board 外收起。
## 非常驻弹窗，Control 直接挂场景树（z 等价源 frameworkLayer:100）。坐标源 cocos→Godot y 翻转（边缘 UI 非中心对称）。
## 重构（2026-07-17）：UI 静态节点（shade/board/2 toggle/5 button）固化进 shortcut_content.tscn
## （位置/size/texture/visible/modulate/mouse_filter 编辑器可视化调）。panel instantiate + 绑信号 +
## 保留抽屉展开/快捷入口跳转业务逻辑（动画/切换/路由）。Control 非 PopWindow，content 挂 panel 自身。
## Task 4 两件套改造（2026-08-17）：红点 tag 静态节点（主 Tag + 5 按钮 _tag，源 createBoard :310-321
## + createButtons :223-231）照源补全进 tscn；panel 补 refresh_tags()（源 refreshTags :126-144 +
## framework.lua 五个 check handler，package/fragment 照源恒 false）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/shortcut_content.tscn")

const CONTENT_SCALE: float = 1.28125
const SCREEN_H: float = 640.0
const BOARD_CENTER_X: float = 900.0
# 用户视觉偏好(2026-07-14):快捷栏"更上一点贴近顶部"。整个抽屉上移 100px(板顶 180→80 / toggle 200→100,底部留 100px 空白)。
const BOARD_UP_OFFSET: float = -132.0           # 整个抽屉上移量(负=上)；-132 让下拉钮与货币栏上端平齐（top=26）
const BOARD_TOP_Y: float = SCREEN_H - 460.0 + BOARD_UP_OFFSET   # 源板顶 180 + 上移 → 48
const BOARD_WIDTH: float = 82.0
# 收起态板高受控偏离（批 2 Task 8 NinePatch 化）：源 40（uires.lua height_min），但 Godot
# NinePatchRect 最小尺寸=patch margin 和（top40+bottom25=65），40 会被引擎钳到 65；
# 源 Cocos Scale9Sprite 允许 margin 挤压渲染、Godot 不支持。收起态板被 toggle 钮覆盖视觉无感。
const BOARD_H_MIN: float = 65.0
const BOARD_H_MAX: float = 460.0
const TOGGLE_CENTER: Vector2 = Vector2(900.0, SCREEN_H - 440.0 + BOARD_UP_OFFSET)   # y=68，下拉钮 top=26 与货币栏 top=26 上端平齐
const BUTTON_CENTER_Y: Array[float] = [146.0, 236.0, 326.0, 416.0, 506.0]   # 间距 90（源 70~79 太挤，用户要加大）；整体随 BOARD_UP_OFFSET 上移对齐
const BUTTON_ORIGIN_CENTER: Vector2 = TOGGLE_CENTER   # 收起叠点 = 切换钮位置（源 button_ori_pos）
const ANIM_DUR: float = 0.12
const SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)   # 透明检测区（源 out_board shortcut_board_rect 无视觉 shade，仅点击收起检测）
const TOUCH_WIDTH: float = 100.0

# ── 按钮 key + .tscn 节点名映射（源 button_info :11-49）──
const BUTTON_KEYS: Array[String] = ["heroPackage", "package", "fragment", "task", "todoList"]
const BUTTON_NODE_NAMES: Dictionary = {
	"heroPackage": "BtnHeroPackage",
	"package": "BtnPackage",
	"fragment": "BtnFragment",
	"task": "BtnTask",
	"todoList": "BtnTodoList",
}
# 红点 tag 节点名（源 createButtons _tag :223-231；Task 4 两件套改造静态化进 tscn）
const TAG_NODE_NAMES: Dictionary = {
	"heroPackage": "HeroPackageTag",
	"package": "PackageTag",
	"fragment": "FragmentTag",
	"task": "TaskTag",
	"todoList": "TodoListTag",
}

signal open_requested(key: String)   # 按钮点击 → main_scene 路由（package/fragment→PackagePanel / heroPackage→hero_scene）

var _is_open: bool = false
var _shade: ColorRect = null
var _board: NinePatchRect = null
var _toggle_down: TextureButton = null
var _toggle_up: TextureButton = null
var _buttons: Dictionary = {}    # key(String) -> TextureButton
var _main_tag: TextureRect = null   # 收起态聚合红点（源 createBoard tag :310-321）
var _tags: Dictionary = {}    # key(String) -> TextureRect（源 createButtons _tag）
var _tween: Tween = null


# 初始收起（源 isShortcutOpen = identity=="main"；本项目独立面板默认收起）。
func setup_panel(open_initial: bool = false) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 自身不吞，子节点（shade/board/button）各自 STOP 吞
	_build_content()
	if open_initial:
		_apply_open_instant()
	else:
		_apply_closed_instant()


# 建 UI 内容（Phase 重构：从 shortcut_content.tscn instantiate + 绑信号）。
# shortcut 是 Control 非 PopWindow，无 container → content 直接挂自身（同 battle_prepare 范式）。
# .tscn 已固化位置/size/texture/visible/modulate/mouse_filter 为收起态；此处只收集节点引用 + 绑 pressed。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	add_child(content)
	_shade = content.get_node("%Shade") as ColorRect
	_shade.gui_input.connect(_on_shade_gui_input)
	_board = content.get_node("%Board") as NinePatchRect   # tscn Board 已 NinePatchRect 化（源 Scale9Sprite cap(0,25,62,26)）
	_toggle_down = content.get_node("%ToggleDown") as TextureButton
	_toggle_down.pressed.connect(_toggle_open)
	_toggle_up = content.get_node("%ToggleUp") as TextureButton
	_toggle_up.pressed.connect(_toggle_open)
	for key in BUTTON_KEYS:
		var btn: TextureButton = content.get_node("%" + String(BUTTON_NODE_NAMES[key])) as TextureButton
		btn.pressed.connect(_on_button_pressed.bind(key))
		_buttons[key] = btn
		_tags[key] = content.get_node("%" + String(TAG_NODE_NAMES[key])) as TextureRect
	_main_tag = content.get_node("%Tag") as TextureRect
	# 运行时覆盖 .tscn 固化的 toggle/board 位置（.tscn 已固化相同值，此行兜底防误改 + 保常量单一来源）。
	var toggle_topleft: Vector2 = _center_to_topleft(TOGGLE_CENTER, _toggle_down)
	_toggle_down.position = toggle_topleft
	_toggle_up.position = toggle_topleft
	_board.position = Vector2(BOARD_CENTER_X - BOARD_WIDTH / 2.0, BOARD_TOP_Y)
	_board.size = Vector2(BOARD_WIDTH, BOARD_H_MIN)


func _toggle_open() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if _is_open:
		_close()
	else:
		_open()


func _open() -> void:
	_is_open = true
	Events.bus.emit_tutorial_step(&"SUopenShortcut")
	_shade.visible = true
	_toggle_down.visible = false
	_toggle_up.visible = true
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_board, "size", Vector2(BOARD_WIDTH, BOARD_H_MAX), ANIM_DUR).set_ease(Tween.EASE_OUT)
	# 按钮 staggered（源 popBoard :466-475 阈值显现；本项目按索引延迟，等价效果）
	for i in range(BUTTON_KEYS.size()):
		var key: String = BUTTON_KEYS[i]
		var btn: TextureButton = _buttons[key]
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var delay: float = i * (ANIM_DUR * 0.2)
		var target_pos: Vector2 = _center_to_topleft(Vector2(BOARD_CENTER_X, BUTTON_CENTER_Y[i]), btn)
		_tween.parallel().tween_property(btn, "position", target_pos, ANIM_DUR * 0.5).set_delay(delay)
		_tween.parallel().tween_property(btn, "modulate:a", 1.0, ANIM_DUR * 0.5).set_delay(delay)
	refresh_tags()


func _close() -> void:
	_is_open = false
	_toggle_down.visible = true
	_toggle_up.visible = false
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_board, "size", Vector2(BOARD_WIDTH, BOARD_H_MIN), ANIM_DUR).set_ease(Tween.EASE_IN)
	var target_pos: Vector2 = _center_to_topleft(BUTTON_ORIGIN_CENTER, _toggle_down)
	for i in range(BUTTON_KEYS.size()):
		var key: String = BUTTON_KEYS[i]
		var btn: TextureButton = _buttons[key]
		_tween.parallel().tween_property(btn, "position", target_pos, ANIM_DUR * 0.4)
		_tween.parallel().tween_property(btn, "modulate:a", 0.0, ANIM_DUR * 0.4)
	_tween.chain().tween_callback(_on_close_finished)


func _on_close_finished() -> void:
	_shade.visible = false
	for key in _buttons:
		(_buttons[key] as TextureButton).mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh_tags()


# 初始展开态（无动画，照源 isShortcutOpen=main）：板高 max，按钮竖排 opacity=1，up 可见 down 隐藏，shade 透明检测。
func _apply_open_instant() -> void:
	_is_open = true
	_shade.visible = true
	_toggle_down.visible = false
	_toggle_up.visible = true
	_board.size = Vector2(BOARD_WIDTH, BOARD_H_MAX)
	for i in range(BUTTON_KEYS.size()):
		var key: String = BUTTON_KEYS[i]
		var btn: TextureButton = _buttons[key]
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.position = _center_to_topleft(Vector2(BOARD_CENTER_X, BUTTON_CENTER_Y[i]), btn)
		btn.modulate.a = 1.0
	refresh_tags()


# 初始收起态（无动画）：按钮叠 origin opacity=0 + IGNORE，板高 min，down 可见 up 隐藏。
func _apply_closed_instant() -> void:
	var origin_topleft: Vector2 = _center_to_topleft(BUTTON_ORIGIN_CENTER, _toggle_down)
	for key in _buttons:
		var btn: TextureButton = _buttons[key]
		btn.position = origin_topleft
		btn.modulate.a = 0.0
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.size = Vector2(BOARD_WIDTH, BOARD_H_MIN)
	_toggle_up.visible = false
	_toggle_down.visible = true
	_shade.visible = false
	refresh_tags()


func _on_button_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if key == "heroPackage":
		Events.bus.emit_tutorial_step(&"SUclickHeroPackage")
	open_requested.emit(key)
	_close()   # 选完收起抽屉（源点按钮跳转场景，本项目弹窗后收起）


func _on_shade_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_close()


# ── 红点刷新（源 shortcut.lua:126-144 refreshTags + framework.lua:668-737 五个 check handler）──
# Task 4 两件套改造：tag 节点静态化进 tscn，本块只控 visible。
# 刷新时机照源（createButtons 建面板 / doShortcut 开关抽屉）：setup 两分支 + 开关抽屉；
# 数据中途变化不自动刷（源同，面板重建/开关时算），外部可调 refresh_tags() 主动刷。

# 照源 refreshTags :126-144：各按钮 tag 按数据显隐；主 tag = 收起态 && 任一按钮有 tag。
func refresh_tags() -> void:
	var any_show: bool = false
	for key in BUTTON_KEYS:
		var show: bool = _check_button_tag(key)
		(_tags[key] as TextureRect).visible = show
		any_show = any_show or show
	_main_tag.visible = not _is_open and any_show


# 源 framework.lua:727-737 getCheckSCTagHandler 分发。package/fragment 照源 :685-699 恒 false
# （死代码占位）；task/todoList/heroPackage 按数据。源 heroPackage 的 identity 屏蔽不译
# （HudOverlay 全局仅 main 显示本面板，无"已在该页面"态）。
func _check_button_tag(key: String) -> bool:
	match key:
		"package":
			return false
		"fragment":
			return false
		"task":
			return _has_unclaimed_task()
		"todoList":
			return _has_claimable_dailyjob()
		"heroPackage":
			return _has_equippable_prop() or _has_summonable_hero()
	return false


# 源 framework.lua:701-709 checkCompletedTask：任一任务完成未领（可领取）即亮。
func _has_unclaimed_task() -> bool:
	var p: PlayerData = GameData.player
	if p == null:
		return false
	var tm: TaskManager = p.task_manager
	for id in tm.completed:
		if tm.is_completed(id) and not tm.is_claimed(id):
			return true
	return false


# 源 playertools.lua:127-146 checkDailyjobCount：目标达成 && 今日未领（本项目领取后计数归零
# 表达"未领"，与 claim_job_reward 判定对齐）。源 checkDailyjobTrigger（服务器触发窗口）单机化
# 无对应物，以 get_visible_daily_jobs 显示窗口代位；target>0 防 Todolist 空目标行常亮。
func _has_claimable_dailyjob() -> bool:
	var p: PlayerData = GameData.player
	if p == null:
		return false
	var cm: ConfigManager = GameData.config
	var tm: TaskManager = p.task_manager
	var now: int = TaskManager.current_now_minutes()
	for job_id in tm.get_visible_daily_jobs(cm, now):
		var row: Dictionary = cm.get_raw_table("Todolist").get(str(job_id), {})
		var target: int = int(row.get("Task Target", 0))
		if target > 0 and tm.get_dailyjob_count(job_id) >= target:
			return true
	return false


# 源 readhero.lua:732-750 checkEquipableProp：任一英雄任一空槽"配方可合成且等级可穿"。
func _has_equippable_prop() -> bool:
	var p: PlayerData = GameData.player
	if p == null:
		return false
	var cm: ConfigManager = GameData.config
	for inst_id in p.hero_manager.heroes:
		var hero: HeroInstance = p.hero_manager.heroes[inst_id] as HeroInstance
		if hero == null:
			continue
		for slot in range(1, HeroManager.EQUIP_SLOT_COUNT + 1):
			if int(hero.equip_slots[slot - 1]) > 0:
				continue
			var eid: int = EquipdetailQuery.get_slot_expected_equip(hero, slot, cm)
			if eid > 0 and EquipdetailQuery.is_equip_craftable(eid, cm, p) \
					and bool(EquipdetailQuery.can_wear_equip(hero, eid, cm)["can"]):
				return true
	return false


# 源 readhero.lua:751-758 canSummonHero：任一未拥有英雄碎片够召唤。
func _has_summonable_hero() -> bool:
	var p: PlayerData = GameData.player
	if p == null:
		return false
	var cm: ConfigManager = GameData.config
	for tid in ReadheroHandbook.get_miss_list(cm, p.hero_manager):
		if ReadheroHandbook.check_stone_enough(tid, cm, p.hero_manager):
			return true
	return false


func _center_to_topleft(center: Vector2, btn: TextureButton) -> Vector2:
	return center - _button_size(btn) / 2.0


func _button_size(btn: TextureButton) -> Vector2:
	# :284-309 down/up toggle t="Sprite" config={} 无 fix → 显示=纹理/CS
	if btn.texture_normal != null:
		return TexDisplaySize.display_size(btn.texture_normal.resource_path)
	return Vector2(76.0, 76.0)   # 估算（无纹理降级，Phase 4 校准）


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


# ── 公共查询/控制 API（供 HudOverlay 全局管理）──

func is_open() -> bool:
	return _is_open


# 无动画强制展开（照源 framework.lua:989-992 doShortcut(true) 非 main 场景强制展开）。
func open_instant() -> void:
	_apply_open_instant()
