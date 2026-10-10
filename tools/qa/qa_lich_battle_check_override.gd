extends Node

## 一次性验证 override v3（2026-10-10）：开一场 ch203 50022，实测 Boss 本体放大
## （size_mod×scale）、auto/倍速初始态、Boss 行为采样（抖动/不攻击取证）。
## nerf 策略：卸装备+技能归 1（保 100 级）——打得过 wave1/2 小怪但不秒 Boss，供采样。
## 用完 uninstall_override。


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	await get_tree().create_timer(1.0).timeout
	var pd: Variant = GameData.player
	pd.stage_manager.act_times.clear()   # QA 多轮实测耗尽当日组次数（ch203 按 ActStageGroupDungeon 组计），清限供装配
	pd.stage_limit.clear()
	var mgr: Variant = pd.stage_manager
	var tids: Array[int] = []
	var snapshot: Array = []   # [hero, level, skill_levels]
	for inst_id in pd.team:
		var h: Variant = pd.hero_manager.heroes.get(int(inst_id))
		if h == null:
			continue
		tids.append(int(h.tid))
		snapshot.append([h, h.level, (h.skill_levels as Array).duplicate()])
	# 临时降 60 级+技能归 1（保装备；内存快照，装配后立即恢复）——打得动小怪不秒 Boss
	for s in snapshot:
		var h: Variant = s[0]
		h.level = 60
		for i in range((h.skill_levels as Array).size()):
			h.skill_levels[i] = 1
	var asm_r: Dictionary = mgr.assemble_stage_battle(50022, pd, tids, BattleRng.new(7))
	for s in snapshot:
		var h: Variant = s[0]
		h.level = s[1]
		var sl: Array = h.skill_levels
		for i in range(sl.size()):
			sl[i] = s[2][i]
	if not bool(asm_r.get("ok", false)):
		print("[QA_BATTLE] assemble fail=", asm_r.get("error", ""))
		return
	GameData.battle_context = {
		"engine": asm_r["engine"], "battle_info": asm_r["battle_info"],
		"loots": asm_r["loots"], "stage_id": 50022, "player_tids": tids, "mgr": mgr,
	}
	print("[QA_BATTLE] assembled ok, entering battle")
	SceneManager.change_scene("res://scenes/battle/battle_scene.tscn")
	# 扫 Boss（递归，tid>=90000，0.2s 间隔），最长 60s
	var scene: Node = null
	for i in range(300):
		await get_tree().create_timer(0.2).timeout
		scene = get_tree().current_scene
		if scene == null:
			continue
		var actor: BattleActor = _scan_boss(scene)
		if actor != null:
			await _dump(actor, scene, i)
			return
	print("[QA_BATTLE] boss 60s 未出现 scene=", scene.scene_file_path if scene != null else "null")


func _scan_boss(root: Node) -> BattleActor:
	if root is BattleActor:
		var m0: Variant = (root as BattleActor).model
		if m0 != null and bool(m0.config.get(&"is_boss", false)):
			return root as BattleActor
	for child in root.get_children():
		var hit: BattleActor = _scan_boss(child)
		if hit != null:
			return hit
	return null


func _dump(actor: BattleActor, scene: Node, waited: int) -> void:
	var m: Variant = actor.model
	print("[QA_BATTLE] waited=", waited * 0.2, "s boss tid=", m.tid,
		" size_mod=", m.config.get(&"size_mod", 1.0), " actor.scale=", actor.scale)
	# auto/倍速初始态（扫到时 battle_scene 已就绪）
	print("[QA_BATTLE] scene=", scene.scene_file_path, " auto_combat=", scene.get("auto_combat"),
		" speed_state=", scene.get("speed_state"))
	var ab: Variant = scene.get("auto_btn")
	if ab != null:
		print("[QA_BATTLE] auto_btn.is_on=", ab.is_on())
	# 行为采样 ×12（0.3s 间隔）：位置/当前技能/MP/技能 CD——抓"抖动/不攻击"现场
	for k in range(12):
		await get_tree().create_timer(0.3).timeout
		var cs: Variant = m.current_skill
		var cs_name: String = "-"
		if cs != null:
			cs_name = String(cs.info.get("Skill Name", "?"))
		var cd1: float = -1.0
		var cd2: float = -1.0
		if m.skills.has("1"):
			cd1 = float(m.skills["1"].cd_remaining)
		if m.skills.has("2"):
			cd2 = float(m.skills["2"].cd_remaining)
		print("[QA_BATTLE] sample", k, " pos=", m.position, " cur_skill=", cs_name,
			" mp=", int(m.mp), " cd1=", cd1, " cd2=", cd2)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://qa_lich_battle.png")
	print("[QA_BATTLE] screenshot=user://qa_lich_battle.png DONE")
