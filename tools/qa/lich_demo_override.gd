extends Node
## 一次性 QA override：演示巫妖王换皮出场——内存注入 50028/50029 通关进度（不落存档，
## 重启即失效）+ 主场景就绪后滚动主城并打开 ch203 面板（截图取证用，用后即 uninstall）。

var _tries: int = 0
var _armed: bool = true


func _ready() -> void:
	get_tree().process_frame.connect(_wait_and_act)


func _wait_and_act() -> void:
	if not _armed:
		return
	_tries += 1
	var scene := get_tree().current_scene
	if scene == null or scene.name != "MainScene":
		if _tries > 900:
			_disarm()
		return
	_disarm()
	# 内存注入前置通关（演示解锁，不 save）
	var player = GameData.player
	player.stage_manager.progress[50028] = 1
	player.stage_manager.progress[50029] = 1
	print("[QA override] 演示进度已注入: 50028/50029 cleared")
	var parallax: Object = scene.get("_parallax")
	if parallax != null and parallax.has_method("scroll_to"):
		parallax.scroll_to(-900.0, 0.0)
	await get_tree().create_timer(0.8).timeout
	MainSceneEntryRouter.open_lich_map(get_tree().current_scene)


func _disarm() -> void:
	_armed = false
	get_tree().process_frame.disconnect(_wait_and_act)
