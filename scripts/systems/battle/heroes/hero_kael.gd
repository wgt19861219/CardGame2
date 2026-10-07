extends RefCounted
# Kael（祈求者）单位 hook — 照源 Kael.lua:107-207/455-533 翻译（Phase 2.7，2026-07-01）。
# 能量球系统单位侧：update（deliveredBalls 生命周期 + autoPick/autoGet 衰减 + manager.update）
#   / castSkill（球组合技能消耗球）/ reset（清球）/ die（清 View 球桩）。
# 投放球辅助 + 10 技能 hook 见 HeroKaelSkill（class_name 全局，本文件 apply 调，避 preload 循环）。
# engine 投放槽位见 BattleEngineBall（increase_ball/get_delivered_empty_slot）。EnergyBallManager 续2.6。
# View（removeBall/removeAllBall/BallCreate）跳过 Phase 4。

const KAEL_SKILL_ELEMENT: Dictionary = {
	530: [1, 1, 1], 531: [3, 0, 0], 532: [2, 1, 0], 533: [2, 0, 1], 534: [0, 3, 0],
	535: [1, 2, 0], 536: [0, 2, 1], 537: [0, 0, 3], 538: [0, 1, 2], 539: [1, 0, 2]
}
const CAMP_PLAYER: int = 1
const CAMP_ENEMY: int = -1
const ULT_TIME_DEFAULT: float = 2.0

# HeroKaelSkill 实例保活：本文件实例由 BattleHeroScripts._cache 持有（每 script_path 一份，
# 玩家/敌方两个 Kael 复用同一本文件实例），技能 hook Callable 的宿主必须随数组累积保活——
# 曾因 new().apply() 用后即弃致 RefCounted 释放、全部技能 hook（含普攻投球）自迁移起静默
# 失效（Callable.is_valid()=false 走 default 无报错），能量球系统从未运转（2026-10-07 实测破获）。
var _skill_hook_hosts: Array = []


func apply(hero: Variant) -> void:
	# skill_condition 先行赋值（HeroKaelSkill.apply 据此给球技能挂 canCastWithTarget 球组合校验）
	hero.skill_condition = KAEL_SKILL_ELEMENT
	var skill_hooks := HeroKaelSkill.new()  # class_name 全局（避 preload 循环：本文件 preload 其会环）
	_skill_hook_hosts.append(skill_hooks)
	skill_hooks.apply(hero)
	hero.hero_hooks["update"] = Callable(self, "_update")
	hero.hero_hooks["castSkill"] = Callable(self, "_cast_skill")
	hero.hero_hooks["reset"] = Callable(self, "_reset")
	hero.hero_hooks["die"] = Callable(self, "_die")
	hero.hero_hooks["specialCheckEnableAi"] = Callable(self, "_special_check_enable_ai")
	hero.energy_ball_manager = BattleEnergyBallManager.new(hero)
	hero.delivered_balls = {}
	hero.ordered_idx = []
	hero.is_kael = true
	hero.show_ball = Callable(HeroKaelSkill, "_show_ball")
	hero.display_ball = false
	hero.ai_mode = bool(hero.engine.arena_mode) or (int(hero.camp) == CAMP_ENEMY and not bool(hero.engine.replay_mode))
	# 玩家侧自动拾球兜底：源靠 ballBar UI 玩家手点（tapBall），本项目球条 View 未实装
	# （Phase 4 债）无点球途径——不拾球则球技能（canCastSkill 球组合校验）恒不可放，
	# 玩家卡尔退化成仅普攻。auto_combat 单位级只驱动拾球（放大招走场景级 auto_combat，
	# 互不相干），球条 UI 实装后还原为 false 交还手动（受控偏离，2026-10-07）。
	hero.auto_combat = int(hero.camp) == CAMP_PLAYER
	hero.ult_time = ULT_TIME_DEFAULT
	hero.start_ult_time = false
	if int(hero.camp) == CAMP_PLAYER:
		hero.engine.player_kael_hero = hero
	else:
		hero.engine.enemy_kael_hero = hero


func _update(hero: Variant, dt: float) -> void:
	for idx in hero.delivered_balls.keys():
		if not hero.delivered_balls.has(idx):
			continue  # 迭代内 erase 后跳过（keys 快照安全）
		var ball: Dictionary = hero.delivered_balls[idx]
		ball["duration"] = float(ball.get("duration", 0.0)) - dt
		if float(ball.get("duration", 0.0)) < BattleEnergyBallManager.EPSILON and not bool(ball.get("startAutoGet", false)):
			# removeBall（View）Phase 4
			hero.delivered_balls.erase(idx)
			hero.engine.used_delivered_ball_slots[int(ball.get("deliveredSlotIdx", 0))] = false
		if (bool(hero.ai_mode) or bool(hero.auto_combat)) and float(ball.get("autoPick", 0.0)) > BattleEnergyBallManager.EPSILON:
			ball["autoPick"] = float(ball.get("autoPick", 0.0)) - dt
		if bool(ball.get("startAutoGet", false)) and float(ball.get("autoGet", 0.0)) > BattleEnergyBallManager.EPSILON:
			ball["autoGet"] = float(ball.get("autoGet", 0.0)) - dt
			if float(ball.get("autoGet", 0.0)) < BattleEnergyBallManager.EPSILON:
				hero.engine.used_delivered_ball_slots[int(ball.get("deliveredSlotIdx", 0))] = false
				_add_energy_ball(hero, int(idx), str(ball.get("balltype", "")), int(ball.get("myslotidx", 0)))
		hero.energy_ball_manager.update(dt)
	# 自动拾球接线（源 autoTapBall 定义完备但无调用方——源靠 ballBar View 玩家手点拾球，
	# 本项目球条 UI 未实装（Phase 4 债），ai_mode/auto_combat 时由 update 链驱动自动拾取，
	# 球系统闭环：普攻投球→拾球进槽→满 3 球必命中 10 组合之一→canCastWithTarget 放行→清球）
	HeroKaelSkill._auto_tap_ball(hero)
	hero._update_default(dt)  # basefunc（源 basefunc(kael, dt)）


func _add_energy_ball(hero: Variant, idx: int, ball_type: String, my_slot_idx: int) -> void:
	if hero.delivered_balls.has(idx):
		hero.delivered_balls.erase(idx)
		hero.energy_ball_manager.add_energy_ball(ball_type, my_slot_idx)


func _cast_skill(hero: Variant, skill: Variant, target: Variant) -> void:
	var cur: Variant = hero.current_skill
	if cur != null and not bool(cur.info.get("Manual", false)):
		cur.interrupt()
	BattleUnitBehavior.cast_skill(hero, skill, target)  # basefunc（源 basefunc(kael, skill, target)）
	var sid: int = int(skill.info.get("Skill Group ID", 0))
	if KAEL_SKILL_ELEMENT.has(sid):
		hero.energy_ball_manager.consume_energy_ball()


func _reset(hero: Variant) -> void:
	hero._reset_default()  # basefunc（源 basefunc(kael)）
	hero.delivered_balls = {}
	hero.energy_ball_manager.clear()


func _die(hero: Variant, killer: Variant) -> void:
	hero._die_default(killer)  # basefunc（源 basefunc(kael, killer)）
	# removeAllBall（View）Phase 4


func _special_check_enable_ai(hero: Variant) -> bool:
	if bool(hero.energy_ball_manager.is_slots_available()) and not bool(hero.engine.arena_mode):
		return true
	return false
