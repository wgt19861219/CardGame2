extends Node
## 一次性 QA override：主城场景中央 spawn 一个 LichKing FcaAnimation 播 Idle——
## 引擎内真渲染验证换皮资产（离线渲染器 vs 引擎渲染错位归属判定）。用后即 uninstall。

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
	var atlas := AtlasSprite.new()
	var ok_atlas: bool = atlas.load_atlas("res://assets/anim_frames/LichKing/sheet.plist")
	var fca := FcaAnimation.new()
	scene.add_child(fca)
	fca.position = Vector2(400, 300)
	fca.scale = Vector2(2.0, 2.0)
	var ok_fca: bool = fca.load_from_ani("LichKing", atlas)
	fca.play("Idle")
	print("[QA actor preview] atlas=", ok_atlas, " fca=", ok_fca, " actions=", fca.get_action_names())


func _disarm() -> void:
	_armed = false
	get_tree().process_frame.disconnect(_wait_and_act)
