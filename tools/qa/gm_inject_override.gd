extends Node

## GM 测试数据注入 override（2026-10-07 用户指示：打不过精英关，刷测试数据）。
## 经 runtime install_override 注册为 MCPOVERRIDE autoload，重启游戏 _ready 跑一次：
## 存当前进度 → 解锁全关卡+等级 80 → 全英雄 → 练度 → 测试物资 → 落盘。
## 2026-10-08 二次注入（装备进阶方案 B 实测）：rank 5→12（方案 B 填 rank12-23 槽，
## rank12 起步可测 12→23 进阶全链+金1→红4），注入前手动备份 save_save_1.pre_equipb_20261008.json。
## 2026-10-08 v4（用户指示：删除所有测试装备，实测「点来源→能否扫荡」获取链路）：
## 清空背包装备类条目（Category ∈ EQUIP.SYNTHETICS 成品 / EQUIP.PARTS 散件），
## 保留消耗品（含扫荡券 390）/卷轴（REEL）/灵魂石（SOUL_STONE），不动英雄穿戴与练度。
## 注入前备份 save_save_1.pre_gm_clear_20261008.json。用完 uninstall_override 清注册。


func _ready() -> void:
	var pd: Variant = GameData.player
	var cm: Variant = GameData.config
	if pd == null or cm == null:
		print("[GM_CLEAR] FAIL: GameData not ready")
		return
	var equip_table: Dictionary = cm.get_raw_table("Equip")
	var clear_cats: Dictionary = {"EQUIP.SYNTHETICS": true, "EQUIP.PARTS": true}
	var removed: Array = []
	for item_id in pd.items.keys().duplicate():
		var row: Dictionary = equip_table.get(str(item_id), {})
		if clear_cats.has(String(row.get("Category", ""))):
			removed.append(int(item_id))
			pd.items.erase(item_id)
	GameData.save()
	print("[GM_CLEAR v4] removed_kinds=", removed.size(), " ids=", removed)
