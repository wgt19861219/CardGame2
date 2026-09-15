extends SceneTree

## 探针3：长战斗验证（临时，不入 CI）。
## 敌方 hp×20 拉长每波时长，验证小技能在长波内能否正常施放（判定引擎全链路好坏）。


func _init() -> void:
	var cm := ConfigManager.new()
	cm.load_all()
	var lib := SkillLibrary.new(cm)
	var pd := PlayerData.new(cm)
	pd.vitality = 100
	for tid in [1, 2, 3, 4, 5]:
		pd.hero_manager.add_hero(tid)
	for inst_id in pd.hero_manager.heroes.keys():
		var h: HeroInstance = pd.hero_manager.heroes[inst_id]
		h.rank = 7
		h.level = 70
		h.skill_levels = [70, 70, 70, 70]
	var rng := BattleRng.new(12345)
	var mgr := StageManager.new(cm)
	mgr.skill_lib = lib
	var asm: Dictionary = mgr.assemble_stage_battle(1, pd, [1, 2, 3, 4, 5], rng)
	var eng: BattleEngine = asm["engine"]
	# 敌方每 tick 锁满血（战斗不结束，纯观察技能轮转）
	var max_ticks := 3600   # 60 秒（TICK_INTERVAL=1/60 时）

	var cast_counts: Dictionary = {}
	var prev_casting: Dictionary = {}
	var ticks := 0
	while ticks < max_ticks and not eng.stage_ended:
		if not eng.running:
			if eng.wave_clear:
				BattleEngineWaves.next_battle(eng, cm)
				eng.wave_clear = false
				eng.running = true
				continue
			break
		for u in eng.unit_list:
			if int(u.camp) == BattleEngine.CAMP_ENEMY and u.is_alive():
				u.attribs["HP"] = 1000000000   # 上限拉到天文数字，一击打不死
				u.set_hp(1000000000)
		eng.update(BattleEngine.TICK_INTERVAL)
		ticks += 1
		for u in eng.unit_list:
			if int(u.camp) != BattleEngine.CAMP_PLAYER or not u.is_alive():
				continue
			for s in u.skill_list:
				var key: String = "%s/%s%s" % [str(u.info.get("Display Name", u.info.get("ID", "?"))), str(s.info.get("Skill Name", "?")), "(M)" if bool(s.info.get("Manual", false)) else ""]
				var now_casting: bool = bool(s.casting)
				if now_casting and not bool(prev_casting.get(key, false)):
					cast_counts[key] = int(cast_counts.get(key, 0)) + 1
				prev_casting[key] = now_casting
	print("=== 长战斗施放计数（敌方 hp×20，玩家方）===")
	if cast_counts.is_empty():
		print("（无任何技能施放记录）")
	for k in cast_counts.keys():
		print("  %s -> %d 次" % [k, int(cast_counts[k])])
	print("总 ticks=%d stage_ended=%s last_result=%s" % [ticks, eng.stage_ended, eng.last_result])
	quit(0)
