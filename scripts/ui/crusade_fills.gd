class_name CrusadeFills
extends RefCounted

## crusade panel fill 下沉（批 3 Task 7，LINT005 View 400 行上限）：格子散点 fill +
## 规则页文本 fill 纯数据绑定。SOP fills 条款：禁建静态结构节点/禁样式 override。
## 照源 gametable/crusadeconfig.lua battle1-15/box1-15 散点位置（三段 Map 容器，
## 逐图 px/CS 实测尺寸）+ ui/crusade.lua:543-595 initRuleLayer 17 项。
## 贴图口径（批 3 Task 4 定稿）：crusade 系条目 Prescaled=false → 只算显式 scale 累乘
## （box=px/CS×0.8；battle 无 scale=px/CS；rect 恒 normal 图口径，源 setTexture 不改 contentSize）。
## 战节点状态（2026-09-13 二轮修正）：battle 贴图回归源两态（normal/locked——
## _current/_passed 黑剪影资产实机观感"透底发灰+光晕暗淡"，用户验收"图标变透明了"，
## 与 2026-08-17 归源守卫判断一致，受控启用作废）；已通关标记改白光底晕（silver_light
## 叠彩色图下方，不换图不透明感不变，参考页「绿勾光晕=已过」等价表达）。宝箱可领取
## 态叠 _light 金光星闪。

const CONTENT_SCALE: float = 1.28125
const STAGE_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/stage/crusade_stage_"
const BOX_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/crusade_box_"
# 源 crusadeconfig box config={scale=0.8}（:96 等 15 处）；closed 图 PIL 实测像素
# （bronze 89×84 / silver·gold_closed 90×84）。
const BOX_SCALE: float = 0.8
const BOX_CLOSED_PX := {
	"bronze": Vector2(89.0, 84.0), "silver": Vector2(90.0, 84.0), "gold": Vector2(90.0, 84.0),
}
# 可领取宝箱金光星闪（参考页对齐 2026-09-13）：源 crusadeconfig _light 死资产启用；
# gold_light 127×108px PIL 实测（无 TextureConfig 条目 → ÷CS），星芒叠宝箱上方。
const BOX_LIGHT_RES: String = "res://assets/ui/alpha/HVGA/crusade/crusade_box_gold_light.png"
const BOX_LIGHT_PX: Vector2 = Vector2(127.0, 108.0)
const BOX_LIGHT_NAME: String = "BoxLight"
const LIGHT_BREATH_MIN: float = 0.5
const LIGHT_BREATH_TIME: float = 0.7
# 已通关节点白光底晕（2026-09-13 二轮）：silver_light 128×108px÷CS 圆形柔光，垫在
# 彩色 battle 图下方（挂 Map 先于按钮 → 绘制序在下），中心随节点对齐。
const STAGE_LIGHT_RES: String = "res://assets/ui/alpha/HVGA/crusade/crusade_box_silver_light.png"
const STAGE_LIGHT_NAME: String = "StageLight"
const STAGE_LIGHT_SCALE: Vector2 = Vector2(1.3, 1.3)
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
## {"stages": Array[TextureButton], "boxes": Array[TextureButton],
## "lights": Array[TextureRect]}（stages/boxes 顺序按 idx 1-15，lights 与 stages 对位）。
static func fill_stage_grid(content: Control, player: PlayerData, on_stage: Callable, on_box: Callable) -> Dictionary:
	var stages: Array[TextureButton] = []
	var boxes: Array[TextureButton] = []
	var lights: Array[TextureRect] = []
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
			box.add_child(_make_box_light(box_sz))
			map_node.add_child(box)
			boxes.append(box)
		for b in range(5):
			var idx: int = s * 5 + b + 1
			var tex: Texture2D = _load_tex(stage_texture_normal(idx)) as Texture2D
			var btn_sz: Vector2 = (tex.get_size() if tex != null else Vector2(110.0, 110.0)) / CONTENT_SCALE
			# 白光底晕先挂（树序在 battle 前 → 画在 battle 下方）。
			map_node.add_child(_make_stage_light(BATTLE_POS[s][b]))
			lights.append(map_node.get_child(map_node.get_child_count() - 1) as TextureRect)
			var btn := TextureButton.new()
			btn.texture_normal = tex
			btn.texture_disabled = _load_tex(stage_texture_locked(idx))
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			btn.position = map_local_top_left(BATTLE_POS[s][b], btn_sz)
			btn.size = btn_sz
			btn.pressed.connect(on_stage.bind(idx))
			map_node.add_child(btn)
			stages.append(btn)
	return {"stages": stages, "boxes": boxes, "lights": lights}


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


## open 态档位（源 crusade.lua:23-26 boxImg 换图只认 5/10/15：15=gold、5/10=silver）。
static func box_tier(i: int) -> String:
	if i == 15:
		return "gold"
	if i == 5 or i == 10:
		return "silver"
	return "bronze"


## closed 态档位（源 crusadeconfig.lua 初始配置另一套口径：box3/5/9/12=silver_closed
## [cfg:115/:193/:232]、box10=gold_closed [cfg:206]、box15=gold）。2026-08-22 巡检订正：
## 旧统一用 boxImg 档致未领取时 box3/9/12 显铜（应银）、box10 显银（应金）。
static func box_tier_closed(i: int) -> String:
	if i == 10 or i == 15:
		return "gold"
	if i == 3 or i == 5 or i == 9 or i == 12:
		return "silver"
	return "bronze"


static func box_texture(player: PlayerData, i: int) -> String:
	var state: String = "open" if player.crusade_manager.is_stage_rewarded(i) else "closed"
	var tier: String = box_tier(i) if state == "open" else box_tier_closed(i)
	return BOX_TEX_DIR + tier + "_" + state + ".png"


## 源 battle 按钮两态贴图（crusadeconfig:285-286：normal=crusade_stage_N.png，
## disable=crusade_stage_N_locked.png；disable 换图=Godot texture_disabled 语义）。
static func stage_texture_normal(i: int) -> String:
	return STAGE_TEX_DIR + str(i) + ".png"


static func stage_texture_locked(i: int) -> String:
	return STAGE_TEX_DIR + str(i) + "_locked.png"


## 源 crusade.lua:328 enable(false) 布尔直译（and 高于 or）：
## (battleState[i]=="unpassed" and i>currentStage) or (currentStage==i and
## battleState[i-1]~="rewarded" and i>1)。
static func stage_locked(player: PlayerData, i: int) -> bool:
	var mgr = player.crusade_manager
	return (not mgr.is_stage_cleared(i) and i > mgr.cur_stage) \
		or (mgr.cur_stage == i and not mgr.is_stage_rewarded(i - 1) and i > 1)


## 已通关节点白光底晕子节点（挂 Map 在 battle 按钮之前 → 绘制序在下；默认隐藏，
## panel _refresh_stage_states 按 cleared 显隐）。
static func _make_stage_light(cocos_pos: Vector2) -> TextureRect:
	var light := TextureRect.new()
	light.name = STAGE_LIGHT_NAME
	light.texture = _load_tex(STAGE_LIGHT_RES)
	var sz: Vector2 = Vector2(128.0, 108.0) / CONTENT_SCALE * STAGE_LIGHT_SCALE
	light.size = sz
	light.position = map_local_top_left(cocos_pos, sz)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.visible = false
	return light


## 宝箱金光子节点（随 box 摇晃弹跳联动缩放；默认隐藏，状态启停见 set_box_light）。
static func _make_box_light(box_sz: Vector2) -> TextureRect:
	var light := TextureRect.new()
	light.name = BOX_LIGHT_NAME
	light.texture = _load_tex(BOX_LIGHT_RES)
	var sz: Vector2 = BOX_LIGHT_PX / CONTENT_SCALE
	light.size = sz
	light.position = (box_sz - sz) * 0.5
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.visible = false
	return light


## 可领取（通关未领奖）宝箱金光呼吸启停（参考页宝箱发光对齐；与 panel 1.5s 摇晃
## 提示同向叠加）。tween 挂 box 节点、引用存 light meta，防重复启停泄漏。
static func set_box_light(box: TextureButton, on: bool) -> void:
	var light: TextureRect = box.get_node_or_null(BOX_LIGHT_NAME) as TextureRect
	if light == null:
		return
	# get_meta 带默认值在 4.7 仍 push error（GUT 记 Unexpected Errors），has_meta 预检。
	var tw: Tween = null
	if light.has_meta("tw"):
		tw = light.get_meta("tw") as Tween
	if tw != null and tw.is_valid():
		tw.kill()
	light.visible = on
	if not on:
		light.modulate.a = 1.0
		return
	tw = box.create_tween()
	tw.set_loops(-1)
	tw.tween_property(light, "modulate:a", LIGHT_BREATH_MIN, LIGHT_BREATH_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "modulate:a", 1.0, LIGHT_BREATH_TIME).set_trans(Tween.TRANS_SINE)
	light.set_meta("tw", tw)


## 面板刷新入口：路径 → 安全加载（exists 预检，返回 Texture2D 或 null）。
static func stage_button_normal_texture(i: int) -> Variant:
	return _load_tex(stage_texture_normal(i))


static func stage_button_locked_texture(i: int) -> Variant:
	return _load_tex(stage_texture_locked(i))


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


# ── 未通关宝箱悬停预览浮层（源 initRewardUI crusade.lua:247-297 + 声明 crusadeconfig.lua:1101-1198）──
# 2026-08-22 巡检重做：旧 result_label 文本降级。Scale9 main_vit_tips 底中
# (400,280)（源 ccp(400,200) anchor(0.5,0)），行 y：金币 h-20 / 随机宝箱 h-55 /
# 物品 h-90(h-125 图标)，高 88 无物品 / 155 有；scale 0→1 弹出（panel 侧 tween）。
const REWARD_BG_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const REWARD_GOLD_ICON_RES: String = "res://assets/ui/alpha/HVGA/goldicon.png"
const REWARD_RANDOM_ICON_RES: String = "res://assets/ui/alpha/HVGA/handbook_icon_lock.png"
const REWARD_PREVIEW_W: float = 170.0
const REWARD_PREVIEW_H_PLAIN: float = 88.0
const REWARD_PREVIEW_H_ITEM: float = 155.0
const REWARD_PREVIEW_BOTTOM_Y: float = 280.0
const LSTR_RANDOM_REWARD: String = "CRUSADECONFIG.MYSTERIOUS_REWARD"
const LSTR_ITEM_REWARD: String = "CRUSADECONFIG.REWARDS_FOR_THIS_PASS_"


static func build_reward_preview(host: Control, slots: Array, cm: Variant) -> Control:
	var gold: int = 0
	var has_box: bool = false
	var item_id: int = 0
	var item_amt: int = 0
	for s in slots:
		match String(s.get("type", "")):
			"gold":
				gold = int(s["amount"])
			"chestbox":
				has_box = true
			"item":
				item_id = int(s.get("id", 0))
				item_amt = int(s["amount"])
	var has_item: bool = item_id > 0
	var h: float = REWARD_PREVIEW_H_ITEM if has_item else REWARD_PREVIEW_H_PLAIN
	var layer := Control.new()
	layer.position = Vector2(400.0 - REWARD_PREVIEW_W * 0.5, REWARD_PREVIEW_BOTTOM_Y - h)
	layer.size = Vector2(REWARD_PREVIEW_W, h)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(layer)
	_add_scale9_bg(layer, h)
	_add_sprite_row(layer, REWARD_GOLD_ICON_RES, Vector2(42.0, h - 20.0), 0.65)
	_add_label(layer, str(gold), Vector2(115.0, h - 20.0))
	if has_box:
		_add_sprite_row(layer, REWARD_RANDOM_ICON_RES, Vector2(40.0, h - 55.0), 0.5)
		_add_label(layer, _lstr(cm, LSTR_RANDOM_REWARD, "神秘的奖励"), Vector2(115.0, h - 55.0))
	if has_item:
		_add_label(layer, _lstr(cm, LSTR_ITEM_REWARD, "本关奖励"), Vector2(85.0, h - 90.0))
		var stone_host := Control.new()
		stone_host.position = Vector2(40.0, h - 125.0)
		stone_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(stone_host)
		var stone: Control = ReadequipIcon.create_hero_stone_icon(item_id, 0, cm)
		var stone_scale: float = 50.0 / (94.0 / CONTENT_SCALE)   # 源 createHeroStone(param1,50)
		stone.scale = Vector2(stone_scale, stone_scale)
		stone.position = -stone.size * stone_scale * 0.5
		stone_host.add_child(stone)
		_add_label(layer, "x%d" % item_amt, Vector2(115.0, h - 125.0))
	return layer


static func _add_scale9_bg(layer: Control, h: float) -> void:
	var bg := NinePatchRect.new()
	bg.texture = _load_tex(REWARD_BG_RES) as Texture2D
	if bg.texture != null:
		var tw: float = float(bg.texture.get_width())
		var th: float = float(bg.texture.get_height())
		bg.patch_margin_left = int(15.0 / CONTENT_SCALE)
		bg.patch_margin_bottom = int(20.0 / CONTENT_SCALE)
		bg.patch_margin_right = int((tw - 60.0) / CONTENT_SCALE)
		bg.patch_margin_top = int((th - 35.0) / CONTENT_SCALE)
	bg.size = Vector2(REWARD_PREVIEW_W, h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)


static func _add_sprite_row(layer: Control, res: String, center: Vector2, scale: float) -> void:
	var tex: Texture2D = _load_tex(res) as Texture2D
	if tex == null:
		return
	var sz: Vector2 = tex.get_size() / CONTENT_SCALE * scale
	var rect := TextureRect.new()
	rect.texture = tex
	rect.size = sz
	rect.position = center - sz * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)


static func _add_label(layer: Control, text: String, center: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.theme_type_variation = &"BtnLabel"
	lbl.position = center
	lbl.size = Vector2(0.0, 0.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(lbl)
