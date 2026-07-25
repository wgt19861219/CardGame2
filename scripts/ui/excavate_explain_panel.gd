class_name ExcavateExplainPanel
extends PopWindow

## 藏宝地穴玩法说明（View 层）— 照源 ui/popwindow/excavateexplain.lua createContent:4。
## 纯文本（背景故事 4 行 + 标题 + 规则段 16 个 LSTR 子句合成 10 条规则）。
## 无联机依赖，直接复用。P1（2026-07-16）：LSTR EXCAVATEEXPLAIN.* 全键照译。
##
## 重构（2026-07-18，hero_detail 范式）：panel 层静态节点（frame/close/title/scroll/list）
## 固化进 scenes/ui/excavate_explain_content.tscn；故事段+规则段 LSTR label 数量固定但
## 内容动态，保留 procedural 挂 %StoryList（autowrap + 颜色 + 字号运行时设）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_explain_content.tscn")
const COLOR_STORY: Color = Color(1.0, 1.0, 221.0 / 255.0)
const COLOR_RULE: Color = Color(238.0 / 255.0, 204.0 / 255.0, 119.0 / 255.0)
const FONT_SIZE: int = 16
const CONTENT_W: float = 500.0

# 故事段 4 行（照 text_list_1 :8-13，4 个 LSTR key 顺序）
const STORY_KEYS: Array[String] = [
	"EXCAVATEEXPLAIN.DARK_IRON_DWARVES_KINGDOM_BUILDING_IN_THE_GROUND_MORE_WRONG_SECTION_OF_THE_HOLE_DISK_AS_THE_ROOT_OF_THE_TREE_OF_THE_WORLD_TO_BE",
	"EXCAVATEEXPLAIN.BUT_ITS_HISTORY_OLDER_THAN_THE_WORLD_TREE_ITSELF_WHEN_THESE_DORMANT_FOR_MILLIONS_OF_YEARS_OF_HEAVY_TREASURE",
	"EXCAVATEEXPLAIN.SEE_THE_LIGHT_EXPLORERS_WERE_SURPRISED_TO_HAVE_FOUND_GOLD_AND_DIAMONDS_ARE_STILL_DWARVES_TIMELESS_A",
	"EXCAVATEEXPLAIN.DUST_IS_NOT_DYED_BUT_WITH_GOLD_AS_ETERNAL_HUMAN_GREED_AND_PLUNDER",
]
const STORY_FALLBACKS: Array[String] = [
	"黑铁矮人的王国建筑在地下，盘更错节的地洞如同世界之树的根须，",
	"但它的历史比世界之树本身还要古老。当这些沉睡了千万年的宝藏重",
	"见天日，探险者们惊奇得发现，矮人的黄金与钻石依然历久弥新，一",
	"尘不染。但与黄金一样永恒不变的，是人类的贪欲和掠夺。",
]
# 故事尾签名（照 text_2 :14）
const STORY_TITLE_KEY: String = "EXCAVATEEXPLAIN._ANUBAR_WARS"
const STORY_TITLE_FALLBACK: String = "——《阿努巴战记》"

# 规则段（照 text_list_3 :15-33，16 个 LSTR 子句合成 10 条规则）。
# 每条规则是 1-2 个 LSTR 子句拼接（源每个子句独立 label，autowrap 后视觉等效合并）。
const RULE_KEYS: Array[String] = [
	"EXCAVATEEXPLAIN.1_IN_THE_TREASURE_CRYPT_YOU_CAN_FIND_A_VARIETY_OF_RESOURCE_POINTS_INCLUDING_GOLD_DIAMOND_AND_LABORATORY",
	"EXCAVATEEXPLAIN.2_YOU_CAN_LAUNCH_MULTIPLE_ATTACKS_POINT_TO_RESOURCES_EACH_ATTACK_WILL_CONSUME_SOME_ENERGY_AND",
	"EXCAVATEEXPLAIN.OBTAIN_THE_CORRESPONDING_TEAM_EXPERIENCE_BEFORE_THE_END_OF_ALL_THE_FIGHTING_BOTH_OFFENSIVE_AND_DEFENSIVE_HEROS_LIFE",
	"EXCAVATEEXPLAIN.AND_ENERGY_VALUES_​​ARE_NOT_RESET",
	"EXCAVATEEXPLAIN.3_IF_YOU_BEAT_ALL_THE_DEFENDERS_IN_A_LIMITED_TIME_YOU_CAN_CAPTURE_RESOURCE_POINTS_OCCUPIED_CAPITAL",
	"EXCAVATEEXPLAIN.YOU_WILL_CONTINUE_TO_SOURCE_PRODUCTION_RESOURCES",
	"EXCAVATEEXPLAIN.4_WHEN_THE_NEW_OCCUPATION_TREASURES_RANGING_FROM_THE_PROTECTION_OBTAINED_12_HOURS_DEPENDING_ON_THE_TYPE_OF_TREASURES",
	"EXCAVATEEXPLAIN.ROOMS_IN_THE_GUARD_TIME_OTHER_PLAYERS_CAN_NOT_SEARCH_AND_ATTACK_THIS_TREASURE",
	"EXCAVATEEXPLAIN.5_RESOURCE_POINTS_YOU_NEED_TO_SEND_A_HERO_DEFENSE_HAD_OCCUPIED_THE_MORE_HEROIC_GARRISON_RESOURCE_EXPLOITATION",
	"EXCAVATEEXPLAIN.FASTER",
	"EXCAVATEEXPLAIN.6_DURING_THE_HEROIC_GARRISON_CAN_NOT_PARTICIPATE_IN_OTHER_BATTLES_YOU_CAN_ALWAYS_REPLACE_THE_GARRISON_HERO",
	"EXCAVATEEXPLAIN.7_RESOURCE_LIMITED_RESOURCE_POINTS_TOTAL_RESERVES_ALL_MINING_FINISHED_THE_HERO_WILL_BE_SHIPPED_ALL_RESOURCES",
	"EXCAVATEEXPLAIN.BACK_TO_YOUR_WAREHOUSE",
	"EXCAVATEEXPLAIN.8_IF_THE_RESOURCE_EXTRACTION_PROCESS_WAS_ATTACKED_AND_DEFENSE_FAILS_YOU_MAY_LOSE_PART",
	"EXCAVATEEXPLAIN.RESOURCES_HAVE_BEEN_MINED_THE_REMAINING_RESOURCES_WILL_BE_TRANSPORTED_BACK_TO_YOUR_WAREHOUSE",
	"EXCAVATEEXPLAIN.9_SOME_LARGE_RESOURCE_POINTS_CAN_ACCOMMODATE_MORE_THAN_A_COMMON_DEFENSIVE_PLAYER_YOU_CAN_INVITE_THE_SAME_GUILD",
	"EXCAVATEEXPLAIN.SMALL_PARTNER_WITH_DEFENSE_ALL_DEFENDERS_CAN_EXPLOIT_RESOURCES",
	"EXCAVATEEXPLAIN.10_IN_THE_TREASURE_CRYPT_BATTLE_THE_HERO_OF_THE_DEFENSE_WILL_GET_SOME_INITIAL_ENERGY",
]
# 规则 fallback（源子句逐行对应，每行一个 label；autowrap 后视觉等效）
const RULE_FALLBACKS: Array[String] = [
	"1.在藏宝地穴，你能找到各种资源点，包括金矿、钻石矿和实验室",
	"2.你可以向资源点发起多次攻击，每次攻击都会消耗一定体力，并",
	"获得对应的战队经验。所有战斗结束之前，攻守双方英雄的生命值",
	"和能量值都不会重置。",
	"3.如果在限定时间内击败所有守军，就可以占领资源点。占领的资",
	"源点会为你持续生产资源。",
	"4.新占领的宝藏根据不同宝藏类型获得1小时至2小时不等的保护时",
	"间，在保护时间内，其他玩家无法搜索到以及进攻这个宝藏。",
	"5.你需要派遣英雄防守已占领的资源点，驻防英雄越多，资源开采",
	"的速度越快。",
	"6.英雄驻防期间，不能参加其他战斗。你可以随时更换驻防英雄。",
	"7.资源点的资源总储量有限，全部开采完后，英雄会将所有资源运",
	"回你的仓库。",
	"8.如果资源开采过程中遭到袭击并防守失败，你可能会损失一部分",
	"已经开采的资源，剩余资源会运回你的仓库。",
	"9.某些大型资源点可以容纳多名玩家共同防守，你可以邀请同公会",
	"的小伙伴一同防御。所有防御者都可以开采资源。",
	"10.在藏宝地穴的战斗中，防守方的英雄会获得一定初始能量。",
]

var _story_list: VBoxContainer = null


func setup_panel() -> void:
	setup()
	_build_content()


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = GameData.config
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# 建 UI：preload .tscn instantiate + 绑 close + fill 故事/规则 LSTR labels。
# 位置/size 静态节点（frame/close/title/scroll/list）已在 .tscn 固化。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	_story_list = content.get_node("%StoryList") as VBoxContainer
	# 故事段（照 :37-46 4 行 + 尾签名）
	for i in range(STORY_KEYS.size()):
		_story_list.add_child(_make_label(_lstr(STORY_KEYS[i], STORY_FALLBACKS[i]), COLOR_STORY))
	_story_list.add_child(_make_label(_lstr(STORY_TITLE_KEY, STORY_TITLE_FALLBACK), COLOR_STORY, HORIZONTAL_ALIGNMENT_RIGHT))
	# 规则段（照 :53-62，源每子句独立 label，颜色 ccc3(238,204,119)）
	for i in range(RULE_KEYS.size()):
		_story_list.add_child(_make_label(_lstr(RULE_KEYS[i], RULE_FALLBACKS[i]), COLOR_RULE))


func _make_label(text: String, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(CONTENT_W, 0)
	l.add_theme_font_size_override("font", FONT_SIZE)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
