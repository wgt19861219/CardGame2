class_name PlayerDataSerde
extends RefCounted

## PlayerData 存档序列化（Data 层 mixin）— 从 PlayerData 拆出控 ≤250 行。
## static 方法第一参 pd（PlayerData 实例），照 battle mixin 范式。
## 入口统一 int 校验（存档/外部数据可能含 float，强制 int）。


## 序列化到字典（存档用）。主类 to_dict 转发本方法。
static func to_dict(pd: PlayerData) -> Dictionary:
	return {
		"diamond": pd.diamond,
		"crusade_point": pd.crusade_point,
		"guildpoint": pd.guildpoint,
		"arena_point": pd.arena_point,
		"dungeonpoint": pd.dungeonpoint,
		"items": pd.items.duplicate(true),
		"vitality": pd.vitality,
		"vitality_max": pd.vitality_max,
		"vitality_last_recover": pd.vitality_last_recover,
		"vitality_today_buy": pd.vitality_today_buy,
		"vitality_buy_day": pd.vitality_buy_day,
		"team_level": pd.team_level,
		"team_exp": pd.team_exp,
		"vip_level": pd.vip_level,
		"skill_points": pd.skill_points,
		"skill_reset_times": pd.skill_reset_times,
		"skill_cd_time": pd.skill_cd_time,
		"skill_last_reset_date": pd.skill_last_reset_date,
		"player_name": pd.player_name,
		"avatar": pd.avatar,
		"team": pd.team,
		"hero_manager": pd.hero_manager.to_dict(),
		"crusade_manager": pd.crusade_manager.to_dict(),
		"tutorial_manager": pd.tutorial_manager.to_dict(),
		"task_manager": pd.task_manager.to_dict(),
		"daily_login": pd.daily_login.to_dict(),
		"midas": pd.midas.to_dict(),
		"stage_manager": pd.stage_manager.to_dict(),
		"handbook": pd.handbook.to_dict(),
		"mailbox": pd.mailbox.to_dict(),
		"tutorial_records": pd.tutorial_records.duplicate(true), "tavern_record": pd.tavern_record.duplicate(true),
		"excavate": pd.excavate.to_dict(),
		"ladder": pd.ladder.to_dict(),
		"guild_data": pd.guild_data.to_dict(),
		"shop_auto_refresh": pd.shop_auto_refresh.duplicate(true),
		"shop_expire_end": pd.shop_expire_end.duplicate(true),
		"stage_limit": pd.stage_limit.duplicate(true),
		"stage_limit_day": pd.stage_limit_day,
		"stage_reset_times": pd.stage_reset_times.duplicate(true),
	}


## 从字典重建。入口统一 int 校验（存档/外部数据可能含 float，强制 int）。
static func from_dict(data: Dictionary, cm: ConfigManager) -> PlayerData:
	var pd := PlayerData.new(cm)
	pd.diamond = int(data.get("diamond", 0))
	pd.crusade_point = int(data.get("crusade_point", 0))
	pd.guildpoint = int(data.get("guildpoint", 0))
	# arena_point 统一归 PlayerData（源 player.arenapoint）；旧存档 ladder.arenapoint fallback 迁移
	# P2-2026-07-10：is Dictionary 守卫（as Dictionary 对损坏存档返 null → .get 崩溃）
	var ladder_raw: Variant = data.get("ladder", {})
	pd.arena_point = int(data.get("arena_point", int(ladder_raw.get("arenapoint", 0)) if ladder_raw is Dictionary else 0))
	pd.dungeonpoint = int(data.get("dungeonpoint", 0))
	var items_data: Dictionary = data.get("items", {})
	pd.items.clear()
	for k in items_data:
		pd.items[int(k)] = int(items_data[k])
	pd.vitality = int(data.get("vitality", 0))
	pd.vitality_max = int(data.get("vitality_max", PlayerData.VITALITY_DEFAULT_MAX))
	# 恢复接线（2026-09-17）前老档时间戳恒 0：补当前时间，防 recover 首调 elapsed 巨大一次性回满。
	pd.vitality_last_recover = int(data.get("vitality_last_recover", 0))
	if pd.vitality_last_recover <= 0:
		pd.vitality_last_recover = int(Time.get_unix_time_from_system())
	pd.vitality_today_buy = int(data.get("vitality_today_buy", 0))
	pd.vitality_buy_day = int(data.get("vitality_buy_day", 0))
	pd.team_level = int(data.get("team_level", 1))
	pd.team_exp = int(data.get("team_exp", 0))
	pd.vip_level = int(data.get("vip_level", 0))
	pd.skill_points = int(data.get("skill_points", PlayerData.SKILL_DEFAULT_POINTS))
	pd.skill_reset_times = int(data.get("skill_reset_times", 0))
	pd.skill_cd_time = int(data.get("skill_cd_time", 0))
	pd.skill_last_reset_date = int(data.get("skill_last_reset_date", 0))
	pd.player_name = String(data.get("player_name", "Player"))
	pd.avatar = int(data.get("avatar", 0))
	var team_arr: Array = data.get("team", [])
	pd.team.clear()
	for inst_id in team_arr:
		pd.team.append(int(inst_id))
	var hm_data: Dictionary = data.get("hero_manager", {})
	pd.hero_manager = HeroManager.from_dict(hm_data, cm)
	pd.hero_manager.items = pd.items   # 碎片/魂石单账本（源 equip_qunty；_init 注入随换实例失效需重注入）
	# 旧档迁移（2026-09-09 前 fragments 独立容器）：并入 items 单账本。相加——两侧
	# 获得路径互斥（重复英雄碎魂/分解写 fragments，抽卡魂石/GM 写 items），无重复计数。
	var legacy_frags: Variant = hm_data.get("fragments", {})
	if legacy_frags is Dictionary:
		for frag_id in (legacy_frags as Dictionary):
			var fid := int(frag_id)
			pd.items[fid] = int(pd.items.get(fid, 0)) + int((legacy_frags as Dictionary)[frag_id])
	var cd_data: Dictionary = data.get("crusade_manager", {})
	pd.crusade_manager = CrusadeManager.from_dict(cd_data, cm)
	var td_data: Dictionary = data.get("tutorial_manager", {})
	pd.tutorial_manager = TutorialManager.from_dict(td_data)
	pd.task_manager = TaskManager.from_dict(data.get("task_manager", {}))
	pd.daily_login = DailyLoginManager.from_dict(data.get("daily_login", {}))
	pd.midas = MidasManager.from_dict(data.get("midas", {}), cm)
	pd.stage_manager = StageManager.from_dict(data.get("stage_manager", {}), cm)
	pd.handbook = HandbookManager.from_dict(data.get("handbook", {}))
	pd.mailbox = MailData.from_dict(data.get("mailbox", {}))
	var tr_data: Dictionary = data.get("tutorial_records", {}); pd.tutorial_records.clear()
	for k in tr_data:
		pd.tutorial_records[int(k)] = int(tr_data[k])
	var tv_data: Dictionary = data.get("tavern_record", {})
	# P2-2026-07-10：is Dictionary 守卫（损坏存档非 Dictionary 值 → as 返 null → .duplicate 崩溃）
	for k in tv_data:
		var tv_val: Variant = tv_data[k]
		if tv_val is Dictionary:
			pd.tavern_record[k] = (tv_val as Dictionary).duplicate(true)
	var ex_data: Dictionary = data.get("excavate", {})
	pd.excavate = ExcavateManager.from_dict(ex_data, cm)
	pd.ladder = LadderManager.new()
	# P2-2026-07-10：损坏存档守卫（ladder 非 Dictionary 时跳过 from_dict 避类型不匹配崩溃）
	if ladder_raw is Dictionary:
		pd.ladder.from_dict(ladder_raw)
	var guild_raw: Variant = data.get("guild_data", {})
	if guild_raw is Dictionary:
		pd.guild_data = GuildData.from_dict(guild_raw)
	var sar_data: Dictionary = data.get("shop_auto_refresh", {})
	for k in sar_data: pd.shop_auto_refresh[int(k)] = int(sar_data[k])
	var see_data: Dictionary = data.get("shop_expire_end", {})
	for k in see_data: pd.shop_expire_end[int(k)] = int(see_data[k])
	var sl_data: Dictionary = data.get("stage_limit", {})
	for k in sl_data: pd.stage_limit[int(k)] = int(sl_data[k])
	pd.stage_limit_day = int(data.get("stage_limit_day", 0))
	var srt_data: Dictionary = data.get("stage_reset_times", {})
	for k in srt_data: pd.stage_reset_times[int(k)] = int(srt_data[k])
	pd.recalc_vitality_max()   # 上限按等级重算（2026-09-17 接线：老档恒 120 的存量失真矫正）
	return pd
