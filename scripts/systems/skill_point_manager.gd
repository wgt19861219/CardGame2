class_name SkillPointManager
extends RefCounted

## 技能点子系统 Logic 层（照源 player.lua:658-686 getSkillLvupChance + :718-731 resetSkillData）。
## 拆出独立类控 PlayerData 行数（≤300）+ 保 Logic 可 headless 单测。
## 两职责：
##   1. recover：按时间自动恢复技能点（CD 间隔 300s，受 VIP["Max Skill Points"] 上限）
##   2. check_cross_day_reset：跨日重置 skill_reset_times（梯度计费回退第 1 档）

const SECONDS_PER_MINUTE: int = 60
const DAY_KEY_YEAR_WEIGHT: int = 10000
const DAY_KEY_MONTH_WEIGHT: int = 100
const SKILL_RECOVER_CD: int = 300


## 增加技能点（受 VIP["Max Skill Points"] 上限，源 player.lua:648 addSkillPoint + :704 getMaxSkillChance）。
## amount 负=扣减；limit<=0（VIP 表缺字段）时无上限直加。
static func add(pd: PlayerData, amount: int) -> void:
	var limit: int = int(VipData.get_vip_field(pd.vip_level, "Max Skill Points", pd.cm))
	if limit > 0:
		pd.skill_points = min(pd.skill_points + amount, limit)
	else:
		pd.skill_points += amount


## 按时间恢复技能点（照源 player.lua:658-686 getSkillLvupChance）。
## 机制：dt = now - cd_time；addChance = dt / cd；chance = min(chance + addChance, max)。
## 满（chance >= max）时 cd_time = now（停止累积）；否则 cd_time = now - (dt % cd)（保留不足 1 次 CD 的零头）。
## 返回本次恢复量（addChance，受上限钳制后差值）。
static func recover(pd: PlayerData, now_seconds: int) -> int:
	var limit: int = int(VipData.get_vip_field(pd.vip_level, "Max Skill Points", pd.cm))
	if limit <= 0:
		return 0   # VIP 表无上限字段（不应发生），降级不恢复避越界
	if pd.skill_points >= limit:
		pd.skill_cd_time = now_seconds
		return 0
	# 等效"刚恢复到此 chance 的时刻"，之后按时间慢慢恢复；非源 getSkillLvupChance 内部逻辑）。
	# 单机化：cd_time=0 时初始化为 now 并立即写回（dt=0 不恢复，后续按时间累积）。
	if pd.skill_cd_time <= 0:
		pd.skill_cd_time = now_seconds
	var dt: int = max(now_seconds - pd.skill_cd_time, 0)
	var add_chance: int = dt / SKILL_RECOVER_CD
	if add_chance <= 0:
		return 0
	var old_chance: int = pd.skill_points
	pd.skill_points = min(pd.skill_points + add_chance, limit)
	if pd.skill_points >= limit:
		pd.skill_cd_time = now_seconds
	else:
		pd.skill_cd_time = now_seconds - (dt % SKILL_RECOVER_CD)
	return pd.skill_points - old_chance


## 跨日重置 skill_reset_times（照源 player.lua:718-731 resetSkillData）。
## 同步更新 last_reset_date = now（避免次日连续判定；源 reset 后由下次 buy 时 getSkillResetTimes→resetSkillData 再判）。
static func check_cross_day_reset(pd: PlayerData, now_seconds: int) -> void:
	if _crossed_day(pd.skill_last_reset_date, now_seconds):
		pd.skill_reset_times = 0
		pd.skill_last_reset_date = now_seconds


static func _crossed_day(last_ts: int, now: int) -> bool:
	if last_ts <= 0:
		return true
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return _local_day_key(last_ts, off_min) != _local_day_key(now, off_min)


static func _local_day_key(ts: int, off_min: int) -> int:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ts + off_min * SECONDS_PER_MINUTE)
	return int(dt["year"]) * DAY_KEY_YEAR_WEIGHT + int(dt["month"]) * DAY_KEY_MONTH_WEIGHT + int(dt["day"])
