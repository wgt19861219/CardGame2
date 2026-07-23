class_name AwakeHelper
extends RefCounted

## 觉醒养成辅助（Logic 层）— 用户授权的单机化新增设计（源 Lua 无觉醒养成激活）。
## 源仅含觉醒展示弹窗 popheroawake.lua + 战斗 awake 守卫（stage_manager.protoAwake hook），
## 玩家不可主动激活觉醒。本项目碎片觉醒方案：消耗该英雄专属碎片 N 个 → HeroInstance.awake=true。
## 战斗 hook 已就位（stage_manager._init_self_hero:231 proto["_awake"]=hero.awake），
## awake=true 自动激活觉醒技能（Lina_awake 等），本模块只管养成激活。

# 单机化新增：觉醒消耗的专属碎片数。源 Lua 无觉醒养成数值，由本任务用户授权定义。
const AWAKE_FRAGMENT_COST: int = 50


## 觉醒基础资格（不含碎片数检查）：Unit["Can Awake"]=true 且 hero.awake==false。
## 不查碎片数（解耦 Logic/Data 边界，碎片数由调用方通过 can_awake_with_count 补查）。
static func can_awake(cm: ConfigManager, hero: HeroInstance) -> bool:
	if hero == null:
		return false
	if hero.awake:
		return false   # 已觉醒
	if cm == null:
		return false
	if not cm.get_bool(&"Unit", int(hero.tid), &"Can Awake"):
		return false   # Unit 表标不可觉醒（DR/Lina 等）
	return true


## 完整觉醒资格（含碎片数）：can_awake + 专属碎片 >= AWAKE_FRAGMENT_COST。
## View 层入口预检（按钮可见性）+ awake_hero 前置校验共用。
static func can_awake_with_count(cm: ConfigManager, hero: HeroInstance, frag_count: int) -> bool:
	if not can_awake(cm, hero):
		return false
	return frag_count >= AWAKE_FRAGMENT_COST


## 觉醒该英雄专属碎片 ID（查 Fragment 表，源无此映射，碎片系统照源 Fragment 表设计）。
## 返 0 表示该英雄无碎片配置（不可觉醒走 can_awake 的 Can Awake 守卫，本方法仅查碎片 id）。
static func fragment_id_for_hero(cm: ConfigManager, hero_tid: int) -> int:
	if cm == null:
		return 0
	return int(cm.get_raw_table(&"Fragment").get(str(hero_tid), {}).get(&"Fragment ID", 0))


## 执行觉醒（单机化新增，源无此逻辑）：
## ① can_awake_with_count 校验 ② 扣专属碎片 AWAKE_FRAGMENT_COST ③ hero.awake=true。
## 返 {ok:bool}（ok=true 触发弹窗 B）。不足/已觉醒/Can Awake=false 返 {ok:false}。
static func awake_hero(player: PlayerData, hero: HeroInstance) -> Dictionary:
	if player == null or hero == null:
		return {"ok": false}
	var cm: ConfigManager = player.cm
	var frag_id: int = fragment_id_for_hero(cm, int(hero.tid))
	if frag_id <= 0:
		return {"ok": false}
	var frag_count: int = player.hero_manager.fragment_count(frag_id)
	if not can_awake_with_count(cm, hero, frag_count):
		return {"ok": false}
	# 扣专属碎片（HeroManager.spend_fragment 不足返 false，再守卫一次防并发）
	if not player.hero_manager.spend_fragment(frag_id, AWAKE_FRAGMENT_COST):
		return {"ok": false}
	hero.awake = true
	return {"ok": true}
