extends RefCounted

## ExBossSpider 英雄 hook（Logic 层）— 照源 battle/heroes/ExBossSpider.lua（116 行）。
## 蜘蛛 Boss：reset 首次出场 Buff152（uncontrollable，存 uncon_buff 引用）+ atk2（清负面 debuff + 加 Buff159
##   周期回血 makeup + onAttackFrame 移除无敌/不可控 buff + createBuff update/onRemoved）+ atk4（createBuff 周期 AP 伤害）。
## buff update/onRemoved hook 复用续4/5 基础设施（buff.hero_hooks["update"]/["onRemoved"]，basefunc = _update_default/_on_removed_default）。

const HERO_NAME: String = "ExBossSpider"
const PERCENT_PER_SEC: float = 0.213          # 源 :1 needMakeupPercent 系数
const RESET_BUFF_ID: int = 152                # 源 :8 首次出场 uncontrollable buff
const ATK2_BUFF_ID: int = 159                 # 源 :29 周期回血 buff
const MAKEUP_CAP: float = 0.618               # 源 :35 min 上限
const MAKEUP_DECAY: float = 0.9               # 源 :48 每秒衰减
const TIME_TAG_INIT: float = 0.5              # 源 :81/:98 buff timeTag 初值
const TIME_TAG_PERIOD: float = 1.0            # 源 :42/:90 周期阈值
const GLOBAL_CD_ON_REMOVE: float = 1.5        # 源 :53
const CRIT_MOD_DISABLED: float = 0.0          # 源 :92 takeDamage 第 6 参 crit_mod=0（禁暴击；第 5 参 coefficient=1 目标无对应字段不传）
const INVULNERABLE_BUFF_NAME: String = "ExBossSpider_Invulnerable"  # 源 :22/:56/:66


# 源 :3-14 reset：basefunc + has_resetted 守卫 → 首次加 Buff152 + 存 uncon_buff 引用（atk2 onAttackFrame/buffonRemoved 用）。
func _reset(hero: Variant) -> void:
	hero._reset_default()
	if not bool(hero.custom_data.get("has_resetted", false)):
		hero.custom_data["has_resetted"] = true
		var binfo: Variant = hero.cm.lookup(&"Buff", "", RESET_BUFF_ID)
		var buff: Variant = BattleBuff.new(binfo, hero, hero)
		hero.custom_data["uncon_buff"] = buff
		hero.add_buff(buff, hero)


# 源 :15-37 atk2 start：清负面 debuff（caster 空/异营/无敌）+ 加 Buff159 + needMakeupPercent + basefunc。
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


# 源 :38-50 atk2 buff update：basefunc + timeTag 倒计 1s 周期回血（needMakeupPercent*HP）+ needMakeupPercent×0.9 衰减。
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


# 源 :51-62 atk2 buff onRemoved：basefunc + global_cd=1.5 + 移除无敌 buff + addBuff(uncon_buff)。
func _atk2_buff_on_removed(buff: Variant) -> void:
	buff._on_removed_default()
	var owner: Variant = buff.caster  # 源 skill=buff（Lua self），buff.caster=施法者 hero
	owner.global_cd = GLOBAL_CD_ON_REMOVE
	for buf in owner.buff_list:
		if String(buf.name) == INVULNERABLE_BUFF_NAME:
			owner.remove_buff(buf)
			break
	var uncon: Variant = owner.custom_data.get("uncon_buff", null)
	if uncon != null:
		owner.add_buff(uncon, owner)


# 源 :63-78 atk2 onAttackFrame：移除无敌 buff + 移除 uncon_buff 同名 buff + basefunc。
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


# 源 :79-85 atk2 createBuff：basefunc 建 buff → timeTag=0.5 + update/onRemoved hook。
func _atk2_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.custom_data["timeTag"] = TIME_TAG_INIT
	buff.hero_hooks["update"] = Callable(self, "_atk2_buff_update")
	buff.hero_hooks["onRemoved"] = Callable(self, "_atk2_buff_on_removed")
	return buff


# 源 :86-94 atk4 buff update：basefunc + timeTag 倒计 1s 周期 AP 伤害（damagePerSec）。
func _atk4_buff_update(buff: Variant, dt: float) -> void:
	buff._update_default(dt)
	var time_tag: float = float(buff.custom_data.get("timeTag", 0.0)) - dt
	if time_tag <= 0.0:
		time_tag = time_tag + TIME_TAG_PERIOD
		buff.owner.take_damage({"amount": float(buff.custom_data.get("damagePerSec", 0.0)), "damage_type": "AP", "field": "hp", "source": buff.caster, "crit_mod": CRIT_MOD_DISABLED})
	buff.custom_data["timeTag"] = time_tag


# 源 :95-101 atk4 createBuff：basefunc 建 buff → damagePerSec=Script Arg1 + timeTag=0.5 + update hook。
func _atk4_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.custom_data["damagePerSec"] = float(skill.info.get("Script Arg1", 0))
	buff.custom_data["timeTag"] = TIME_TAG_INIT
	buff.hero_hooks["update"] = Callable(self, "_atk4_buff_update")
	return buff


# 源 :102-115 init_hero：挂 reset（单位）/ atk2（start/onAttackFrame/createBuff）/ atk4（createBuff）。
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
