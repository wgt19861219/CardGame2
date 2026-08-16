class_name CrusadeFills
extends RefCounted

## crusade panel fill 下沉（批 3 Task 7，LINT005 View 400 行上限）：格子散点 fill +
## 规则页文本 fill 纯数据绑定。SOP fills 条款：禁建静态结构节点/禁样式 override。
## 照源 gametable/crusadeconfig.lua battle1-15/box1-15 散点位置（三段 Map 容器，
## 逐图 px/CS 实测尺寸）+ ui/crusade.lua:543-595 initRuleLayer 17 项。
## 贴图口径（批 3 Task 4 定稿）：crusade 系条目 Prescaled=false → 只算显式 scale 累乘
## （box=px/CS×0.8；battle 无 scale=px/CS；rect 恒 normal 图口径，源 setTexture 不改 contentSize）。

const CONTENT_SCALE: float = 1.28125
const STAGE_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/stage/crusade_stage_"
const BOX_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/crusade_box_"
# 源 crusadeconfig box config={scale=0.8}（:96 等 15 处）；closed 图 PIL 实测像素
# （bronze 89×84 / silver·gold_closed 90×84）。
const BOX_SCALE: float = 0.8
const BOX_CLOSED_PX := {
	"bronze": Vector2(89.0, 84.0), "silver": Vector2(90.0, 84.0), "gold": Vector2(90.0, 84.0),
}
const MAP_NAMES: Array[String] = ["LaftMap", "RightMap", "RightMap2"]
# 源 battle1-15 中心（Map 局部 cocos，crusadeconfig:280-579，每段 5 只）。
const BATTLE_POS: Array[Array] = [
	[Vector2(135.0, 260.0), Vector2(210.0, 132.0), Vector2(370.0, 211.0), Vector2(548.0, 268.0), Vector2(584.0, 126.0)],
	[Vector2(121.0, 190.0), Vector2(345.0, 130.0), Vector2(278.0, 275.0), Vector2(472.0, 283.0), Vector2(584.0, 145.0)],
	[Vector2(30.0, 265.0), Vector2(60.0, 120.0), Vector2(185.0, 230.0), Vector2(375.0, 277.0), Vector2(285.0, 130.0)],
]
# 源 box1-15 中心（Map 局部 cocos，段 1/2/3 = 4+6+5 只不均匀，crusadeconfig:85-279）。
const BOX_POS: Array[Array] = [
	[Vector2(100.0, 155.0), Vector2(350.0, 110.0), Vector2(410.0, 310.0), Vector2(488.0, 162.0)],
	[Vector2(-10.0, 170.0), Vector2(215.0, 117.0), Vector2(320.0, 186.0), Vector2(370.0, 305.0), Vector2(468.0, 133.0), Vector2(627.0, 262.0)],
	[Vector2(-10.0, 175.0), Vector2(157.0, 130.0), Vector2(233.0, 310.0), Vector2(350.0, 195.0), Vector2(435.0, 125.0)],
]
const BOX_SECTION_BASE: Array[int] = [0, 4, 10]
# 源 initRuleLayer 17 项（crusade.lua:543-595）：6 叙事 + 空 + 标题 + 7 规则 + 空×2。
const RULE_LSTR_KEYS: Array[String] = [
	"CRUSADE.TEXT_DARK_WHITE_MOLTEN_VOLCANIC_BURST",
	"CRUSADE.TEXT_DARK_WHITE_DRAGON_TREASURE_REVEALS_TO_THE_WORLD",
	"CRUSADE.TEXT_DARK_WHITE_DREAMER_BEWARE_OF_YOUR_GREED",
	"CRUSADE.TEXT_DARK_WHITE_BECAUSE_THE_MORE_DANGEROUS_MAN_THAN_ARALIA",
	"CRUSADE.TEXT_DARK_WHITE_IS_THE_TREASURE_HUNTER_WITH_YOU",
	"CRUSADE.TEXT_DARK_WHITE_PROPHECY_OF_FIRE_VOLUME_VII",
	"",
	"CRUSADE.TEXT_NormalButton_BATTLE_RULES_",
	"CRUSADE.TEXT___NORMALBUTTON___ABOVE_1_LEVEL_20+_HEROES_CAN_PARTICIPATE_IN_THE_EXPEDITION",
	"CRUSADE.TEXT___NORMALBUTTON___2_DURING_THE_EXPEDITION_HP_AND_ENERGY_OF_BOTH_SIDE_WILL_NOT_RECOVER_AND_RESET",
	"CRUSADE.TEXT___NORMALBUTTON___3_DIED_HEROES_WILL_NOT_BE_RESURRECTED",
	"CRUSADE.TEXT___NORMALBUTTON___4_IF_THE_FIGHT_IS_NOT_OVER_IN_DUE_TIME_ALL_HEROES_OF_BOTH_SIDE_SHALL_BE_COUNTED_AS_DEAD",
	"CRUSADE.TEXT___NORMALBUTTON___5_PLAYERS_CAN_PARTICIPATE_THE_EXPEDITION_ONCE_A_DAY_VIP10_OR_HIGHER_CAN_PARTICIPATE_MULTIPLE_TIMES_A_DAY",
	"CRUSADE.TEXT_NormalButton_6_AFTER_DEFEATING_EVERY_WAVE_OF_ENEMY_YOU_CAN_OPEN_CHEST_TO_GET_GREATER_REWARDS_REWARDS",
	"CRUSADE.TEXT_NormalButton_7_YOU_CAN_ALSO_GET_DRAGONSCALE_COINS_FROM_THE_CHEST_WITH_THE_FIRST_RESET_OF_THE_EXPEDITION_DRAGONSCALE_COINS",
	"",
	"",
]
const RULE_TITLE_KEY: String = "CRUSADECONFIG.BURNING_CRUSADE"
const RULE_TITLE_FALLBACK: String = "燃烧的远征"


## 格子动态行照源散点（box 先挂——源 z 序 box 下 battle 上）。返回
## {"stages": Array[TextureButton], "boxes": Array[TextureButton]}（顺序均按 idx 1-15）。
static func fill_stage_grid(content: Control, player: PlayerData, on_stage: Callable, on_box: Callable) -> Dictionary:
	var stages: Array[TextureButton] = []
	var boxes: Array[TextureButton] = []
	for s in range(3):
		var map_node: Control = content.get_node("%" + MAP_NAMES[s]) as Control
		for b in range(BOX_POS[s].size()):
			var idx: int = BOX_SECTION_BASE[s] + b + 1
			var box_sz: Vector2 = (BOX_CLOSED_PX[box_tier(idx)] as Vector2) / CONTENT_SCALE * BOX_SCALE
			var box := TextureButton.new()
			box.texture_normal = _load_tex(box_texture(player, idx))
			box.ignore_texture_size = true
			box.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			box.position = map_local_top_left(BOX_POS[s][b], box_sz)
			box.size = box_sz
			box.pressed.connect(on_box.bind(idx))
			map_node.add_child(box)
			boxes.append(box)
		for b in range(5):
			var idx: int = s * 5 + b + 1
			var tex: Texture2D = _load_tex(STAGE_TEX_DIR + str(idx) + ".png") as Texture2D
			var btn_sz: Vector2 = (tex.get_size() if tex != null else Vector2(110.0, 110.0)) / CONTENT_SCALE
			var btn := TextureButton.new()
			btn.texture_normal = _load_tex(stage_texture(player, idx))
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			btn.position = map_local_top_left(BATTLE_POS[s][b], btn_sz)
			btn.size = btn_sz
			btn.pressed.connect(on_stage.bind(idx))
			map_node.add_child(btn)
			stages.append(btn)
	return {"stages": stages, "boxes": boxes}


## 源 Map 为空容器（中心点语义，无 contentSize）：cocos 子中心 (x,y 上正) 相对
## Map 中心 → Godot 局部左上 = (x-半宽, -(y+半高))（dungeon_map 同口径）。
static func map_local_top_left(cocos_pos: Vector2, node_size: Vector2) -> Vector2:
	return Vector2(cocos_pos.x - node_size.x * 0.5, -cocos_pos.y - node_size.y * 0.5)


## 规则页文本 fill（结构静态在 tscn：RuleTitleLabel + RuleItem1-17；色已静态化）。
static func fill_rule_layer(content: Control, cm: Variant) -> void:
	var title: Label = content.get_node("%RuleTitleLabel") as Label
	title.text = _lstr(cm, RULE_TITLE_KEY, RULE_TITLE_FALLBACK)
	for i in range(RULE_LSTR_KEYS.size()):
		var key: String = RULE_LSTR_KEYS[i]
		if key == "":
			continue
		var item: Label = content.get_node("%RuleItem" + str(i + 1)) as Label
		item.text = parse_rule_text(_lstr(cm, key, key))


## 剥源 LSTR 富文本 <text|style|内容> 前缀与闭合尾 >（dark_white/normalButton 色已静态化）。
static func parse_rule_text(raw: String) -> String:
	var s := raw
	var idx := s.find("|")
	if idx != -1:
		var idx2 := s.find("|", idx + 1)
		if idx2 != -1:
			s = s.substr(idx2 + 1)
	if s.ends_with(">"):
		s = s.substr(0, s.length() - 1)
	return s


static func box_tier(i: int) -> String:
	if i == 15:
		return "gold"
	if i == 5 or i == 10:
		return "silver"
	return "bronze"


static func box_texture(player: PlayerData, i: int) -> String:
	var state: String = "open" if player.crusade_manager.is_stage_rewarded(i) else "closed"
	return BOX_TEX_DIR + box_tier(i) + "_" + state + ".png"


static func stage_texture(player: PlayerData, i: int) -> String:
	var state: String = "locked"
	if player.crusade_manager.cur_stage == i:
		state = "current"
	elif player.crusade_manager.is_stage_cleared(i):
		state = "passed"
	return STAGE_TEX_DIR + str(i) + "_" + state + ".png"


## 面板刷新入口：路径 → 安全加载（exists 预检，返回 Texture2D 或 null）。
static func stage_button_texture(player: PlayerData, i: int) -> Variant:
	return _load_tex(stage_texture(player, i))


static func box_button_texture(player: PlayerData, i: int) -> Variant:
	return _load_tex(box_texture(player, i))


## 资源安全加载（exists 预检，避 headless/未 import 时 load push_error）。
static func _load_tex(path: String) -> Variant:
	return load(path) if ResourceLoader.exists(path) else null


static func _lstr(cm: Variant, key: String, fallback: String) -> String:
	if cm != null:
		var v: String = cm.get_lstr(key)
		return v if v != key else fallback
	return fallback
