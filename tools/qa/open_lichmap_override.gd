extends Node
## 一次性调试 override：等 MainScene 就绪后自动打开冰封王座地图面板（bridge 实机验证用）


func _ready() -> void:
	var waited := 0
	while waited < 600:
		await get_tree().process_frame
		waited += 1
		var s := get_tree().current_scene
		if s != null and s.name == "MainScene":
			# 再等主城构建完成（_ready 异步资源装帧）
			await get_tree().create_timer(1.5).timeout
			MainSceneEntryRouter.open_lich_map(get_tree().current_scene)
			break
	queue_free()
