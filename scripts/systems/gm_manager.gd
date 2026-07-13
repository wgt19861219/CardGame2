class_name GmManager
extends RefCounted

## GM 调试命令集（Logic 层）— 照源 local_server.lua:1912-2094 gm_cmd handler 翻译。
## 12 类单机本地数据操作（开发/测试必备工具，源全部走 local_server 非联机）。
## 单机化：源 handler 接收 obj（命令字段）+ 操作 localdata（存档）；本项目直接操作 PlayerData。
##
## 数据层缺口（源 localdata 有但 PlayerData 未实现，跳过并标注）：
##   - arena_point（竞技场币）：PlayerData 仅有 crusade_point，arena_point 待补
##   - recharge_sum（累计充值）：单机化无充值，待补
##   - sweep_today_free（扫荡免费次数）：StageManager 不持久化，待补
##
## 用法：GmManager.execute(player, cm, cmd, stage_mgr) — cmd key 为命令名（下划线前缀）。
## stage_mgr 可选（unlock_all_stages 用，可为 null）。返回 _reset（完整 user 数据，照源）。

const MAX_UNLOCK_LEVEL: int = 80   # 源 unlock_all_stages 设 player.level = 80
const HERO_INIT_GS: int = 100      # 源 get_all_heroes gs = 100
const CHAPTER_MAX: int = 14        # 源 :1935 章节范围上限（Chapter ID 1-14）
const MAX_NORMAL_STAGES: int = 9999  # 源 stage.max_normal = 9999
const BITS_ID_LOW: int = 0         # 源 ed.bits(itemBits, 0, 10) — id 占低 10 位
const BITS_ID_COUNT: int = 10
const BITS_AMOUNT_LOW: int = 10    # 源 ed.bits(itemBits, 10, 11) — amount 占 11 位
const BITS_AMOUNT_COUNT: int = 11


## 源 gm_cmd handler 主入口：逐项检查 obj 字段执行对应 GM 命令。
static func execute(
	player: PlayerData, cm: ConfigManager, cmd: Dictionary, stage_mgr: Variant = null
) -> Dictionary:
	if cmd.get("_unlock_all_stages", 0) > 0:
		_unlock_all_stages(cm, stage_mgr)
		player.team_level = MAX_UNLOCK_LEVEL
	if cmd.get("_get_all_heroes", 0) > 0:
		_get_all_heroes(player, cm)
	if cmd.has("_set_hero_info"):
		_set_hero_info(player, cmd["_set_hero_info"])
	if cmd.has("_set_vitality"):
		player.vitality = int(cmd["_set_vitality"])
	if cmd.has("_set_money"):
		_set_money(player, cmd["_set_money"])
	# _set_recharge_sum：单机化裁剪（无充值流程），源 recharge_sum 仅累计充值（VIP 可能基于）；
	# PlayerData 无该字段，GM 调试无实际用途 → 补字段待 recharge_sum 用途（VIP 接入）明确
	if cmd.has("_set_player_level"):
		player.team_level = int(cmd["_set_player_level"])
	if cmd.has("_set_player_exp"):
		player.team_exp = int(cmd["_set_player_exp"])
	if cmd.has("_set_items"):
		_set_items(player, cmd["_set_items"])
	if cmd.get("_reset_device", 0) > 0:
		_reset_device(player, cm)
	# _open_mystery_shop 源为空操作（照源不处理）
	# _reset_sweep：目标 sweep 用扫荡券（SWEEP_COIN_ID=390，use_sweep_times）非源 sweep_today_free（每日免费次数），
	# 机制差异；重置扫荡券需统一评估（关联 P1-三轮-4 sweep 机制复核）
	# _set_dailylogin_days：DailyLoginManager.frequency = days（GM 设连续登录天数，不影响领奖状态）
	if cmd.has("_set_dailylogin_days"):
		# 源 :2063-2066 daily_login.frequency = days（GM 设连续登录天数）
		player.daily_login.frequency = int(cmd["_set_dailylogin_days"])
	# 源 :2068-2081 清理非 Hero 英雄（旧存档混入怪物/召唤物）
	_cleanup_non_hero(player, cm)
	# 源 GM 返回 _reset（完整 user 数据）
	return {"_reset": {"_user": _build_user(player)}}


# 源 :1924-1945 unlock_all_stages：遍历 Stage 表，normal/elite 关设 3 星 + max_normal=9999。
static func _unlock_all_stages(cm: ConfigManager, stage_mgr: Variant) -> void:
	if stage_mgr == null:
		return   # 无 StageManager 实例则跳过（stage 进度无持久化目标）
	var stage_table: Dictionary = cm.get_raw_table("Stage")
	for sid_key in stage_table:
		var sid: int = int(sid_key)
		if sid > 0:
			var row: Dictionary = stage_table[sid_key]
			var ch: int = int(row.get("Chapter ID", 0))
			if ch >= 1 and ch <= CHAPTER_MAX:   # 源 :1935 章节范围
				var s_type: String = StageAccount.stage_type(sid)
				if s_type == "normal" or s_type == "elite":
					stage_mgr.progress[sid] = StageManager.STARS_FULL   # 源设 3 星
	stage_mgr.max_normal = MAX_NORMAL_STAGES   # 源 stage.max_normal = 9999


# 源 :1947-1969 get_all_heroes：遍历 Unit 表，Hero 类型 + 有 Portrait 的加入玩家英雄列表。
static func _get_all_heroes(player: PlayerData, cm: ConfigManager) -> void:
	var unit_table: Dictionary = cm.get_raw_table("Unit")
	var existing: Dictionary = {}
	for inst_id in player.hero_manager.heroes:
		var h: HeroInstance = player.hero_manager.heroes[inst_id]
		existing[h.tid] = true
	for tid_key in unit_table:
		var tid: int = int(tid_key)
		if tid > 0 and not existing.has(tid):
			var unit: Dictionary = unit_table[tid_key]
			if String(unit.get("Unit Type", "")) == "Hero" and unit.has("Portrait"):
				player.hero_manager.add_hero(tid)   # rank/level/stars 默认 1，照源初始值


# 源 :1971-1986 set_hero_info：批量设置英雄 rank/level/stars/exp/gs。
static func _set_hero_info(player: PlayerData, hero_list: Array) -> void:
	for hero_msg in hero_list:
		var tid: int = int(hero_msg.get("_tid", 0))
		if tid != 0:
			var hero: HeroInstance = _find_hero_by_tid(player, tid)
			if hero != null:
				if hero_msg.has("_rank"):
					hero.rank = int(hero_msg["_rank"])
				if hero_msg.has("_level"):
					hero.level = int(hero_msg["_level"])
				if hero_msg.has("_stars"):
					hero.stars = int(hero_msg["_stars"])
				if hero_msg.has("_exp"):
					hero.exp = int(hero_msg["_exp"])
				if hero_msg.has("_gs"):
					hero.gs = int(hero_msg["_gs"])


# HeroManager 按 tid 查英雄（heroes 是 inst_id→HeroInstance，需遍历）。
static func _find_hero_by_tid(player: PlayerData, tid: int) -> HeroInstance:
	for inst_id in player.hero_manager.heroes:
		var h: HeroInstance = player.hero_manager.heroes[inst_id]
		if h.tid == tid:
			return h
	return null


# 源 :1997-2021 set_money：按 _type 设置 gold/diamond/crusadepoint/arenapoint + 兼容旧 _money/_rmb。
static func _set_money(player: PlayerData, sm: Dictionary) -> void:
	var money_type: String = String(sm.get("_type", ""))
	var amount: int = int(sm.get("_amount", 0))
	if money_type != "" and amount != 0:
		match money_type:
			"gold":
				player.hero_manager.gold = amount
			"diamond":
				player.diamond = amount
			"crusadepoint":
				player.crusade_point = amount
			"arenapoint":
				player.arena_point = amount  # 源 set_money arenapoint（arena_point 统一归 PlayerData）
	# 源 :2017-2020 兼容旧格式 _money（金）/ _rmb（钻）
	if sm.has("_money"):
		player.hero_manager.gold = int(sm["_money"])
	if sm.has("_rmb"):
		player.diamond = int(sm["_rmb"])


# 源 :2038-2044 set_items：bits 解码（低 10 位 id，11-21 位 amount）。
static func _set_items(player: PlayerData, item_bits_list: Array) -> void:
	for item_bits in item_bits_list:
		var packed: int = int(item_bits)
		var item_id: int = _bits(packed, BITS_ID_LOW, BITS_ID_COUNT)
		var amount: int = _bits(packed, BITS_AMOUNT_LOW, BITS_AMOUNT_COUNT)
		player.items[item_id] = amount


# 源 tools.lua:66 bits(num, low, count) = (num >> low) & ((1 << count) - 1)。
static func _bits(num: int, low: int, count: int) -> int:
	return (num >> low) & ((1 << count) - 1)


# 源 :2046-2049 reset_device：删号重练（重置 PlayerData 到 DEFAULT_DATA 初始状态）。
# 源 LocalData.reset() = deepCopy(DEFAULT_DATA)，全字段重置。
# apply_default_data 仅设 diamond/gold/heroes/items，不重置 level/exp/vitality，故手动补齐。
static func _reset_device(player: PlayerData, cm: ConfigManager) -> void:
	player.team_level = 1
	player.team_exp = 0
	player.vitality = PlayerData.VITALITY_DEFAULT_MAX
	player.crusade_point = 0
	player.vip_level = 0
	player.apply_default_data()


# 源 :2068-2081 清理非 Hero 英雄（旧存档混入怪物/召唤物：Unit 类型 != Hero 或无 Portrait）。
static func _cleanup_non_hero(player: PlayerData, cm: ConfigManager) -> void:
	var unit_table: Dictionary = cm.get_raw_table("Unit")
	var to_remove: Array[int] = []
	for inst_id in player.hero_manager.heroes:
		var h: HeroInstance = player.hero_manager.heroes[inst_id]
		var u: Dictionary = unit_table.get(str(h.tid), {})
		if not u.is_empty() and (String(u.get("Unit Type", "")) != "Hero" or not u.has("Portrait")):
			to_remove.append(int(inst_id))
	for inst_id in to_remove:
		player.hero_manager.heroes.erase(inst_id)


# 源 :2083-2094 buildUser：构造完整 user 数据快照（GM 返回用）。
static func _build_user(player: PlayerData) -> Dictionary:
	return {
		"_money": player.hero_manager.gold,
		"_rmb": player.diamond,
		"_level": player.team_level,
		"_exp": player.team_exp,
		"_vip": player.vip_level,
		"_name": player.player_name,
	}
