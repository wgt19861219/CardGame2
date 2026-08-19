extends GutTest
# Phase 3.3 ③ unit_sprite 适配测试（2026-07-02）。
# 验 UnitSprite.setup：FCA 加载（Coco tid=1）/ 无 Puppet 降级头像 /
#   动作时长查询（AnimDuration 表或 FCA 算）。
# 注：血条由 actor 的 FloatingBarGroup 管理（源 puppet 不带血条，battle_scene 集成）。
# ConfigManager 真 加载 resources/data；MockUnit duck-type BattleUnit 的 camp/info/hp/mp/attribs。

var _cm: ConfigManager = null


class MockUnit:
	extends RefCounted
	var camp: int = 1
	var info: Dictionary = {}
	var hp: int = 100
	var mp: int = 50
	var attribs: Dictionary = {"HP": 100, "MP": 100}


func before_all() -> void:
	_cm = ConfigManager.new()
	_cm.load_all()


func after_all() -> void:
	UnitSprite.clear_atlas_cache()


func _make_coco() -> MockUnit:
	var u := MockUnit.new()
	u.info = _cm.get_raw_table(&"Unit").get("1", {}).duplicate()
	return u


func test_setup_loads_fca_coco() -> void:
	var sprite := UnitSprite.new()
	add_child(sprite)
	sprite.setup(_make_coco(), _cm)
	assert_true(sprite._using_fca, "Coco 应成功加载 FCA")
	assert_not_null(sprite._fca, "FcaAnimation 实例应就位")
	assert_gt(sprite._fca.get_action_names().size(), 0, "FCA 应解析出动作")
	sprite.queue_free()


func test_setup_fallback_no_puppet() -> void:
	var sprite := UnitSprite.new()
	add_child(sprite)
	var u := MockUnit.new()
	u.info = {"Portrait": "UI/HERO/Coco.jpg"}  # 无 Puppet 字段
	sprite.setup(u, _cm)
	assert_false(sprite._using_fca, "无 Puppet 应降级头像")
	assert_not_null(sprite._fallback_portrait, "应有降级头像")
	sprite.queue_free()


func test_attack_duration_positive() -> void:
	var sprite := UnitSprite.new()
	add_child(sprite)
	sprite.setup(_make_coco(), _cm)
	assert_gt(sprite.get_attack_duration(), 0.0, "攻击时长应 > 0（AnimDuration 表查或 FCA 算）")
	sprite.queue_free()


# ── 施法动作时间锚定（2026-08-19，源 skill.lua:242 setActionElapsed 等效）──
# 替代 cast_rate_for 整体慢放（慢放下动作龟速而特效常速 = "技能播放比人物动作快"根因）。

# 超长 elapsed 钳到末帧：动作播完停末帧（源 clamp 语义），不触发 finished 切 Idle。
func test_set_action_elapsed_clamps_to_last_frame() -> void:
	var sprite := UnitSprite.new()
	add_child(sprite)
	sprite.setup(_make_coco(), _cm)
	var fca: Variant = sprite._fca
	var action: String = fca.get_current_action()
	var frames: Array = fca.get("_actions").get(action, {}).get("frames", [])
	assert_gt(frames.size(), 0, "当前动作应有帧")
	fca.set_action_elapsed(999.0)
	var fps: float = fca.get("_actions").get(action, {}).get("fps", 24.0)
	var total_t: float = float(frames.size()) / fps
	assert_almost_eq(float(fca.get("_elapsed")), total_t - 0.001, 0.0005, "超长 elapsed 应钳到末帧时间")
	assert_eq(int(fca.get("_applied_frame")), frames.size() - 1, "应应用末帧")
	assert_true(bool(fca.get("_playing")), "锚定不应停播放态（源不改 _playing）")
	sprite.queue_free()


# 锚定到中段帧：帧切换且 elapsed 生效（自由推进+微校语义）。
func test_set_action_elapsed_mid_frame() -> void:
	var sprite := UnitSprite.new()
	add_child(sprite)
	sprite.setup(_make_coco(), _cm)
	var fca: Variant = sprite._fca
	var action: String = fca.get_current_action()
	var fps: float = fca.get("_actions").get(action, {}).get("fps", 24.0)
	var frames: Array = fca.get("_actions").get(action, {}).get("frames", [])
	fca.set_action_elapsed(3.0 / fps)   # 第 3 帧时刻
	assert_eq(int(fca.get("_applied_frame")), 3, "应锚到第 3 帧")
	fca.set_action_elapsed(3.0 / fps)   # 重复锚定同帧不重复 apply（_applied_frame 守卫）
	assert_eq(int(fca.get("_applied_frame")), 3, "同帧重复锚定应幂等")
	sprite.queue_free()


# 施法中动作播完不回 Idle（保持末帧等 phase 结束；非施法播完正常回 Idle）。
class CastableUnit:
	extends MockUnit
	var current_skill: Variant = null


func test_action_finished_keeps_frame_while_casting() -> void:
	var sprite := UnitSprite.new()
	add_child(sprite)
	var u := CastableUnit.new()
	u.info = _cm.get_raw_table(&"Unit").get("1", {}).duplicate()
	var cs := {"casting": true}
	u.current_skill = cs
	sprite.setup(u, _cm)
	sprite._fca.play("atk", false)
	sprite._on_fca_action_finished("atk")
	assert_ne(sprite._fca.get_current_action(), "Idle", "施法中动作播完不应切 Idle")
	cs["casting"] = false
	sprite._on_fca_action_finished("atk")
	assert_eq(sprite._fca.get_current_action(), "Idle", "非施法动作播完应回 Idle")
	sprite.queue_free()
