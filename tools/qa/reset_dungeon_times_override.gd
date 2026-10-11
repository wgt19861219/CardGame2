extends Node
## QA override：启动即清 ch203 副本计次（50022-50030 base 键），测试包随包 autoload
## 免每日次数限制（测试语义；正式包不带）。与 open_lichmap/gm_max override 共存。


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var pd = GameData.player
	if pd == null or pd.get("stage_manager") == null:
		return
	var mgr = pd.stage_manager
	var cleared: int = 0
	for sid in range(50022, 50031):
		if int(mgr.act_times.get(sid, 0)) > 0:
			mgr.act_times.erase(sid)
			cleared += 1
	if cleared > 0:
		GameData.save()
		print("[QA reset_dungeon_times] cleared=", cleared)
