class_name BattleStatisticsCalc
extends RefCounted

## 战斗伤害统计计算（Logic 层）— 照源 ui/battleStatistics.lua 纯逻辑段翻译。
## 源文件 setImx/getBarTime/setCommaForNumber/numberJump(speed)/showPlayBar(分营) 的无副作用部分。
## View 层（battle_statistics_panel.gd）调本类算比例/分营/千分位，自身只管动画与节点。
## 单机化：pvp 的 changeTitle 裁剪（源 :149-152 改 self/enemy 标题，单机无 pvp）。

const MAX_BAR_TIME: float = 0.8        # 源 showPlayBar/setCount 传 getBarTime 第三参 0.8（条/数字动画时长基准）
const MAX_HEROES_PER_CAMP: int = 5     # 源 showPlayBar mCNum<=5 / eCNum<=5
const COMMA_GROUP_SIZE: int = 3        # 源 setCommaForNumber :31 i==3 千分位每3位分组
const CAMP_PLAYER: int = 1             # 源 ed.emCampPlayer（BattleEngine.CAMP_PLAYER）
const CAMP_ENEMY: int = 2              # 源 ed.emCampEnemy


# 源 setImx(:9-13)：遍历单位取 dmg_statistics 最大值（条形图比例分母）。
# units: Array of {dmg_statistics: float, ...}（duck-type，照源 ipairs engineList）。
static func calc_max_dmg(units: Array) -> float:
	var max_dmg: float = 0.0
	for unit in units:
		max_dmg = maxf(max_dmg, float(unit.dmg_statistics))
	return max_dmg


# 源 getBarTime(:17-22)：tdmg / cmaxdmg * maxtime（cmaxdmg==0 守卫返 0，防空除）。
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


# 源 setCommaForNumber(:23-40)：整数千分位（"1234567"→"1,234,567"）。
# 源 tostring(number) 对浮点带小数；本照源对 int 值用（dmg_statistics 显示前 math.floor）。
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


# 源 numberJump(:46-48) speed = dmg_statistics / speedtime（speedtime==0 守卫 speed=0）。
# 数字跳动每秒增量；View 层 Tween 用此算插值斜率。
static func get_number_speed(dmg_statistics: float, speed_time: float) -> float:
	if speed_time == 0.0:
		return 0.0
	return dmg_statistics / speed_time


# 源 showPlayBar(:109-131) / setCount(:132-148) 分营遍历：player/enemy 各取前 MAX_HEROES_PER_CAMP，
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
