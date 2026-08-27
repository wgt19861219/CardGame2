class_name LadderRulesPopup
extends PopWindow

## 竞技场规则说明弹窗（View 层）— 照源 pvp.lua createRewardInfoLayer(:375-461) +
## initRewardList(:214-320)。main_vit_tips 底板 550×360 cap(15,20,45,15) 中心 (400,240)、
## 标题「竞技场规则说明」22 号 ccc3(251,206,16) + pvp_tip_title_bg 标题底 scalexy(1.3,1.1)、
## 右上 close（源 @(670,390) cocos → Godot (670,90)）。
## 内容照源 initRewardList 全序列：当前排名可领奖励（PVPRankReward 按 currentRank 定位）→
## 竞技场战斗规则 8 条 → 历史最高排名奖励 3 条 → 每日排名奖励 1 条 → 前 6 档排名奖励。
## LSTR 值带富文本标记（<text|normalButton|...>）→ _strip_rich 剥壳取纯文本。
## 受控披露：奖励串 Item 类降级为 ×数量文字（道具图标链路另批）；源 listview 富文本行距
## 简化为 Label 堆叠。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/ladder_rules_content.tscn")
const CONTENT_SCALE: float = 1.28125
const RMB_ICON: String = "res://assets/ui/alpha/HVGA/rmbicon.png"
const GOLD_ICON: String = "res://assets/ui/alpha/HVGA/goldicon.png"
const ARENA_ICON: String = "res://assets/ui/alpha/HVGA/money_arenatoken_small.png"
const ICON_SCALE: float = 0.5
# 段落标题色 ccc3 dark_white / 正文 normalButton（源 rich 语义，default_theme variation）。
const VAR_SECTION: String = "LadderRulesSectionLabel"
const VAR_BODY: String = "LadderRulesBodyLabel"
# 内容序列（LSTR 键 → 段落性质；段落标题 dark_white 变体，正文 normalButton）。
const SECTIONS: Array = [
	{"key": "PVP.TEXT_DARK_WHITE_ARENA_COMBAT_RULES_", "section": true},
	{"key": "PVP.TEXT_NORMALBUTTON_1_IN_AUTOMATIC_ARENA_COMBAT_PLAYERS_CAN_NOT_CAST_SPELLS_MANUALLY"},
	{"key": "PVP.TEXT_NORMALBUTTON_2_IN_ARENA_COMBAT_ALL_HEROS_HEALTH_AND_CURE_EFFECTS_WILL_BE_INCREASED_AT_THE_SAME_WIDTH_"},
	{"key": "PVP.TEXT_NORMALBUTTON_3_IF_YOU_WON_AND_THE_DEFENSE_IS_RANKED_HIGHER_THAN_THE_OFFENSIVE_SIDE_THE_RANKINGS_WILL_SWAP_SIDES"},
	{"key": "PVP.TEXT_NORMALBUTTON_4_IF_THE_BATTLE_TIMED_OUT_THEN_THE_OFFENSIVE_SIDE_WILL_BE_TREATED_AS_LOSE_"},
	{"key": "PVP.TEXT_NORMALBUTTON_5_EACH_PLAYER_HAS_5_FREE_COMBAT_TIMES_PER_DAY_FREE_TIME_WILL_BE_RESET_AT_5AM_"},
	{"key": "PVP.TEXT_NORMALBUTTON_6_AFTER_EACH_BATTLE_THE_OFFENSIVE_SIDE_WILL_RECEIVE_A_10MINUTE_COOL_DOWN"},
	{"key": "PVP.TEXT_NORMALBUTTON_7_ENEMY_WHO_IS_IN_A_FIGHTING_CAN_NOT_BE_SELECTED_AS_THE_OPPONENT"},
	{"key": "PVP.TEXT_NORMALBUTTON_8_THE_WHOLE_SETTLEMENT_RANK_AND_RANK_AWARDS_ISSUED_THROUGH_THE_MAIL_AT_9PM_EVERY_DAY"},
	{"key": "PVP.TEXT_DARK_WHITE_HISTORY_HIGHEST_RANKING_AWARD_RULES_", "section": true},
	{"key": "PVP.TEXT_NORMALBUTTON_WHEN_A_PLAYER_SUCCESSFULLY_ROSE_TO_HISHER_HIGHEST_RANK_WILL_BE_AWARDED_A_ONETIME_DIAMOND_REWARDS"},
	{"key": "PVP.TEXT_NORMALBUTTON_HIGHEST_RANKING_AWARD_VARIES_ON_THE_RATE_OF_PROGRESS_AT_LEAST_ONE_DIAMOND"},
	{"key": "PVP.TEXT_NORMALBUTTON_HIGHEST_RANKING_AWARD_ISSUED_BY_MAIL"},
	{"key": "PVP.TEXT_DARK_WHITE_DAILY_RANK_REWARD_RULES_", "section": true},
	{"key": "PVP.TEXT_NORMALBUTTON_AN_AWARDMAIL_WILL_BE_SENT_OUT_ACCORDING_TO_THE_RANKING_OF_THE_SETTLEMENT_DETAILED_REWARD_RULES_FOLLOWS_"},
]

var _cm: ConfigManager
var _current_rank: int


func setup_panel(cm: ConfigManager, current_rank: int) -> void:
	_cm = cm
	_current_rank = maxi(1, current_rank)
	transparent_shade = false
	setup()
	_build()


func _build() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	(content.get_node("%Title") as Label).text = _cm.get_lstr("PVP.ARENA_RULE_DESCRIPTION")
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	var host: Control = content.get_node("%ListHost") as Control
	_fill_list(host)


# 照源 initRewardList :227-320 序列：当前排名奖励段 → SECTIONS → 前 6 档奖励。
func _fill_list(host: Control) -> void:
	var reward_table: Dictionary = _cm.get_raw_table(&"PVPRankReward")
	var reward_row: Dictionary = _locate_self_reward(reward_table)
	if not reward_row.is_empty():
		_add_line(host, _cm.get_lstr("PVP.TEXT_NORMALBUTTON_MAINTAIN_AT_THIS_RANK__S_YOU_CAN_CLAIM___") % [_rank_segment_text(reward_table)], VAR_BODY)
		_add_reward_line(host, reward_row)
		_add_line(host, " ", VAR_BODY)
	for item: Dictionary in SECTIONS:
		_add_line(host, _cm.get_lstr(String(item["key"])), VAR_SECTION if bool(item.get("section", false)) else VAR_BODY)
	_add_line(host, " ", VAR_BODY)
	for i in range(1, 7):
		var row: Dictionary = reward_table.get(str(i), {})
		if row.is_empty():
			continue
		_add_line(host, "%s: " % _rank_segment_text(reward_table, i), VAR_BODY)
		_add_reward_line(host, row)
		_add_line(host, " ", VAR_BODY)


# 当前排名定位（源 :227-239：首个 Floor Rank >= currentRank 档）。
func _locate_self_reward(reward_table: Dictionary) -> Dictionary:
	for key: String in reward_table:
		var row: Dictionary = reward_table[key]
		if _current_rank <= int(row.get("Floor Rank", 999999)):
			return row
	return {}


# 排名段文案（源 :230-234：与上档 Floor Rank 断档时「第a至第b名」，否则「第N名」）。
# 传 row_key 时按第 row_key 档取上档比对；否则按 self 档。
func _rank_segment_text(reward_table: Dictionary, row_key: int = -1) -> String:
	var keys: Array = reward_table.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	var idx: int = row_key if row_key > 0 else _self_reward_index(reward_table, keys)
	if idx < 1 or idx > keys.size():
		return ""
	var row: Dictionary = reward_table[keys[idx - 1]]
	var floor_rank: int = int(row.get("Floor Rank", 0))
	if idx >= 2:
		var prev_floor: int = int(reward_table[keys[idx - 2]].get("Floor Rank", 0))
		if prev_floor < floor_rank - 1:
			return _cm.get_lstr("PVP.THE_FIRST_D_TO_THE_D") % [prev_floor + 1, floor_rank]
	return _cm.get_lstr("PVP.THE_D") % [floor_rank]


func _self_reward_index(reward_table: Dictionary, keys: Array) -> int:
	for i in keys.size():
		if _current_rank <= int(reward_table[keys[i]].get("Floor Rank", 999999)):
			return i + 1
	return keys.size()


# 奖励串（源 getRewardResult :192-213）：Diamond/Gold/ArenaPoint 图标+数值；Item 降级 ×N 文字。
func _add_reward_line(host: Control, row: Dictionary) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(line)
	_append_reward(line, RMB_ICON, str(int(row.get("Reward Amount 1", 0))), false)
	_append_reward(line, GOLD_ICON, str(int(row.get("Reward Amount 2", 0))), false)
	_append_reward(line, ARENA_ICON, "×%d" % int(row.get("Reward Amount 3", 0)), true)
	for ri in range(4, 11):
		if str(row.get("Reward Type %d" % ri, "")) == "Item" and int(row.get("Reward Amount %d" % ri, 0)) > 0:
			_append_reward(line, "", "×%d" % int(row.get("Reward Amount %d" % ri, 0)), false)


func _append_reward(line: Control, icon_res: String, amount_text: String, show_icon_raw: bool) -> void:
	if icon_res != "" and ResourceLoader.exists(icon_res):
		var icon := TextureRect.new()
		icon.texture = load(icon_res) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var sz: Vector2 = icon.texture.get_size() / CONTENT_SCALE
		if not show_icon_raw:
			sz *= ICON_SCALE
		icon.size = sz
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(icon)
	if not amount_text.is_empty() and amount_text != "0" and amount_text != "×0":
		var lbl := Label.new()
		lbl.text = amount_text
		lbl.theme_type_variation = VAR_BODY
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(lbl)


func _add_line(host: Control, text_value: String, variation: String) -> void:
	var lbl := Label.new()
	lbl.text = _strip_rich(text_value)
	lbl.theme_type_variation = variation
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(500.0, 0.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(lbl)


# LSTR 值剥富文本壳："<text|style|正文>" → "正文"（壳内无 '>'，正文到倒数第 2 字符；
# 无壳原样返回）。旧实现 find(">") 取到结尾终止符致正文全空（2026-08-27 实机抓出）。
func _strip_rich(text_value: String) -> String:
	var s := text_value
	if s.begins_with("<text|"):
		var p1 := s.find("|")
		var p2 := s.find("|", p1 + 1)
		if p2 >= 0:
			s = s.substr(p2 + 1)
		if s.ends_with(">"):
			s = s.substr(0, s.length() - 1)
	return s
