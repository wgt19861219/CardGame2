class_name ReadheroAttribs
extends RefCounted

## 英雄属性查询（Logic 层）— 照源 readhero.lua getHeroAttByHero :11-37 翻译（Phase 5.1，2026-07-02）。
## 复用 BattleUnit（engine=null/lib=null；rebuild 光环段 if u.engine != null 守卫跳过，
## attribs 主体计算不依赖 engine）取 attribs/orig_attribs，算 base/add/all。供 herodetail 属性面板消费。


# 源 getHeroAttByHero :11-37 — 建 BattleUnit 取 attribs → base/add/all（v!=0 才入）。
# base = round(orig_attribs)；all = round(attribs)；add = all - base。
static func get_hero_att_by_hero(hero: HeroInstance, cm: ConfigManager) -> Dictionary:
	if hero == null:
		return {}
	var proto: Dictionary = {
		"_tid": hero.tid,
		"_level": hero.level,
		"_stars": hero.stars,
		"_rank": hero.rank,
	}
	var unit := BattleUnit.new(proto, 1, {}, cm, null, {}, null)
	var att: Dictionary = unit.attribs
	var ori: Dictionary = unit.orig_attribs
	var att_info: Dictionary = {}
	for k in att:
		var v: float = float(att[k])
		if v != 0.0:
			var base_v: int = int(round(float(ori.get(k, 0.0))))
			var all_v: int = int(round(v))
			att_info[k] = {"base": base_v, "add": all_v - base_v, "all": all_v}
	return att_info
