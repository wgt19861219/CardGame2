extends GutTest

## 主菜单入口闭环集成测试（照源 main.lua:1305 getMainButtonHandler 分发）。
# tavern/crusade 接已有 Panel；联机玩法走 Toast 不崩。headless 验点击→Panel 弹出。
# 注：不用 await wait_frames（GUT 9.6.0 deprecated + 全量跑时序假阳性）；_ready 在 add_child 同步触发。

const MAIN_SCENE_PATH: String = "res://scenes/main_menu/main_scene.tscn"

var _scene: Control


func before_each() -> void:
	_scene = load(MAIN_SCENE_PATH).instantiate()
	add_child(_scene)   # _ready 同步跑完（建地图/状态栏/Events 订阅）


func after_each() -> void:
	if is_instance_valid(_scene):
		_scene.queue_free()


func test_tavern_entry_opens_panel() -> void:
	assert_true(is_instance_valid(_scene), "main_scene 实例有效")
	var before: int = _scene.get_child_count()
	_scene._on_entry_pressed("tavern")
	var after: int = _scene.get_child_count()
	assert_true(after > before, "tavern 入口应往 main_scene 加 TavernPanel（before=%d after=%d）" % [before, after])


func test_volcano_entry_opens_panel() -> void:
	assert_true(is_instance_valid(_scene), "main_scene 实例有效")
	var before: int = _scene.get_child_count()
	_scene._on_entry_pressed("volcano")
	var after: int = _scene.get_child_count()
	assert_true(after > before, "volcano 入口应往 main_scene 加 CrusadePanel（源 volcano=Crusade 远征）（before=%d after=%d）" % [before, after])


func test_unknown_entry_no_crash() -> void:
	_scene._on_entry_pressed("ranklist")
	_scene._on_entry_pressed("pvp")
	_scene._on_entry_pressed("nonsense_id")
	assert_true(true, "未知/裁剪入口走 Toast 分支不崩")


# B4 入口接线（第九轮 P1-B4）：estren → EquipStrengthenPanel 打开
# （照源 ui/main.lua:1424-1434 pushScene equipstrengthen.create 独立场景可达）。
# 直接测 _open_equip_strengthen（unlock 检查由 _on_entry_pressed 上游负责，此处聚焦入口可达性）。
func test_estren_entry_opens_panel() -> void:
	assert_true(is_instance_valid(_scene), "main_scene 实例有效")
	var before: int = _scene.get_child_count()
	_scene._open_equip_strengthen()
	var after: int = _scene.get_child_count()
	assert_true(after > before, "estren → EquipStrengthenPanel 打开（源 pushScene equipstrengthen.create）（before=%d after=%d）" % [before, after])
