extends Node

## GM 测试数据注入 override（2026-10-07 用户指示：打不过精英关，刷测试数据）。
## 经 runtime install_override 注册为 MCPOVERRIDE autoload，重启游戏 _ready 跑一次：
## 存当前进度 → 解锁全关卡+等级 80 → 全英雄 → 练度 rank5/level80/stars5 → 测试物资 → 落盘。
## 用完 uninstall_override 清注册；重玩原始进度恢复 save_save_1.pre_gm_inject_20261007.json 备份。


func _ready() -> void:
	var pd: Variant = GameData.player
	var cm: Variant = GameData.config
	if pd == null or cm == null:
		print("[GM_INJECT] FAIL: GameData not ready")
		return
	GameData.save()   # 先保当前进度（精英 30 次验证会话内的进度）再注入
	GmManager.execute(pd, cm, {"_unlock_all_stages": 1}, pd.stage_manager)
	GmManager.execute(pd, cm, {"_get_all_heroes": 1})
	var hero_list: Array = []
	for inst_id in pd.hero_manager.heroes:
		var h: Variant = pd.hero_manager.heroes[inst_id]
		hero_list.append({"_tid": h.tid, "_rank": 5, "_level": 80, "_stars": 5})
	GmManager.execute(pd, cm, {"_set_hero_info": hero_list})
	var kit: Dictionary = GmManager.grant_test_kit(pd)
	GameData.save()
	print("[GM_INJECT] done level=", pd.team_level,
		" heroes=", pd.hero_manager.heroes.size(),
		" gold=", kit.get("gold"), " diamond=", kit.get("diamond"),
		" vitality=", kit.get("vitality"))
