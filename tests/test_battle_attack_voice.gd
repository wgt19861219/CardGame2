extends GutTest
# 普攻 ATK 语音轮换（设计文档 2.1；源 skill.lua:8 ATK_SOUNDS + :414-421）。
# 轮换公式 (counter-1)%3：源 Lua 1-based，GDScript 0-based 直接 %3 会 off-by-one（一审 MAJOR-1）。
# is_hero 跳过为受控偏离（三-7：源无判定靠缺文件静默）。落空普攻也播（插在 :216/:217 之间——二审 m-4）。

const BattleSkillEffectScript = preload("res://scripts/systems/battle/battle_skill_effect.gd")
const EmitStub = preload("res://tests/helpers/battle_emit_stub.gd")


# EmitStub 为 RefCounted 无 name 成员，桩内声明 var name 遮蔽安全（helper 侧照
# battle_unit_behavior.gd:64 `String(u.name)` 先例直取 caster.name）。
class VoiceUnit extends EmitStub:
	var name: String = "coco"
	var hero_flag: bool = true
	func is_hero() -> bool:
		return hero_flag


func _voice_suffixes(u: VoiceUnit) -> Array:
	var out: Array = []
	for e in u.events:
		if e.type == BattleEvent.Type.VOICE:
			out.append(e.text2)
	return out


func test_atk_voice_rotation_starts_atk() -> void:
	var u := VoiceUnit.new()
	for counter in [1, 2, 3, 4]:
		BattleSkillEffectScript.emit_attack_voice(u, counter)
	assert_eq(_voice_suffixes(u), ["_ATK", "_ATK2", "_ATK3", "_ATK"],
		"首攻 _ATK，三轮换循环（防 off-by-one）")
	var e0: BattleEvent = u.events[0]
	assert_eq(e0.text, "COCO", "英雄名 to_upper")


func test_atk_voice_non_hero_skipped() -> void:
	var u := VoiceUnit.new()
	u.hero_flag = false
	BattleSkillEffectScript.emit_attack_voice(u, 1)
	assert_eq(_voice_suffixes(u), [], "非英雄不发音效事件（is_hero 收紧，三-7）")


func test_atk_voice_empty_name_skipped() -> void:
	var u := VoiceUnit.new()
	u.name = ""
	BattleSkillEffectScript.emit_attack_voice(u, 1)
	assert_eq(_voice_suffixes(u), [], "空名跳过（照源 :416-417）")


func test_attack_frame_wired() -> void:
	# 守卫断言：battle_skill 出手帧接 helper，且插在 counter 自增后（grep 先例模式）。
	var src := FileAccess.get_file_as_string("res://scripts/systems/battle/battle_skill.gd")
	var idx_inc: int = src.find("attack_counter += 1")
	var idx_call: int = src.find("BattleSkillEffect.emit_attack_voice(caster, attack_counter)")
	assert_true(idx_inc != -1 and idx_call != -1, "两处代码都在")
	assert_true(idx_inc < idx_call, "helper 调用在 counter 自增之后（一审 MAJOR-1 公式前提）")
