class_name DungeonMapPanel
extends PopWindow

## 入口：main_scene em(英雄试炼 50005-7)/equip(装备副本 50001-4) → setup_panel。
## 3 section × 5 boss 横向滚动 + boss 点击弹难度 + 通关宝箱开箱 + 组通关迷雾消散。
## 照源 ui/dungeon_map.lua:538-676 + gametable/dungeonmapconfig.lua（:256-520 难度弹窗
## 段由 dungeon_degree_popup 独立组件承担，setup_popup 接口不变）。
## 2026-08-16 两件套改造（批3关卡组）：静态层（Scroll/ScrollContent 内 Bg1-3/Sub1-3/
## Fog1-3 + content 根 Light1-2/Frame/TitleBg/BottomFrame）全静态进 dungeon_map_content.tscn；
## 原 CrusadePanelBuilder procedural 美术层退役；boss/box 是动态行（数量随 groupIds
## 数据、贴图 15 变体各异），照源裸 CCSprite:create 循环 fill 保留代码构造。

const DegreePopup := preload("res://scripts/ui/dungeon_degree_popup.gd")
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/dungeon_map_content.tscn")

# 点空间直译（批3 Task 1 定稿）：cocos 点值 = Godot 点值，贴图显示尺寸另轨 = 像素÷CS。
# crusade 系 TextureConfig 条目全 Prescaled=false → 条目 CS 不施加（源 resource_manager
# win32 路径 return 1），只算显式 setScale/readnode config.scale 累乘。
const CONTENT_SCALE: float = 1.28125
const STAGE_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/stage/crusade_stage_"
const BOX_CLOSED_TEX := "res://assets/ui/alpha/HVGA/crusade/crusade_box_bronze_closed.png"
const BOX_OPEN_TEX := "res://assets/ui/alpha/HVGA/crusade/crusade_box_bronze_open.png"
# 源 sub1-3（空容器中心 (25,12)/(752,12)/(1477,12)，dragContainer 局部）→ marker 原点
# (x, 480-12)——Sub 内 boss/box 中心相对 sub 中心，cocos y 上正 → Godot 负。
const SUB_ORIGINS := [
	Vector2(25.0, 468.0), Vector2(752.0, 468.0), Vector2(1477.0, 468.0),
]
# 滚动内容坐标系：dragLayer 全屏 480 高（y=480-cocos_y）；内容宽照源 calcMaxRight
# （:129-142 拖拽 x∈[min(0,660-maxX),0] 不留空白）等价 = maxX+140，窄于视口 800 不滚。
const CONTENT_VIEW_HEIGHT: float = 480.0
const CONTENT_BASE_WIDTH: float = 800.0
const SCROLL_TAIL_MARGIN: float = 140.0
const MAX_SECTIONS: int = 3
const BOSSES_PER_SECTION: int = 5
const MAX_BOSSES: int = 15
const CRUSADE_BOSS_POS := [
	[Vector2(135.0, 260.0), Vector2(210.0, 132.0), Vector2(370.0, 211.0), Vector2(548.0, 268.0), Vector2(584.0, 126.0)],
	[Vector2(121.0, 190.0), Vector2(345.0, 130.0), Vector2(278.0, 275.0), Vector2(472.0, 283.0), Vector2(584.0, 145.0)],
	[Vector2(30.0, 265.0), Vector2(60.0, 120.0), Vector2(185.0, 230.0), Vector2(375.0, 277.0), Vector2(285.0, 130.0)],
]
const CRUSADE_BOX_POS := [
	[Vector2(100.0, 155.0), Vector2(350.0, 110.0), Vector2(410.0, 310.0), Vector2(488.0, 162.0)],
	[Vector2(-10.0, 170.0), Vector2(215.0, 117.0), Vector2(320.0, 186.0), Vector2(370.0, 305.0), Vector2(468.0, 133.0), Vector2(627.0, 262.0)],
	[Vector2(-10.0, 175.0), Vector2(157.0, 130.0), Vector2(233.0, 310.0), Vector2(350.0, 195.0), Vector2(435.0, 125.0)],
]
const TEAM_MAX: int = 5
const DUNGEON_DIFF_OFFSET: int = 1000
const STAGE_IMG_COUNT: int = 15
# 源 :609-612 box setScale(0.8)；:212 换 open 图只 setTexture 不改 rect（尺寸恒 closed 口径）。
const BOX_SCALE: float = 0.8
# 源 setSpriteGray（resource_manager.lua:871-877）= ccc3(100,100,100)+opacity 180
# （2026-08-22 巡检订正：旧 (0.4,0.4,0.4) 色值偏且缺 alpha）。
const GRAY_MODULATE := Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0)

var player: PlayerData = null
var stage_manager: StageManager = null
var rng: BattleRng = null
var mode: String = ""
var group_ids: Array[int] = []
var bosses: Array = []                  # boss 数据（base_id/name/difficulties/section_idx）
var group_counts: Dictionary = {}
var group_offsets: Dictionary = {}
var boss_buttons: Array[TextureButton] = []
var box_rects_by_idx: Dictionary = {}
var fog_rects: Array[TextureRect] = []
var title_label: Label = null
var _active_popup: DungeonDegreePopup = null
var _content: Control = null             # .tscn 根（静态层持有者）


func setup_panel(p_player: PlayerData, p_stage_manager: StageManager, p_rng: BattleRng, p_mode: String, p_group_ids: Array[int]) -> void:
	hud_identity = "dungeonMap"   # T4：原 apply/remove override 样板上收基类
	transparent_shade = true   # T4：原 shade 透明 hack 上收基类（content 自带全屏 FrameworkBg）
	player = p_player
	stage_manager = p_stage_manager
	rng = p_rng
	mode = p_mode
	group_ids = p_group_ids
	_collect_bosses()
	setup()
	_build_content()
	_fill_boss_list()
	_refresh_boss_states()


## connect 静态层信号 + 收集 fog 引用（静态美术层已在 .tscn，原 procedural builder 退役）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	# 项目 PopWindow 弹窗化后需自带标题区分 em/equip 模式；无源 LSTR key，文案是项目单机化适配。
	title_label = _content.get_node("%TitleLabel") as Label
	title_label.text = "英雄试炼" if mode == "em" else "装备副本"
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	fog_rects.clear()
	var scroll_content: Control = _content.get_node("%ScrollContent") as Control
	for s in range(1, MAX_SECTIONS + 1):
		fog_rects.append(scroll_content.get_node("%Fog" + str(s)) as TextureRect)


func _fill_boss_list() -> void:
	boss_buttons.clear()
	box_rects_by_idx.clear()
	for s in range(1, MAX_SECTIONS + 1):
		var sub: Control = _content.get_node("%Sub" + str(s)) as Control
		_fill_section_bosses(sub, s)
		_fill_section_boxes(sub, s)
	_apply_scroll_content_width()


## boss 动态行（源 :574-594 裸 CCSprite 循环）：数量随 groupIds、贴图 15 变体尺寸各异
## （239×213~207×169px），显示尺寸 = 像素÷CS 逐图实测（原 STAGE_SIZE=110 定值是迁移误差）。
func _fill_section_bosses(sub: Control, section: int) -> void:
	var section_globals: Array[int] = _section_global_indices(section)
	var boss_row: Array = CRUSADE_BOSS_POS[section - 1]
	for local_idx in range(1, section_globals.size() + 1):
		var global_i: int = section_globals[local_idx - 1]
		var pos_idx: int = min(local_idx, BOSSES_PER_SECTION)
		var bpos: Vector2 = boss_row[pos_idx - 1]
		var img_idx: int = ((global_i - 1) % STAGE_IMG_COUNT) + 1
		var tex: Texture2D = _load_tex(STAGE_TEX_DIR + str(img_idx) + ".png") as Texture2D
		var btn := TextureButton.new()
		btn.texture_normal = tex
		btn.texture_disabled = tex
		# ignore_texture_size 必须先于 size：set_size 会被 minimum_size（默认=纹理原尺寸）钳制。
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var sz: Vector2 = (tex.get_size() if tex != null else Vector2.ZERO) / CONTENT_SCALE
		btn.position = _sub_local_top_left(bpos, sz)
		btn.size = sz
		btn.pressed.connect(Callable(self, "_on_boss_pressed").bind(global_i))
		sub.add_child(btn)
		boss_buttons.append(btn)


## 宝箱动态行（源 :597-621）：closed 89×84px÷CS×0.8 定 rect，通关开箱只换 open 图
## （源 :212 setTexture 不改 contentSize，open 88×99 拉入同 rect）。
func _fill_section_boxes(sub: Control, section: int) -> void:
	var section_globals: Array[int] = _section_global_indices(section)
	var box_row: Array = CRUSADE_BOX_POS[section - 1]
	var box_count: int = min(section_globals.size(), box_row.size())
	var closed_tex: Texture2D = _load_tex(BOX_CLOSED_TEX) as Texture2D
	var box_sz: Vector2 = (closed_tex.get_size() if closed_tex != null else Vector2.ZERO) / CONTENT_SCALE * BOX_SCALE
	for b in range(1, box_count + 1):
		var boxp: Vector2 = box_row[b - 1]
		var boss_idx: int = (section - 1) * BOSSES_PER_SECTION + b
		var box := TextureRect.new()
		box.texture = closed_tex
		# expand_mode 先于 size（同 minimum_size 钳制防护）。
		box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		box.position = _sub_local_top_left(boxp, box_sz)
		box.size = box_sz
		# 源 dungeon_map.lua:211-213 宝箱无点击事件（通关自动换图）——手动开箱系迁移
		# 发明已删（2026-08-22 巡检照源订正，重复发奖一并取消：实际奖励走结算 exit_dungeon）。
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.add_child(box)
		box_rects_by_idx[boss_idx] = box


## 滚动内容宽照源 calcMaxRight（:129-142）：拖到最右时最右 boss 中心距视口右缘 140，
## 内容宽 = maxX+140；boss 不足视口时取视口宽 800（源 min(0,·) 不滚语义）。
func _apply_scroll_content_width() -> void:
	var max_x: float = 0.0
	for i in range(1, bosses.size() + 1):
		var boss: Dictionary = bosses[i - 1]
		var s: int = int(boss.get("section_idx", 1))
		var local_idx: int = i - (s - 1) * BOSSES_PER_SECTION
		var pos_idx: int = min(local_idx, BOSSES_PER_SECTION)
		var row: Array = CRUSADE_BOSS_POS[s - 1]
		if pos_idx - 1 < row.size():
			var abs_x: float = SUB_ORIGINS[s - 1].x + (row[pos_idx - 1] as Vector2).x
			if abs_x > max_x:
				max_x = abs_x
	var width: float = max(max_x + SCROLL_TAIL_MARGIN, CONTENT_BASE_WIDTH)
	# ScrollContainer 按子项 custom_minimum_size 重排（显式 size 会被覆盖），走 min 通道。
	(_content.get_node("%ScrollContent") as Control).custom_minimum_size = Vector2(width, CONTENT_VIEW_HEIGHT)


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


## 源 sub 为空容器（中心点语义，无 contentSize）：boss/box cocos 中心 (x,y 上正) 相对
## sub 中心 → Godot Sub 局部左上 = (x-半宽, -(y+半高))（Sub 原点即源 sub 中心直译）。
static func _sub_local_top_left(cocos_pos: Vector2, node_size: Vector2) -> Vector2:
	return Vector2(cocos_pos.x - node_size.x * 0.5, -cocos_pos.y - node_size.y * 0.5)


func _refresh_boss_states() -> void:
	for i in range(1, bosses.size() + 1):
		var boss: Dictionary = bosses[i - 1]
		var base_id: int = int(boss["base_id"])
		# 源 dungeon_map.lua:207-209 已通关 boss 灰化表"已完成"（cleared→setSpriteGray）；
		# 未解锁仅点击静默（:184）不灰。2026-08-22 巡检订正：旧"未解锁灰"与源完全相反。
		# 宝箱通关即自动换 open 图（源 :211-213 box and cleared→setTexture(open)）。
		var cleared_boss: bool = ExerciseManager.is_boss_cleared(stage_manager.progress, base_id)
		boss_buttons[i - 1].modulate = GRAY_MODULATE if cleared_boss else Color(1, 1, 1)
		var box: TextureRect = box_rects_by_idx.get(i, null)
		if box != null and is_instance_valid(box):
			box.texture = _load_tex(BOX_OPEN_TEX if cleared_boss else BOX_CLOSED_TEX)
	_refresh_fog()


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


func _fade_out_fog(fog: TextureRect) -> void:
	if not is_inside_tree():
		fog.visible = false
		fog.modulate.a = 0.0
		return
	fog.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(fog, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(fog):
			fog.visible = false)


## 源 :184 locked boss 点击静默；toast 是项目适配反馈（文案项目自定，不入 LSTR）。
func _on_boss_pressed(idx: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if not ExerciseManager.is_boss_unlocked(bosses, stage_manager.progress, idx):
		Toast.show_message("通关前置 boss 后解锁")
		return
	_open_degree_popup(idx)


## 难度弹窗（Task 2 独立组件 dungeon_degree_popup，接口：setup_popup 4 参 +
## degree_selected/close_requested 信号，本调用方不得破坏）。
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


## 注：Battle 表缺 dungeon 段（50013-53015，数据债），battle_info 空 → stage_manager stub 桩敌人兜底，下次补 Battle 表 dungeon 段。
func _on_degree_selected(idx: int, diff: Dictionary) -> void:
	_close_degree_popup()
	var boss: Dictionary = bosses[idx - 1]
	var base_id: int = int(boss["base_id"])
	var diff_num: int = int(diff["diff"])
	var lookup_id: int = base_id + (diff_num - 1) * DUNGEON_DIFF_OFFSET
	var tids: Array[int] = _team_tids()
	if tids.is_empty():
		# 项目校验空队防 battle_scene 崩溃，toast 文案项目自定。
		Toast.show_message("无上场英雄")
		return
	var asm_r: Dictionary = stage_manager.assemble_stage_battle(lookup_id, player, tids, rng)
	if not bool(asm_r.get("ok", false)):
		# 2026-08-22 巡检接入每日次数/钥匙/等级检查后 error 分码（文案项目自定，无源 LSTR key）。
		Toast.show_message(_enter_error_text(str(asm_r.get("error", ""))))
		return
	GameData.battle_context = {
		"engine": asm_r["engine"], "battle_info": asm_r["battle_info"],
		"loots": asm_r["loots"], "stage_id": lookup_id, "player_tids": tids, "mgr": stage_manager,
	}
	remove_window()
	SceneManager.change_scene("res://scenes/battle/battle_scene.tscn")


func _enter_error_text(err: String) -> String:
	match err:
		"no_attempts":
			return "今日次数已用完"
		"not_enough_keys":
			return "钥匙不足"
		"not_enough_coins":
			return "龙鳞硬币不足，无法购买次数"
		"heroic_prereq":
			return "需先通关对应普通副本"
		"level_lock":
			return "等级不足"
		"no_vitality":
			return "体力不足"
	return "装配失败"


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


## 资源安全加载（exists 预检，避 headless 未 import 时 push_error）。
static func _load_tex(path: String) -> Variant:
	return load(path) if ResourceLoader.exists(path) else null
