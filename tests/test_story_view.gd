extends GutTest
# P1-B6（2026-07-23）：源 storylayer.lua:235-237 showStory 战斗场景下 pauseBattle("story")，
# :176-178 closeStory resumeBattle("story")。原 story_view._build_ui/_close_story 注释声明
# 但未实现 pause_locks 操作，剧情演出时怪物继续打。照源修复 _apply_story_pause 对称锁/解锁。

# Mock battle_scene：持有 pause_locks 字典 + is_paused 标量（同 battle_scene.gd:48-49 范式）。
class MockBattleScene extends Node:
	var pause_locks: Dictionary = {}
	var is_paused: bool = false


func test_apply_story_pause_true_locks_story() -> void:
	var bs := MockBattleScene.new()
	bs.pause_locks = {}
	bs.is_paused = false
	StoryView._apply_story_pause(bs, true)
	assert_true(bool(bs.pause_locks.get("story", false)), "pause_locks[story]=true（源 :236 pauseBattle）")
	assert_true(bs.is_paused, "is_paused=true（pause_locks.values().has(true) 源 :777-780）")
	bs.queue_free()


func test_apply_story_pause_false_unlocks_story() -> void:
	var bs := MockBattleScene.new()
	bs.pause_locks["story"] = true
	bs.is_paused = true
	StoryView._apply_story_pause(bs, false)
	assert_false(bool(bs.pause_locks.get("story", true)), "pause_locks[story]=false（源 :177 resumeBattle）")
	assert_false(bs.is_paused, "无其他锁 → is_paused=false（源 :777-780 any=false）")
	bs.queue_free()


# 源 :235 ed.getCurrentScene()==ed.scene 仅战斗场景 pauseBattle；非战斗场景 no-op。
func test_apply_story_pause_no_op_when_not_battle_scene() -> void:
	var plain := Node.new()   # 普通节点无 pause_locks 字段
	StoryView._apply_story_pause(plain, true)
	StoryView._apply_story_pause(plain, false)
	assert_true(true, "非 battle scene 调 _apply_story_pause 不崩（源 :235 仅 battle scene pauseBattle）")
	plain.queue_free()


# 多 reason 共存：story 锁 + pauseButton 锁 → 解 story 锁后仍暂停（源 :777-780 any）。
func test_apply_story_pause_mixes_with_pause_button() -> void:
	var bs := MockBattleScene.new()
	bs.pause_locks["pauseButton"] = true   # 玩家手动暂停未解
	bs.is_paused = true
	StoryView._apply_story_pause(bs, false)   # 关剧情但 pauseButton 仍锁
	assert_false(bool(bs.pause_locks.get("story", true)), "story 锁解")
	assert_true(bs.is_paused, "pauseButton 锁仍在 → is_paused=true（源 :777-780 any=true）")
	bs.queue_free()


func test_apply_story_pause_null_scene_no_op() -> void:
	# scene=null 安全（_set_battle_pause get_tree()==null 时 scene=null）
	StoryView._apply_story_pause(null, true)
	StoryView._apply_story_pause(null, false)
	assert_true(true, "null scene 不崩（no-op）")
