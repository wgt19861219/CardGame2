class_name GuildData
extends RefCounted

## 公会持久化状态（Data 层）— 源 player._user_guild{id,name} + 膜拜/活跃状态的单机化落档。
## 一期核心闭环（2026-09-19 用户拍板）：入会/主页/膜拜/公会商店；副本二期、佣兵营三期。
## 单机化大幅简化：免审批即入、无分配队列；公会聊天/日志永久裁剪（feature_catalog SKIPPED）。

const NO_GUILD_ID: int = 0            # 未入会（源 _user_guild._id == 0 语义）
const NPC_GUILD_BASE_VITALITY: int = 5000   # 入会初始活跃（源 local_server makeGuildInfo _vitality=5000）
const DEFAULT_CREATE_SLOGAN: String = "共同战斗，共创辉煌！"   # 源 NPC 公会默认宣言

# guild_id：0=未入会；NPC 会 10001-10005（源 guild_npc_guilds）；自建会沿用 10001 基值（源 _create 同款）。
var guild_id: int = NO_GUILD_ID
var guild_name: String = ""
var guild_avatar: int = 1
var slogan: String = ""
var vitality: int = 0             # 公会活跃（膜拜累积；源恒 5000 假值，单机化为可成长持久值）
var self_vitality: int = 0        # 我对公会的活跃贡献累计（源 _self_vitality）
var worship_use_times: int = 0    # 今日已膜拜次数（上限查 VIP 表 "Worship Times"）
var worship_day: int = 0          # 膜拜次数日锚（本地日 key，跨日清零；照 PlayerData._day_key 范式）
var worship_pending: Array = []   # 挂起未领奖励条目 {worship_id, gold, vitality, guildpoint}（源 _worship 二次领取）


func is_in_guild() -> bool:
	return guild_id != NO_GUILD_ID


func reset_to_no_guild() -> void:
	guild_id = NO_GUILD_ID
	guild_name = ""
	guild_avatar = 1
	slogan = ""
	vitality = 0
	self_vitality = 0
	worship_use_times = 0
	worship_day = 0
	worship_pending.clear()


## 入会/建会初始化（活跃取 NPC 基值，源服务器假值 5000 的可成长单机化）。
func setup_guild(p_id: int, p_name: String, p_avatar: int, p_slogan: String) -> void:
	guild_id = p_id
	guild_name = p_name
	guild_avatar = p_avatar
	slogan = p_slogan
	vitality = NPC_GUILD_BASE_VITALITY
	self_vitality = 0


func to_dict() -> Dictionary:
	var pending: Array = []
	for p in worship_pending:
		if p is Dictionary:
			pending.append((p as Dictionary).duplicate(true))
	return {
		"guild_id": guild_id,
		"guild_name": guild_name,
		"guild_avatar": guild_avatar,
		"slogan": slogan,
		"vitality": vitality,
		"self_vitality": self_vitality,
		"worship_use_times": worship_use_times,
		"worship_day": worship_day,
		"worship_pending": pending,
	}


## 旧档无 guild_data 键 → 全默认（未入会）。入口统一 int/String 校验（治 JSON float→int）。
static func from_dict(data: Dictionary) -> GuildData:
	var gd := GuildData.new()
	gd.guild_id = int(data.get("guild_id", NO_GUILD_ID))
	gd.guild_name = String(data.get("guild_name", ""))
	gd.guild_avatar = int(data.get("guild_avatar", 1))
	gd.slogan = String(data.get("slogan", ""))
	gd.vitality = int(data.get("vitality", 0))
	gd.self_vitality = int(data.get("self_vitality", 0))
	gd.worship_use_times = int(data.get("worship_use_times", 0))
	gd.worship_day = int(data.get("worship_day", 0))
	var pending_raw: Variant = data.get("worship_pending", [])
	if pending_raw is Array:
		for p in (pending_raw as Array):
			if p is Dictionary:
				var entry: Dictionary = (p as Dictionary)
				gd.worship_pending.append({
					"worship_id": int(entry.get("worship_id", 0)),
					"gold": int(entry.get("gold", 0)),
					"vitality": int(entry.get("vitality", 0)),
					"guildpoint": int(entry.get("guildpoint", 0)),
				})
	return gd
