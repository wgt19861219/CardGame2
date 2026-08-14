extends RefCounted

## Naga 英雄 hook（Logic 层）— 照源 Naga.lua（95 行）。
## onHitMiss（miss 时召唤幻象 tid=145 + Buff89 + mDuration 倒计 die + 4 位置随机 + nagalist + mobcd=12）+
##   die（nagalist 幻象同死）+ update（mobcd 倒计）。protoAwake 守卫。
## onHitMiss 调用点：battle_skill_effect.gd dodge miss 分支（源 C++ compiled，目标补 hook 调用）。
## 复用续8/续13 TB 幻象召唤模式（mDuration die + setDeathWithEffect + summonUnit）。

const MIRROR_TIME: float = 12.0
const MIRROR_TID: int = 145
const MIRROR_BUFF_ID: int = 89
const MOBCD_RESET: float = 12.0
const MIRROR_X: float = 60.0
const MIRROR_Y: float = 30.0
const RAND_0_75: float = 0.75
const RAND_0_5: float = 0.5
const RAND_0_25: float = 0.25
const DEFAULT_MOD: float = 1.0


func _mirror_update(unit: Variant, dt: float) -> void:
	var dur: float = float(unit.custom_data.get("mDuration", MIRROR_TIME)) - dt
	unit.custom_data["mDuration"] = dur
	if dur <= 0.0:
		unit.die(null)
	else:
		unit._update_default(dt)


func _on_hit_miss(hero: Variant, skill: Variant) -> void:
	var skillawake: Variant = hero.skills.get("Naga_awake")
	var caster: Variant = skill.caster
	var proto: Dictionary = {"_tid": MIRROR_TID, "_level": int(skillawake.level) if skillawake != null else 1, "_stars": int(hero.stars), "_rank": int(hero.rank)}
	var config: Dictionary = {"is_monster": true, "estimate_rank": true, "hp_mod": float(hero.config.get("hp_mod", DEFAULT_MOD)), "dps_mod": float(hero.config.get("dps_mod", DEFAULT_MOD))}
	var mirror: BattleUnit = BattleUnit.new(proto, int(hero.camp), config, hero.cm, hero.engine, {}, hero.skill_lib)
	var binfo: Variant = caster.cm.lookup(&"Buff", "", MIRROR_BUFF_ID)
	mirror.add_buff(binfo, caster)
	mirror.custom_data["mDuration"] = MIRROR_TIME
	mirror.hero_hooks["update"] = Callable(self, "_mirror_update")
	mirror.isDeathWithEffect = true
	mirror.direction = int(hero.direction)
	# _random_loc 必须提到 if 外（mobcd>0 时也消耗 RNG 算位置），保确定性 RNG 序列与源一致。
	var loc: Vector2 = _random_loc(hero, int(hero.direction))
	if float(hero.custom_data.get("mobcd", 0.0)) <= 0.0:
		hero.engine.summon_unit(mirror, loc, caster)
		var nagalist: Array = hero.custom_data.get("nagalist", [])
		nagalist.append(mirror)
		hero.custom_data["nagalist"] = nagalist
		hero.custom_data["mobcd"] = MOBCD_RESET


func _random_loc(hero: Variant, dir: int) -> Vector2:
	var r: float = float(hero.engine.rng.randf())
	var p: Vector2 = hero.position
	if r <= 1.0 and r > RAND_0_75:
		return Vector2(p.x + float(dir) * MIRROR_X, p.y + float(dir) * MIRROR_Y)
	if r <= RAND_0_75 and r > RAND_0_5:
		return Vector2(p.x + float(dir) * MIRROR_X, p.y - float(dir) * MIRROR_Y)
	if r <= RAND_0_5 and r > RAND_0_25:
		return Vector2(p.x - float(dir) * MIRROR_X, p.y - float(dir) * MIRROR_Y)
	return Vector2(p.x + float(dir) * MIRROR_X, p.y)


func _die(hero: Variant, killer: Variant) -> void:
	var nagalist: Array = hero.custom_data.get("nagalist", [])
	for naga in nagalist:
		if naga != null and bool(naga.is_alive()):
			naga.die(null)
	hero._die_default(killer)


func _hero_update(hero: Variant, dt: float) -> void:
	hero._update_default(dt)
	if hero.custom_data.has("mobcd"):
		hero.custom_data["mobcd"] = float(hero.custom_data.get("mobcd", 0.0)) - dt


func apply(hero: Variant) -> void:
	hero.custom_data["mobcd"] = 0.0
	hero.ordered_idx = []
	if BattleHeroScripts.proto_awake(hero.proto):
		hero.hero_hooks["die"] = Callable(self, "_die")
		hero.hero_hooks["onHitMiss"] = Callable(self, "_on_hit_miss")  # dodge miss 时 battle_skill_effect 调用
		hero.hero_hooks["update"] = Callable(self, "_hero_update")
