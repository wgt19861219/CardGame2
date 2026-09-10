extends GutTest
## 魂石单账本守卫（2026-09-09 根修：获取了灵魂石但英雄详情不体现）。
## 源 equip_qunty 单容器（readhero.lua:649-653 getStoneAmount 直读
## equip_qunty[getStoneid(id)]，任何获得物品的路径天然同账本）；本项目曾发明
## HeroManager.fragments 独立容器，获得路径（抽卡灵魂石分支/GM/奖励）走
## PlayerData.add_item 写 items，读侧（英雄详情 stone bar/升星/背包碎片页）读
## fragments → 双账本脱节（用户档 items 躺 54 魂石、fragments 全 0）。
## 根修 = fragments 退役为 pd.items 引用视图，读写同账本（回归源单容器语义）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 用户 bug 端到端：add_item 获得魂石（抽卡 stone 分支/GM/奖励统一入口）→
# 英雄详情 stone bar 数据源（get_stone_amount）立即可见。
func test_add_item_soulstone_visible_in_stone_amount() -> void:
	var pd := PlayerData.new(cm)
	var stone_id: int = ReadheroHandbook.get_stone_id(2, cm)   # 船长魂石（Fragment[2]）
	pd.add_item(stone_id, 5)
	assert_eq(ReadheroHandbook.get_stone_amount(2, cm, pd.hero_manager), 5,
		"items 获得魂石 → get_stone_amount（英雄详情 stone bar 数据源）体现")


# 账本统一不变式：hero_manager.items 与 pd.items 同一字典引用（双向可见）。
func test_hero_manager_items_shares_pd_items_ledger() -> void:
	var pd := PlayerData.new(cm)
	var stone_id: int = ReadheroHandbook.get_stone_id(2, cm)
	pd.add_item(stone_id, 3)
	assert_eq(int(pd.hero_manager.items.get(stone_id, 0)), 3,
		"pd.add_item 后经 hero_manager.items 可见（同引用）")
	pd.hero_manager.add_fragment(stone_id, 4)
	assert_eq(int(pd.items.get(stone_id, 0)), 7,
		"hero_manager.add_fragment 后经 pd.items 可见（同引用）")


# 升星消耗同账本：items 里攒够魂石 → evolve 成功并扣减 items。
func test_evolve_consumes_items_soulstone() -> void:
	var pd := PlayerData.new(cm)
	var inst_id: int = pd.hero_manager.add_hero(2)
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	var stars_before: int = hero.stars
	var stone_id: int = ReadheroHandbook.get_stone_id(2, cm)
	var need: int = ReadheroHandbook.get_stone_need(2, cm, pd.hero_manager)
	if need <= 0:
		return   # 表结构变动（已达顶）则跳过
	pd.hero_manager.gold = 1000000
	pd.add_item(stone_id, need)
	assert_true(pd.hero_manager.evolve(inst_id), "items 魂石达 need → 升星成功")
	assert_eq(int(pd.items.get(stone_id, -1)), 0, "升星扣减落在 items 同账本")
	assert_eq(hero.stars, stars_before + 1, "星级 +1")


# 旧档迁移（2026-09-09 前 fragments 独立容器格式）：读档时并入 items
#（相加——两侧获得路径互斥，无重复计数；用户档 items 已有魂石 + fragments 残留并存）。
func test_legacy_save_fragments_migrate_into_items() -> void:
	var stone_id: int = ReadheroHandbook.get_stone_id(2, cm)
	var data := {
		"items": {str(stone_id): 2},
		"hero_manager": {"gold": 0, "fragments": {str(stone_id): 3}, "heroes": [], "next_id": 1},
	}
	var pd := PlayerDataSerde.from_dict(data, cm)
	assert_eq(int(pd.items.get(stone_id, 0)), 5, "旧档 fragments(3) 并入 items(2) → 5")
	assert_eq(pd.hero_manager.fragment_count(stone_id), 5, "迁移后经 hero_manager 读同值")


# to_dict 不再输出独立 fragments（碎片计数即 pd.items，防账本再分裂）。
func test_hero_manager_to_dict_no_standalone_fragments() -> void:
	var pd := PlayerData.new(cm)
	pd.add_item(ReadheroHandbook.get_stone_id(2, cm), 7)
	var hm_dict: Dictionary = pd.hero_manager.to_dict()
	assert_false(hm_dict.has("fragments"), "fragments 独立容器退役")
	var pd_dict: Dictionary = pd.to_dict()
	var items_saved: Dictionary = pd_dict["items"]
	assert_eq(int(items_saved.get(ReadheroHandbook.get_stone_id(2, cm), 0)), 7,
		"魂石计数随 pd.items 持久化")
