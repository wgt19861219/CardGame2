class_name FeatureCatalog
extends RefCounted

## 功能清单（盘点自源 local_server.lua 的 71 个 M.handlers.* 命令）。
## 作玩法模块的校验基准：每个非 SKIPPED handler 应对应一个实现，缺失即功能遗漏。
## 源 71 = 非 SKIPPED 51（DOMAINS 登记）+ SKIPPED 20（单机裁剪：社交/付费/SDK/活动/上报）。
## 单机化是唯一允许的偏差（复刻铁律）：联机/付费/时效活动 handler 归 SKIPPED_HANDLERS。
## 注：ladder/top_arena/query_ranklist 源为单机 NPC 假榜（AI_NAMES 生成），归 DOMAINS 不裁剪。
## 注：cdkey_gift（源 :3984 恒 success 无校验）/ system_setting（源 :2202 空响应）/ get_svr_time（源 :612 返本地时间戳）——源本身就是空 stub 或本地数据，单机版天然等价，不单独实现。

# 域 → handler 命令名（盘点自 local_server.lua，单机版需实现的 51 个）
const DOMAINS: Dictionary = {
	"battle": ["enter_stage", "exit_stage", "enter_act_stage", "sweep_stage", "reset_elite", "tbc", "ladder", "top_arena", "excavate"],
	"hero": ["hero_upgrade", "hero_evolve", "consume_item", "skill_levelup", "buy_skill_stren_point", "sync_skill_stren", "split_hero", "query_split_data", "query_split_return"],
	"equip": ["wear_equip", "equip_synthesis", "hero_equip_upgrade", "fragment_compose", "sell_item"],
	"gacha": ["tavern_draw", "ask_magicsoul"],
	"economy": ["sync_vitality", "buy_vitality", "midas", "query_data"],
	"shop": ["shop_refresh", "shop_consume", "shop_star_consume", "open_shop"],
	"mail": ["get_maillist", "read_mail"],
	"task": ["trigger_task", "require_rewards", "trigger_job", "job_rewards"],
	"tutorial": ["tutorial"],
	"player": ["login", "get_svr_time", "set_name", "set_avatar", "system_setting", "query_ranklist", "gm_cmd", "ask_daily_login", "cdkey_gift", "chapter_star_reward", "query_replay"],
}

# 单机版裁剪的 20 个 handler（联机社交/付费/SDK 登录/时效活动/暂停上报）
const SKIPPED_HANDLERS: Array[String] = [
	# 社交
	"chat", "guild", "request_guild_log",
	# 付费
	"charge", "recharge_rebate", "continue_pay",
	# SDK 登录 / 切服（单机用 login）
	"sdk_login", "change_server",
	# VIP（源已移除，保留空 handler）
	"get_vip_gift",
	# 时效活动 / 推广
	"worldcup", "fb_attention", "activity_info", "activity_lotto_info",
	"activity_lotto_reward", "activity_bigpackage_info", "activity_bigpackage_reward",
	"activity_bigpackage_reset", "ask_activity_info", "every_day_happy",
	# 暂停上报（客户端→服务端，单机无意义）
	"suspend_report",
]

# 重命名映射：源 handler 名 → 本项目复刻方法名
const RENAMED: Dictionary = {
	"skill_levelup": "upgrade_skill_level",  # 源 :1327 → hero_manager.upgrade_skill_level
}

# handler → 实现位置映射（catalog_check 校验方法存在性，防"只登记不实现"潜伏）。
# 格式 "Class.method"（精确）或 "Class（说明）"（逻辑分散/源 stub）。
const IMPLEMENTATIONS: Dictionary = {
	"enter_stage": "StageManager.enter_stage", "exit_stage": "StageManager.exit_stage",
	"enter_act_stage": "StageManager.enter_act_stage", "sweep_stage": "StageManager.sweep",
	"reset_elite": "StageManager", "tbc": "CrusadeManager", "ladder": "LadderManager",
	"top_arena": "RanklistManager", "excavate": "ExcavateManager",
	"hero_upgrade": "HeroManager.upgrade_rank", "hero_evolve": "HeroManager.hero_evolve",
	"consume_item": "EatexpPanel.do_eat_hero",  # 源 :991 喂经验（解码itemBits+查Equip.Exp缺省60+hero.addExp），非 add_item（加物品）。单机化 View 承载：do_eat_hero=pd.remove_item+HeroManager.add_hero_exp
	"skill_levelup": "HeroManager.upgrade_skill_level",
	"buy_skill_stren_point": "PlayerData.buy_skill_stren_point", "sync_skill_stren": "PlayerData",
	"split_hero": "HeroManager.split", "query_split_data": "HeroManager", "query_split_return": "HeroManager",
	"wear_equip": "HeroManager.wear_equip", "equip_synthesis": "EquipCraftManager.synthesize_equip",
	"hero_equip_upgrade": "PlayerData.enhance_equip", "fragment_compose": "HeroManager.compose",
	"sell_item": "PlayerData.sell_equip",
	"tavern_draw": "PlayerData.draw_tavern_full", "ask_magicsoul": "TavernData",
	"sync_vitality": "VitalityManager.recover", "buy_vitality": "VitalityManager.buy",
	"midas": "MidasManager.exchange", "query_data": "PlayerData",
	"shop_refresh": "ShopManager.refresh", "shop_consume": "ShopManager.buy",
	"shop_star_consume": "ShopManager", "open_shop": "ShopManager",
	"get_maillist": "MailData", "read_mail": "MailData",
	"trigger_task": "TaskManager.trigger_task", "require_rewards": "TaskManager.claim_task_reward",
	"trigger_job": "TaskManager.record_dailyjob_progress", "job_rewards": "TaskManager.claim_job_reward",
	"tutorial": "TutorialManager",
	"login": "PlayerDataSerde", "get_svr_time": "stub", "set_name": "PlayerData",
	"set_avatar": "PlayerData", "system_setting": "stub", "query_ranklist": "RanklistManager",
	"gm_cmd": "PlayerData", "ask_daily_login": "DailyLoginManager",
	"cdkey_gift": "stub", "chapter_star_reward": "StageManager.claim_chapter_star_reward",
	"query_replay": "stub",
}

func get_domains() -> Array:
	return DOMAINS.keys()

func get_handlers(domain: String) -> Array:
	return DOMAINS.get(domain, [])

func get_all_handlers() -> Array:
	var all: Array = []
	for domain in DOMAINS:
		all += DOMAINS[domain]
	return all

func get_skipped() -> Array:
	return SKIPPED_HANDLERS.duplicate()

func handler_count() -> int:
	return get_all_handlers().size()

func skipped_count() -> int:
	return SKIPPED_HANDLERS.size()

func total_source_count() -> int:
	# 源 local_server.lua 的 M.handlers.* 总数（校验 51 + 20 == 71）
	return handler_count() + skipped_count()

func has_handler(handler: String) -> bool:
	return get_all_handlers().has(handler)

func is_skipped(handler: String) -> bool:
	return SKIPPED_HANDLERS.has(handler)
