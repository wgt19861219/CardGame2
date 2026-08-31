extends Node

## 一次性自动取证（倍速档持久化 2026-08-31）：
## 预写 cfg 2 档 → 组战斗 scene.speed_state 应 2 → 按钮切 3 档落盘 → 第二场战斗（新 scene）应持 3 档。
## cfg 是真实用户文件：先备份原值，跑完恢复（覆盖写回，沙箱禁文件删除）。

const CFG_PATH: String = "user://battle.cfg"
const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_scene.tscn")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	if pd == null:
		push_error("QA_AUTO: player null")
		return
	var cm: Variant = pd.cm
	# 备份原 cfg
	var backup_exists: bool = false
	var backup_state: int = 1
	var cfg0 := ConfigFile.new()
	if cfg0.load(CFG_PATH) == OK:
		backup_exists = true
		backup_state = int(cfg0.get_value("battle", "speed_state", 1))

	# 预写 2 档
	var cfg := ConfigFile.new()
	cfg.set_value("battle", "speed_state", 2)
	cfg.save(CFG_PATH)

	pd.tutorial_manager.skip_all()
	var rng := BattleRng.new(12345)
	var tids: Array[int] = [1, 2, 3]
	var asm: Dictionary = pd.stage_manager.assemble_stage_battle(1, pd, tids, rng)
	if not bool(asm.get("ok", false)):
		push_error("QA_AUTO: assemble 失败")
		return
	await get_tree().process_frame
	var scene: Node = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(scene)
	scene.setup(asm["engine"], cm, asm["battle_info"])
	await get_tree().create_timer(1.5).timeout
	print("QA_AUTO: 第一场 speed_state=", scene.speed_state, "（应=2 预写档） btn=", scene.speed_btn.get_state())
	# 切档 2→3，落盘
	scene.speed_btn._on_pressed()
	var cfg2 := ConfigFile.new()
	cfg2.load(CFG_PATH)
	print("QA_AUTO: 切档后 cfg=", int(cfg2.get_value("battle", "speed_state", -1)), "（应=3） scene=", scene.speed_state)
	scene.queue_free()
	await get_tree().create_timer(0.5).timeout

	# 第二场战斗（新 scene，模拟玩家再打一场）
	var rng2 := BattleRng.new(999)
	var asm2: Dictionary = pd.stage_manager.assemble_stage_battle(1, pd, tids, rng2)
	var scene2: Node = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(scene2)
	scene2.setup(asm2["engine"], cm, asm2["battle_info"])
	await get_tree().create_timer(1.5).timeout
	print("QA_AUTO: 第二场 speed_state=", scene2.speed_state, "（应=3 持久化） btn=", scene2.speed_btn.get_state())
	scene2.queue_free()

	# 恢复原 cfg（沙箱禁文件删除：直接覆盖写回备份值，无原文件时写默认 1 行为等价——load fallback 1）
	var cfg3 := ConfigFile.new()
	cfg3.set_value("battle", "speed_state", backup_state)
	cfg3.save(CFG_PATH)
	print("QA_AUTO: DONE")
