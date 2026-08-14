class_name BattleHeroScripts
extends RefCounted

## 英雄 hook 脚本装配（Logic 层）— 照源 unit.lua:216 `require(info.Script)` 的 Godot 等价（阶段三 T2，2026-08-14）。
## 数据表 Script 字段（如 "battle/heroes/Viper"）按文件名约定拼 res:// 路径直 load + 实例缓存，
## 取代 BattleHeroRegistry 人工 preload 映射表（双登记维护，曾漏 Lion/DOTsr 致 hook 静默失效）。
## 文件名约定：hero_ + Script 末段小写（迁移期 71/71 registry 键实测命中）。
## hero_cm.gd / hero_kael_skill.gd 数据表不引用（CM 走默认行为、Kael 内部 class_name 复用），约定路径不会触发。

const SCRIPTS_DIR: String = "res://scripts/systems/battle/heroes/"

static var _cache: Dictionary = {}


## 装配英雄 hook：按 script_path 直 load 对应 hero_*.gd 并 apply(hero)（实例缓存保热路径）。
## load 失败静默跳过（缺文件由 test_hero_scripts 数据表全量对账守卫，不在运行时 crash）。
static func apply(script_path: String, hero: Variant) -> void:
	if script_path == "":
		return
	var inst: Variant = _cache.get(script_path, null)
	if inst == null:
		if not can_load(script_path):
			return
		inst = _load_script(script_path).new()
		_cache[script_path] = inst
	inst.apply(hero)


## script_path（"battle/heroes/Viper"）→ res://scripts/systems/battle/heroes/hero_viper.gd 是否存在可加载。
## 用 ResourceLoader.exists 探测（load 缺路径会打引擎 ERROR，被 GUT 记 Unexpected Errors）。
static func can_load(script_path: String) -> bool:
	return ResourceLoader.exists(_script_path(script_path))


static func _load_script(script_path: String) -> Resource:
	return load(_script_path(script_path)) as Resource


static func _script_path(script_path: String) -> String:
	var hero_name: String = script_path.get_file().to_lower()
	return SCRIPTS_DIR + "hero_" + hero_name + ".gd"


# 实现读 proto._awake（HeroInstance.awake 养成控制，stage_manager 构建 proto 时注入）。
# 召唤物/怪物 proto 无 _awake 键 → 默认 false（不觉醒）。（自 battle_hero_registry.gd 迁入，语义不变）
static func proto_awake(proto: Dictionary) -> bool:
	return bool(proto.get("_awake", false))
