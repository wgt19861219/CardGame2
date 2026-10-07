class_name TavernThousandData
extends RefCounted

## 魂匣百抽三选一 Logic（Data 层，2026-10-07 自创新玩法，源无对应物）。
## 百抽 = 10 组十连（100 抽）**免费赠送**（2026-10-07 用户拍板「送 1000 抽不消耗钻石」，
## 同日再拍板「换成一百抽」——千抽 102 格连弹+循环光效 tween 在真机过载卡顿，减量根治）：
## roll 3 组独立结果 → 玩家选定 1 组入包，其余作废。
## 产出 = **全英雄池**（2026-10-07 用户拍板「放全部英雄池」非单期热点——热点版聚合仅
## 3 魂石+1 英雄，三组几乎同构，三选一无对比意义）：每次 = 随机全英雄魂石 ×1-3 +
## 每 10 抽保底随机英雄整卡 ×1（对齐 magic 十连必得结构）。
## tavern_data.gd / player_data.gd 已顶行数上限（代码行 297/300、300/300）故独立成文件。

const COMBO_GROUPS: int = 10               # 百抽 = 10 组十连（10×10 = 100 抽）
const CHOICE_COUNT: int = 3                # 候选结果组数（三选一）
const HERO_ID_MAX: int = 100               # 英雄 id 上限（对齐 player_data._settle_tavern_loot 口径）
const STONE_AMOUNT_MAX: int = 3            # 每抽魂石数量上限（对齐热点版每位 rand(1,3) 量级）
# 百抽已用标记 key（2026-10-07 用户需求：选定后入口按钮消失，防免费无限重复领）。
# 借宿 pd.tavern_record 嵌套 dict：player_data.gd 代码行已顶 300/300 上限不可加字段；
# 值必须是 dict——serde from_dict 对非 Dictionary 值有损坏守卫会跳过，平铺 bool 存档往返即丢。
# "ThousandPick" 不与 box 键（Bronze/Gold/MagicSoul）冲突。
const USED_FLAG_KEY: String = "ThousandPick"


## 百抽是否已选定（一次性赠送语义：选定一组结算后入口按钮隐藏，终身一次）。
static func is_thousand_used(pd: PlayerData) -> bool:
	return int(pd.tavern_record.get(USED_FLAG_KEY, {}).get("used", 0)) == 1


## 选定结算后置位。重选不置位——候选未选定不入包，不消耗这一次性资格。
static func mark_thousand_used(pd: PlayerData) -> void:
	pd.tavern_record[USED_FLAG_KEY] = {"used": 1}


## 百抽任务进度（TavernGroupUse 按 COMBO_GROUPS 组十连计，对齐逐次十连口径；抽卡行为发生了）。
## 百抽免费无扣费环节，本函数是百抽唯一的玩家态副作用入口（结算除外）。
static func record_thousand_use(pd: PlayerData, cm: Variant) -> void:
	if pd.task_manager != null:
		pd.task_manager.record_by_type(cm, "TavernGroupUse", COMBO_GROUPS)


## roll CHOICE_COUNT 组独立百抽结果（全英雄池）：每组 = 100 条魂石（随机英雄魂石 ×1-3，
## Fragment ID 反查）+ 10 条整卡（每 10 抽保底 1 张随机英雄）。同 rng 序列连续推进三组天然独立。
## 英雄池复用 TavernData._collect_valid_hero_ids（跨文件调私有 static，照
## PopTavernLootMagic._lookup_name 跨文件先例）。
static func roll_thousand_groups(rng: Variant, cm: Variant) -> Array:
	var hero_ids: Array[int] = TavernData._collect_valid_hero_ids(cm)
	if hero_ids.is_empty():
		hero_ids = TavernData.FALLBACK_HERO_IDS.duplicate()
	var groups: Array = []
	for _g in CHOICE_COUNT:
		var loots: Array = []
		for _i in COMBO_GROUPS * TavernData.COMBO_DRAW_COUNT:
			var frag_id: int = _frag_id_of(hero_ids[int(rng.randi_range(0, hero_ids.size() - 1))], cm)
			if frag_id > 0:
				loots.append({"id": frag_id, "amount": int(rng.randi_range(1, STONE_AMOUNT_MAX))})
		for _i in COMBO_GROUPS:
			loots.append({"id": hero_ids[int(rng.randi_range(0, hero_ids.size() - 1))], "amount": 1})
		groups.append(loots)
	return groups


## 选定组结算：物品（含魂石，id>=100）→ add_item；英雄（id<100）→ 未拥有 add_hero
## （1 张整卡）+ 余量转魂石碎片、已拥有全转碎片（对齐 player_data._settle_tavern_loot
## 分流语义；同英雄逐条处理，第 1 张 add_hero 后第 2 张起 _owns_hero 自动走碎片分支，总量守恒）。
static func settle_thousand_group(pd: PlayerData, group_loots: Array, cm: Variant) -> void:
	for loot in group_loots:
		var item_id: int = int(loot["id"])
		var amount: int = int(loot["amount"])
		if item_id >= HERO_ID_MAX:
			pd.add_item(item_id, amount)
			continue
		if not _owns_hero(pd, item_id):
			pd.hero_manager.add_hero(item_id)
			amount -= 1
		if amount > 0:
			_add_hero_fragment(pd, item_id, amount, cm)


static func _owns_hero(pd: PlayerData, tid: int) -> bool:
	for inst_id in pd.hero_manager.heroes:
		var h: Variant = pd.hero_manager.heroes[inst_id]
		if h != null and int(h.tid) == tid:
			return true
	return false


## 英雄 → 魂石物品 id（Fragment 表反查，对齐 player_data._fragment_id_for_hero；roll/结算共用）。
static func _frag_id_of(tid: int, cm: Variant) -> int:
	return int(cm.get_raw_table(&"Fragment").get(str(tid), {}).get(&"Fragment ID", 0))


## 英雄转魂石碎片入包。
static func _add_hero_fragment(pd: PlayerData, tid: int, amount: int, cm: Variant) -> void:
	if amount <= 0:
		return
	var frag_id: int = _frag_id_of(tid, cm)
	if frag_id > 0:
		pd.hero_manager.add_fragment(frag_id, amount)
