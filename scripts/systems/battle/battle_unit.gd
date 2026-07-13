class_name BattleUnit
extends BattleEntity

## 战斗单位（Logic 层）— 照源 unit.lua Unit 翻译（Phase 2.2 属性层，2026-06-30）。
## 本轮：字段/构造 UnitCreate/getUnitInfo/rebuild 基础属性计算/基础方法。
## 待 Phase 2.2续：update(AI/移动/碰撞/regen)/takeDamage 伤害公式/die/hurt/idle/castSkill/castManualSkill/
##   initSkill 技能装配/addBuff/removeAllBuffs/battleSupply + rebuild 装备/被动/光环/buff 段。
## 源调全局 ed.engine/ed.getDataTable → Godot 侧 engine + ConfigManager 注入（确定性 + 三层分离）。
## 初始化辅助委托 BattleUnitInit（控 ≤250）。

const BattleUnitInit = preload("res://scripts/systems/battle/battle_unit_init.gd")

enum State { IDLE, WALK, ATTACK, HURT, DEAD, BIRTH, DYING, ACTION_TRANSITION }

# 源 attrib_names（unit.lua:252-283）
const ATTRIB_NAMES: Array[String] = [
	"STR", "INT", "AGI", "HP", "MP", "AD", "AP", "ARM", "MR", "CRIT", "MCRIT",
	"HPS", "MPS", "HIT", "DODG", "ARMP", "MRI", "LFS", "CDR", "HEAL", "HPR",
	"MPR", "HAST", "MSPD", "PDM", "TDM", "PIMU", "MIMU", "SKL", "SILR"
]
# 源 attrib_trans（unit.lua:286-294）：基础属性派生次级
const ATTRIB_TRANS: Dictionary = {
	"STR": {"HP": 18.0, "ARM": 0.15},
	"INT": {"AP": 2.4, "MR": 0.1},
	"AGI": {"AD": 0.4, "CRIT": 0.4, "ARM": 0.08},
}
# 源 attrib_gs（unit.lua:296-319）：gs 战力权重
const ATTRIB_GS: Dictionary = {
	"HP": 4, "AD": 60, "AP": 30, "ARM": 200, "MR": 200, "CRIT": 125, "MCRIT": 125,
	"HPS": 6, "MPS": 15, "DODG": 100, "HIT": 200, "ARMP": 400, "MRI": 400,
	"LFS": 60, "CDR": 125, "HEAL": 300, "SKL": 2000, "SILR": 150
}
# 源 monster_attribs（unit.lua:321-329）：Monster 星级缩放属性
const MONSTER_ATTRIBS: Array[String] = ["HP", "AD", "AP", "ARM", "MR", "CRIT", "MCRIT"]
const MONSTER_STAR_BASE: float = 0.875  # 源 0.875 + 0.125*stars
const MONSTER_STAR_STEP: float = 0.125
const GS_DIVISOR: int = 100  # 源 gs / 100
const RANK_MAX: int = 12  # 源 rank > 12 → 12
const RANK_EST_OFFSET: int = 9  # 源 estimate_rank: floor((level+9)/10)
const RANK_EST_DIVISOR: int = 10
const LV_REQ_UNREACHABLE: int = 9999  # hero_equip LvReq 缺省（不可达）
const PERC_DENOM: int = 10000  # 源 hp/mp _perc 分母（万分之一）
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
var hp: int = 0
var mp: int = 0
var max_shield: int = 0  # 源单位 maxShield（ExPhoenix apply 按 level 设，floating_bar 读盾 UI，P1-10）
var show_ball: Variant = null  # 源 hero.showBall（Kael apply 设 Callable(HeroKaelSkill,"_show_ball")，engine.deliver_ball 遍历调，P1-5）
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
var skill_condition: Dictionary = {}  # 源 skillConditon（Kael 能量球 hook 填，Skill Group ID → 球组合[ice,fire,lightning]）
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
var boss_icon_name: String = ""  # 源 :206 info["Boss Portrait"]（BigHpBar bossIconNode）
var is_scale_action_running: bool = false    # 源 :1487 isScaleActionRunning（技能缩放动画）
var scale_action_duration: float = 0.0       # 源 :1488 scaleActionDuration
var scale_action_running_time: float = 0.0   # 源 :1489 scaleActionRunningTime
var scale_action_scale_value: float = 0.0    # 源 :1490 scaleActionScaleValue
var focamp: int = 0
var what: String = "Unit"  # 源 :114 单位类型标识（Troll ai.walkTo 检查 dest.what=="Unit"；battle_scene Loot 区分）
# —— 行为字段（源 unit.lua:176-211 UnitCreate 段，Phase 2.2续-A 伤害闭环依赖）——
var manually_casting: bool = false      # 源 :193
var current_skill: Variant = null       # 源 :192（施法中技能实例；castSkill 设）
var can_cast_manual: bool = false       # 源 :203
var walk_v: Vector2 = Vector2.ZERO      # 源 :180 移动速度向量
var walk_speed_multiplier: float = 1.0  # 源 :189
var push: bool = false  # 源 :987/:993（碰撞推移；idle 读选 Move/Idle）
var speeder: float = 1.0  # 源 :885 MSPD 加速倍率（View actor.update 读）
var dt_action: float = 0.0  # 源 :887 dt×speeder（动作推进）
var hp_low: bool = false  # 源 :1013 hp/HP<0.2
var hasCorpse: bool = false  # 源 :1029 DYING→DEAD 留尸
var knockup_time: float = -1.0          # 源 :183
var knockup_v: Vector2 = Vector2.ZERO
var action_name: String = ""            # 源 :194 当前动作名
var action_loop: bool = false
var action_duration: float = 0.0
var action_elapsed: float = 0.0
var dPSStatisticsRatio: float = 1.0     # 源 :208（照源拼写；crusade/excavate :211 覆盖，Phase 2.1续模式入口）
var isDeathWithEffect: bool = false     # 源 :1139 setDeathWithEffectOrNot
var is_disapear_when_die: Variant = null  # 源 :1144 setDisapearWhenDie（nil→View die 淡出；SilverDragon 设 false 立即消失）
var is_boss_create_with_effect: Variant = null  # 源 Boss 创建特效标识（AncientTreant 设 false）
var can_cast_tick: int = -1             # 源 castManualSkill:1118 / skill can_cast 缓存
var puppet_stack: Array = []            # 源 :176 Puppet 栈（View；set_action 取动作时长，本轮空栈 fallback）
var action_stage_id: int = 0            # 源 :207 info["Period Group"]（Boss 多阶段，0=无）
var action_stage_infos: Array = []      # 源 :548 getActionStageInfo 填（Period 表各阶段数据）
var current_action_stage: int = 0       # 源 :585（0=nil 未进阶段）
var is_action_stage_change_by_manual: bool = false  # 源 :595 setActionStageChangeByManual
var skills: Dictionary = {}             # 源 :687 self.skills[id]（Basic Skill ID → skill，Phase 2.7 initSkill 填）
var hero_hooks: Dictionary = {}         # 英雄 hook（源 override 等价）：update/castSkill/die/reset/...（Phase 2.7）
var cm: Variant = null                  # ConfigManager 引用（_init 注入；hero hook 经 caster.cm 查 Buff/Unit 表，源 ed.lookupDataTable 等价）
var skill_lib: Variant = null           # SkillLibrary 引用（_init 注入；召唤物 UnitCreate 复用 caster.skill_lib，Necromancersr 骷髅）
# —— Kael 能量球字段（源 Kael.lua init_hero :506-526，apply 时填）——
var energy_ball_manager: Variant = null  # 源 :506 EnergyBallManagerCreate(hero)
var delivered_balls: Dictionary = {}     # 源 :513 deliveredBalls（idx→球 Dict）
var ordered_idx: Array = []              # 源 :514 orderedIdx（View 球排序，Logic 桩）
var is_kael: bool = false                # 源 :515 isKael
var display_ball: bool = false           # 源 :516（View 球显示开关，Logic 桩 false）
var ai_mode: bool = false                # 源 :517 aiMode（arena/enemy 方自动；autoTapBall/SpecialCheckEnableAi 读）
var auto_combat: bool = false            # 源 :524 auto_combat（玩家挂机自动 tap）
var ult_time: float = 0.0                # 源 :525 ultTime（Kael apply 设 2.0，0=未设；View 读）
var start_ult_time: bool = false         # 源 :526 startUltTime


# 源 UnitCreate（unit.lua:111-230）。本轮：config/rank/info/字段/rebuild/initHpMp；initSkill/ai/Script/idle 下轮。
func _init(unit_proto: Dictionary, unit_camp: int, unit_config: Dictionary, cm: ConfigManager, unit_engine: Variant = null, extra_data: Dictionary = {}, lib: Variant = null) -> void:
	proto = unit_proto; camp = unit_camp; engine = unit_engine
	self.cm = cm  # ConfigManager 注入（hero hook 经 caster.cm 查表，源 ed.lookupDataTable 等价）
	skill_lib = lib  # SkillLibrary 注入（召唤物 UnitCreate 复用，Necromancersr 骷髅需技能装配）
	dyna_data = extra_data
	config = BattleUnitInit.normalize_config(unit_config)
	tid = int(proto.get("_tid", 0))
	stars = int(proto.get("_stars", DEFAULT_STARS))
	level = int(proto.get("_level", 1))
	BattleUnitInit.calc_rank(self, cm)   # 源 rank 计算（unit.lua:127-140）
	info = BattleUnitInit.get_unit_info(cm, tid, rank)
	BattleUnitInit.apply_info_fields(self)   # 源 :205-207 name/hp_layer/boss_icon/radius/focamp/equips
	ai = BattleAi.create(self)  # 源 :190 createAiForUnit（initSkill 前）
	BattleUnitEquip.load_equips(self, cm)  # 源 :147-175（rebuild 前；equips 供 rebuild:452-460）
	BattleUnitSkill.init_skill(self, cm, lib)  # 源 :213（rebuild 前；lib null 跳过）
	rebuild()  # 源 :214
	BattleUnitInit.init_hp_mp(self)  # 源 :215
	state = State.IDLE  # 源 :225 idle()→IDLE（setAction View 桩）
	# 源 unit.lua:216-219：英雄 lua hook（info.Script → require → init_hero(self)）
	var script_path: String = String(info.get("Script", ""))
	if script_path != "":
		BattleHeroRegistry.apply(script_path, self)
	puppet_stack = [String(info.get("Puppet", ""))]  # 源 :176 初始栈含 info.Puppet


# 源 initHpMpInfo（unit.lua:54-73）— 委托 BattleUnitInit（battle_unit_combat reset 也调）
func _init_hp_mp() -> void:
	BattleUnitInit.init_hp_mp(self)


# 源 rebuild（unit.lua:418-524）— 拆 BattleUnitRebuild.rebuild（续-E 补全装备/被动/光环/buff 段）。
func rebuild() -> void:
	BattleUnitRebuild.rebuild(self)


# 源 isAlive（unit.lua:872-874）
func is_alive() -> bool:
	return state != State.DEAD and state != State.DYING


# 源 isHero（unit.lua:695-697）
func is_hero() -> bool:
	return String(info.get("Unit Type", "")) == "Hero" and not bool(config.get("is_monster", false))


# 源 setHP（unit.lua:848-856）
func set_hp(new_hp: int) -> int:
	var capped: int = min(new_hp, int(attribs.get("HP", 0)))
	capped = max(capped, 0)
	hp = capped
	return hp


# 源 setMP（unit.lua:859-867）
func set_mp(new_mp: int) -> int:
	var capped: int = min(new_mp, int(attribs.get("MP", 0)))
	capped = max(capped, 0)
	mp = capped
	return mp


# 源 isMercenary/setMercenaryData/getMercenaryData（unit.lua:39-52）
func is_mercenary() -> bool:
	return mercenary_data != null

func set_mercenary_data(data: Variant) -> void:
	mercenary_data = data

func get_mercenary_data() -> Variant:
	return mercenary_data

# 源 display（unit.lua:239-241）
func display() -> String:
	var sign: String = "+" if camp == 1 else "-"
	var dead_mark: String = "" if is_alive() else "D"
	return "[%s%s]%s" % [sign, dead_mark, name]


# —— 行为/结算转发（Phase 2.2续，实现在 BattleUnitBehavior/BattleUnitCombat 静态）——
# 源 :1039 idle / :1053 walkTowards / :1075 summon / :1085 castSkill（BattleUnitBehavior）
func idle() -> void:
	BattleUnitBehavior.idle(self)

func walk_towards(dest: Vector2) -> void:
	BattleUnitBehavior.walk_towards(self, dest)

func summon(born_action_name: String = "") -> void:
	BattleUnitBehavior.summon(self, born_action_name)

# 源 :1085 castSkill（英雄 hook override 点，Kael 消耗能量球）。hook 内调 BattleUnitBehavior.cast_skill 当 basefunc（无 _default，静态即 basefunc 等价）。
func cast_skill(skill: Variant, target: Variant) -> void:
	var h: Callable = hero_hooks.get("castSkill", Callable())
	if h.is_valid():
		h.call(self, skill, target)
	else:
		BattleUnitBehavior.cast_skill(self, skill, target)

# 源 :1096 castManualSkill（英雄 lua hook override 点，如 Sniper 大招后 target.unfreezeActor）。hook 内调 _cast_manual_skill_default 当 basefunc。
func cast_manual_skill() -> void:
	var h: Callable = hero_hooks.get("castManualSkill", Callable())
	if h.is_valid():
		h.call(self)
	else:
		_cast_manual_skill_default()

func _cast_manual_skill_default() -> void:
	BattleUnitBehavior.cast_manual_skill(self)

# 源 :814 setAction / :1252 takeDamage / :1148 die / :1217 takeHeal / :1393 knockup（BattleUnitCombat）
func set_action(action_name: String, loop: bool = false, interrupt: bool = false) -> void:
	BattleUnitCombat.set_action(self, action_name, loop, interrupt)

# 源 :1252 takeDamage（英雄 hook override 点，TitanHead 累计 skill4damage）。hook 内调 _take_damage_default 当 basefunc。
func take_damage(params: Dictionary) -> float:
	var h: Callable = hero_hooks.get("takeDamage", Callable())
	return float(h.call(self, params)) if h.is_valid() else _take_damage_default(params)

func _take_damage_default(params: Dictionary) -> float:
	return BattleUnitCombat.take_damage(self, params)

# 源 :1148 die（英雄 lua hook override 点，如 SNK 重生）。hook 内调 _die_default 当 basefunc 避递归。
func die(killer: Variant) -> void:
	var h: Callable = hero_hooks.get("die", Callable())
	if h.is_valid():
		h.call(self, killer)
	else:
		_die_default(killer)

func _die_default(killer: Variant) -> void:
	BattleUnitCombat.die(self, killer)

# 源 :643 reset（英雄 hook override 点，Kael 清能量球 / ExBossHuskar）。hook 内调 _reset_default 当 basefunc。
func reset() -> void:
	var h: Callable = hero_hooks.get("reset", Callable())
	if h.is_valid():
		h.call(self)
	else:
		_reset_default()

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


# 源 setDisapearWhenDie（unit.lua:1143-1146）：设字段（View die 时读淡出/立即消失，Logic 层仅存）。
func set_disapear_when_die(b: bool) -> void:
	is_disapear_when_die = b


# 源 enterActionStageFromOneStage（unit.lua:578-592）：Boss 多阶段切换（AncientTreant atk6 finish 切阶段 2）。转发静态。
func enter_action_stage_from_one_stage(n_stage: int) -> void:
	BattleUnitActionStage.enter_action_stage_from_one_stage(self, n_stage)


# 源 enterActionStage（unit.lua:617-631）：Boss 多阶段直接切换（TitanHead atk5/atk6）。转发静态（实现续5 BattleUnitActionStage）。
func enter_action_stage(n_stage: int) -> void:
	BattleUnitActionStage.enter_action_stage(self, n_stage)

# 源 handleUnitDieEvent（unit.lua:1212-1213）空函数体——英雄 lua hook override 钩子（SF/TA）。
# 基类空实现；无 _default（基类空体，hook 无 basefunc 可调），hook 直接覆盖逻辑。
func handle_unit_die_event(unit: Variant, killer: Variant) -> void:
	var h: Callable = hero_hooks.get("handleUnitDieEvent", Callable())
	if h.is_valid():
		h.call(self, unit, killer)

# 源 :878 update（英雄 lua hook override 点，如 SNK 重生计时 / SF dyingTimer）。hook 内调 _update_default 当 basefunc。
func update(dt: float) -> void:
	var h: Callable = hero_hooks.get("update", Callable())
	if h.is_valid():
		h.call(self, dt)
	else:
		_update_default(dt)

func _update_default(dt: float) -> void:
	BattleUnitUpdate.update(self, dt)  # 源 :878 tick 主驱动（覆盖基类 BattleEntity.update）

# 源 :1022 onActionFinished（英雄 lua hook override 点，如 SNK 重生期跳过）。hook 内调 _on_action_finished_default 当 basefunc。
func on_action_finished() -> void:
	var h: Callable = hero_hooks.get("onActionFinished", Callable())
	if h.is_valid():
		h.call(self)
	else:
		_on_action_finished_default()

func _on_action_finished_default() -> void:
	BattleUnitUpdate.on_action_finished(self)


# 源 unit.lua:1425-1453 pushPuppet/removePuppet/usePuppet — puppet 栈管理（变羊/变鸭换模型）。
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
	if actor != null and actor.has_method("use_puppet"):
		actor.use_puppet()
