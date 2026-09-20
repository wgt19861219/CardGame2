class_name GuildManager
extends RefCounted

## 公会 Logic 层 — 照源 local_server.lua:2812-2966（guild handler NPC 模拟）+ guildconfig.lua 尾部常量
## + guild.lua 膜拜流程（freeWorship/goldWorship/rmbWorship/reqWorshReward:1505-1600）。
## 一期核心闭环（2026-09-19 用户拍板）：列表/查找/创建/加入/退出/主页/膜拜/公会商店。
## 单机化大幅简化：免审批即入（verify 型公会也直接进，受控偏离）、成员管理只读、
## 无分配队列/插队/流拍；聊天与日志永久裁剪（feature_catalog SKIPPED 保留）。
## 错误返回中文串（View 层直接 Toast，对齐源 showToast 语义）。

const CREATE_COST: int = 500              # 创建花费（源 _list._create_cost=500 钻）
const MAX_NAME_LEN: int = 10              # 公会名上限（源 guild.lua:23 + LSTR 超长文案）
const MAX_MEMBER_CNT: int = 50            # 源 guildconfig maxGuildMember
const SELF_GUILD_ID: int = 10001          # 自建会 id 基值（源 _create 写 _id=10001）
const PLAYER_ACTIVE: int = 100            # 玩家成员活跃（源 makePlayerMember _active=100）
const WORSHIP_LEVEL_DIF: int = 1          # 膜拜对象需等级 ≥ 自己+1（源 worshipLevelDif；LSTR 文案写"5级"是历史残留）
const JOIN_TYPE_FREE: String = "no_verify"
const JOIN_TYPE_VERIFY: String = "verify"
const JOB_CHAIRMAN: String = "chairman"
const JOB_ELDER: String = "elder"
const JOB_MEMBER: String = "member"
const WORSHIP_TABLE: StringName = &"GuildWorship"
const VIP_TABLE: StringName = &"VIP"
const VIP_FIELD_WORSHIP_TIMES: String = "Worship Times"
const VIP_FIELD_DIAMOND_WORSHIP: String = "Diamond Worship"
# 公会币产出（受控偏离）：源=副本通关 30 币/次（guildCoinCount），一期无副本 → 膜拜领取时按档附币，
# 日量级对齐源上限（源 maxGetGuildCoinTime=3 次/日 ×30 币）。见验收记录。
const GUILDPOINT_PER_WORSHIP: Dictionary = {1: 10, 2: 15, 3: 25}
const ACTIVE_RAND_MIN: int = 10           # NPC 成员活跃随机区间（源 math.random(10,100)）
const ACTIVE_RAND_MAX: int = 100
const LOGIN_OFFSET_RAND_MAX: int = 3600   # NPC 上次登录距今秒数上限（源 math.random(0,3600)）
const INSTANCE_TIMES_RAND_MAX: int = 5    # NPC 副本参与次数上限（源 math.random(0,5)）
const DAY_KEY_YEAR_WEIGHT: int = 10000    # 本地日 key 权重（照 PlayerData._day_key/vitality_manager 范式）
const DAY_KEY_MONTH_WEIGHT: int = 100
const DAY_KEY_DAY_WEIGHT: int = 100
const SECONDS_PER_MINUTE: int = 60

# NPC 公会（源 guild_npc_guilds 五个，member_cnt 不含玩家）。
const NPC_GUILDS: Array[Dictionary] = [
	{"id": 10001, "name": "英雄殿堂", "avatar": 1, "slogan": "共同战斗，共创辉煌！", "member_cnt": 9, "join_type": JOIN_TYPE_FREE, "join_limit": 30},
	{"id": 10002, "name": "暗影军团", "avatar": 143, "slogan": "黑暗中前行", "member_cnt": 15, "join_type": JOIN_TYPE_FREE, "join_limit": 32},
	{"id": 10003, "name": "龙骑联盟", "avatar": 147, "slogan": "龙之力量", "member_cnt": 22, "join_type": JOIN_TYPE_VERIFY, "join_limit": 35},
	{"id": 10004, "name": "风暴之翼", "avatar": 150, "slogan": "自由翱翔", "member_cnt": 18, "join_type": JOIN_TYPE_FREE, "join_limit": 30},
	{"id": 10005, "name": "圣光骑士团", "avatar": 155, "slogan": "光明永存", "member_cnt": 30, "join_type": JOIN_TYPE_VERIFY, "join_limit": 40},
]

# NPC 成员（源 guild_npc_members 八个；玩家入会后自任 chairman，照源 makePlayerMember）。
const NPC_MEMBERS: Array[Dictionary] = [
	{"uid": 9001, "name": "亚历山大", "avatar": 10, "level": 90, "vip": 10, "job": JOB_ELDER},
	{"uid": 9002, "name": "贝奥武夫", "avatar": 15, "level": 85, "vip": 8, "job": JOB_MEMBER},
	{"uid": 9003, "name": "克里斯蒂娜", "avatar": 20, "level": 82, "vip": 7, "job": JOB_MEMBER},
	{"uid": 9004, "name": "达芙妮", "avatar": 5, "level": 78, "vip": 5, "job": JOB_MEMBER},
	{"uid": 9005, "name": "埃里克", "avatar": 30, "level": 75, "vip": 3, "job": JOB_MEMBER},
	{"uid": 9006, "name": "菲奥娜", "avatar": 25, "level": 72, "vip": 2, "job": JOB_MEMBER},
	{"uid": 9007, "name": "加雷斯", "avatar": 35, "level": 88, "vip": 9, "job": JOB_MEMBER},
	{"uid": 9008, "name": "海伦娜", "avatar": 40, "level": 80, "vip": 6, "job": JOB_MEMBER},
]

var cm: Variant = null


func _init(p_cm: Variant = null) -> void:
	cm = p_cm


# ── 公会列表 / 查找 / 创建 / 加入 / 退出 ──────────────────────────────

func get_guild_list() -> Array:
	return NPC_GUILDS.duplicate(true)


func search_guild(guild_id: int) -> Dictionary:
	for g in NPC_GUILDS:
		if int(g["id"]) == guild_id:
			return g.duplicate(true)
	return {}


func create_guild(pd: PlayerData, guild_name: String, avatar: int) -> Dictionary:
	if pd.guild_data.is_in_guild():
		return _err("已在公会中")
	if guild_name.strip_edges().is_empty():
		return _err("公会名称不能为空")
	if guild_name.length() > MAX_NAME_LEN:
		return _err("公会名称不得超过10个字")
	if pd.diamond < CREATE_COST:
		return _err("钻石不足")
	pd.spend_diamond(CREATE_COST)
	# 自建会沿用 10001 基值（源 _create 写 _id=10001 同款）；玩家自任 chairman。
	pd.guild_data.setup_guild(SELF_GUILD_ID, guild_name, maxi(avatar, 1), GuildData.DEFAULT_CREATE_SLOGAN)
	return {"ok": true, "err": ""}


func join_guild(pd: PlayerData, guild_id: int) -> Dictionary:
	if pd.guild_data.is_in_guild():
		return _err("已在公会中")
	var g: Dictionary = search_guild(guild_id)
	if g.is_empty():
		return _err("没有查找到公会")
	# 单机化大幅简化：verify 型也即入（源 join_confirm 审批流裁剪，受控偏离）。
	pd.guild_data.setup_guild(guild_id, String(g["name"]), int(g["avatar"]), String(g["slogan"]))
	return {"ok": true, "err": ""}


## 退出/解散合一（源 _leave/_dismiss 同为清 _user_guild；玩家恒 chairman，语义即解散）。
func leave_guild(pd: PlayerData) -> Dictionary:
	if not pd.guild_data.is_in_guild():
		return _err("尚未加入公会")
	pd.guild_data.reset_to_no_guild()
	return {"ok": true, "err": ""}


func set_slogan(pd: PlayerData, new_slogan: String) -> Dictionary:
	if not pd.guild_data.is_in_guild():
		return _err("尚未加入公会")
	pd.guild_data.slogan = new_slogan
	return {"ok": true, "err": ""}


# ── 公会主页信息组装 ──────────────────────────────────────────────

## 成员列表 = 玩家（chairman，照源 makePlayerMember）+ 8 NPC（active/last_login 随机注入可测）。
## last_login 存绝对时间戳（now-rand(0,3600)，源 os.time()-math.random(0,3600) 直译；
## View 用 now-last_login 算"今日 HH:MM/N天前"描述）。
func get_guild_info(pd: PlayerData, rng: BattleRng, now: int) -> Dictionary:
	var members: Array = []
	members.append(_player_member(pd))
	for npc in NPC_MEMBERS:
		members.append({
			"uid": int(npc["uid"]), "job": String(npc["job"]),
			"active": rng.randi_range(ACTIVE_RAND_MIN, ACTIVE_RAND_MAX),
			"last_login": now - rng.randi_range(0, LOGIN_OFFSET_RAND_MAX),
			"join_instance_time": rng.randi_range(0, INSTANCE_TIMES_RAND_MAX),
			"name": String(npc["name"]), "level": int(npc["level"]),
			"avatar": int(npc["avatar"]), "vip": int(npc["vip"]),
		})
	return {
		"summary": {
			"id": pd.guild_data.guild_id, "name": pd.guild_data.guild_name,
			"avatar": pd.guild_data.guild_avatar, "slogan": pd.guild_data.slogan,
			"member_cnt": members.size(),
		},
		"members": members,
		"vitality": pd.guild_data.vitality,
		"self_vitality": pd.guild_data.self_vitality,
	}


func _player_member(pd: PlayerData) -> Dictionary:
	return {
		"uid": 1, "job": JOB_CHAIRMAN, "active": PLAYER_ACTIVE, "last_login": 0, "join_instance_time": 0,
		"name": pd.player_name, "level": pd.team_level, "avatar": pd.avatar, "vip": pd.vip_level,
	}


## 膜拜对象资格：等级 ≥ 自己 + worshipLevelDif 的 NPC（源 guild.lua:257 成员行膜拜按钮显隐）。
func can_worship_member(member: Dictionary, player_level: int) -> bool:
	return int(member.get("level", 0)) >= player_level + WORSHIP_LEVEL_DIF


# ── 膜拜（三档，GuildWorship 表驱动）────────────────────────────────

## 膜拜次数信息（VIP 表 Worship Times 为上限；跨日惰性清零，源服务器日重置的单机化）。
func get_worship_times_info(pd: PlayerData, now: int) -> Dictionary:
	_check_worship_daily_reset(pd, now)
	var max_times: int = int(VipData.get_vip_field(pd.vip_level, VIP_FIELD_WORSHIP_TIMES, cm))
	return {"used": pd.guild_data.worship_use_times, "max": max_times,
			"left": maxi(max_times - pd.guild_data.worship_use_times, 0)}


## 三档展示数据（View 膜拜弹窗 fill 用；锁档=钻石档需 VIP "Diamond Worship" 门槛，源 getMinDiamondWorshipLevel）。
func get_worship_options(pd: PlayerData) -> Array:
	var table: Dictionary = cm.get_raw_table(WORSHIP_TABLE)
	var options: Array = []
	var worship_id: int = 1
	while table.has(str(worship_id)):
		var row: Dictionary = table[str(worship_id)]
		var locked: bool = false
		var price_type: String = String(row.get("Price Type", ""))
		if price_type == "Diamond":
			locked = pd.vip_level < _min_diamond_worship_vip()
		options.append({
			"worship_id": worship_id,
			"consume": bool(row.get("Consume", false)),
			"price_amount": int(row.get("Price Amount", 0)),
			"price_type": price_type,
			"gold": int(row.get("Reward Amount", 0)),
			"vitality": int(row.get("Get Vitality", 0)),
			"guildpoint": int(GUILDPOINT_PER_WORSHIP.get(worship_id, 0)),
			"locked": locked,
		})
		worship_id += 1
	return options


## 膜拜执行：校验链（在会→档位存在→对象资格→次数→消耗）全过 → 扣消耗 + 挂起奖励 + 活跃贡献。
func worship(pd: PlayerData, member_uid: int, worship_id: int, now: int) -> Dictionary:
	if not pd.guild_data.is_in_guild():
		return _err("尚未加入公会")
	var table: Dictionary = cm.get_raw_table(WORSHIP_TABLE)
	if not table.has(str(worship_id)):
		return _err("膜拜档位不存在")
	var member: Dictionary = _find_npc_member(member_uid)
	if member.is_empty() or not can_worship_member(member, pd.team_level):
		return _err("只能膜拜等级高于自己的成员")
	_check_worship_daily_reset(pd, now)
	var max_times: int = int(VipData.get_vip_field(pd.vip_level, VIP_FIELD_WORSHIP_TIMES, cm))
	if pd.guild_data.worship_use_times >= max_times:
		return _err("今日膜拜次数已用完")
	var row: Dictionary = table[str(worship_id)]
	var price_type: String = String(row.get("Price Type", ""))
	var price_amount: int = int(row.get("Price Amount", 0))
	if price_type == "Gold":
		if pd.hero_manager.gold < price_amount:
			return _err("金币不足")
		pd.add_point("gold", -price_amount)
	elif price_type == "Diamond":
		if pd.vip_level < _min_diamond_worship_vip():
			return _err("VIP等级达到%d级解锁" % _min_diamond_worship_vip())
		if pd.diamond < price_amount:
			return _err("钻石不足")
		pd.spend_diamond(price_amount)
	# 奖励挂起（源 _worship_req 后 worshipTag 亮 → reqWorshReward 二次领取）；活跃贡献按档同步累计。
	var vitality_gain: int = int(row.get("Get Vitality", 0))
	pd.guild_data.worship_pending.append({
		"worship_id": worship_id,
		"gold": int(row.get("Reward Amount", 0)),
		"vitality": vitality_gain,
		"guildpoint": int(GUILDPOINT_PER_WORSHIP.get(worship_id, 0)),
	})
	pd.guild_data.worship_use_times += 1
	pd.guild_data.self_vitality += vitality_gain
	pd.guild_data.vitality += vitality_gain
	return {"ok": true, "err": ""}


## 领取挂起奖励（源 _worship_withdraw 一次领全部）：金币+体力（clamp 上限）+公会币。
func worship_withdraw(pd: PlayerData) -> Dictionary:
	if pd.guild_data.worship_pending.is_empty():
		return {"ok": false, "err": "当前没有可领取的奖励", "rewards": {}}
	var gold: int = 0
	var vitality: int = 0
	var guildpoint: int = 0
	for p in pd.guild_data.worship_pending:
		gold += int(p.get("gold", 0))
		vitality += int(p.get("vitality", 0))
		guildpoint += int(p.get("guildpoint", 0))
	pd.guild_data.worship_pending.clear()
	pd.add_point("gold", gold)
	pd.add_point("guildpoint", guildpoint)
	pd.vitality = min(pd.vitality + vitality, pd.vitality_max)
	return {"ok": true, "err": "", "rewards": {"gold": gold, "vitality": vitality, "guildpoint": guildpoint}}


func has_pending_worship_reward(pd: PlayerData) -> bool:
	return not pd.guild_data.worship_pending.is_empty()


# ── 内部 ──────────────────────────────────────────────────────────

func _find_npc_member(uid: int) -> Dictionary:
	for npc in NPC_MEMBERS:
		if int(npc["uid"]) == uid:
			return npc
	return {}


## 钻石膜拜最低 VIP（源 guild.lua:117-123 扫 VIP 表首个 "Diamond Worship"==true 的等级）。
func _min_diamond_worship_vip() -> int:
	var vt: Dictionary = cm.get_raw_table(VIP_TABLE)
	var index: int = 0
	while vt.has(str(index)):
		var value: Variant = vt[str(index)].get(VIP_FIELD_DIAMOND_WORSHIP, null)
		if value == true:
			return index
		index += 1
	return index


## 膜拜次数跨日惰性清零（本地日 key 对照，照 PlayerData.check_stage_limit_daily_reset 范式）。
func _check_worship_daily_reset(pd: PlayerData, now: int) -> void:
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(now + off_min * SECONDS_PER_MINUTE)
	var day: int = int(dt["year"]) * DAY_KEY_YEAR_WEIGHT + int(dt["month"]) * DAY_KEY_MONTH_WEIGHT + int(dt["day"])
	if pd.guild_data.worship_day == day:
		return
	pd.guild_data.worship_day = day
	pd.guild_data.worship_use_times = 0


static func _err(msg: String) -> Dictionary:
	return {"ok": false, "err": msg}
