class_name RanklistSummary
extends PopWindow

## 排行榜摘要弹窗（View 层）— 照源 ranklist/userpvpsummary.lua create :18-207。
## main_vit_tips frame 345×305 + 头像 + name/level + 上轮排名 + 总战力。
## NPC 假数据简化：源 win_cnt/heroes(5 英雄图标)/guild 目标 NPC 无数据，跳过（下轮 NPC 假数据扩展）。
## 坐标源 ccp(400,240) → 目标 _to_godot(480,320) → frame 左上。
##
## 重构（2026-07-18，hero_detail 范式）：frame + 5 Label 静态化进
## scenes/ui/ranklist_summary_content.tscn（位置/size 编辑器可视化调）；avatar 动态（按 avatar id
## 查 Avatar.Picture）保留 procedural 挂 %AvatarHost（pos=0,0 保持子组件局部坐标系不变）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/ranklist_summary_content.tscn")
# 源 :54-58 head fix_size DGSizeMake(65,65)=(50.78,50.78) 点（批4 Task 8 DG×0.78125 修正）。
const HEAD_SIZE: Vector2 = Vector2(50.78, 50.78)

var _cm: Variant


func setup_panel(p_name: String, level: int, param: int, avatar: int, rank: int, cm: Variant) -> void:
	_cm = cm
	setup()
	_build(p_name, level, param, avatar, rank)


func _build(p_name: String, level: int, param: int, avatar: int, rank: int) -> void:
	shade_layer.gui_input.connect(_on_shade_input)
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	(content.get_node("%NameLabel") as Label).text = p_name + " Lv" + str(level)
	(content.get_node("%LastRankValueLabel") as Label).text = str(rank)
	(content.get_node("%PowerValueLabel") as Label).text = str(param)
	_fill_avatar(content, avatar)


# avatar 动态加载（源 :54-65 fix_size 65 + Avatar.Picture），保留 procedural 挂 %AvatarHost。
func _fill_avatar(content: Node, avatar: int) -> void:
	if _cm == null:
		return
	var pic: String = String(_cm.get_raw_table(&"Avatar").get(str(avatar), {}).get("Picture", ""))
	if pic.is_empty():
		return
	var head_path: String = "res://assets/ui/" + pic.substr(3)
	if not ResourceLoader.exists(head_path):
		return
	var host: Control = content.get_node("%AvatarHost") as Control
	var head := TextureRect.new()
	head.texture = load(head_path)
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.size = HEAD_SIZE
	head.position = Vector2.ZERO
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(head)


func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		remove_window()
