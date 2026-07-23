class_name PlayerData
extends RefCounted

## 玩家数据（Data 层）：钻石/体力/战队等级 + 持有 HeroManager。
## 存档序列化委托 PlayerDataSerde（控 ≤250）。
## 入口统一 int 校验（from_dict 全字段 int()，治旧版 JSON float→int P0）。

const PlayerDataSerde = preload("res://scripts/data/player_data_serde.gd")
## 持久化用 SaveManager（var_to_str 类型保真）。金币归 HeroManager（2.1）。

const MAX_TEAM_LEVEL: int = 99            # 战队等级上限（源 2026-06 解除绑定）
const VITALITY_DEFAULT_MAX: int = 120     # 体力上限（源 DEFAULT_DATA vitality=120）
const VITALITY_RECOVER_INTERVAL: int = 360  # 每 360s 恢复 1 点（速率待核源 sync_vitality）
const BUY_VIT_COST: int = 50           # 源 local_server:1795 买体力钻石消耗
const BUY_VIT_AMOUNT: int = 120        # 源 :1798 每次买体力量
const BUY_VIT_HARD_CAP: int = 9999     # 源 :1798 买体可囤积上限（区别于自然恢复上限 120）
const SKILL_POINT_COST: int = 1        # 技能升级消耗技能点
const SKILL_BUY_AMOUNT: int = 10       # 源 local_server:2185 buy_skill_stren_point 每次 chance+=10
const SKILL_BUY_MAX_TIMES: int = 30    # 源 skillstren.lua:467 GradientPrice 封顶第 30 行
# 源 local_server.lua:85 DEFAULT_DATA.skill.chance=5（新玩家初始技能点）
const SKILL_DEFAULT_POINTS: int = 5
const TEAM_EXP_PER_LEVEL: int = 100       # 简化：每级 100 经验（PlayerLevel 表集成后续）
const REWARD_MULTIPLIER: int = 10         # 源 takeStageReward 金币/战队经验 ×10（:1332/1339）
const LOOT_TYPE_HERO: String = "hero"     # 源 player.lua:1351 loots type=="hero" → addHero
const LOOT_TYPE_EQUIP: String = "equip"   # 源 :1353 type=="equip" → addEquip
const LOOT_TYPE_BOOK: String = "book"     # 源 :1355 type=="book" → addSkillbook
const MAX_ITEMS_PER_SLOT: int = 999       # 源 parameter.lua:41 max_item_amount（背包单格上限）
const HERO_ID_MAX: int = 100              # 源 player.lua itemType：id<100 hero（抽卡 heroId 碎片判定）
const SWEEP_COIN_ID: int = 390            # 源 parameter.sweep_coin_id（parameter.lua:35，扫荡券物品 ID）
const DEFAULT_DIAMOND: int = 5000         # 源 local_server.lua:52 DEFAULT_DATA player.diamond
const DEFAULT_GOLD: int = 100000          # 源 :51 DEFAULT_DATA player.gold
const DEFAULT_HERO_TIDS: Array[int] = [1, 2, 3, 4, 5]  # 源 :63-69 DEFAULT_DATA heroes tid 1-5
const DEFAULT_ITEMS: Dictionary = {101: 10, 102: 10, 106: 5, 107: 5, 108: 5, 109: 5, 110: 5, 111: 5}  # 源 :70-73 DEFAULT_DATA items

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
# 源 DEFAULT_DATA.skill：chance=5(初始技能点) / cd_time=0(恢复时间戳) / reset_times=0(梯度计费次数) / last_reset_date=0(跨日重置戳)
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
# 源 shop data._last_auto_refresh_time（local_server.lua:104/1219）：每店上次自动刷新 ts（0=不自动刷新）。ShopManager 临时实例不持久化挂 PlayerData。
var shop_auto_refresh: Dictionary = {}
# 源 shop data._expire_time（local_server.lua:1316）：地精(2)/黑市(3)/星际(6) 停留截止 ts（0=不限时）。单机化方案 B 开店起计+到期清记录（再点重计）。
var shop_expire_end: Dictionary = {}
# 源 ed.player:getTutorialRecord/setTutorialRecord（tutorial.lua:40/56）：unlock step 完成记录（step_id → times）。
# 独立于 tutorial_manager 线性 steps 链 —— unlock step 是升级时并行触发 + 即时记录（id-based，源机制）。
var tutorial_records: Dictionary = {}
# 源 ed.player._tavern_record（player.lua:1731）：每 box 免费记录 {left_cnt,last_get_time,has_first_draw}。
# key=box（Bronze/Gold/MagicSoul；单机化直接索引，源用 box_color 等价）。
var tavern_record: Dictionary = {}
# 源 ed.player.stage_limit（player.lua）：关卡每日已挑战次数（normalStage→count），checkEnabled 判剩余。
# 日重置待 SaveManager 时间逻辑补全（当前累计不重置 → 剩余递减，降级）。
var stage_limit: Dictionary = {}
var cm: ConfigManager
# EventBus 可选注入（check_unlocks 发 feature_unlocked 信号用；null 时仅 set record 不发信号，headless 可测）。
var events: EventBus = null

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


## 源 local_server.lua:44-108 DEFAULT_DATA：新玩家初始英雄/经济/物品。
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
func spend_vitality(amount: int) -> bool:
	if vitality < amount:
		return false
	vitality -= amount
	return true


## 是否还能买体力（照源 player.lua:603 canBuyVitality：今日次数 < VIP["Buy Vit Max"]）。
## UI 预检用，与 buy_vitality 互补：本方法只查 VIP 当日上限，buy_vitality 还查钻石是否够。
func can_buy_vitality() -> bool:
	var limit: int = int(VipData.get_vip_field(vip_level, "Buy Vit Max", cm))
	return limit <= 0 or vitality_today_buy < limit


## 买体力（照源 local_server:1793 buy_vitality + player.lua:605 VIP 上限）。
## 扣 50 钻 + 体力+120 + today_buy++（受 VIP["Buy Vit Max"] 上限）。返是否成功。
func buy_vitality() -> bool:
	var limit: int = int(VipData.get_vip_field(vip_level, "Buy Vit Max", cm))
	if limit > 0 and vitality_today_buy >= limit:
		return false   # 超 VIP 当日上限
	if diamond < BUY_VIT_COST:
		return false
	diamond -= BUY_VIT_COST
	# 源 :1798 买体力用 9999 硬上限（允许囤积），非自然恢复的 vitality_max(120)
	vitality = min(vitality + BUY_VIT_AMOUNT, BUY_VIT_HARD_CAP)
	vitality_today_buy += 1
	return true


## 增加技能点（受 VIP["Max Skill Points"] 上限，源 player.lua:704）。Logic 委托 SkillPointManager。
func add_skill_point(amount: int = 1) -> void:
	SkillPointManager.add(self, amount)


## 买技能强化点（照源 local_server:2184-2193 + skillstren.lua:187-202/463-468）。
## 源 handler 只 chance+=10+reset_times++，扣钻在 client（addrmb(-cost)）。
## 单机化 Logic 统一入口：梯度计费 GradientPrice[min(reset_times+1,30)]["Skill Upgrade Reset"] 钻石。
## 买前先跨日重置 skill_reset_times（源 player.lua:727 getSkillResetTimes 内部 resetSkillData→:718-731）。
## 返是否成功（钻石不足返 false）。
func buy_skill_stren_point() -> bool:
	# 源 player.lua:727 getSkillResetTimes 先 resetSkillData 跨日归 0 再返次数（梯度回退第 1 档）
	SkillPointManager.check_cross_day_reset(self, Time.get_unix_time_from_system())
	var cost: int = _get_skill_buy_cost()
	if diamond < cost:
		return false
	diamond -= cost
	skill_reset_times += 1
	add_skill_point(SKILL_BUY_AMOUNT)
	return true


## 按时间自动恢复技能点（照源 player.lua:658-686 getSkillLvupChance）。CD 间隔 300s，上限 VIP["Max Skill Points"]。
## Logic 委托 SkillPointManager（控行数 + 可单测）。返回本次恢复量。
func recover_skill_point(now_seconds: int) -> int:
	return SkillPointManager.recover(self, now_seconds)


## 下一笔购买钻石消耗（源 skillstren.lua:463-468 getResetCost）。
func _get_skill_buy_cost() -> int:
	var idx: int = min(skill_reset_times + 1, SKILL_BUY_MAX_TIMES)
	var gp: Dictionary = cm.get_raw_table(&"GradientPrice")
	return int(gp.get(str(idx), {}).get(&"Skill Upgrade Reset", 0))


## 源 ed.player:getTutorialRecord(id)（tutorial.lua:40）：读 unlock step 完成次数（0 表未完成）。
func get_tutorial_record(step_id: int) -> int: return int(tutorial_records.get(step_id, 0))


## 源 ed.player:setTutorialRecord(id, times)（tutorial.lua:56）：标记 unlock step 完成（默认 1 次）。
func set_tutorial_record(step_id: int, times: int = 1) -> void:
	tutorial_records[step_id] = times


## 技能升级：消耗技能点 + hero_manager.upgrade_skill_level。返是否成功。
func upgrade_hero_skill(inst_id: int, skill_idx: int) -> bool:
	if skill_points < SKILL_POINT_COST:
		return false
	if not hero_manager.upgrade_skill_level(inst_id, skill_idx):
		return false
	skill_points -= SKILL_POINT_COST
	# 源 record.lua refreshCommonRecord("skillUpgradeSuccess") → 日常任务 SkillUpgradeSuccess
	if task_manager != null and cm != null:
		task_manager.record_by_type(cm, "SkillUpgradeSuccess")
	return true


## 装备强化（照源 ui/equipstrengthen.lua:495-616 + local_server.lua:1436-1443）。
## Logic 抽至 EquipCraftManager（治 LINT005 + 装备 Logic 独立成层）；薄代理保持 ed.player 入口。
func enhance_equip(inst_id: int, slot: int, materials: Dictionary) -> bool:
	return EquipCraftManager.enhance_equip(self, inst_id, slot, materials)


## 装备钻石一键满级（照源 ui/equipstrengthen.lua:701-722 upFastStren op_type=2）。代理 EquipCraftManager。
func enhance_equip_to_max(inst_id: int, slot: int) -> bool:
	return EquipCraftManager.enhance_equip_to_max(self, inst_id, slot)


## 装备合成（照源 local_server:1059-1115 equip_synthesis）。代理 EquipCraftManager。
func synthesize_equip(target_id: int) -> bool:
	return EquipCraftManager.synthesize_equip(self, target_id)


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


## VIP 特权解锁查询（源 VIP[level].field bool）。
func is_vip_unlocked(field: String) -> bool:
	return bool(VipData.get_vip_field(vip_level, field, cm))

## 设置参战阵容（inst_id 列表；调用方保证 inst_id 有效 + 数量合规）。
func set_team(inst_ids: Array[int]) -> void: team = inst_ids.duplicate()


## 设置玩家头像（照源 local_server.lua:1837-1845 set_avatar handler）。
## 源设 localdata.player.avatar + LocalData.save；本项目存档由 SaveManager 管，只设字段。
## avatar_id 有效性由调用方（头像选择面板）保证，handler 照源不校验。
func set_avatar(new_avatar: int) -> void: avatar = new_avatar


## 设置玩家名（照源 local_server.lua:1819-1833 set_name handler）。
## 源：非空名 → 设 player.name + save；空名 → success（客户端已校验）。本项目只设非空。
func set_player_name(new_name: String) -> void:
	if new_name != "": player_name = new_name


## 抽卡（消耗钻石，返 chest_group 供产出 Logic）。免费跳过消耗。
func draw_tavern(tavern_type: String, is_ten: bool, is_free: bool, count: int, cm: Variant) -> Dictionary:
	# Cost Type 区分（源 row Gold=Bronze 金币 / Diamond=MagicSoul 钻石）抽至 TavernData.consume_tavern_cost。
	var row: Dictionary = TavernData.get_tavern_info(tavern_type, is_ten, is_free, count, cm)
	if not TavernData.consume_tavern_cost(self, row, is_free):
		return {"ok": false}
	# 源 record.lua refreshCommonRecord("tavernGroupUse") → 日常任务 TavernGroupUse
	if task_manager != null:
		task_manager.record_by_type(cm, "TavernGroupUse")
	return {"ok": true, "chest_group": int(row.get("Chest Group ID", 0))}


## 完整抽卡：消耗钻石 + 产出物品/碎片进背包（照源 local_server.lua:1673 tavern_draw handler）。
## 源产出 _item_ids（equip + 30% 英雄碎片）进 equip_qunty 单一容器；本项目双容器分流：
## equip（id>=100）→ items；英雄碎片（id<100，源 :1761 产 heroId）反查 Fragment 表转 Fragment ID → fragments。
func draw_tavern_full(tavern_type: String, is_ten: bool, is_free: bool, count: int, rng: Variant) -> Dictionary:
	var r: Dictionary = draw_tavern(tavern_type, is_ten, is_free, count, cm)
	if not bool(r["ok"]):
		return {"ok": false}
	var draw_type: int = 1 if is_ten else 0   # 源 drawType enum: 0=单抽, 1=十连
	var loots: Array = TavernData.roll_tavern_loot(draw_type, 0, rng, cm)
	for loot in loots:
		var item_id: int = int(loot["id"])
		var amount: int = int(loot["amount"])
		if item_id < HERO_ID_MAX:   # 源 :1761 heroId 当碎片 → 反查 Fragment ID 进 fragments 容器
			var frag_id: int = _fragment_id_for_hero(item_id)
			if frag_id > 0:
				hero_manager.add_fragment(frag_id, amount)
		else:
			add_item(item_id, amount)
	return {"ok": true, "loots": loots}


## 反查 Fragment 表得英雄碎片物品 id（源 Fragment[tid]["Fragment ID"]）。
## 抽卡产 heroId（源 local_server:1761），本项目 fragments 容器 key 是 Fragment ID，需转换。
func _fragment_id_for_hero(tid: int) -> int:
	return int(cm.get_raw_table(&"Fragment").get(str(tid), {}).get(&"Fragment ID", 0))

## 体力恢复（基于时间差）。返回恢复量；满体力时刷新时间戳。
func recover_vitality(now_seconds: int) -> int:
	if vitality >= vitality_max:
		vitality_last_recover = now_seconds
		return 0
	var elapsed: int = now_seconds - vitality_last_recover
	if elapsed < VITALITY_RECOVER_INTERVAL:
		return 0
	var recovered: int = elapsed / VITALITY_RECOVER_INTERVAL
	vitality = min(vitality + recovered, vitality_max)
	vitality_last_recover += recovered * VITALITY_RECOVER_INTERVAL
	return recovered

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


## 源 baselsr.lua:29-54 playerLevelup：遍历 11 功能，新解锁（check_area_unlock 且 tutorial_records 未记录）
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
	# 源 PlayerLevel[level].Exp（精确）；表缺失 fallback 简化公式
	var exp: int = PlayerLevelData.get_level_exp(team_level, cm)
	return exp if exp > 0 else team_level * TEAM_EXP_PER_LEVEL


## 关卡胜利发奖（照源 player.lua:1330-1369 takeStageReward）。
## 金币+钻石+战队经验+英雄经验+掉落；setStageStars/recalcHeroGs 单机化标注（已存/标注）。
func take_stage_reward(stage_id: int, _stars: int, hero_tids: Array[int], loots: Array = []) -> void:
	var data := StageData.from_config(cm, stage_id)
	# 源 :1332 addMoney(Money Reward*10)
	hero_manager.add_money(data.money_reward * REWARD_MULTIPLIER)
	# 源 :1334-1338 addrmb（stageType：普通20/精英50/活动100；本项目无 stage_type 工具，按 elite 阈值简化）
	add_diamond(StageAccount.diamond_reward(stage_id))
	# 源 :1339 addExp(Exp Reward*10, "battle")
	add_team_exp(data.exp_reward * REWARD_MULTIPLIER)
	# 源 :1340-1346 英雄经验（heroexp=Heroexp Reward/hero_count，非佣兵；本项目无佣兵全发）
	var hero_count: int = max(hero_tids.size(), 1)
	var hero_exp: int = int(data.heroexp_reward / hero_count)
	for tid in hero_tids:
		var inst_id: int = _find_hero_inst_by_tid(int(tid))
		if inst_id > 0:
			hero_manager.add_hero_exp(inst_id, hero_exp)
	# 源 :1347-1359 loots 按 type 发放：hero→add_hero / equip·book→add_item。
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
	# 源 :1360 setStageStars（StageManager.progress 已存关卡星数，不重复）
	# 源 :1362-1367 recalcHeroGs（GS 系统，标注）


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
