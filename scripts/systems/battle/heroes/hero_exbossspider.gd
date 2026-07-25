extends RefCounted

## ExBossSpider 英雄 hook（Logic 层）— 照源 battle/heroes/ExBossSpider.lua（116 行）。
## 蜘蛛 Boss：reset 首次出场 Buff152（uncontrollable，存 uncon_buff 引用）+ atk2（清负面 debuff + 加 Buff159
##   周期回血 makeup + onAttackFrame 移除无敌/不可控 buff + createBuff update/onRemoved）+ atk4（createBuff 周期 AP 伤害）。
## buff update/onRemoved hook 复用续4/5 基础设施（buff.hero_hooks["update"]/["onRemoved"]，basefunc = _update_default/_on_removed_default）。

const HERO_NAME: String = "ExBossSpider"
const PERCENT_PER_SEC: float = 0.213
const RESET_BUFF_ID: int = 152
const ATK2_BUFF_ID: int = 159
const MAKEUP_CAP: float = 0.618
const MAKEUP_DECAY: float = 0.9
const TIME_TAG_INIT: float = 0.5
const TIME_TAG_PERIOD: float = 1.0
const GLOBAL_CD_ON_REMOVE: float = 1.5
const CRIT_MOD_DISABLED: float = 0.0
const INVULNERABLE_BUFF_NAME: String = "ExBossSpider_Invulnerable"


func _reset(hero: Variant) -> void:
	hero._reset_default()
	if not bool(hero.custom_data.get("has_resetted", false)):
		hero.custom_data["has_resetted"] = true
		var binfo: Variant = hero.cm.lookup(&"Buff", "", RESET_BUFF_ID)
		var buff: Variant = BattleBuff.new(binfo, hero, hero)
		hero.custom_data["uncon_buff"] = buff
		hero.add_buff(buff, hero)


func _atk2_start(skill: Variant, target: Variant) -> void:
	var caster: Variant = skill.caster
	var my_camp: int = int(caster.camp)
	var debuff_list: Array = []
	for buff in caster.buff_list:
		if buff == null:
			continue
		var bc: Variant = buff.caster
		if bc == null or int(bc.camp) != my_camp or String(buff.name) == INVULNERABLE_BUFF_NAME:
			debuff_list.append(buff)
	for buff in debuff_list:
		caster.remove_buff(buff)
	var binfo: Variant = caster.cm.lookup(&"Buff", "", ATK2_BUFF_ID)
	caster.add_buff(BattleBuff.new(binfo, caster, caster), caster)
	var full_hp: float = float(caster.attribs.get("HP", 0))
	var lack_percent: float = 1.0 - float(caster.hp) / full_hp if full_hp > 0.0 else 0.0
	caster.custom_data["needMakeupPercent"] = min(MAKEUP_CAP, lack_percent) * PERCENT_PER_SEC
	skill._start_default(target)


func _atk2_buff_update(buff: Variant, dt: float) -> void:
	buff._update_default(dt)
	var owner: Variant = buff.owner
	var full_hp: float = float(owner.attribs.get("HP", 0))
	var time_tag: float = float(buff.custom_data.get("timeTag", 0.0)) - dt
	if time_tag <= 0.0:
		time_tag = time_tag + TIME_TAG_PERIOD
		var makeup: float = float(owner.custom_data.get("needMakeupPercent", 0.0)) * full_hp
		if float(owner.hp) < full_hp:
			owner.take_heal(makeup, "HP")
		owner.custom_data["needMakeupPercent"] = float(owner.custom_data.get("needMakeupPercent", 0.0)) * MAKEUP_DECAY
	buff.custom_data["timeTag"] = time_tag


func _atk2_buff_on_removed(buff: Variant) -> void:
	buff._on_removed_default()
	var owner: Variant = buff.caster
	owner.global_cd = GLOBAL_CD_ON_REMOVE
	for buf in owner.buff_list:
		if String(buf.name) == INVULNERABLE_BUFF_NAME:
			owner.remove_buff(buf)
			break
	var uncon: Variant = owner.custom_data.get("uncon_buff", null)
	if uncon != null:
		owner.add_buff(uncon, owner)


func _atk2_on_attack_frame(skill: Variant) -> void:
	var owner: Variant = skill.caster
	for buf in owner.buff_list:
		if String(buf.name) == INVULNERABLE_BUFF_NAME:
			owner.remove_buff(buf)
			break
	var uncon: Variant = owner.custom_data.get("uncon_buff", null)
	if uncon != null:
		var uncon_name: String = String(uncon.name)
		for buf in owner.buff_list:
			if String(buf.name) == uncon_name:
				owner.remove_buff(buf)
				break
	skill._on_attack_frame_default()


func _atk2_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.custom_data["timeTag"] = TIME_TAG_INIT
	buff.hero_hooks["update"] = Callable(self, "_atk2_buff_update")
	buff.hero_hooks["onRemoved"] = Callable(self, "_atk2_buff_on_removed")
	return buff


func _atk4_buff_update(buff: Variant, dt: float) -> void:
	buff._update_default(dt)
	var time_tag: float = float(buff.custom_data.get("timeTag", 0.0)) - dt
	if time_tag <= 0.0:
		time_tag = time_tag + TIME_TAG_PERIOD
		buff.owner.take_damage({"amount": float(buff.custom_data.get("damagePerSec", 0.0)), "damage_type": "AP", "field": "hp", "source": buff.caster, "crit_mod": CRIT_MOD_DISABLED})
	buff.custom_data["timeTag"] = time_tag


func _atk4_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.custom_data["damagePerSec"] = float(skill.info.get("Script Arg1", 0))
	buff.custom_data["timeTag"] = TIME_TAG_INIT
	buff.hero_hooks["update"] = Callable(self, "_atk4_buff_update")
	return buff


func apply(hero: Variant) -> void:
	hero.hero_hooks["reset"] = Callable(self, "_reset")
	var skill_atk2: Variant = hero.skills.get(HERO_NAME + "_atk2")
	if skill_atk2:
		skill_atk2.hero_hooks["start"] = Callable(self, "_atk2_start")
		skill_atk2.hero_hooks["onAttackFrame"] = Callable(self, "_atk2_on_attack_frame")
		skill_atk2.hero_hooks["createBuff"] = Callable(self, "_atk2_create_buff")
	var skill_atk4: Variant = hero.skills.get(HERO_NAME + "_atk4")
	if skill_atk4:
		skill_atk4.hero_hooks["createBuff"] = Callable(self, "_atk4_create_buff")
