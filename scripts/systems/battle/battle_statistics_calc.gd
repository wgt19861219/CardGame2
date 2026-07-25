class_name BattleStatisticsCalc
extends RefCounted

## 战斗伤害统计计算（Logic 层）— 照源 ui/battleStatistics.lua 纯逻辑段翻译。
## View 层（battle_statistics_panel.gd）调本类算比例/分营/千分位，自身只管动画与节点。
## 单机化：pvp 的 changeTitle 裁剪（源 :149-152 改 self/enemy 标题，单机无 pvp）。

const MAX_BAR_TIME: float = 0.8
const MAX_HEROES_PER_CAMP: int = 5
const COMMA_GROUP_SIZE: int = 3
const CAMP_PLAYER: int = 1
const CAMP_ENEMY: int = 2


# units: Array of {dmg_statistics: float, ...}（duck-type，照源 ipairs engineList）。
static func calc_max_dmg(units: Array) -> float:
	var max_dmg: float = 0.0
	for unit in units:
		max_dmg = maxf(max_dmg, float(unit.dmg_statistics))
	return max_dmg


# 用于条形图动画时长（barTime）与数字跳动 speedTime（源同公式）。
static func get_bar_time(tdmg: float, cmaxdmg: float, maxtime: float) -> float:
	if cmaxdmg == 0.0:
		return 0.0
	return tdmg / cmaxdmg * maxtime


# 条形图比例（dmg/maxdmg，0~1）。源 upBar len/maxdmg（:120/:125/:114）+ getBarTime 共用。
# maxdmg==0 守卫返 0（与 get_bar_time 一致，防空除）。
static func get_bar_ratio(dmg: float, max_dmg: float) -> float:
	if max_dmg == 0.0:
		return 0.0
	return dmg / max_dmg


static func format_comma(number: int) -> String:
	var s: String = str(number)
	var out: String = ""
	var n: int = 0
	for i in range(s.length() - 1, -1, -1):
		n += 1
		out = s[i] + out
		if n == COMMA_GROUP_SIZE:
			n = 0
			out = "," + out
	if out.length() > 0 and out[0] == ",":
		out = out.substr(1)
	return out


# 数字跳动每秒增量；View 层 Tween 用此算插值斜率。
static func get_number_speed(dmg_statistics: float, speed_time: float) -> float:
	if speed_time == 0.0:
		return 0.0
	return dmg_statistics / speed_time


# 保持源 engineList 顺序（ipairs 顺序即 add_unit 顺序）。返 {player: Array, enemy: Array}。
# units: Array of {camp: int, dmg_statistics: float, ...}（duck-type）。
static func split_by_camp(units: Array) -> Dictionary:
	var player: Array = []
	var enemy: Array = []
	for unit in units:
		var c: int = int(unit.camp)
		if c == CAMP_PLAYER and player.size() < MAX_HEROES_PER_CAMP:
			player.append(unit)
		elif c == CAMP_ENEMY and enemy.size() < MAX_HEROES_PER_CAMP:
			enemy.append(unit)
	return {"player": player, "enemy": enemy}
