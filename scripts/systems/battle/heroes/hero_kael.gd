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


func apply(hero: Variant) -> void:
	HeroKaelSkill.new().apply(hero)  # class_name 全局（避 preload 循环：hero_kael_skill.gd preload 本文件会环）
	hero.hero_hooks["update"] = Callable(self, "_update")
	hero.hero_hooks["castSkill"] = Callable(self, "_cast_skill")
	hero.hero_hooks["reset"] = Callable(self, "_reset")
	hero.hero_hooks["die"] = Callable(self, "_die")
	hero.hero_hooks["specialCheckEnableAi"] = Callable(self, "_special_check_enable_ai")
	hero.energy_ball_manager = BattleEnergyBallManager.new(hero)
	hero.skill_condition = KAEL_SKILL_ELEMENT
	hero.delivered_balls = {}
	hero.ordered_idx = []
	hero.is_kael = true
	hero.show_ball = Callable(HeroKaelSkill, "_show_ball")
	hero.display_ball = false
	hero.ai_mode = bool(hero.engine.arena_mode) or (int(hero.camp) == CAMP_ENEMY and not bool(hero.engine.replay_mode))
	hero.auto_combat = false
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
