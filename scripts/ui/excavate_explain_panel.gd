class_name ExcavateExplainPanel
extends PopWindow

## 藏宝地穴玩法说明（View 层）— 照源 ui/popwindow/excavateexplain.lua createContent:4。
## 源继承 ed.ui.explainwindow 通用说明窗（框/标题条/关闭钮/滚动区在基类声明表），
## 只填文本：4 行故事 + 尾签名 + 18 子句规则（每子句独立 label，autowrap 后视觉等效）。
## 无联机依赖，直接复用。P1（2026-07-16）：LSTR EXCAVATEEXPLAIN.* 全键照译。
##
## 两件套（2026-08-17，excavate 批 Task 2）：框归源 main_vit_tips Scale9 + 标题条 +
## 关闭钮 + 23 行 label 全静态进 excavate_explain_content.tscn（A 类债 #3 修复：
## 弃 excavate_main_frame 600x440 强拉误用）；颜色/字号走 theme variation
## ExplainTitleLabel / ExplainStoryLabel / ExplainRuleLabel。本文件只做 LSTR fill +
## 关闭信号。标题归源通用窗 PVP.RULE_DESCRIPTION"规则说明"（弃迁移发明
## "藏宝地穴说明"，excavateexplain.lua 不覆写基类标题）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/excavate_explain_content.tscn")
const TITLE_KEY: String = "PVP.RULE_DESCRIPTION"
const TITLE_FALLBACK: String = "规则说明"

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

# 规则段（照 text_list_3 :15-34，18 个 LSTR 子句独立 label，autowrap 后视觉等效合并）
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


func setup_panel() -> void:
	setup()
	_build_content()


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = GameData.config
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# 两件套 fill：标题/故事/签名/规则 23 行 LSTR 文本 + 关闭信号
# （位置/样式/行结构全在 tscn + theme，签名右对齐与 gap17 亦静态化）。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	(content.get_node("%TitleLabel") as Label).text = _lstr(TITLE_KEY, TITLE_FALLBACK)
	# 故事段（照 :37-46 4 行 + 尾签名）
	for i in range(STORY_KEYS.size()):
		(content.get_node("%%StoryRow%d" % (i + 1)) as Label).text = _lstr(STORY_KEYS[i], STORY_FALLBACKS[i])
	(content.get_node("%StorySign") as Label).text = _lstr(STORY_TITLE_KEY, STORY_TITLE_FALLBACK)
	# 规则段（照 :53-62，源每子句独立 label，颜色 ccc3(238,204,119)）
	for i in range(RULE_KEYS.size()):
		(content.get_node("%%RuleRow%d" % (i + 1)) as Label).text = _lstr(RULE_KEYS[i], RULE_FALLBACKS[i])
