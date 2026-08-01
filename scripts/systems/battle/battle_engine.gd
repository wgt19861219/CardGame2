class_name BattleEngine
extends RefCounted

## 战斗引擎（Logic 层）— 照源 battle_engine.lua 翻译（Phase 2.1 核心重翻，2026-06-30）。
## 固定步长 tick 循环 + 单位/投射物/NPC 三列表调度 + 胜负判定。
## 确定性契约（D2 照源）：tick_interval=0.033（源 ed.tick_interval:19），整数 ticks 计数，update 固定步长累加器（不依赖 wall-clock）。
## 单位 duck-type：调单位 is_alive/update/die/...（源 camelCase→Godot snake_case），不 import 单位类；Phase 2.2 翻新单位对接。
## 本轮核心：字段/reset/update/tick/单位容器/foreach/freeze/胜负骨架/pve_mode/battle_supply。
## 待 Phase 2.1续：模式入口(enter_stage/enter_arena/...)/能量球(Kael)/操作流回放/结算统计/downExit/相机震动。

const CAMP_BOTH: int = 0
const CAMP_PLAYER: int = 1
const CAMP_ENEMY: int = -1

const TICK_INTERVAL: float = 0.033
const TIME_LIMIT_DEFAULT: float = 90.0
const STAGE_MIN_X: float = 0.0
const STAGE_MAX_X: float = 800.0; const STAGE_MIN_Y: float = -120.0; const STAGE_MAX_Y: float = 120.0
const KILL_MP_BONUS: int = 300
const STAR_BASE: int = 3
const PERCENT_DENOM: float = 100.0  # 百分比字段（Mps Restraint）分母
const RESULT_WIN: int = 0
const RESULT_LOSE: int = 1
const RESULT_TIMEOUT: int = 3
const LIST_NAMES: Array[String] = ["unit_list", "projectile_list", "npc_list"]
const INITIAL_POSITIONS: Array[Vector2] = [Vector2(0, 0), Vector2(-80, -40), Vector2(-160, 0), Vector2(-240, -40), Vector2(-320, 0)]

# —— 状态字段（照源 resetStage/resetBattle）——
var enabled: bool = true
var stage_ended: bool = false
var wave_clear: bool = false        # 本波清完待切波（wave_id < Waves，View 显示 next_btn）
var running: bool = true
var ticks: int = 0
var next_tick: float = 0.0
var tick_interval: float = TICK_INTERVAL
var time_limit: float = TIME_LIMIT_DEFAULT
var freeze_level: int = 0
var supplied: bool = false
var mp_bonus: float = 1.0
var rng: BattleRng = null  # D2 确定性：本场战斗随机源（setupBattle 注入），skill 暴击/闪避/check_add_buff 走此（禁全局 rand，源 ed.rand）
var result_stars: int = 0
var wave_id: int = 1; var battle_lookup_id: int = 0; var monster_num: int = 0
var stage_rect: Dictionary = {}
var unit_list: Array = []  # duck-type 单位
var projectile_list: Array = []
var npc_list: Array = []
var alive_units: Dictionary = {}  # camp(int) -> Array
var alive_alliance_count: int = 0
var alive_enemy_count: int = 0
var dead_alliance_count: int = 0
var dead_enemy_count: int = 0
var loot_count: int = 0
var gold_count: int = 0
var death_count: int = 0
var hero_id_list: Array[int] = []
var arena_mode: bool = false
var crusade_mode: bool = false
var excavate_mode: bool = false
var replay_mode: bool = false
var guild_instance_mode: bool = false
var gm_mode: bool = false
var stage_info: Dictionary = {}
var last_result: int = -1  # exit_stage 记录最终结果（供 View/结算读，Phase 2.1续）
# —— Kael 能量球投放槽位（源 battle_engine.lua :108/:789-848，Kael apply 时填 player/enemy_kael_hero）——
var used_delivered_ball_slots: Dictionary = {}
var player_kael_hero: Variant = null
var enemy_kael_hero: Variant = null
var _global_ball_idx: int = 0


func _init() -> void:
	reset_stage()


func reset_stage() -> void:
	enabled = true
	stage_ended = false
	wave_clear = false
	stage_info = {}
	arena_mode = false
	crusade_mode = false
	excavate_mode = false
	replay_mode = false
	guild_instance_mode = false
	gm_mode = false
	stage_rect = {"minX": STAGE_MIN_X, "maxX": STAGE_MAX_X, "minY": STAGE_MIN_Y, "maxY": STAGE_MAX_Y}
	ticks = 0
	tick_interval = TICK_INTERVAL
	hero_id_list = []
	loot_count = 0
	gold_count = 0
	death_count = 0
	last_result = -1
	used_delivered_ball_slots = {}
	reset_battle()


func reset_battle() -> void:
	next_tick = 0.0
	time_limit = TIME_LIMIT_DEFAULT
	projectile_list = []
	npc_list = []
	alive_alliance_count = 0
	alive_enemy_count = 0
	dead_alliance_count = 0
	dead_enemy_count = 0
	freeze_level = 0
	supplied = false
	running = true
	var old := unit_list
	unit_list = []
	alive_units = {CAMP_PLAYER: [], CAMP_ENEMY: [], CAMP_BOTH: []}
	for unit in old:
		if int(unit.camp) == CAMP_PLAYER:
			add_unit(unit)


func update(dt: float) -> void:
	if not running:
		return
	next_tick -= dt
	while next_tick <= 0.0:
		tick()
		next_tick += tick_interval


func tick() -> void:
	time_limit -= tick_interval
	for list_name in LIST_NAMES:
		_advance_entity_list(list_name)
	ticks += 1
	if time_limit <= 0.0:
		result_stars = 0
		if crusade_mode or excavate_mode:
			for unit in unit_list:
				unit.die(null)
		on_battle_end()
		exit_stage(RESULT_TIMEOUT)
	elif alive_enemy_count == 0:
		unfreeze(true)
		on_battle_end()
		victory()
	elif alive_alliance_count == 0:
		result_stars = 0
		unfreeze(true)
		AudioPlayer.play_sfx("battle_lose")
		on_battle_end()
		exit_stage(RESULT_LOSE)


func _advance_entity_list(list_name: String) -> void:
	var list: Array = get(list_name)
	var list_len: int = list.size()
	var write: int = 0
	for i in range(list_len):
		var entity: Variant = list[i]
		# frozen_model：仅 true 才跳过（兼容 mock null 与真单位 false），!= true 守护
		if entity.get("frozen_model") != true:
			entity.update(tick_interval)
		if not bool(entity.terminated):
			list[write] = entity
			write += 1
	if write < list_len:
		list.resize(write)


func add_unit(unit: Variant) -> void:
	var alive: bool = bool(unit.is_alive())
	unit.previous_position = Vector2(unit.position)
	unit_list.append(unit)
	if alive:
		_alive_list(int(unit.camp)).append(unit)
		_alive_list(CAMP_BOTH).append(unit)
		match int(unit.camp):
			CAMP_PLAYER: alive_alliance_count += 1
			CAMP_ENEMY: alive_enemy_count += 1
	else:
		match int(unit.camp):
			CAMP_PLAYER: dead_alliance_count += 1
			CAMP_ENEMY: dead_enemy_count += 1
	unit.index_in_engine = unit_list.size()
	unit.actor = null


func summon_unit(unit: Variant, position: Vector2, summoner: Variant, born_action_name: String = "") -> void:
	unit.config["is_summoned"] = true
	unit.position = position
	add_unit(unit)
	unit.summon(born_action_name)
	unit.config["summoner"] = summoner


# 调用方 onAttackFrame 无条件 addProjectile(createProjectile()) 收到 nil 时需被忽略（源 :1714/:1742）。
# previous_position 源在 add 时设，GDScript 已在 BattleProjectile._init 设（create→add 间 position 不变，等价）。
func add_projectile(projectile: Variant) -> void:
	if projectile != null:
		projectile_list.append(projectile)


func add_chain(chain: Variant) -> void:
	if chain != null:
		projectile_list.append(chain)


func add_npc(npc: Variant) -> void: npc_list.append(npc)


func create_npc(npc_id: int, is_flip: bool, owner: Variant) -> Variant:
	var npc_info: Dictionary = owner.cm.get_raw_table(&"NPC").get(str(npc_id), {})
	if npc_info.is_empty():
		return null
	npc_info["id"] = npc_id
	var npc: BattleNpc = BattleNpc.new(npc_info, self, is_flip, owner)
	add_npc(npc)
	return npc


func on_unit_die(unit: Variant, killer: Variant) -> void:
	BattleEngineDie.on_unit_die(self, unit, killer)


func on_npc_die(npc: Variant) -> void:
	BattleEngineDie.on_npc_die(self, npc)


const BattleEngineQuery = preload("res://scripts/systems/battle/battle_engine_query.gd")
const BattleEngineDie = preload("res://scripts/systems/battle/battle_engine_die.gd")

func foreach_alive_unit(camp: int) -> Array:
	return BattleEngineQuery.alive_units(self, camp)


func foreach_npc() -> Array:
	return BattleEngineQuery.npcs(self)


func foreach_entity() -> Array:
	return BattleEngineQuery.entities(self)


func find_monster(id_or_name: Variant) -> Variant:
	return BattleEngineQuery.find_monster(self, id_or_name)


func find_boss() -> Variant:
	return BattleEngineQuery.find_boss(self)


func find_hero(id_or_name: Variant) -> Variant:
	return BattleEngineQuery.find_hero(self, id_or_name)


func get_unit_by_index(index: int, camp: int) -> Variant:
	return BattleEngineQuery.unit_by_index(self, index, camp)


func get_unit_num(camp: int) -> int:
	return BattleEngineQuery.unit_num(self, camp)


func freeze() -> void:
	if freeze_level == 0:
		for unit in unit_list:
			unit.freeze()
		for projectile in projectile_list:
			projectile.freeze()
		for npc in npc_list:
			npc.freeze()
	freeze_level += 1


func unfreeze(force: bool = false) -> void:
	if force:
		if freeze_level == 0:
			return
		freeze_level = 1
	freeze_level -= 1
	if freeze_level == 0:
		for entity in foreach_entity():
			entity.unfreeze()


func on_battle_end() -> void:
	BattleEngineDie.on_battle_end(self)


func battle_supply(supply_enemy: bool = false) -> void:
	var camp: int = CAMP_ENEMY if supply_enemy else CAMP_PLAYER
	for unit in foreach_alive_unit(camp):
		var coefficient: float = 1.0
		var restraint: int = int(stage_info.get("Mps Restraint", 0))
		if restraint > 0:
			coefficient = float(restraint) / PERCENT_DENOM
		unit.battle_supply(coefficient)
		unit.remove_all_buffs()
	if not supply_enemy:
		supplied = true


func pve_mode() -> bool:
	return not arena_mode and not crusade_mode and not guild_instance_mode and not excavate_mode


func victory(_skip: bool = false) -> void:
	running = false
	# 源 :1579 还有下一波时（wave_id < Waves）不结束关卡：View 层自动切波。
	# 仅最后一波或 skip 才真正 exit_stage（算星级、stage_ended + 胜利音效）。
	var total_waves: int = int(stage_info.get("Waves", 1))
	if wave_id < total_waves and not _skip:
		wave_clear = true   # 本波清完待切波（View 检测此标志自动切下一波）
		return
	AudioPlayer.play_sfx("battle_win")
	death_count = 0
	for unit in unit_list:
		if int(unit.camp) == CAMP_PLAYER and bool(unit.is_hero()) and not bool(unit.is_alive()):
			death_count += 1
	result_stars = max(1, STAR_BASE - death_count)
	if crusade_mode or excavate_mode:
		battle_supply()
	stage_ended = true
	exit_stage(RESULT_WIN)


func exit_stage(result: int, _exit_flag: bool = false) -> void:
	running = false
	enabled = false
	stage_ended = true
	last_result = result


# 存活列表（按 camp 索引；懒建）
func _alive_list(camp: int) -> Array:
	if not alive_units.has(camp):
		alive_units[camp] = []
	return alive_units[camp]
