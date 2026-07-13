extends RefCounted

## Coco 英雄 hook（Logic 层）— 照源 battle/heroes/Coco.lua（16 行）。
## Coco_ult.launchPoint：basefunc 返出生点 → X 偏移 -400·direction（反向 400）+ Y=0 + height=10。
## launchPoint 是新 hook 点（返回值类，battle_skill launch_point 拆 _launch_point_default）。

const LAUNCH_X_OFFSET: float = 400.0  # 源 :4 X 反向偏移
const LAUNCH_HEIGHT: float = 10.0     # 源 :6 height=10


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Coco_ult")
	if skill:
		skill.hero_hooks["launchPoint"] = Callable(self, "_launch_point")


# 源 :1-8 launchPoint（basefunc [pos,height] → X 偏移 + Y=0 + height=10）。
func _launch_point(skill: Variant) -> Array:
	var result: Array = skill._launch_point_default()  # basefunc 返 [Vector2 pos, float height]
	var pos: Vector2 = result[0]
	pos.x = pos.x - LAUNCH_X_OFFSET * float(skill.caster.direction)
	pos.y = 0.0
	return [pos, LAUNCH_HEIGHT]
