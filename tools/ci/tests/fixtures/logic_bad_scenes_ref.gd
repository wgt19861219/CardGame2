class_name BadScenesRef
extends RefCounted

const HeroScenePath: String = "res://scenes/hero/hero_scene.gd"  # 字符串常量测 LAYER001（非 preload，避免编辑器 parse 不存在文件报错）

func make() -> void:
	var battle: Object = load("res://scenes/battle/battle_scene.gd")
