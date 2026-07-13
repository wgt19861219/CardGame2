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
