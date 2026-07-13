class_name BattleEngineBall
extends RefCounted

## Kael 能量球投放槽位（Logic 层）— 照源 battle_engine.lua:763-848 翻译（Phase 2.7，2026-07-01）。
## 从 engine 拆出（源是 engine 方法 increBall/getDeliveredEmptySlot/manualTapBall，Godot ≤300 行铁律 + 三层分离强制拆分，静态接 engine 实例）。
## slotPositions（:794-807）含 ed.rand() 是 View 屏幕槽位坐标，Logic 简化：只保留 X 坐标（100+70*i）做"按 X 找最近空槽"，
## Y 坐标 View Phase 4 生成。源返 idx, slotPositions[idx] 双值，Logic 只需 idx（Kael deliveredBalls 存 deliveredSlotIdx）。

const SLOT_POS_X_BASE: int = 100        # 源 :797/803 slotPositions[i][1] = 100+70*i
const SLOT_POS_X_STEP: int = 70
const NORMAL_SLOT_COUNT: int = 10       # 源 :811 for i=1,10（普通投放槽 1-10）
const NORMAL_SLOT_FALLBACK_MAX: int = 9  # 源 :823 rand*9+1
const MANUAL_SLOT_OFFSET: int = 10      # 源 :832 for i=11,20（手动大招槽 11-20）
const MANUAL_SLOT_COUNT: int = 10
const MANUAL_SLOT_FALLBACK_MAX: int = 10  # 源 :844 rand*10+1
const NEAR_LEN_INIT: float = 9999999.0  # 源 :810 nearlen=9999999


# 源 increBall（:789-792）：全局球 idx 递增（球唯一标识，deliveredBalls key）。
static func increase_ball(engine: Variant) -> int:
	engine._global_ball_idx = int(engine._global_ball_idx) + 1
	return int(engine._global_ball_idx)


# 源 getDeliveredEmptySlot（:808-826）：按 X 找最近空普通槽（1-10）；全占则随机 1-9。
static func get_delivered_empty_slot(engine: Variant, x: float) -> int:
	var near_i: int = 0
	var near_len: float = NEAR_LEN_INIT
	for i in range(1, NORMAL_SLOT_COUNT + 1):
		if not bool(engine.used_delivered_ball_slots.get(i, false)):
			var a: float = abs(float(SLOT_POS_X_BASE + SLOT_POS_X_STEP * i) - x)
			if near_len > a:
				near_len = a
				near_i = i
	if near_i != 0:
		return near_i
	return int(engine.rng.randf() * NORMAL_SLOT_FALLBACK_MAX) + 1  # 源 :823 rand*9+1


# 源 getManualDeliveredEmptySlot（:829-847）：手动大招槽（11-20）；全占随机 1-10
# （源 fallback slotPositions[r] r=1-10，与 11-20 错位，照源不修正）。
static func get_manual_delivered_empty_slot(engine: Variant, x: float) -> int:
	var near_i: int = 0
	var near_len: float = NEAR_LEN_INIT
	for i in range(MANUAL_SLOT_OFFSET + 1, MANUAL_SLOT_OFFSET + MANUAL_SLOT_COUNT + 1):
		if not bool(engine.used_delivered_ball_slots.get(i, false)):
			var a: float = abs(float(SLOT_POS_X_BASE + SLOT_POS_X_STEP * (i - MANUAL_SLOT_OFFSET)) - x)
			if near_len > a:
				near_len = a
				near_i = i
	if near_i != 0:
		return near_i
	return int(engine.rng.randf() * MANUAL_SLOT_FALLBACK_MAX) + 1  # 源 :844 rand*10+1


# 源 manualTapBall（:766-785）：auto_combat 路径推 operation_list（回放 op=5）。
# Phase 2.1续操作流回放未做，桩（Kael auto_combat 默认 false，玩家方不走此路径）。
static func manual_tap_ball(_engine: Variant, _deliverer: Variant, _idx: int, _my_slot_idx: int, _nexttick: bool) -> void:
	pass  # operation_list 回放 Phase 2.1续


# 源 deliverBall（battle_engine.lua:1763-1770）：遍历同阵营单位，有 show_ball 则调（投球给 Kael）。
# P1-5：跨英雄投球链路机制（SB awake→deliverBall→同阵营 Kael.showBall→Kael 接球）。触发者 SB awake_update
#   随 protoAwake Phase5（hero_sb awake_update 暂缓），机制就位待触发。
static func deliver_ball(engine: Variant, unit: Variant, skill: Variant, idx: int) -> void:
	for u in engine.unit_list:
		if int(u.camp) == int(unit.camp) and u.get("show_ball") != null:
			var cb: Callable = u.show_ball  # hero.show_ball = Callable(HeroKaelSkill, "_show_ball")（避 Variant.call 歧义）
			cb.call(u, unit, skill, idx)  # _show_ball(kael=u, deliverer=unit, skill, event_idx=idx)
