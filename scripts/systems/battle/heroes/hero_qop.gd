extends RefCounted

## QOP 英雄 hook（Logic 层）— 照源 battle/heroes/QOP.lua（15 行）。
## QOP_atk3.start：basefunc → 查 Buff（Script Arg1）→ addBuff。
## cm 访问：caster.cm.lookup（Phase 2.7续 cm 访问路径；QOP 曾为查 Buff 表阻塞，现已解除）。

func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("QOP_atk3")
	if skill:
		skill.hero_hooks["start"] = Callable(self, "_start")


func _start(skill: Variant, target: Variant) -> void:
	skill._start_default(target)  # basefunc（AV 确立的 start hook 模式：拆 _default 避递归）
	var bid: int = int(skill.info.get("Script Arg1", 0))
	var caster: Variant = skill.caster
	var binfo: Variant = caster.cm.lookup(&"Buff", "", bid)  # ed.lookupDataTable
	caster.add_buff(binfo, caster)
