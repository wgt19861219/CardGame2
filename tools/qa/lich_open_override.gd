extends Node
## 一次性 QA override v2：主场景就绪后滚动主城地图到右段并打开 ch203 冰封王座面板
## （bridge 合成拖拽事件驱动不了视差 gui_input，走真实产品代码；bridge 截图验证用，
## 用后即 uninstall——照 gm_inject_override 惯例）。

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
		if _tries > 600:
			_disarm()
		return
	_disarm()
	# 滚动主城到右段（scroll 位置 clamp [-1388, 212]，取 -900 让 x1450 段进视口）
	var parallax: Object = scene.get("_parallax")
	if parallax != null and parallax.has_method("scroll_to"):
		parallax.scroll_to(-900.0, 0.0)
	await get_tree().create_timer(0.8).timeout
	MainSceneEntryRouter.open_lich_map(get_tree().current_scene)

func _disarm() -> void:
	_armed = false
	get_tree().process_frame.disconnect(_wait_and_act)
