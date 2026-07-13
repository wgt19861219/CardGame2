extends RefCounted

## Troll（巨魔）英雄 hook（Logic 层）— 照源 battle/heroes/Troll.lua（19 行）。
## ai.walkTo override：dest 是单位且非前排（Position Type ~= 前排）→ 临时 attack_range=Troll_atk3 Max Range
##   （近战射程，让巨魔对后排单位走近放近战 atk3）；basefunc 后恢复原射程。
## 源 T(LSTR("UNIT.FRONT_ROW")) 是本地化"前排"串；GDScript 数据复用源 JSON 存 LSTR key
##   （"UNIT.FRONT_ROW" 未翻译），无本地化系统，用 key 比较等价区分前排/非前排。

const FRONT_ROW_KEY: String = "UNIT.FRONT_ROW"  # 源 T(LSTR("UNIT.FRONT_ROW")) 前排标识

var skill3_attack_range: float = 0.0  # 源 :1 文件级 local（Troll_atk3 Max Range，近战射程）


# 源 :11-18 init_hero：Troll_atk3 存在 → 记近战射程 + 覆盖 ai.walkTo。
func apply(hero: Variant) -> void:
	var skill3: Variant = hero.skills.get("Troll_atk3")
	if skill3:
		skill3_attack_range = float(skill3.info.get("Max Range", 0))
		hero.ai.hero_hooks["walkTo"] = Callable(self, "_walk_to")


# 源 :2-10 walkTo：dest 是 unit（what=="Unit"）且非前排 → 临时 attack_range=近战射程；basefunc 后恢复。
func _walk_to(ai: Variant, dest: Variant) -> void:
	var owner: Variant = ai.owner
	var old_range: float = float(owner.attack_range)
	# Vector2 无 what 字段，先类型守卫（源 dest 是 unit 时 what=="Unit"）
	if not (dest is Vector2) and dest.what == "Unit" and String(dest.info.get("Position Type", "")) != FRONT_ROW_KEY:
		owner.attack_range = skill3_attack_range
	ai._walk_to_default(dest)  # basefunc
	owner.attack_range = old_range
