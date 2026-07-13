extends GutTest

## stage_account dungeon 结算分支验证（照源 stageaccount.lua:36-100 isDungeon 分支）。
# 源 :52-80：dungeon 关 exp = Exp Reward × 10 / gold = goldByDiff[difficulty] / total_exp = Exp×10 / is_key_stage false。
# 当时"照源不接"是 StageDungeon 表未接入，现已接入（expand_battle_dungeon + StageData 表分流）可补。

var _cm: ConfigManager
var _player: PlayerData


func before_each() -> void:
	_cm = GameData.config
	if not _cm.is_loaded():
		_cm.load_all()
	_player = GameData.player


func _build(sid: int, victory: bool = true) -> Dictionary:
	var param: Dictionary = {"stage_id": sid, "victory": victory, "heroes": [1], "loots": []}
	return StageAccount.build_result_param(param, _cm, _player, _player.hero_manager)


func test_dungeon_exp_x10() -> void:
	# 源 :54 dungeon exp = Exp Reward × 10
	var r: Dictionary = _build(51013)
	var data := StageData.from_config(_cm, 51013)
	assert_eq(int(r["exp"]), data.exp_reward * 10, "dungeon exp × 10")
	assert_eq(int(r["total_exp"]), data.exp_reward * 10, "dungeon total_exp × 10（源 :77）")


func test_dungeon_is_key_stage_false() -> void:
	# 源 :50 isKeyStage = not isDungeon and row["Key Stage"]（dungeon 强制 false）
	var r: Dictionary = _build(51013)
	assert_eq(bool(r["is_key_stage"]), false, "dungeon is_key_stage 强制 false")


func test_dungeon_gold_by_diff2() -> void:
	# 源 :55-56 goldByDiff[2] = 3500（51013 Difficulty=2）
	var r: Dictionary = _build(51013)
	assert_eq(int(r["gold"]), 3500, "dungeon diff2 gold 3500")


func test_dungeon_gold_by_diff4() -> void:
	# 53013 Difficulty=4 → goldByDiff[4] = 8000
	var r: Dictionary = _build(53013)
	assert_eq(int(r["gold"]), 8000, "dungeon diff4 gold 8000")


func test_dungeon_gold_by_diff1_base() -> void:
	# 50013 base Difficulty=1 → goldByDiff[1] = 2000
	var r: Dictionary = _build(50013)
	assert_eq(int(r["gold"]), 2000, "dungeon diff1 gold 2000")


func test_normal_exp_no_x10() -> void:
	# 普通关 1：源 :58 exp = Exp Reward（不 ×10）+ :59 gold = Money Reward
	var r: Dictionary = _build(1)
	var data := StageData.from_config(_cm, 1)
	assert_eq(int(r["exp"]), data.exp_reward, "普通关 exp 不 ×10")
	assert_eq(int(r["gold"]), data.money_reward, "普通关 gold = Money Reward")
	assert_eq(bool(r["is_key_stage"]), data.key_stage, "普通关 is_key_stage 读字段（非强制 false）")


func test_is_dungeon_stage_old_segment() -> void:
	# 旧段 4xxxx 兼容（StageData.is_dungeon_stage 含旧段，照源 local_server:456-461）
	assert_true(StageData.is_dungeon_stage(40001), "旧段 40001 是 dungeon")
	assert_true(StageData.is_dungeon_stage(43021), "旧段 43021 是 dungeon")
	assert_false(StageData.is_dungeon_stage(44000), "44000 非 dungeon（超出旧段）")
