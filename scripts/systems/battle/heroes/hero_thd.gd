extends RefCounted

## THD（潮汐猎人）英雄 hook（Logic 层）— 照源 battle/heroes/THD.lua（20 行）。
## THD_ult.createBuff：创建 buff 后覆写 onRemoved——自然到期（timer<=0）追加 Buff 70。

const FOLLOWUP_BUFF_ID: int = 70


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("THD_ult")
	if skill:
		skill.hero_hooks["createBuff"] = Callable(self, "_create_buff")


func _create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.hero_hooks["onRemoved"] = Callable(self, "_on_removed")
	return buff


func _on_removed(buff: Variant) -> void:
	if float(buff.timer) <= 0.0:
		var binfo: Variant = buff.owner.cm.lookup(&"Buff", "", FOLLOWUP_BUFF_ID)
		buff.owner.add_buff(binfo, buff.caster)
	buff._on_removed_default()
