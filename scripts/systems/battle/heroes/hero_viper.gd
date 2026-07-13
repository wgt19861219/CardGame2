extends RefCounted

## Viper 英雄 hook（Logic 层）— 照源 battle/heroes/Viper.lua（14 行）。
## Viper_ult.createProjectile：basefunc 创建弹射物后 enableTrack(target) 追踪。
## 源 override 机制 → skill.hero_hooks["createProjectile"] = wrapper（Phase 2.7 hook 基础设施）。

func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Viper_ult")
	if skill:
		skill.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")


# 源 :1-8 createProjectile（basefunc(skill) → enableTrack）。
func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc = 默认 _create_projectile
	if skill.target == null:
		return null  # 源 :4 if not skill.target then return（nil，调用方跳过添加；P1 修复照源不返无追踪弹）
	projectile.enable_track(skill.target)
	return projectile
