extends RefCounted

## Viper 英雄 hook（Logic 层）— 照源 battle/heroes/Viper.lua（14 行）。
## Viper_ult.createProjectile：basefunc 创建弹射物后 enableTrack(target) 追踪。

func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Viper_ult")
	if skill:
		skill.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")


func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc = 默认 _create_projectile
	if skill.target == null:
		return null
	projectile.enable_track(skill.target)
	return projectile
