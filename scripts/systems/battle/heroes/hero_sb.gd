extends RefCounted

## SB（裂魂人）英雄 hook（Logic 层）— 照源 SB.lua（205 行）翻译。
## rush 冲撞：reset（位置+友军检测决定 atk2 cd999 或 Waiting buff）+ atk2 start（rush_destination + 算 Attack time 定位 +
##   walk_v 冲撞速度 + Rush buff 动态挂 update）+ atk2 onAttackFrame（到位定位+移除 Rush+walk_v=0）+ Rush buff update（AOE 遍历
##   testPointInShape 对未 affected 单位调 takeEffectOn knockup+Buff6）。ult start（传送 target 身前）。
## 源 skillatk2_finish/skillult_takeEffectAt 定义未挂（死代码）跳过；awake_update protoAwake 守卫暂缓 Phase5。
## getInitDir（源 compiled）= 初始方向 = camp，直接用 int(camp)。

const RUSH_SPEED: float = 300.0              # 源 :2 冲撞速度
const SB_RUSH_BUFF_ID: int = 148             # 源 :3 Rush buff
const SB_WAITING_BUFF_ID: int = 149          # 源 :4 Waiting buff
const KNOCKUP_BUFF_ID: int = 6               # 源 :44 击退 buff
const RESET_X_BASE: float = 400.0            # 源 :8/:64/:109/:122 屏幕中心 X
const RESET_X_OFFSET: float = 480.0          # 源 :8 reset 偏移
const RUSH_POS_COEF: float = 80.0            # 源 :64/:122 80
const RUSH_DESTINATION: float = 400.0        # 源 :109
const KNOCKUP_X_REF: float = 390.0           # 源 :38 390+dir*extraDis
const KNOCKUP_X_FAR: float = 800.0           # 源 :37 800-x
const KNOCKUP_DIS_COEF: float = 0.05         # 源 :37 *0.05
const KNOCKUP_MIN_TIME: float = 0.3          # 源 :39 max(0.3,...)
const KNOCKUP_DIST_DIV: float = 400.0        # 源 :39 distance/400
const AOE_ARG1: float = 120.0                # 源 :88 arg1 固定 120
const CD_INFINITY: float = 999.0             # 源 :29 cd_remaining=999
const ULT_TARGET_OFFSET: float = 70.0        # 源 :151/:162 target.x+dir*70
const DYING_TIMER_SENTINEL: float = 99999.0  # 源 :179 dyingTimer=99999 防重触


# 源 :5-33 reset：basefunc + position（400-480·dir）+ 友军检测（name!=hero.name and 同营）+ atk2 cd999 或 Waiting buff。
func _reset(hero: Variant) -> void:
	hero._reset_default()
	var dir: int = int(hero.camp)  # 源 getInitDir = 初始方向 = camp
	hero.position = Vector2(RESET_X_BASE - RESET_X_OFFSET * float(dir), hero.position.y)
	var has_friend: bool = false
	for unit in hero.engine.unit_list:
		if String(unit.name) != String(hero.name) and int(unit.camp) == int(hero.camp):
			has_friend = true
			break
	for skill in hero.skill_list:
		if String(skill.info.get("Skill Name", "")) == "SB_atk2":
			if has_friend:
				var binfo: Variant = hero.cm.lookup(&"Buff", "", SB_WAITING_BUFF_ID)
				hero.add_buff(BattleBuff.new(binfo, hero, hero), hero)
			else:
				skill.cd_remaining = CD_INFINITY
			break


# 源 :34-60 atk2 takeEffectOn（独立函数，buff update 调）：knockup（distance based）+ Buff6 + basefunc takeEffectOn。
func _atk2_take_effect_on(skill: Variant, unit: Variant) -> void:
	var owner: Variant = skill.caster
	var x: float = unit.position.x
	var dir: int = int(owner.camp)
	var extra_dis: float = (x if dir > 0 else KNOCKUP_X_FAR - x) * KNOCKUP_DIS_COEF
	var distance: float = abs(x - (KNOCKUP_X_REF + float(dir) * extra_dis))
	unit.knockup(max(KNOCKUP_MIN_TIME, distance / KNOCKUP_DIST_DIV), Vector2(distance * float(dir), 0.0))
	var affected: Dictionary = owner.custom_data.get("skillatk2_affected_units", {})
	affected[unit] = true
	var binfo: Variant = owner.cm.lookup(&"Buff", "", KNOCKUP_BUFF_ID)
	unit.add_buff(BattleBuff.new(binfo, unit, owner), owner)
	skill.take_effect_on(unit, owner)


# 源 :75-103 Rush buff update：遍历 AOE 单位（testPointInShape）对未 affected 的调 takeEffectOn。
func _atk2_buff_update(buff: Variant, dt: float) -> void:
	var owner: Variant = buff.owner
	var skillatk2: Variant = owner.custom_data.get("skillatk2", null)
	if skillatk2 != null:
		var caster: Variant = skillatk2.caster
		var info: Dictionary = skillatk2.info
		var direction: int = int(caster.direction)
		var loc: Vector2 = caster.position
		var origin: Vector2 = Vector2(loc.x + float(info.get("X Shift", 0.0)) * float(direction), loc.y)
		var shape: String = str(info.get("AOE Shape", ""))
		var arg2: float = float(info.get("Shape Arg2", 0.0))
		var affected: Dictionary = caster.custom_data.get("skillatk2_affected_units", {})
		for unit in caster.engine.foreach_alive_unit(int(skillatk2._affected_camp())):
			if not affected.has(unit):
				var p2: Vector2 = unit.position - origin
				p2 = Vector2(p2.x * float(direction), p2.y)
				if BattleSkillEffect.test_point_in_shape(p2, shape, AOE_ARG1, arg2):
					affected[unit] = true
					_atk2_take_effect_on(skillatk2, unit)
	buff._update_default(dt)


# 源 :104-135 atk2 start：basefunc + skillatk2/affected_units/rush_destination + 算 Attack time 定位 + walk_v 冲撞 + Rush buff（update hook）。
func _atk2_start(skill: Variant, target: Variant) -> void:
	skill._start_default(target)
	var sb: Variant = skill.caster
	sb.custom_data["skillatk2"] = skill
	sb.custom_data["skillatk2_affected_units"] = {}
	sb.custom_data["rush_destination"] = RUSH_DESTINATION
	var event_list: Array = skill.current_phase.get("event_list", [])
	var atk_time: float = 0.0
	for ev in event_list:
		if str(ev.get("Type", "")) == "Attack":
			atk_time = float(ev.get("Time", 0.0))
			break
	var dir: int = int(sb.camp)
	sb.position = Vector2(RESET_X_BASE - (RUSH_POS_COEF + atk_time * RUSH_SPEED) * float(dir), 0.0)
	sb.walk_v = Vector2(RUSH_SPEED * float(dir), 0.0)
	var binfo: Variant = sb.cm.lookup(&"Buff", "", SB_RUSH_BUFF_ID)
	var buff: Variant = BattleBuff.new(binfo, sb, sb)
	buff.hero_hooks["update"] = Callable(self, "_atk2_buff_update")
	sb.add_buff(buff, sb)


# 源 :61-74 atk2 onAttackFrame：position（400-80·dir,0）+ 移除 Rush buff + walk_v=0（不调 basefunc，完全替换）。
func _atk2_on_attack_frame(skill: Variant) -> void:
	var owner: Variant = skill.caster
	owner.position = Vector2(RESET_X_BASE - RUSH_POS_COEF * float(int(owner.camp)), 0.0)
	for buff in owner.buff_list:
		if int(buff.info.get("ID", 0)) == SB_RUSH_BUFF_ID:
			owner.remove_buff(buff)
	owner.walk_v = Vector2.ZERO


# 源 :147-157 ult start：basefunc + target 身前 70 传送。
func _ult_start(skill: Variant, target: Variant) -> void:
	skill._start_default(target)
	var caster: Variant = skill.caster
	if skill.target != null:
		var pos1: float = skill.target.position.x + float(int(caster.direction)) * ULT_TARGET_OFFSET
		caster.position = Vector2(pos1, skill.target.position.y)


# 源 :172-188 awake_update（protoAwake 守卫）：dying 状态倒计 dyingTimer，到 0 触发 SB_awake takeEffectAt + deliverBall 投球；
# 非 dying 重置 dyingTimer。basefunc 末尾调。
func _awake_update(hero: Variant, dt: float) -> void:
	if hero.state == BattleUnit.State.DYING:
		if not hero.custom_data.has("dyingTimer"):
			hero.custom_data["dyingTimer"] = 1.0  # 源 :175 dyingTimer=1
		hero.custom_data["dyingTimer"] = float(hero.custom_data["dyingTimer"]) - dt
		if float(hero.custom_data["dyingTimer"]) <= 0.0:
			hero.custom_data["dyingTimer"] = DYING_TIMER_SENTINEL  # 源 :179 99999 防重触
			var skill: Variant = hero.skills.get("SB_awake")
			if skill:
				skill.take_effect_at(hero.position)  # 源 :181
				BattleEngineBall.deliver_ball(hero.engine, hero, skill, 1)  # 源 :182
	else:
		hero.custom_data["dyingTimer"] = null  # 源 :185
	hero._update_default(dt)  # basefunc


# 源 :189-203 init_hero：protoAwake→awake_update / reset / atk2（start+onAttackFrame）/ ult（start）。
func apply(hero: Variant) -> void:
	if BattleHeroRegistry.proto_awake(hero.proto):
		hero.hero_hooks["update"] = Callable(self, "_awake_update")
	hero.hero_hooks["reset"] = Callable(self, "_reset")
	var skillatk2: Variant = hero.skills.get("SB_atk2")
	if skillatk2:
		skillatk2.hero_hooks["start"] = Callable(self, "_atk2_start")
		skillatk2.hero_hooks["onAttackFrame"] = Callable(self, "_atk2_on_attack_frame")
	var skillult: Variant = hero.skills.get("SB_ult")
	if skillult:
		skillult.hero_hooks["start"] = Callable(self, "_ult_start")
