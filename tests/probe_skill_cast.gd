extends SceneTree

## 探针：技能触发诊断（临时，不入 CI，GUT 不发现——无 test_ 前缀）。
## 跑法：godot --headless -s res://tests/probe_skill_cast.gd
## 输出：装配清单（各英雄 skill_list）+ 施放计数（casting 边沿）+ 周期采样（cd/mp/卡点）。


func _init() -> void:
	var cm := ConfigManager.new()
	cm.load_all()
	var lib := SkillLibrary.new(cm)
	var pd := PlayerData.new(cm)
	pd.vitality = 100
	for tid in [1, 2, 3, 4, 5]:
		pd.hero_manager.add_hero(tid)
	# 模拟实战英雄：高 rank（解锁全部槽位）+ 高等级（技能等级门槛）
	for inst_id in pd.hero_manager.heroes.keys():
		var h: HeroInstance = pd.hero_manager.heroes[inst_id]
		h.rank = 7
		h.level = 70
		h.skill_levels = [70, 70, 70, 70]
	var rng := BattleRng.new(12345)
	var mgr := StageManager.new(cm)
	mgr.skill_lib = lib
	var asm: Dictionary = mgr.assemble_stage_battle(1, pd, [1, 2, 3, 4, 5], rng)
	if not bool(asm.get("ok", false)):
		push_error("assemble 失败: %s" % String(asm.get("error", "")))
		quit(1)
		return
	var eng: BattleEngine = asm["engine"]

	# --- 1. 装配清单 ---
	print("=== 装配清单（玩家方）===")
	for u in eng.unit_list:
		if int(u.camp) != BattleEngine.CAMP_PLAYER:
			continue
		var uname: String = str(u.info.get("Display Name", u.info.get("ID", "?")))
		print("[%s] rank=%d level=%d mp=%.0f/%s" % [uname, u.rank, u.level, u.mp, str(u.attribs.get("MP", "?"))])
		for s in u.skill_list:
			print("  skill: %-22s name=%-18s manual=%-5s costMP=%-4.0f initCD=%-6.2f CD=%-6.2f range=%-6.0f type=%s" % [
				str(s.info.get("Skill Group ID")), str(s.info.get("Skill Name", "?")),
				str(bool(s.info.get("Manual", false))), float(s.info.get("Cost MP", 0.0)),
				float(s.info.get("Init CD", 0.0)), float(s.info.get("CD", 0.0)),
				float(s.info.get("Max Range", 0.0)), str(s.info.get("Damage Type", "")),
			])
		for ps in u.passive_skill_list:
			print("  passive: %s" % str(ps.get("Skill Name", "?")))
		for au in u.aura_skill_list:
			print("  aura: %s" % str(au.get("Skill Name", "?")))

	# --- 2. 跑战斗 + 施放计数 + 采样 ---
	var cast_counts: Dictionary = {}
	var prev_casting: Dictionary = {}
	var reason_samples: Array[String] = []
	var ticks := 0
	while ticks < 3000 and not eng.stage_ended:
		if not eng.running:
			if eng.wave_clear:
				BattleEngineWaves.next_battle(eng, cm)
				eng.wave_clear = false
				eng.running = true
				# 方案 A 接线后 View 真实时序：入场窗口（走路+过场）技能 CD 照源持续衰减
				for u in eng.unit_list:
					BattleUnitUpdate.tick_skill_cd_only(u, 2.5)
				continue
			break
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
		if ticks % 120 == 0 and reason_samples.size() < 15:
			var lines: Array[String] = []
			for u in eng.unit_list:
				if int(u.camp) != BattleEngine.CAMP_PLAYER or not u.is_alive() or u.skill_list.is_empty():
					continue
				var parts: Array[String] = []
				for s in u.skill_list:
					var reason := "READY"
					if float(s.info.get("Cost MP", 0.0)) > float(u.mp):
						reason = "MP缺(need%.0f have%.0f)" % [float(s.info.get("Cost MP", 0.0)), float(u.mp)]
					elif float(s.cd_remaining) > 0.0:
						reason = "CD%.1f" % float(s.cd_remaining)
					parts.append("%s[%s]%s" % [str(s.info.get("Skill Name", "?")), reason, "*" if bool(s.casting) else ""])
				lines.append("%s mp=%.0f: %s" % [str(u.info.get("Display Name", u.info.get("ID", "?"))), float(u.mp), " | ".join(parts)])
			reason_samples.append("t=%d\n  %s" % [ticks, "\n  ".join(lines)])

	print("\n=== 施放计数（玩家方）===")
	if cast_counts.is_empty():
		print("（无任何技能施放记录）")
	for k in cast_counts.keys():
		print("  %s -> %d 次" % [k, int(cast_counts[k])])
	print("\n=== 卡点采样 ===")
	for s in reason_samples:
		print(s)
	print("\n总 ticks=%d stage_ended=%s" % [ticks, eng.stage_ended])
	quit(0)
