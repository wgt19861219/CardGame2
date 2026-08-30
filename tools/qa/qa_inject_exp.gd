extends Node

## 一次性注入：给用户存档刷经验药三档各 20 个（吃经验验证用；免 bridge，注入后存档退出）。
## 不动等级/英雄/其他数据——保持用户档纯净，只加物品。GM 位打包：id | amount<<10。

const GmManager = preload("res://scripts/systems/gm_manager.gd")

const EXP_ITEMS: Array = [
	{"id": 169, "n": 20},   # 经验药水 Exp=60
	{"id": 218, "n": 20},   # 经验软糖 Exp=300
	{"id": 290, "n": 20},   # 经验奶酪 Exp=1500
]


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	var bits: Array = []
	for it in EXP_ITEMS:
		pd.items[int(it["id"])] = int(it["n"])   # 直接设（等效 _set_items 位打包语义）
	var err: int = GameData.save()
	print("QA_EXP injected 3x20 err=", err, " items[169]=", pd.items.get(169), " [218]=", pd.items.get(218), " [290]=", pd.items.get(290))
	get_tree().quit()
