class_name LadderDailyReward
extends RefCounted

## 竞技场每日排名奖励（Logic 层工具，2026-09-17 经济单机优化接入）。
## 源为服务器每日按排名结算下发（表 PVPRankReward 35 档，此前无代码消费方=死表，
## 钻石经济每日循环产出缺失的根修）；单机化按昨日 rank 发系统邮件（源即邮件渠道，走 MailData）。
## 自 LadderManager 下沉独立控行数（照 StageChapterReward 先例）。

const REWARD_SLOT_MAX: int = 10
const MAIL_FROM: String = "竞技场"
const MAIL_TITLE: String = "竞技场每日奖励"
# PVPRankReward 服务端口径 Reward Type → 邮件 raw 附件槽（Item 例外进 _items）。
const COIN_SLOT_MAP: Dictionary = {
	"Gold": "money",
	"Diamond": "diamonds",
	"SkillPoint": "skill_point",
}
const POINT_SLOT_MAP: Dictionary = {
	"ArenaPoint": "arenapoint",
	"CrusadePoint": "crusadepoint",
	"GuildPoint": "guildpoint",
	"DungeonPoint": "dungeonpoint",
}
const SLOT_TYPE_PREFIX: String = "Reward Type "
const SLOT_ID_PREFIX: String = "Reward ID "
const SLOT_AMOUNT_PREFIX: String = "Reward Amount "
const SECONDS_PER_MINUTE: int = 60
const DATE_FORMAT: String = "%04d-%02d-%02d"


## rank → 奖励表行（Floor Rank 升序区段下限：rank ∈ [Floor N, Floor N+1) 用行 N；
## 超末档取末行）。表空返 {}（调用方跳过发信）。
static func reward_row(rank: int, cm: ConfigManager) -> Dictionary:
	var table: Dictionary = cm.get_raw_table(&"PVPRankReward")
	if table.is_empty():
		return {}
	var rows: Array = []
	for key in table:
		rows.append(table[key])
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("Floor Rank", 0)) < int(b.get("Floor Rank", 0)))
	var picked: Dictionary = rows[0]
	for row in rows:
		if int(row.get("Floor Rank", 0)) <= rank:
			picked = row
		else:
			break
	return picked


## 按排名生成 raw mail（照 MailData raw 格式；奖励槽 1-10 按 Reward Type 分发附件槽）。
## 表空返 {}；正文含排名便于玩家对账。
static func build_mail(rank: int, mail_id: int, cm: ConfigManager, now: int) -> Dictionary:
	var row: Dictionary = reward_row(rank, cm)
	if row.is_empty():
		return {}
	var mail: Dictionary = {
		"_id": mail_id,
		"_status": "unread",
		"_date": _date_str(now),
		"_content": {"_plain_mail": {
			"_from": MAIL_FROM,
			"_title": MAIL_TITLE,
			"_content": "你在竞技场的每日排名已结算（第 %d 名），附件是奖励，请查收！" % rank,
		}},
		"_money": 0,
		"_diamonds": 0,
		"_skill_point": 0,
		"_points": {},
		"_items": [],
	}
	for i in range(1, REWARD_SLOT_MAX + 1):
		var suffix: String = str(i)
		var rtype: String = String(row.get(SLOT_TYPE_PREFIX + suffix, ""))
		var amount: int = int(row.get(SLOT_AMOUNT_PREFIX + suffix, 0))
		if rtype == "" or amount <= 0:
			continue
		if COIN_SLOT_MAP.has(rtype):
			var coin_key: String = "_" + String(COIN_SLOT_MAP[rtype])
			mail[coin_key] = int(mail[coin_key]) + amount
		elif POINT_SLOT_MAP.has(rtype):
			var point_key: String = String(POINT_SLOT_MAP[rtype])
			(mail["_points"] as Dictionary)[point_key] = int((mail["_points"] as Dictionary).get(point_key, 0)) + amount
		elif rtype == "Item":
			var rid: int = int(row.get(SLOT_ID_PREFIX + suffix, 0))
			if rid > 0:
				(mail["_items"] as Array).append({"id": rid, "amount": amount})
	return mail


## 本地日期字符串 YYYY-MM-DD（与各系统 _local_day_key 同时区口径）。
static func _date_str(now: int) -> String:
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(now + off_min * SECONDS_PER_MINUTE)
	return DATE_FORMAT % [int(dt["year"]), int(dt["month"]), int(dt["day"])]
