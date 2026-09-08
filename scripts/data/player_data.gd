class_name PlayerData
extends RefCounted

## 玩家数据（Data 层）：钻石/体力/战队等级 + 持有 HeroManager。
## 存档序列化委托 PlayerDataSerde（控 ≤250）。
## 入口统一 int 校验（from_dict 全字段 int()，治旧版 JSON float→int P0）。

const PlayerDataSerde = preload("res://scripts/data/player_data_serde.gd")
## 持久化用 SaveManager（var_to_str 类型保真）。金币归 HeroManager（2.1）。

const MAX_TEAM_LEVEL: int = 99            # 战队等级上限（源 2026-06 解除绑定）
const VITALITY_DEFAULT_MAX: int = 120     # 体力上限（源 DEFAULT_DATA vitality=120）
const SKILL_DEFAULT_POINTS: int = 5
const TEAM_EXP_PER_LEVEL: int = 100       # 简化：每级 100 经验（PlayerLevel 表集成后续）
const REWARD_MULTIPLIER: int = 10
const LOOT_TYPE_HERO: String = "hero"
const LOOT_TYPE_EQUIP: String = "equip"
const LOOT_TYPE_BOOK: String = "book"
const MAX_ITEMS_PER_SLOT: int = 999
const HERO_ID_MAX: int = 100
const SWEEP_COIN_ID: int = 390
const DEFAULT_DIAMOND: int = 5000
const DEFAULT_GOLD: int = 100000
const DEFAULT_HERO_TIDS: Array[int] = [1, 2, 3, 4, 5]
const DEFAULT_ITEMS: Dictionary = {101: 10, 102: 10, 106: 5, 107: 5, 108: 5, 109: 5, 110: 5, 111: 5}

var diamond: int = 0
var crusade_point: int = 0  # 远征币（源 CrusadePoint 奖励货币）
var guildpoint: int = 0     # 公会币（源 addGuildMoney→addPoint，shop_consume payType=6）
var arena_point: int = 0    # 竞技场币（源 addPvpMoney→addPoint，shop_consume payType=5；PVP 奖励+shop 支付统一归 PlayerData）
var dungeonpoint: int = 0   # 副本硬币/龙鳞（源 addDungeonPoint→addPoint，副本奖励货币+钥匙消耗）
var items: Dictionary = {}  # item_id(int) -> count(int)（源 Item 奖励/背包）
var vitality: int = VITALITY_DEFAULT_MAX  # 新玩家初始体力（源 DEFAULT_DATA vitality=120；存档加载由 from_dict 覆盖）
var vitality_max: int = VITALITY_DEFAULT_MAX
var vitality_last_recover: int = 0  # 上次恢复时间戳（秒）
var vitality_today_buy: int = 0     # 今日买体力次数（源 todaybuy，受 VIP["Buy Vit Max"] 上限）
var team_level: int = 1
var team_exp: int = 0
var vip_level: int = 0  # VIP 等级（源 VIP 表特权查询）
var skill_points: int = SKILL_DEFAULT_POINTS  # 受 VIP["Max Skill Points"] 上限，源 player.lua:704
var skill_reset_times: int = 0  # 今日已购技能强化点次数（源 player.lua:718 reset_times，梯度计费+跨日重置）
var skill_cd_time: int = 0  # 技能点上次恢复时间戳（源 player.lua:674 _skill_levelup_cd，CD 300s 恢复 1 点）
var skill_last_reset_date: int = 0  # 跨日重置参考日期戳（源 player.lua:720 _last_reset_date，checkTwoDateod 判跨日）
var player_name: String = "Player"
var avatar: int = 0
var team: Array[int] = []  # 参战英雄 inst_id 列表（阵容；供 BattleSetup 构造 player_team）
var hero_manager: HeroManager
var crusade_manager: CrusadeManager
var tutorial_manager: TutorialManager
var task_manager: TaskManager
var daily_login: DailyLoginManager
var midas: MidasManager
var stage_manager: StageManager
var handbook: HandbookManager
var mailbox: MailData
var excavate: ExcavateManager
var ladder: LadderManager
var shop_auto_refresh: Dictionary = {}
var shop_expire_end: Dictionary = {}
# 独立于 tutorial_manager 线性 steps 链 —— unlock step 是升级时并行触发 + 即时记录（id-based，源机制）。
var tutorial_records: Dictionary = {}
# key=box（Bronze/Gold/MagicSoul；单机化直接索引，源用 box_color 等价）。
var tavern_record: Dictionary = {}
# 日重置待 SaveManager 时间逻辑补全（当前累计不重置 → 剩余递减，降级）。
var stage_limit: Dictionary = {}
# key=normalStageId（源 elite2NormalStage），value=今日已重置次数。
var stage_reset_times: Dictionary = {}
var cm: ConfigManager
# EventBus 可选注入（check_unlocks 发 feature_unlocked 信号用；null 时仅 set record 不发信号，headless 可测）。
var events: EventBus = null
# 存档标脏钩子（GameData 注入 mark_save_dirty；缺省 Callable 时静默跳过，headless 可测）。
var save_hook: Callable = Callable()

func _init(p_cm: ConfigManager) -> void:
	cm = p_cm
	hero_manager = HeroManager.new(cm)
	crusade_manager = CrusadeManager.new(cm)
	tutorial_manager = TutorialManager.new(TutorialData.default_steps())
	task_manager = TaskManager.new()
	daily_login = DailyLoginManager.new()
	midas = MidasManager.new(cm)
	stage_manager = StageManager.new(cm)
	handbook = HandbookManager.new()
	mailbox = MailData.new()
	excavate = ExcavateManager.new(cm)
	ladder = LadderManager.new()


## 仅 GameData._load_or_new_player 无存档时调用（不在 _init 调，保 PlayerData.new 单测"空档"假设）。
func apply_default_data() -> void:
	diamond = DEFAULT_DIAMOND
	hero_manager.gold = DEFAULT_GOLD
	for tid in DEFAULT_HERO_TIDS:
		var inst_id: int = hero_manager.add_hero(tid)
		team.append(inst_id)
		if handbook != null:
			handbook.record_hero(tid)
	for item_id in DEFAULT_ITEMS:
		add_item(int(item_id), int(DEFAULT_ITEMS[item_id]))

func add_diamond(amount: int) -> void: diamond += amount


## 统一货币增减（照源 playertools.lua:16-47 addPoint：gold→addMoney/diamond→addrmb/4 point→_points）。
## amount 负=扣减；diamond 扣走 spend_diamond（带 track + 余额校验）。无效类型 push_warning（源 print）。
func add_point(coin_type: String, amount: int) -> void:
	match coin_type:
		"gold": hero_manager.add_money(amount)
		"diamond":
			if amount < 0: spend_diamond(-amount)
			else: diamond += amount
		"crusadepoint": crusade_point += amount
		"arenapoint": arena_point += amount
		"guildpoint": guildpoint += amount
		"dungeonpoint": dungeonpoint += amount
		_: push_warning("Invalid coin type: " + coin_type)


## 统一货币查询（照源 playertools.lua:7-14 getPoint）。无效类型返 0。
func get_point(coin_type: String) -> int:
	match coin_type:
		"gold": return hero_manager.gold
		"diamond": return diamond
		"crusadepoint": return crusade_point
		"arenapoint": return arena_point
		"guildpoint": return guildpoint
		"dungeonpoint": return dungeonpoint
		_: return 0


## 添加道具（源 Item 奖励，背包累加）。
func add_item(item_id: int, count: int = 1) -> void:
	if item_id <= 0 or count <= 0:
		return
	items[item_id] = int(items.get(item_id, 0)) + count
	# 图鉴收集（装备 id >= 100）
	if handbook != null and item_id >= HERO_ID_MAX:
		handbook.record_equip(item_id)

func spend_diamond(amount: int) -> bool:
	if diamond < amount:
		return false
	diamond -= amount
	return true


## 消耗体力（Stage 通关基础）。不足返 false。
## 体力购买/时间恢复见 VitalityManager（阶段三 T3 归位；本方法属货币读写留聚合根）。
func spend_vitality(amount: int) -> bool:
	if vitality < amount:
		return false
	vitality -= amount
	return true


func get_tutorial_record(step_id: int) -> int: return int(tutorial_records.get(step_id, 0))


func set_tutorial_record(step_id: int, times: int = 1) -> void:
	tutorial_records[step_id] = times


## 技能升级：消耗技能点 + hero_manager.upgrade_skill_level → 见 SkillPointManager.upgrade_hero_skill（阶段三 T3 迁出）。
## 装备强化/满级/合成 → 见 EquipCraftManager（enhance_equip/enhance_equip_to_max/synthesize_equip）。


## 扣物品不加金币（照源 player.lua:1232 consumeEquip 减 equip_qunty[id]，eatexplist 喂药消耗经验药用）。
## 区别 sell_equip（卖=扣+加金币）：本方法纯扣，对应源 consumeEquip 服务端扣物品不发金。
## 返实际扣减数（不足返 0，成功返 count）；eatexplist 用 0 判定持有量耗尽拦截。
func remove_item(item_id: int, count: int = 1) -> int:
	if item_id <= 0 or count <= 0:
		return 0
	var have: int = int(items.get(item_id, 0))
	if have < count:
		return 0
	items[item_id] = have - count
	return count


## 装备出售（照源 ofsell.lua:140 income=sellAmount×unitPrice + network.lua:929/933 sell_item 回包：
## 加金币 + 删背包；local_server:1359 net 桩无 Logic）。删 items 装备 + 加 hero_manager.gold。返 income（-1 失败）。
func sell_equip(item_id: int, count: int) -> int:
	if count <= 0 or int(items.get(item_id, 0)) < count:
		return -1
	var sell_price: int = int(cm.get_raw_table(&"Equip").get(str(item_id), {}).get("Sell Price", 0))
	items[item_id] = int(items[item_id]) - count
	hero_manager.add_money(sell_price * count)
	return sell_price * count


## 单机特权 VIP 等级：无充值系统，VIP 特权按表内最高档生效（2026-09-08 去 VIP 限制）。
## 显示层（角标/金框/排行榜）仍用 vip_level，与特权解耦。
func privilege_vip_level() -> int:
	return VipData.get_max_level(cm)


## VIP 特权解锁查询（源 VIP[level].field bool）；单机化后按特权档（满级）判。
func is_vip_unlocked(field: String) -> bool:
	return bool(VipData.get_vip_field(privilege_vip_level(), field, cm))

## 设置参战阵容（inst_id 列表；调用方保证 inst_id 有效 + 数量合规）。
func set_team(inst_ids: Array[int]) -> void: team = inst_ids.duplicate()


## 设置玩家头像（照源 local_server.lua:1837-1845 set_avatar handler）。
## avatar_id 有效性由调用方（头像选择面板）保证，handler 照源不校验。
## 2026-08-21 补 save_hook 标脏（此前换头像/改名均不落盘，重启丢失）。
func set_avatar(new_avatar: int) -> void:
	avatar = new_avatar
	if save_hook.is_valid():
		save_hook.call()


## 设置玩家名（照源 local_server.lua:1819-1833 set_name handler）。
func set_player_name(new_name: String) -> void:
	if new_name != "":
		player_name = new_name
		if save_hook.is_valid():
			save_hook.call()


## 抽卡（消耗钻石，返 chest_group 供产出 Logic）。免费跳过消耗。
func draw_tavern(tavern_type: String, is_ten: bool, is_free: bool, count: int, cm: Variant) -> Dictionary:
	# Cost Type 区分（源 row Gold=Bronze 金币 / Diamond=MagicSoul 钻石）抽至 TavernData.consume_tavern_cost。
	var row: Dictionary = TavernData.get_tavern_info(tavern_type, is_ten, is_free, count, cm)
	if not TavernData.consume_tavern_cost(self, row, is_free):
		return {"ok": false}
	if task_manager != null:
		task_manager.record_by_type(cm, "TavernGroupUse")
	return {"ok": true, "chest_group": int(row.get("Chest Group ID", 0))}


## 完整抽卡：消耗钻石 + 产出物品/碎片进背包（照源 local_server.lua:1673 tavern_draw handler
## + 品质分池/首抽高档/gold 保底/magic 计数/新英雄碎魂重建 2026-09-07）。
## equip（id>=100）→ items；英雄（id<100）→ 未拥有 add_hero / 已拥有转魂石（源 _smash_idx）。
func draw_tavern_full(tavern_type: String, is_ten: bool, is_free: bool, count: int, rng: Variant) -> Dictionary:
	var r: Dictionary = draw_tavern(tavern_type, is_ten, is_free, count, cm)
	if not bool(r["ok"]):
		return {"ok": false}
	var draw_type: int = 1 if is_ten else 0
	# 首抽高一档（refresh_first_tavern 置位前读取；源首抽独立 Chest Group 重建）
	var is_first: bool = TavernData.is_first_ten_draw(self, tavern_type) if is_ten \
			else TavernData.is_first_one_draw(self, tavern_type)
	# magic 十连计数（源 DrawTimes 26 切组依据；读旧值 roll，成功后 +1）
	var magic_combo: int = int(tavern_record.get("MagicSoul", {}).get("combo_count", 0))
	var loots: Array = TavernData.roll_tavern_loot(draw_type, 0, rng, cm, tavern_type, is_first, magic_combo)
	_settle_tavern_loot(loots)
	if tavern_type == "MagicSoul" and is_ten:
		if not tavern_record.has("MagicSoul"):
			tavern_record["MagicSoul"] = {}
		tavern_record["MagicSoul"]["combo_count"] = magic_combo + 1
	return {"ok": true, "loots": loots}


## 抽卡产出结算：英雄分流——未拥有 add_hero（源 _new_heroes 新英雄全量下发的单机化等价，
## 星级取 Unit.Initial Stars）、已拥有转魂石 ×amount（源 _smash_idx 重复英雄碎魂）。
func _settle_tavern_loot(loots: Array) -> void:
	for loot in loots:
		var item_id: int = int(loot["id"])
		var amount: int = int(loot["amount"])
		if item_id < HERO_ID_MAX:
			if _owns_hero(item_id):
				var frag_id: int = _fragment_id_for_hero(item_id)
				if frag_id > 0:
					hero_manager.add_fragment(frag_id, amount)
			else:
				hero_manager.add_hero(item_id)
		else:
			add_item(item_id, amount)


func _owns_hero(tid: int) -> bool:
	for inst_id in hero_manager.heroes:
		var h: Variant = hero_manager.heroes[inst_id]
		if h != null and int(h.tid) == tid:
			return true
	return false


## 反查 Fragment 表得英雄碎片物品 id（源 Fragment[tid]["Fragment ID"]）。
## 抽卡产 heroId（源 local_server:1761），本项目 fragments 容器 key 是 Fragment ID，需转换。
func _fragment_id_for_hero(tid: int) -> int:
	return int(cm.get_raw_table(&"Fragment").get(str(tid), {}).get(&"Fragment ID", 0))

## 体力时间恢复 → VitalityManager.recover（阶段三 T3 迁出；⚠️ 当前零调用，恢复链路未接线，见验收记录）。

## 战队经验增加，自动升级（上限 MAX_TEAM_LEVEL）+ 发放 Vitality Reward（源 PlayerLevel）。
## 实际升级后调 check_unlocks（源 baselsr.lua:25-28 happenPlayerLevelup 仅升级时设标志）。
func add_team_exp(amount: int) -> void:
	var old_level: int = team_level
	team_exp += amount
	while team_level < MAX_TEAM_LEVEL and team_exp >= _exp_to_next():
		team_exp -= _exp_to_next()
		var reward: int = PlayerLevelData.get_vitality_reward(team_level, cm)
		team_level += 1
		vitality = min(vitality + reward, vitality_max)
	if team_level >= MAX_TEAM_LEVEL:
		team_exp = 0
	if team_level > old_level:
		check_unlocks()


## → set_tutorial_record + 发 feature_unlocked 信号。返新解锁 step 名列表。
## record 守卫保证每个功能只触发一次（源 ed.teach 内部 not checkDone 等价）。
func check_unlocks() -> Array[StringName]:
	var fl := FeatureLimit.new(cm)
	var newly: Array[StringName] = []
	for feature in FeatureLimit.BASELSR_UNLOCK_MAP:
		var step: StringName = FeatureLimit.BASELSR_UNLOCK_MAP[feature]
		var step_id: int = TutorialData.get_unlock_step_id(step)
		if step_id > 0 and fl.check_area_unlock(feature, team_level) and get_tutorial_record(step_id) == 0:
			set_tutorial_record(step_id)
			newly.append(step)
			if events != null:
				events.emit_feature_unlocked(step)
	return newly


func _exp_to_next() -> int:
	var exp: int = PlayerLevelData.get_level_exp(team_level, cm)
	return exp if exp > 0 else team_level * TEAM_EXP_PER_LEVEL


## 关卡胜利发奖（照源 player.lua:1330-1369 takeStageReward）。
## 金币+钻石+战队经验+英雄经验+掉落；setStageStars/recalcHeroGs 单机化标注（已存/标注）。
func take_stage_reward(stage_id: int, _stars: int, hero_tids: Array[int], loots: Array = []) -> void:
	var data := StageData.from_config(cm, stage_id)
	hero_manager.add_money(data.money_reward * REWARD_MULTIPLIER)
	add_diamond(StageAccount.diamond_reward(stage_id))
	add_team_exp(data.exp_reward * REWARD_MULTIPLIER)
	var hero_count: int = max(hero_tids.size(), 1)
	var hero_exp: int = int(data.heroexp_reward / hero_count)
	for tid in hero_tids:
		var inst_id: int = _find_hero_inst_by_tid(int(tid))
		if inst_id > 0:
			hero_manager.add_hero_exp(inst_id, hero_exp)
	# 单机化：源 addEquip/addSkillbook 进独立容器（equip_qunty/skillbook_qunty），本项目合并进 PlayerData.items 通用背包。
	for loot in loots:
		var ld: Dictionary = loot
		var item_id: int = int(ld.get("id", 0))
		var item_type: String = String(ld.get("type", ""))
		if item_type == LOOT_TYPE_HERO:
			hero_manager.add_hero(item_id)
			if handbook != null:
				handbook.record_hero(item_id)
		elif item_type == LOOT_TYPE_EQUIP or item_type == LOOT_TYPE_BOOK:
			add_item(item_id)


## 扫荡券持有数（照源 player.lua:760 getSweepTimes：equip_qunty[sweep_coin_id]）。
## 单机化：扫荡券合并进 items 通用背包（源独立 equip_qunty）。
func get_sweep_times() -> int:
	return int(items.get(SWEEP_COIN_ID, 0))


## 消耗扫荡券（照源 player.lua:765 useSweepTimes → :1232 consumeEquip 减 equip_qunty[id]）。
## 不足返 false（源 consumeEquip 不足仅 print 不阻断；本项目 Logic 返 bool 让上层 sweep 决策）。
func use_sweep_times(times: int) -> bool:
	if times <= 0:
		return true
	var have: int = int(items.get(SWEEP_COIN_ID, 0))
	if have < times:
		return false
	items[SWEEP_COIN_ID] = have - times
	return true


func _find_hero_inst_by_tid(tid: int) -> int:
	for inst_id in hero_manager.heroes:
		var h: HeroInstance = hero_manager.heroes[inst_id]
		if h.tid == tid:
			return int(inst_id)
	return 0


## 确保远征敌人已生成（新档/读档后 enemies 空 → init_crusade）。进入 Crusade UI 前调。
func ensure_crusade(rng: BattleRng) -> void:
	if crusade_manager.enemies.is_empty():
		crusade_manager.init_crusade(rng)

## 序列化到字典（存档用）— 委托 PlayerDataSerde（控 ≤250）
func to_dict() -> Dictionary:
	return PlayerDataSerde.to_dict(self)

## 从字典重建 — 委托 PlayerDataSerde。入口统一 int 校验（存档/外部数据可能含 float，强制 int）。
static func from_dict(data: Dictionary, cm: ConfigManager) -> PlayerData:
	return PlayerDataSerde.from_dict(data, cm)
