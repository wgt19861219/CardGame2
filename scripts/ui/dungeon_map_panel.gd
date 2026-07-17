class_name DungeonMapPanel
extends PopWindow

## 副本地图（dungeon_map）UI — 照源 ui/dungeon_map.lua 翻译。
## 入口：main_scene em(英雄试炼 50005-7)/equip(装备副本 50001-4) → setup_panel。
## 源 pushScene 场景 → 单机化 PopWindow 弹窗（同 CrusadePanel 范式，UIRes 缺代码重建）。
## 3 section × 5 boss 横向滚动 + boss 点击弹难度 + 通关宝箱开箱 + 组通关迷雾消散。
## 源 dragContainer 手动拖拽 → ScrollContainer+HBox（CrusadePanel 既有适配），坐标表 crusadeBossPos/BoxPos 降级为顺序布局。
## 2026-07-17 重构：静态层（FrameworkBg/TitleLabel/ResultLabel/CloseBtn/Scroll/Sub1-3/Fog1-3）
## 静态化进 dungeon_map_content.tscn（位置/size 可视化调）；boss/box 照源 for 循环 fill
## 动态建在 Sub 下（数量随 bosses 变，位置照源 crusadeBossPos/BoxPos 表）。

const DegreePopup := preload("res://scripts/ui/dungeon_degree_popup.gd")
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/dungeon_map_content.tscn")

# 源 hello.lua:311 setContentScaleFactor(615/480)=1.28125：cocos sprite contentSize=纹理/CS，position 不变。
# 纯 Sprite（CCSprite 无 fix_size）→ Godot 需 EXPAND_IGNORE_SIZE + size=tex/CS（含 setScale 累乘）等价。
const CONTENT_SCALE: float = 1.28125
const STAGE_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/stage/crusade_stage_"
const BOX_CLOSED_TEX := "res://assets/ui/alpha/HVGA/crusade/crusade_box_bronze_closed.png"
const BOX_OPEN_TEX := "res://assets/ui/alpha/HVGA/crusade/crusade_box_bronze_open.png"
const FOG_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/crusade_fog_"
const STAGE_SIZE := Vector2(110.0, 110.0)
const BOX_SIZE := Vector2(60.0, 60.0)
const SECTION_HEIGHT: float = 350.0      # 源 cocos y 翻转基准（坐标 y 上限 310+余量），_cocos_center_to_topleft 用
const FOG_SIZE := Vector2(230.0, 90.0)   # .tscn Fog 已固化（源 y=SECTION_HEIGHT-210-FOG_SIZE.y/2=95）
const MAX_SECTIONS: int = 3            # 源 dungeon_map.lua:43
const BOSSES_PER_SECTION: int = 5       # 源 :625 ceil(i/5)
const MAX_BOSSES: int = 15              # 源 :44
# 源 dungeon_map.lua:30-34 crusadeBossPos 3 section × 5 boss 固定坐标（cocos）
const CRUSADE_BOSS_POS := [
	[Vector2(135.0, 260.0), Vector2(210.0, 132.0), Vector2(370.0, 211.0), Vector2(548.0, 268.0), Vector2(584.0, 126.0)],
	[Vector2(121.0, 190.0), Vector2(345.0, 130.0), Vector2(278.0, 275.0), Vector2(472.0, 283.0), Vector2(584.0, 145.0)],
	[Vector2(30.0, 265.0), Vector2(60.0, 120.0), Vector2(185.0, 230.0), Vector2(375.0, 277.0), Vector2(285.0, 130.0)],
]
# 源 :36-40 crusadeBoxPos（section1=4 / section2=6 / section3=5）
const CRUSADE_BOX_POS := [
	[Vector2(100.0, 155.0), Vector2(350.0, 110.0), Vector2(410.0, 310.0), Vector2(488.0, 162.0)],
	[Vector2(-10.0, 170.0), Vector2(215.0, 117.0), Vector2(320.0, 186.0), Vector2(370.0, 305.0), Vector2(468.0, 133.0), Vector2(627.0, 262.0)],
	[Vector2(-10.0, 175.0), Vector2(157.0, 130.0), Vector2(233.0, 310.0), Vector2(350.0, 195.0), Vector2(435.0, 125.0)],
]
const TEAM_MAX: int = 5                 # 源 5v5 上场英雄上限
const DUNGEON_DIFF_OFFSET: int = 1000   # 源 battle_engine.lua:359 lookupId += (diff-1)*1000
const STAGE_IMG_COUNT: int = 15         # 源 :642 (i-1)%15+1
const FOG_IMG_COUNT: int = 4            # 源 :693 ((s-1)%4)+1
const BOX_OPEN_SCALE: float = 0.8       # 源 :674 setScale(0.8)
const GRAY_MODULATE := Color(0.4, 0.4, 0.4)  # 源 setSpriteGray 近似

var player: PlayerData = null
var stage_manager: StageManager = null
var rng: BattleRng = null
var mode: String = ""                   # 源 param.mode（em/equip）
var group_ids: Array[int] = []          # 源 param.groupIds
var bosses: Array = []                  # boss 数据（base_id/name/difficulties/section_idx）
var group_counts: Dictionary = {}       # 源 groupBossCounts（group_idx → boss 数）
var group_offsets: Dictionary = {}      # 源 groupBossOffset（group_idx → 起始偏移）
var opened_chests: Dictionary = {}      # 源 openedChests（base_id → bool）
var boss_buttons: Array[TextureButton] = []
var box_rects_by_idx: Dictionary = {}    # 源 box%d{bossIdx} 稀疏映射（bossIdx=(s-1)*5+b，:678）
var fog_rects: Array[TextureRect] = []
var title_label: Label = null
var result_label: Label = null
var _active_popup: DungeonDegreePopup = null  # 源 dungeon_map.lua:23 degreePopup
var _content: Control = null             # .tscn 根（%FrameworkBg/Title/Close/Scroll/Sub1-3/Fog1-3 持有者）


func setup_panel(p_player: PlayerData, p_stage_manager: StageManager, p_rng: BattleRng, p_mode: String, p_group_ids: Array[int]) -> void:
	player = p_player
	stage_manager = p_stage_manager
	rng = p_rng
	mode = p_mode
	group_ids = p_group_ids
	_collect_bosses()
	setup()
	# 源 dungeon_map.lua:605 pushScene 独立场景（framework.lua:749 自动建全屏 bg.jpg，见 :6 注释），
	# 本项目单机化 pushScene→PopWindow，故 shade 透明 + %FrameworkBg（.tscn 已固化）还原源视觉（同 PackagePanel 范式）。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_content()
	_fill_boss_list()
	_refresh_boss_states()


## 建 UI 内容。静态层（FrameworkBg/TitleLabel/ResultLabel/CloseBtn/Scroll/Sub1-3/Fog1-3）
## 从 dungeon_map_content.tscn instantiate（位置/size 可视化）；fog texture 按 section fill。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	# 源 dungeon_map.lua 无 title label（scene 标题由入口 panel 继承，dungeonmapconfig 也无文本）。
	# 项目 PopWindow 弹窗化后需自带标题区分 em/equip 模式；无源 LSTR key，文案是项目单机化适配。
	title_label = _content.get_node("%TitleLabel") as Label
	title_label.text = "英雄试炼" if mode == "em" else "装备副本"
	# 源无 result_label（dungeon_map.lua 状态在 bottom 栏）。项目 PopWindow 弹窗化补的提示，文案项目自定。
	result_label = _content.get_node("%ResultLabel") as Label
	result_label.text = "共 %d 个 boss（点击挑战）" % bosses.size()
	# 主面板 close 照源 statusbar.lua:164 backbtn（framework 全局注入大面板返回）；
	# X(dungeon_map.lua:344) 属 DegreePopup 弹窗，保留独立组件 dungeon_degree_popup。
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	# 3 sub + fog 已 .tscn 固化位置/size（源 subOffsetX 25/752/1477 + fog y=210 anchor 0,0.5）；
	# texture/visible/modulate 按源 fill。
	fog_rects.clear()
	for s in range(1, MAX_SECTIONS + 1):
		var sub: Control = _content.get_node("%Sub" + str(s)) as Control
		var fog: TextureRect = sub.get_node("%Fog" + str(s)) as TextureRect
		var fog_idx: int = ((s - 1) % FOG_IMG_COUNT) + 1  # 源 :693
		fog.texture = _load_tex(FOG_TEX_DIR + str(fog_idx) + ".png")
		fog_rects.append(fog)


## 源 dungeon_map.lua:636-683 build：3 section × 5 boss + box 按 crusadeBossPos/BoxPos 表 fill 动态建。
func _fill_boss_list() -> void:
	boss_buttons.clear()
	box_rects_by_idx.clear()
	for s in range(1, MAX_SECTIONS + 1):
		var sub: Control = _content.get_node("%Sub" + str(s)) as Control
		_fill_section_bosses(sub, s)
		_fill_section_boxes(sub, s)


## 源 :636-656 section 内 boss 按 crusadeBossPos[s][localIdx] 固定坐标（anchor 0.5）。
func _fill_section_bosses(sub: Control, section: int) -> void:
	var section_globals: Array[int] = _section_global_indices(section)
	var boss_row: Array = CRUSADE_BOSS_POS[section - 1]
	for local_idx in range(1, section_globals.size() + 1):
		var global_i: int = section_globals[local_idx - 1]
		var pos_idx: int = min(local_idx, BOSSES_PER_SECTION)  # 源 :641
		var bpos: Vector2 = boss_row[pos_idx - 1]
		var img_idx: int = ((global_i - 1) % STAGE_IMG_COUNT) + 1  # 源 :642
		var btn := TextureButton.new()
		btn.texture_normal = _load_tex(STAGE_TEX_DIR + str(img_idx) + ".png")
		btn.texture_disabled = btn.texture_normal
		btn.position = _cocos_center_to_topleft(bpos, STAGE_SIZE)
		btn.size = STAGE_SIZE
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.pressed.connect(Callable(self, "_on_boss_pressed").bind(global_i))
		sub.add_child(btn)
		boss_buttons.append(btn)


## 源 :658-683 section 内宝箱按 crusadeBoxPos[s][b]，box%d{bossIdx=(s-1)*5+b} 稀疏映射。
func _fill_section_boxes(sub: Control, section: int) -> void:
	var section_globals: Array[int] = _section_global_indices(section)
	var box_row: Array = CRUSADE_BOX_POS[section - 1]
	var box_count: int = min(section_globals.size(), box_row.size())  # 源 :666
	for b in range(1, box_count + 1):
		var boxp: Vector2 = box_row[b - 1]
		var boss_idx: int = (section - 1) * BOSSES_PER_SECTION + b  # 源 :677
		var box := TextureRect.new()
		box.texture = _load_tex(BOX_CLOSED_TEX)
		box.position = _cocos_center_to_topleft(boxp, BOX_SIZE)
		box.size = BOX_SIZE
		box.scale = Vector2(BOX_OPEN_SCALE, BOX_OPEN_SCALE)  # 源 :674
		box.ignore_texture_size = true
		box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		box.gui_input.connect(Callable(self, "_on_box_gui_input").bind(boss_idx))
		sub.add_child(box)
		box_rects_by_idx[boss_idx] = box


## 源 dungeon_map.lua:608-627 收集 bosses + group_counts/offsets + sectionIdx 分配。
func _collect_bosses() -> void:
	bosses = []
	group_counts = {}
	group_offsets = {}
	var mgr := ExerciseManager.new()
	mgr.setup(stage_manager.config)
	for g in range(1, group_ids.size() + 1):
		var gid: int = int(group_ids[g - 1])
		group_offsets[g] = bosses.size()
		var group: Array = mgr.get_dungeon_bosses(gid)
		group_counts[g] = group.size()
		for boss in group:
			bosses.append(boss)
			if bosses.size() >= MAX_BOSSES:
				break
		if bosses.size() >= MAX_BOSSES:
			break
	# 源 :624-627 boss.sectionIdx = ceil(i/5)，封顶 MAX_SECTIONS
	for i in range(1, bosses.size() + 1):
		var section: int = int(ceil(float(i) / float(BOSSES_PER_SECTION)))
		bosses[i - 1]["section_idx"] = min(section, MAX_SECTIONS)


## 返回 section 内 boss 的全局索引（升序）。
func _section_global_indices(section: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(1, bosses.size() + 1):
		var boss: Dictionary = bosses[i - 1]
		if int(boss.get("section_idx", 1)) == section:
			result.append(i)
	return result


## 源 cocos anchor 0.5,0.5 pos=中心 → Godot Control 左上（y 翻转）。
static func _cocos_center_to_topleft(cocos_pos: Vector2, node_size: Vector2) -> Vector2:
	var godot_y := SECTION_HEIGHT - cocos_pos.y
	return Vector2(cocos_pos.x - node_size.x * 0.5, godot_y - node_size.y * 0.5)


## 源 dungeon_map.lua:264-276 refreshBattleState：未解锁灰显 + cleared+openedChests 才 open（手动开箱）。
func _refresh_boss_states() -> void:
	for i in range(1, bosses.size() + 1):
		var boss: Dictionary = bosses[i - 1]
		var base_id: int = int(boss["base_id"])
		var unlocked: bool = ExerciseManager.is_boss_unlocked(bosses, stage_manager.progress, i)
		boss_buttons[i - 1].modulate = GRAY_MODULATE if not unlocked else Color(1, 1, 1)
		# 源 :271 cleared and openedChests[baseId] 才切 open（手动开，非 cleared 自动开）
		var box: TextureRect = box_rects_by_idx.get(i, null)
		if box != null and is_instance_valid(box):
			var cleared: bool = ExerciseManager.is_boss_cleared(stage_manager.progress, base_id)
			var opened: bool = bool(opened_chests.get(base_id, false))
			box.texture = _load_tex(BOX_OPEN_TEX if (cleared and opened) else BOX_CLOSED_TEX)
	_refresh_fog()


## 源 dungeon_map.lua:281-292 refreshFogAnimation：组通关 fog CCFadeOut(0.5)+setVisible(false)。
func _refresh_fog() -> void:
	for s in range(1, MAX_SECTIONS + 1):
		var idx: int = s - 1
		if idx >= fog_rects.size():
			break
		var fog: TextureRect = fog_rects[idx]
		if not is_instance_valid(fog):
			continue
		var cleared: bool = ExerciseManager.is_group_cleared(bosses, group_counts, group_offsets, stage_manager.progress, s)
		if cleared:
			if fog.modulate.a > 0.01:  # 避免重复 tween
				_fade_out_fog(fog)
		else:
			fog.visible = true
			fog.modulate = Color(1, 1, 1, 1)


## 源 :286-289 CCFadeOut(0.5) + setVisible(false)；不在树内则立即隐（单测路径）。
func _fade_out_fog(fog: TextureRect) -> void:
	if not is_inside_tree():
		fog.visible = false
		fog.modulate.a = 0.0
		return
	fog.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(fog, "modulate:a", 0.0, 0.5)  # 源 CCFadeOut(0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(fog):
			fog.visible = false)


## 源 dungeon_map.lua:582-595 selectBoss → 弹难度选择（DegreePopup）。
## 源 :185-189 点未解锁 boss 无 toast（dungeon_map.lua isBossUnlocked false 直接 return）；
## 本 toast 是项目适配反馈，文案项目自定（DUNGEON.HEROIC_PREREQ 语义不符，不入 LSTR）。
func _on_boss_pressed(idx: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")  # 源 exerciselsr.clickExercise（sound_res 无 exercise 段，common_* 适配）
	if not ExerciseManager.is_boss_unlocked(bosses, stage_manager.progress, idx):
		Toast.show_message("通关前置 boss 后解锁")
		return
	_open_degree_popup(idx)


## 源 dungeon_map.lua:316-498 showDegreePopup：创建 DegreePopup + 连信号 + show。
func _open_degree_popup(idx: int) -> void:
	_close_degree_popup()
	var boss: Dictionary = bosses[idx - 1]
	var popup: DungeonDegreePopup = DegreePopup.new("dungeonDegree", {})
	popup.setup_popup(idx, String(boss.get("name", "")), boss.get("difficulties", []), player.team_level)
	popup.degree_selected.connect(_on_degree_selected)
	popup.close_requested.connect(_on_degree_close)
	popup.show_window(self)
	_active_popup = popup


func _close_degree_popup() -> void:
	if _active_popup != null and is_instance_valid(_active_popup):
		_active_popup.remove_window()
	_active_popup = null


## 源 dungeon_map.lua:547-570 + battle_engine.lua:357-363 点难度 → 战斗入口。
## diff>1 时 lookup_id = base_id + (diff-1)*1000（源 lookupId 调整）。assemble + battle_context + 切 battle_scene。
## 注：Battle 表缺 dungeon 段（50013-53015，数据债），battle_info 空 → stage_manager stub 桩敌人兜底，下次补 Battle 表 dungeon 段。
func _on_degree_selected(idx: int, diff: Dictionary) -> void:
	_close_degree_popup()
	var boss: Dictionary = bosses[idx - 1]
	var base_id: int = int(boss["base_id"])
	var diff_num: int = int(diff["diff"])
	var lookup_id: int = base_id + (diff_num - 1) * DUNGEON_DIFF_OFFSET
	var tids: Array[int] = _team_tids()
	if tids.is_empty():
		# 源 :547-570 stagedetail.createForExercise 直接 pushScene，不校验 team（heroLimit=nil）；
		# 项目校验空队防 battle_scene 崩溃，toast 文案项目自定。
		Toast.show_message("无上场英雄")
		return
	var asm_r: Dictionary = stage_manager.assemble_stage_battle(lookup_id, player, tids, rng)
	if not bool(asm_r.get("ok", false)):
		# 源 :552 体力不足 showHandyDialog("buyVitality")；装配失败源无（装配在 battleprepare）。
		# 项目 assemble_stage_battle 统一返 ok，toast 文案项目自定（无源 LSTR key）。
		Toast.show_message("体力不足或装配失败")
		return
	GameData.battle_context = {
		"engine": asm_r["engine"], "battle_info": asm_r["battle_info"],
		"loots": asm_r["loots"], "stage_id": lookup_id, "player_tids": tids, "mgr": stage_manager,
	}
	remove_window()
	SceneManager.change_scene("res://scenes/battle/battle_scene.tscn")


## 上场英雄 tid 列表（player.team inst_id → tid；空则取前 TEAM_MAX 个，照 crusade_panel 范式）。
func _team_tids() -> Array[int]:
	var tids: Array[int] = []
	if player == null or player.hero_manager == null:
		return tids
	for inst_id in player.team:
		var hero: HeroInstance = player.hero_manager.get_hero(int(inst_id))
		if hero != null:
			tids.append(hero.tid)
	if tids.is_empty():
		for inst_id in player.hero_manager.heroes:
			tids.append(int(player.hero_manager.heroes[inst_id].tid))
			if tids.size() >= TEAM_MAX:
				break
	return tids


func _on_degree_close() -> void:
	_active_popup = null


## 宝箱点击（源 dungeon_map.lua:194-213 dragLayerTouch box 检测 → openChest）。
func _on_box_gui_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_chest(idx)


## 源 dungeon_map.lua:222-259 openChest：切 open 纹理 + 弹跳动画 + 读 StageDungeon 奖励入背包 + toast。
## 源 :246-250 分流 addEquip/addItem，项目 player.add_item 内部统一（含图鉴 record_equip），等价。
## 源 :251-256 toast 中文物名（Item 表 Display Name，无则 fallback "Item:" + id），非数字 ID。
func _open_chest(idx: int) -> void:
	if idx < 1 or idx > bosses.size():
		return
	var boss: Dictionary = bosses[idx - 1]
	var base_id: int = int(boss["base_id"])
	if bool(opened_chests.get(base_id, false)):
		return  # 源 :223 已开 → return
	if not ExerciseManager.is_boss_cleared(stage_manager.progress, base_id):
		# 源 :194-213 仅 cleared+未开宝箱才入点击检测；本 toast 是项目适配（源点未通宝箱不响应）。
		Toast.show_message("通关后可开启宝箱")
		return
	opened_chests[base_id] = true
	var box: TextureRect = box_rects_by_idx.get(idx, null)  # 源 box%d{idx}
	if box != null and is_instance_valid(box):
		box.texture = _load_tex(BOX_OPEN_TEX)
		# 源 :232-236 弹跳动画（scale 1.1→0.9→1.0，绝对值覆盖初始 0.8）
		if is_inside_tree():
			var tw := create_tween()
			tw.tween_property(box, "scale", Vector2(1.1, 1.1), 0.1)
			tw.tween_property(box, "scale", Vector2(0.9, 0.9), 0.1)
			tw.tween_property(box, "scale", Vector2(1.0, 1.0), 0.1)
	# 源 :239-258 StageDungeon[base_id] UI reward1-7 → add_item + toast 中文名
	var stage_data: Dictionary = stage_manager.config.get_raw_table(&"StageDungeon").get(str(base_id), {})
	for i in range(1, 8):
		var reward_id: int = int(stage_data.get(&"UI reward" + str(i), 0))
		if reward_id != 0:
			player.add_item(reward_id)
			Toast.show_message(_reward_display_name(reward_id))  # 源 :254-256 Display Name


## 源 dungeon_map.lua:251-256 查 Item 表 Display Name，无则 fallback "Item:" + id（照源）。
func _reward_display_name(item_id: int) -> String:
	var row: Dictionary = stage_manager.config.get_raw_table(&"Item").get(str(item_id), {})
	var n: String = String(row.get("Display Name", ""))
	if n.length() > 0:
		return n
	return "Item:%d" % item_id  # 源 :255 fallback


## 资源安全加载（exists 预检，避 headless 未 import 时 push_error）。
static func _load_tex(path: String) -> Variant:
	return load(path) if ResourceLoader.exists(path) else null
