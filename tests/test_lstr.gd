extends GutTest
# LSTR 全局语言包查询单测（照源 LocalString.lua:74-80 LSTR(key)）。
# LSTR.json 由 generate_lstr.py 从 zh-CN.lua 生成（4842 keys），ConfigManager.load_all 自动加载。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# LSTR 表加载（load_all 扫 resources/data/LSTR.json）
func test_lstr_table_loaded() -> void:
	assert_true(cm.has_table(&"LSTR"), "LSTR 表已加载")
	assert_true(cm.get_raw_table(&"LSTR").size() > 4000, "LSTR keys 全量（4842）")


# get_lstr 命中返中文（源 LSTR(key) = langs["zh-CN"][key]）
func test_get_lstr_hit() -> void:
	assert_eq(cm.get_lstr("MERCHANTTALK.SHOP"), "百货小店", "MERCHANTTALK.SHOP → 百货小店")
	assert_eq(cm.get_lstr("MERCHANTTALK.GOBLIN_BUSINESSMAN"), "地精商人", "地精商人")


# get_lstr 未命中返 key 本身（源 :76-78 nil == str then return key）
func test_get_lstr_miss_returns_key() -> void:
	var missing: String = "NOT_EXIST_KEY.XYZ"
	assert_eq(cm.get_lstr(missing), missing, "未命中返 key 本身")
	assert_eq(cm.get_lstr(""), "", "空 key 返空")


# 跨命名空间 key（EQUIP/UNIT/SKILL 等 UI 常用）
func test_get_lstr_namespaces() -> void:
	# 这些 key 在 zh-CN.lua 存在（源 UI 用），命中应非空且 != key
	var shop_key: String = cm.get_lstr("MERCHANTTALK.SHOP")
	assert_true(shop_key != "MERCHANTTALK.SHOP" and shop_key.length() > 0, "命中后 != key 且非空")


# main_scene 入口按钮 title（mainres.* LSTR key，照源 mainres.lua title=LSTR(...) + zh-CN.lua:4857-4871）。
# 验证 ENTRIES 15 个 key 都能解析成正确中文（main_scene._make_entry get_lstr 显示）。
func test_mainres_title_keys() -> void:
	var cases: Dictionary = {
		"mainres.Campaign": "战役",
		"mainres.Arean": "竞技场",
		"mainres.Merchant": "商人",
		"mainres.Chests": "召唤法阵",
		"mainres.TimeRift": "时光之穴",
		"mainres.Enchanting": "装备附魔",
		"mainres.Trials": "英雄试炼",
		"mainres.Crusade": "燃烧的远征",
		"mainres.Guild": "公会",
		"mainres.Mailbox": "信箱",
		"mainres.GoblinMerchant": "地精商店",
		"mainres.Godfather": "黑市商人",
		"mainres.StarShop": "星际商店",
		"mainres.Excavate": "藏宝地穴",
		"mainres.Rank": "排行榜",
	}
	for key in cases:
		assert_eq(cm.get_lstr(key), String(cases[key]), key + " → " + String(cases[key]))


# P2-三轮-4：LSTR key 标点完整性（源 Equip.lua:4957 Comment + Stage.lua:10786 description 用 `;`
# 分隔，曾误转 `,` 破坏 zh-CN.lua key 匹配——get_lstr 返 key 本身而非中文）。验证读表→get_lstr 命中。
func test_equip_stage_lstr_keys_semicolon_intact() -> void:
	var equip176: String = String(cm.get_raw_table(&"Equip").get("176", {}).get("Comment", ""))
	var stage164: String = String(cm.get_raw_table(&"Stage").get("164", {}).get("description", ""))
	# 读出的 key 须含 `;`（源原文）；曾误转 `,`（SHIELD,_A_PLAYER / TERROR,_IN_THE_LAND）
	assert_true(equip176.find(";") > 0, "Equip176 Comment 含 `;`（源原文，曾误转 `,`）")
	assert_true(stage164.find(";") > 0, "Stage164 description 含 `;`（源原文，曾误转 `,`）")
	# 经 get_lstr 命中中文（zh-CN.lua:442 / :1826），证明本地化链路通（非返 key 本身）
	assert_true(cm.get_lstr(equip176) != equip176, "Equip176 Comment key `;` 完整 → 命中中文")
	assert_true(cm.get_lstr(stage164) != stage164, "Stage164 description key `;` 完整 → 命中中文")
