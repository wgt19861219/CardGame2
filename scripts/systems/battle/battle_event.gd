class_name BattleEvent
extends RefCounted

## 战斗表现事件（Logic 层值对象）— 阶段三 T4（2026-08-14）。
## 引擎产出表现意图（飘字/特效/音效/着色/震动/演出）入 BattleEngine.events 队列，
## battle_scene 逐帧 drain 分发渲染——Logic 不再鸭子直调 View（治审查报告问题 11：75 处直调 + 37 处守卫）。
## headless 无 View 时事件静默累积于队列（测试可断言），语义等价旧 actor==null 守卫跳过。
## unit 为事件主体（可为 null=场景级）；shader 用 Logic 侧 token 关联 PUSH/REMOVE（View 维护 token→槽位映射）。

enum Type {
	POPUP,          # 飘字：text/color/flag(crit)/text2(style)
	ADD_EFFECT,     # 挂持续特效：text(资源名)/value(zorder)
	REMOVE_EFFECT,  # 移除持续特效：text(资源名)
	PLAY_EFFECT,    # 播一次性特效：text(资源名)/origin/scale/height/value(zorder)
	TINT,           # 着色：rgb
	VOICE,          # 语音：text(单位名)/text2(后缀)
	SHADER_PUSH,    # 压 shader：value(token)/text(shader 名)
	SHADER_REMOVE,  # 弹 shader：value(token)
	SHAKE,          # 镜头震动：value(max_h)/value2(time)/value3(num)
	GOLD_DROP,      # 金币掉落演出
	LOOT_DROP,      # 掉落宝箱演出（源 battle_engine.lua:1038 敌怪死亡 showMonsterLoots）
	LAUNCH,         # 单位 launch 演出：value(time)
	NEW_ACTION,     # 新动作开始：text(action)/flag(loop)（发射时快照，防 drain 时 model 已变）
	PUPPET,         # 傀儡态切换：text(action)/flag(loop)（切换后恢复动作用发射时快照）
	NPC_DEATH,      # NPC 死亡演出（NpcActor）
	ZSPEED,         # 离地速度状态写入（DOTsr atk2 振荡弹跳；View 侧 z_speed/zSpeed 双属性名兼容）
}

var type: int = Type.POPUP
var unit: Variant = null  # BattleEntity 或测试 EmitStub（duck：actor/engine）
var text: String = ""
var text2: String = ""
var color: String = ""
var flag: bool = false
var rgb: Vector3 = Vector3.ONE
var origin: Vector2 = Vector2.ZERO
var scale: float = 1.0
var height: float = 0.0
var value: float = 0.0
var value2: float = 0.0
var value3: float = 0.0


static func popup(unit: Variant, p_text: String, p_color: String, crit: bool = false, style: String = "damage") -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.POPUP
	e.unit = unit
	e.text = p_text
	e.color = p_color
	e.flag = crit
	e.text2 = style
	return e


static func add_effect(unit: Variant, effect_name: String, zorder: int = 0) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.ADD_EFFECT
	e.unit = unit
	e.text = effect_name
	e.value = float(zorder)
	return e


static func remove_effect(unit: Variant, effect_name: String) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.REMOVE_EFFECT
	e.unit = unit
	e.text = effect_name
	return e


static func play_effect(unit: Variant, effect_name: String, at: Vector2, p_scale: float = 1.0, p_height: float = 0.0, zorder: int = 0) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.PLAY_EFFECT
	e.unit = unit
	e.text = effect_name
	e.origin = at
	e.scale = p_scale
	e.height = p_height
	e.value = float(zorder)
	return e


static func tint(unit: Variant, p_rgb: Vector3) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.TINT
	e.unit = unit
	e.rgb = p_rgb
	return e


static func voice(unit: Variant, unit_name: String, suffix: String) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.VOICE
	e.unit = unit
	e.text = unit_name
	e.text2 = suffix
	return e


static func shader_push(unit: Variant, token: int, shader_name: String) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.SHADER_PUSH
	e.unit = unit
	e.value = float(token)
	e.text = shader_name
	return e


static func shader_remove(unit: Variant, token: int) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.SHADER_REMOVE
	e.unit = unit
	e.value = float(token)
	return e


static func shake(unit: Variant, max_height: float, shake_time: float, shake_num: int) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.SHAKE
	e.unit = unit
	e.value = max_height
	e.value2 = shake_time
	e.value3 = float(shake_num)
	return e


static func gold_drop(unit: Variant) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.GOLD_DROP
	e.unit = unit
	return e


static func loot_drop(unit: Variant) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.LOOT_DROP
	e.unit = unit
	return e


static func launch(unit: Variant, time: float) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.LAUNCH
	e.unit = unit
	e.value = time
	return e


static func new_action(unit: Variant, action: String, loop: bool) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.NEW_ACTION
	e.unit = unit
	e.text = action
	e.flag = loop
	return e


static func puppet(unit: Variant, action: String, loop: bool) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.PUPPET
	e.unit = unit
	e.text = action
	e.flag = loop
	return e


static func npc_death(unit: Variant) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.NPC_DEATH
	e.unit = unit
	return e


static func zspeed(unit: Variant, v: float) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = Type.ZSPEED
	e.unit = unit
	e.value = v
	return e
