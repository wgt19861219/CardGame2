extends SceneTree

## 探针2：CD 重置事件高精度监控（临时，不入 CI）。
## 逐 tick 记录每个玩家技能 cd_remaining，检测"CD 突增"（被 reset/interrupt/start），
## 记录事件前后值 + 同一 tick 单位状态，定位是谁重置了小技能 CD。


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
	print("TICK_INTERVAL=%s" % [BattleEngine.TICK_INTERVAL])

	var prev_cd: Dictionary = {}
	var ticks := 0
	var events: Array[String] = []
	while ticks < 3000 and not eng.stage_ended:
		if not eng.running:
			if eng.wave_clear:
				BattleEngineWaves.next_battle(eng, cm)
				eng.wave_clear = false
				eng.running = true
				continue
			break
		eng.update(BattleEngine.TICK_INTERVAL)
		ticks += 1
		for u in eng.unit_list:
			if int(u.camp) != BattleEngine.CAMP_PLAYER or not u.is_alive():
				continue
			for s in u.skill_list:
				var sname: String = str(s.info.get("Skill Name", "?"))
				if sname.ends_with("_atk") or sname.ends_with("_ult"):
					continue   # 只盯小技能
				var key: String = "%s/%s" % [str(u.info.get("Display Name", u.info.get("ID", "?"))), sname]
				var now: float = float(s.cd_remaining)
				var before: float = float(prev_cd.get(key, now))
				prev_cd[key] = now
				if now > before + 0.05:   # CD 突增 = 被重置
					events.append("t=%d %s cd %.2f -> %.2f (+%.2f) | unit: state=%s action=%s cur_skill=%s casting=%s manual=%s global_cd=%.2f attack_counter=%d" % [
						ticks, key, before, now, now - before,
						str(u.state), str(u.action_name),
						str(u.current_skill.info.get("Skill Name", "-")) if u.current_skill != null else "-",
						str(s.casting), str(u.manually_casting), float(u.global_cd), int(s.attack_counter),
					])
					if events.size() > 40:
						break
	print("=== CD 突增事件（小技能）===")
	if events.is_empty():
		print("（无）")
	for e in events:
		print(e)
	print("总 ticks=%d" % ticks)
	quit(0)
