class_name BattleBuff
extends RefCounted

## 战斗 buff（Logic 层）— 照源 buff.lua 翻译（Phase 2.3，2026-06-30）。
## 构造 BuffCreate(info, owner, caster)：持 Buff 表 info + owner/caster 引用。
## apply 属性加成（info[name] + .x/.a 引用 caster_attribs）+ 控制效果（applyEffect 蕴含递归）。
## on_damaged shield 抵伤；update HPR + timer 到期；check_add_buff 命中骰（等级/抗性）。
## owner/caster duck-type（单位，Phase 2.2 续完整对接）。
## View 副作用（onAddedClient 的 effect/shader/Popup）桩，Phase 4 接 Actor。
## 效果 key 常量与蕴含/负面表见 BattleEffectKeys（阶段三 T1 迁出，单一权威来源）。

const RESIST_DENOM: float = 100.0
const LEVEL_INSTANT_PASS_RATE: float = 0.3
const LEVEL_NORM_THRESHOLD: int = 30
const LEVEL_NORM_BASE: int = 10
const LEVEL_NORM_SCALE: int = 20
const SHIELD_TYPE_ALL: String = "all"

var name: String = ""
var info: Dictionary = {}
var timer: float = 0.0
var has_timer: bool = false
var owner: Variant = null  # duck-type 单位
var caster: Variant = null
var caster_attribs: Dictionary = {}
var shield: float = 0.0
var has_shield: bool = false
var clear_on_death: bool = false
var impact_effect: Variant = null
var impact_effect_zorder: int = 0
var puppet_id: int = 0  # View（Phase 4）
var effect_id: int = 0
var shader_id: int = 0
var hero_hooks: Dictionary = {}  # 英雄 hook（源 override 等价）：onRemoved/onDamaged/update（Phase 2.7）
var custom_data: Dictionary = {}  # 运行时自定义（源 Lua 动态加 buff.XXX；英雄 hook 用，如 Spider timeTag / DP attack_timer）


func _init(buff_info: Dictionary, buff_owner: Variant, buff_caster: Variant = null) -> void:
	info = buff_info
	owner = buff_owner
	caster = buff_caster
	name = String(buff_info.get("Name", ""))
	var t: float = float(buff_info.get("Time", 0))
	if t > 0:
		timer = t
		has_timer = true
	caster_attribs = caster.attribs if caster != null else {}
	var sv: float = float(buff_info.get("Shield Value", 0))
	if sv > 0:
		shield = sv
		has_shield = true
		_apply_shield_mod()
	clear_on_death = bool(buff_info.get("Clear On Death ", false))
	impact_effect = buff_info.get("Impact Effect", null)
	impact_effect_zorder = int(buff_info.get("Impact Effect Zorder", 0))


func _apply_shield_mod() -> void:
	if owner == null or not (owner.config is Dictionary) or not (owner.config as Dictionary).has("hp_mod"):
		return
	var shield_mod: float = 1.0
	if owner.engine != null and caster != null and int(caster.camp) == BattleEngine.CAMP_ENEMY \
			and bool(owner.engine.guild_instance_mode):
		shield_mod = 1.0
	else:
		shield_mod = float((owner.config as Dictionary).get("hp_mod", 1.0))
	shield *= shield_mod


func update(dt: float) -> void:
	var h: Callable = hero_hooks.get("update", Callable())
	if h.is_valid():
		h.call(self, dt)
	else:
		_update_default(dt)

func _update_default(dt: float) -> void:
	var hpr: float = float(info.get("HPR", 0)) * dt
	if hpr < 0:
		var damage: float = min(-hpr, float(owner.hp))
		damage *= float(owner.dPSStatisticsRatio)
		if caster != null:
			caster.dmg_statistics = float(caster.dmg_statistics) + damage
	if has_timer:
		timer -= dt
		if timer < 0:
			owner.remove_buff(self)


func apply() -> void:
	var owner_attribs: Dictionary = owner.attribs
	for attr_name in BattleUnit.ATTRIB_NAMES:
		var inc: float = float(info.get(attr_name, 0))
		var x_attr: String = str(info.get(attr_name + ".x", ""))
		if x_attr != "":
			var a_coef: float = float(info.get(attr_name + ".a", 0))
			inc += float(caster_attribs.get(x_attr, 0)) * a_coef
		if inc != 0:
			owner_attribs[attr_name] = float(owner_attribs.get(attr_name, 0)) + inc
	for effect in info.get("Control Effects", []):
		apply_effect(String(effect))


func apply_effect(effect: String) -> void:
	var buff_effects: Dictionary = owner.buff_effects
	if bool(buff_effects.get(BattleEffectKeys.UNCONTROLLABLE, false)) and BattleEffectKeys.NEGATIVE.has(effect):
		return
	if buff_effects.has(effect):
		return
	buff_effects[effect] = true
	for sub in BattleEffectKeys.INCLUSIONS.get(effect, []):
		apply_effect(String(sub))
	if effect == BattleEffectKeys.UNCONTROLLABLE:
		for neg in BattleEffectKeys.NEGATIVE:
			buff_effects.erase(neg)


func is_negative_conflict_uncontrollable() -> bool:
	for effect in info.get("Control Effects", []):
		if BattleEffectKeys.NEGATIVE.has(String(effect)):
			return true
	return false


func has_uncontrollable_effect() -> bool:
	for effect in info.get("Control Effects", []):
		if String(effect) == BattleEffectKeys.UNCONTROLLABLE:
			return true
	return false


func on_added_server() -> void:
	var puppet: String = str(info.get("Puppet", ""))
	if puppet != "" and owner != null and owner.has_method("push_puppet"):
		puppet_id = owner.push_puppet(puppet)


func on_added_client() -> void:
	if owner == null or owner.actor == null:
		return
	var actor: Variant = owner.actor
	if not actor.has_method("add_effect"):
		return
	# Effect → addEffect（.cha FCA 特效）
	var eff: String = str(info.get("Effect", ""))
	if eff != "":
		var z: int = int(info.get("Effect Zorder", 0))
		actor.add_effect(eff, z)
		effect_id = 1  # 标记有 effect（name-keyed，on_removed 按 info.Effect 名清）
	# Shader → pushShader（modulate 降级）
	var shader: String = str(info.get("Shader", ""))
	if shader != "" and actor.has_method("push_shader"):
		shader_id = actor.push_shader(shader)
	# 飘字优先级链（AD→ARM→HAST→Popup Text，后者覆盖前者；源是 if/if 串行非 elseif）
	var str_text: String = ""; var color: String = ""
	var is_player: bool = int(owner.camp) == 0  # ed.emCampPlayer
	var ad: float = float(info.get("AD", 0)); var ad_a: float = float(info.get("AD.a", 0))
	var arm: float = float(info.get("ARM", 0)); var arm_a: float = float(info.get("ARM.a", 0))
	var hast: float = float(info.get("HAST", 0)); var hast_a: float = float(info.get("HAST.a", 0))
	if ad > 0 or ad_a > 0:
		str_text = "inc_attack"; color = "blue" if is_player else "red"
	elif ad < 0 or ad_a < 0:
		str_text = "dec_attack"; color = "red" if is_player else "blue"
	if arm > 0 or arm_a > 0:
		str_text = "inc_armor"; color = "blue" if is_player else "red"
	elif arm < 0 or arm_a < 0:
		str_text = "dec_armor"; color = "red" if is_player else "blue"
	if hast > 0 or hast_a > 0:
		str_text = "haste"; color = "blue" if is_player else "red"
	elif hast < 0 or hast_a < 0:
		str_text = "slow"; color = "red" if is_player else "blue"
	var popup_text: String = str(info.get("Popup Text", ""))
	if popup_text != "":
		str_text = popup_text
		color = "blue" if (caster != null and int(caster.camp) == 0) else "red"
	if str_text != "" and color != "" and actor.has_method("spawn_popup"):
		actor.spawn_popup(str_text, color, false, "text")


func on_removed() -> void:
	var h: Callable = hero_hooks.get("onRemoved", Callable())
	if h.is_valid():
		h.call(self)  # hook 内调 _on_removed_default 当 basefunc（Footman 等）
	else:
		_on_removed_default()

func _on_removed_default() -> void:
	if puppet_id != 0 and owner != null and owner.has_method("remove_puppet"):
		owner.remove_puppet(puppet_id); puppet_id = 0
	if owner == null or owner.actor == null:
		return
	var actor: Variant = owner.actor
	# 清 effect（name-keyed，照源 onRemoved removeEffectWithID）
	if effect_id != 0:
		var eff: String = str(info.get("Effect", ""))
		if eff != "" and actor.has_method("remove_effect"):
			actor.remove_effect(eff)
		effect_id = 0
	# 清 shader（照源 onRemoved removeShader）
	if shader_id != 0 and actor.has_method("remove_shader"):
		actor.remove_shader(shader_id); shader_id = 0


func on_damaged(damage: float, damage_type: String) -> float:
	var h: Callable = hero_hooks.get("onDamaged", Callable())
	if h.is_valid():
		return h.call(self, damage, damage_type)  # hook 内调 _on_damaged_default 当 basefunc（LOA 等）
	return _on_damaged_default(damage, damage_type)

func _on_damaged_default(damage: float, damage_type: String) -> float:
	if has_shield:
		var stype: String = str(info.get("Shield Type", ""))
		if stype == damage_type or stype == SHIELD_TYPE_ALL:
			shield -= damage
			if shield < 0:
				if owner != null and owner.has_method("remove_buff"):
					owner.remove_buff(self)
				return -shield
			_show_shield_immune_popup(owner, stype)
			return 0.0
	return damage


func _show_shield_immune_popup(owner_unit: Variant, stype: String) -> void:
	if owner_unit == null:
		return
	var actor: Variant = owner_unit.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	var color: String = "blue" if int(owner_unit.camp) == BattleEngine.CAMP_PLAYER else "red"
	var str_map: Dictionary = {"AD": "physical_immune", "AP": "magic_immune", "all": "immune"}
	actor.spawn_popup(str(str_map.get(stype, "immune")), color, false, "text")


static func _check_level(buff_info: Dictionary, skill_level: float, target_level: float, rng: BattleRng) -> bool:
	if rng.randf() < LEVEL_INSTANT_PASS_RATE:
		return true
	var dice: float = float(buff_info.get("Level Check Dice", 0))
	if dice == 0:
		return true
	var sl: float = skill_level
	if sl < LEVEL_NORM_THRESHOLD:
		sl = LEVEL_NORM_BASE + sl / LEVEL_NORM_THRESHOLD * LEVEL_NORM_SCALE
	dice *= rng.randf()
	return target_level <= sl + dice


static func _check_resist_attribute(buff_info: Dictionary, attribs: Dictionary, rng: BattleRng) -> Array:
	if attribs.is_empty():
		return [true, ""]
	var attr_name: String = str(buff_info.get("Resist Attribute", ""))
	if attr_name != "" and attribs.has(attr_name):
		if rng.randf() < float(attribs[attr_name]) / RESIST_DENOM:
			return [false, "resist"]
	return [true, ""]


# P1-2：reason="resist" 抗性抵抗 / "" 等级不足=miss（照源多返回值，供 take_effect_on 区分 popup）
static func check_add_buff(buff_info: Dictionary, skill_level: float, target_level: float, attribs: Dictionary, rng: BattleRng) -> Array:
	if not _check_level(buff_info, skill_level, target_level, rng):
		return [false, ""]  # 等级不足 → miss（源 :310-311 return false 无 reason）
	return _check_resist_attribute(buff_info, attribs, rng)
