class_name BattleUnit
extends BattleEntity

## 战斗单位（Logic 层）— 照源 unit.lua Unit 翻译（Phase 2.2 属性层，2026-06-30）。
## 本轮：字段/构造 UnitCreate/getUnitInfo/rebuild 基础属性计算/基础方法。
## 待 Phase 2.2续：update(AI/移动/碰撞/regen)/takeDamage 伤害公式/die/hurt/idle/castSkill/castManualSkill/
##   initSkill 技能装配/addBuff/removeAllBuffs/battleSupply + rebuild 装备/被动/光环/buff 段。
## 初始化辅助委托 BattleUnitInit（控 ≤250）。

const BattleUnitInit = preload("res://scripts/systems/battle/battle_unit_init.gd")

enum State { IDLE, WALK, ATTACK, HURT, DEAD, BIRTH, DYING, ACTION_TRANSITION }

const ATTRIB_NAMES: Array[String] = [
	"STR", "INT", "AGI", "HP", "MP", "AD", "AP", "ARM", "MR", "CRIT", "MCRIT",
	"HPS", "MPS", "HIT", "DODG", "ARMP", "MRI", "LFS", "CDR", "HEAL", "HPR",
	"MPR", "HAST", "MSPD", "PDM", "TDM", "PIMU", "MIMU", "SKL", "SILR"
]
const ATTRIB_TRANS: Dictionary = {
	"STR": {"HP": 18.0, "ARM": 0.15},
	"INT": {"AP": 2.4, "MR": 0.1},
	"AGI": {"AD": 0.4, "CRIT": 0.4, "ARM": 0.08},
}
const ATTRIB_GS: Dictionary = {
	"HP": 4, "AD": 60, "AP": 30, "ARM": 200, "MR": 200, "CRIT": 125, "MCRIT": 125,
	"HPS": 6, "MPS": 15, "DODG": 100, "HIT": 200, "ARMP": 400, "MRI": 400,
	"LFS": 60, "CDR": 125, "HEAL": 300, "SKL": 2000, "SILR": 150
}
const MONSTER_ATTRIBS: Array[String] = ["HP", "AD", "AP", "ARM", "MR", "CRIT", "MCRIT"]
const MONSTER_STAR_BASE: float = 0.875
const MONSTER_STAR_STEP: float = 0.125
const GS_DIVISOR: int = 100
const RANK_MAX: int = 12
const RANK_EST_OFFSET: int = 9
const RANK_EST_DIVISOR: int = 10
const LV_REQ_UNREACHABLE: int = 9999  # hero_equip LvReq 缺省（不可达）
const PERC_DENOM: int = 10000
const DEFAULT_HP_MOD: float = 1.0
const DEFAULT_STARS: int = 1

var tid: int = 0
var stars: int = DEFAULT_STARS
var level: int = 1
var rank: int = 1
var rank_ratio: float = 0.0
var name: String = ""
var info: Dictionary = {}
var config: Dictionary = {}
var dyna_data: Dictionary = {}
var proto: Dictionary = {}
var attribs: Dictionary = {}
var orig_attribs: Dictionary = {}
# 源 unit.lua:55 hpmpInited——首次 initHpMpInfo 后置位，切波 reset 再调直接 return
# （玩家 hp/mp 跨波保留；2026-08-18 用户实跑"切波能量条清零"根因，本项目漏此守卫）。
var hpmp_inited: bool = false
var hp: int = 0
var mp: int = 0
var max_shield: int = 0
var show_ball: Variant = null
var gs: float = 0.0
var state: int = State.IDLE
var equips: Array = []
var buff_list: Array = []  # Phase 2.3 buff 翻译对接
var buff_effects: Dictionary = {}
var skill_list: Array = []  # Phase 2.4 initSkill 翻译对接
var passive_skill_list: Array = []
var aura_skill_list: Array = []
var effect_enemy_aura_skill_list: Array = []
var basic_skill: Variant = null
var manual_skill: Variant = null
var skill_condition: Dictionary = {}
var ai: Variant = null  # Phase 2.5 createAiForUnit 翻译对接
var global_cd: float = 0.0  # Phase 2.5 ai 依赖（源 unit.lua:191 initSkill 段；0.0 默认，initSkill 段 2.2续 照源赋值）
var attack_range: float = 0.0  # Phase 2.5 ai walkTo 依赖（源 unit.lua:358/407 = basic_skill Max Range-5；2.2续 initSkill 段照源赋值）
var dmg_statistics: float = 0.0  # 战斗伤害统计（源 Lua 动态类型浮点累加 buff.lua:40/combat:1325；非 int 截断）
var monster_idx: int = 0
var index_in_team: int = 0
var index_in_engine: int = 0
var mercenary_data: Variant = null
var custom_data: Dictionary = {}  # 运行时自定义属性包（源 Lua 动态加 caster.XXX；英雄 hook 存 AVultposition 等）
var hp_layer: int = 0
var boss_icon_name: String = ""
var is_scale_action_running: bool = false
var scale_action_duration: float = 0.0
var scale_action_running_time: float = 0.0
var scale_action_scale_value: float = 0.0
var focamp: int = 0
var what: String = "Unit"
# —— 行为字段（源 unit.lua:176-211 UnitCreate 段，Phase 2.2续-A 伤害闭环依赖）——
var manually_casting: bool = false
var current_skill: Variant = null
var can_cast_manual: bool = false
var walk_v: Vector2 = Vector2.ZERO
var walk_speed_multiplier: float = 1.0
var push: bool = false
var speeder: float = 1.0
var dt_action: float = 0.0
var hp_low: bool = false
var hasCorpse: bool = false
var knockup_time: float = -1.0
var knockup_v: Vector2 = Vector2.ZERO
var action_name: String = ""
var action_loop: bool = false
var action_duration: float = 0.0
var action_elapsed: float = 0.0
var dPSStatisticsRatio: float = 1.0
var isDeathWithEffect: bool = false
var is_disapear_when_die: Variant = null
var is_boss_create_with_effect: Variant = null
var can_cast_tick: int = -1
var puppet_stack: Array = []
var action_stage_id: int = 0
var action_stage_infos: Array = []
var current_action_stage: int = 0
var is_action_stage_change_by_manual: bool = false
var skills: Dictionary = {}
var hero_hooks: Dictionary = {}         # 英雄 hook（源 override 等价）：update/castSkill/die/reset/...（Phase 2.7）
var cm: Variant = null                  # ConfigManager 引用（_init 注入；hero hook 经 caster.cm 查 Buff/Unit 表，源 ed.lookupDataTable 等价）
var skill_lib: Variant = null           # SkillLibrary 引用（_init 注入；召唤物 UnitCreate 复用 caster.skill_lib，Necromancersr 骷髅）
# —— Kael 能量球字段（源 Kael.lua init_hero :506-526，apply 时填）——
var energy_ball_manager: Variant = null
var delivered_balls: Dictionary = {}
var ordered_idx: Array = []
var is_kael: bool = false
var display_ball: bool = false
var ai_mode: bool = false
var auto_combat: bool = false
var ult_time: float = 0.0
var start_ult_time: bool = false


func _init(unit_proto: Dictionary, unit_camp: int, unit_config: Dictionary, cm: ConfigManager, unit_engine: Variant = null, extra_data: Dictionary = {}, lib: Variant = null) -> void:
	proto = unit_proto; camp = unit_camp; engine = unit_engine
	self.cm = cm  # ConfigManager 注入（hero hook 经 caster.cm 查表，源 ed.lookupDataTable 等价）
	skill_lib = lib  # SkillLibrary 注入（召唤物 UnitCreate 复用，Necromancersr 骷髅需技能装配）
	dyna_data = extra_data
	config = BattleUnitInit.normalize_config(unit_config)
	tid = int(proto.get("_tid", 0))
	stars = int(proto.get("_stars", DEFAULT_STARS))
	level = int(proto.get("_level", 1))
	BattleUnitInit.calc_rank(self, cm)
	info = BattleUnitInit.get_unit_info(cm, tid, rank)
	BattleUnitInit.apply_info_fields(self)
	ai = BattleAi.create(self)
	BattleUnitEquip.load_equips(self, cm)
	BattleUnitSkill.init_skill(self, cm, lib)
	rebuild()
	BattleUnitInit.init_hp_mp(self)
	state = State.IDLE
	var script_path: String = String(info.get("Script", ""))
	if script_path != "":
		BattleHeroScripts.apply(script_path, self)
	puppet_stack = [String(info.get("Puppet", ""))]


func _init_hp_mp() -> void:
	BattleUnitInit.init_hp_mp(self)


func rebuild() -> void:
	BattleUnitRebuild.rebuild(self)


func is_alive() -> bool:
	return state != State.DEAD and state != State.DYING


func is_hero() -> bool:
	return String(info.get("Unit Type", "")) == "Hero" and not bool(config.get("is_monster", false))


func set_hp(new_hp: int) -> int:
	var capped: int = min(new_hp, int(attribs.get("HP", 0)))
	capped = max(capped, 0)
	hp = capped
	return hp


func set_mp(new_mp: int) -> int:
	var capped: int = min(new_mp, int(attribs.get("MP", 0)))
	capped = max(capped, 0)
	mp = capped
	return mp


func is_mercenary() -> bool:
	return mercenary_data != null

func set_mercenary_data(data: Variant) -> void:
	mercenary_data = data

func get_mercenary_data() -> Variant:
	return mercenary_data

func display() -> String:
	var sign: String = "+" if camp == 1 else "-"
	var dead_mark: String = "" if is_alive() else "D"
	return "[%s%s]%s" % [sign, dead_mark, name]


# —— 行为/结算转发（Phase 2.2续，实现在 BattleUnitBehavior/BattleUnitCombat 静态）——
func idle() -> void:
	BattleUnitBehavior.idle(self)

func walk_towards(dest: Vector2) -> void:
	BattleUnitBehavior.walk_towards(self, dest)

func summon(born_action_name: String = "") -> void:
	BattleUnitBehavior.summon(self, born_action_name)

func cast_skill(skill: Variant, target: Variant) -> void:
	var h: Callable = hero_hooks.get("castSkill", Callable())
	if h.is_valid():
		h.call(self, skill, target)
	else:
		BattleUnitBehavior.cast_skill(self, skill, target)

func cast_manual_skill() -> void:
	var h: Callable = hero_hooks.get("castManualSkill", Callable())
	if h.is_valid():
		h.call(self)
	else:
		_cast_manual_skill_default()

func _cast_manual_skill_default() -> void:
	BattleUnitBehavior.cast_manual_skill(self)

func set_action(action_name: String, loop: bool = false, interrupt: bool = false) -> void:
	BattleUnitCombat.set_action(self, action_name, loop, interrupt)

func take_damage(params: Dictionary) -> float:
	var h: Callable = hero_hooks.get("takeDamage", Callable())
	return float(h.call(self, params)) if h.is_valid() else _take_damage_default(params)

func _take_damage_default(params: Dictionary) -> float:
	return BattleUnitCombat.take_damage(self, params)

func die(killer: Variant) -> void:
	var h: Callable = hero_hooks.get("die", Callable())
	if h.is_valid():
		h.call(self, killer)
	else:
		_die_default(killer)

func _die_default(killer: Variant) -> void:
	BattleUnitCombat.die(self, killer)

func reset() -> void:
	var h: Callable = hero_hooks.get("reset", Callable())
	if h.is_valid():
		h.call(self)
	else:
		_reset_default()
	# 公共收尾：hook/default 两路径 rebuild 后 buff 上限可能回落，保留的 hp/mp 重钳
	# （源守卫语义保留值 + 防超上限；切波能量条超框根因收口，2026-08-18）。
	set_hp(int(hp))
	set_mp(int(mp))

func _reset_default() -> void:
	BattleUnitCombat.reset(self)

func hurt() -> void:
	BattleUnitCombat.hurt(self)

func take_heal(amount: float, p_type: String = "hp", source: Variant = null) -> void:
	BattleUnitCombat.take_heal(self, amount, p_type, source)

func knockup(time: float, distance: Vector2) -> void:
	BattleUnitCombat.knockup(self, time, distance)

func start_scaling_action(scale_x: float, duration: float) -> void:
	BattleUnitCombat.start_scaling_action(self, scale_x, duration)

func end_scaling_action() -> void:
	BattleUnitCombat.end_scaling_action(self)

# —— buff 方法转发（Phase 2.2续-E，实现在 BattleUnitBuff 静态；源 unit.lua:700-812）——
func add_buff(buff_or_binfo: Variant, caster: Variant = null) -> Variant:
	return BattleUnitBuff.add_buff(self, buff_or_binfo, caster)

func remove_buff(buff: Variant) -> void:
	BattleUnitBuff.remove_buff(self, buff)

func remove_all_buffs() -> void:
	BattleUnitBuff.remove_all_buffs(self)

func remove_signed_buffer() -> void:
	BattleUnitBuff.remove_signed_buffer(self)

func battle_supply(coefficient: float) -> void:
	BattleUnitBuff.battle_supply(self, coefficient)


func set_disapear_when_die(b: bool) -> void:
	is_disapear_when_die = b


func enter_action_stage_from_one_stage(n_stage: int) -> void:
	BattleUnitActionStage.enter_action_stage_from_one_stage(self, n_stage)


func enter_action_stage(n_stage: int) -> void:
	BattleUnitActionStage.enter_action_stage(self, n_stage)

# 基类空实现；无 _default（基类空体，hook 无 basefunc 可调），hook 直接覆盖逻辑。
func handle_unit_die_event(unit: Variant, killer: Variant) -> void:
	var h: Callable = hero_hooks.get("handleUnitDieEvent", Callable())
	if h.is_valid():
		h.call(self, unit, killer)

func update(dt: float) -> void:
	var h: Callable = hero_hooks.get("update", Callable())
	if h.is_valid():
		h.call(self, dt)
	else:
		_update_default(dt)

func _update_default(dt: float) -> void:
	BattleUnitUpdate.update(self, dt)

func on_action_finished() -> void:
	var h: Callable = hero_hooks.get("onActionFinished", Callable())
	if h.is_valid():
		h.call(self)
	else:
		_on_action_finished_default()

func _on_action_finished_default() -> void:
	BattleUnitUpdate.on_action_finished(self)


func push_puppet(name: String) -> int:
	puppet_stack.append(name)
	use_puppet()
	return puppet_stack.size()

func remove_puppet(puppet_id: int) -> void:
	if puppet_id < 1 or puppet_id > puppet_stack.size():
		return
	puppet_stack[puppet_id - 1] = ""
	while puppet_stack.size() > 0 and puppet_stack[-1] == "":
		puppet_stack.pop_back()
	use_puppet()

func use_puppet() -> void:
	emit_puppet(action_name, action_loop)   # 发射时动作快照（切换后恢复，防 drain 时读到终态）
