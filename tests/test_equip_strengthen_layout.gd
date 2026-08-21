extends GutTest
# equipstrengthen 6 槽布局测试（照源 getEquipPos:1566-1575，2列3行）。
# 源 cocos (ox=235, oy=405) 左下原点 → Godot to_godot(cx+80, 560-cy)。i=1,2 第1行；3,4 第2行；5,6 第3行。
# 两件套 Task 5（2026-08-15）：槽位静态化进 equip_strengthen_content.tscn（%EquipSlot0-5 host
# + EmptyRect gocha 占位），断言从 EquipStrengthenAtt.get_equip_pos 纯函数改为 tscn host rect。

const CS: float = 1.28125


func _instantiate_content() -> Control:
	var scene: PackedScene = load("res://scenes/ui/equip_strengthen_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	return inst


func _slot_center(inst: Control, i: int) -> Vector2:
	var host: Control = inst.get_node("%EquipSlot" + str(i)) as Control
	return Vector2((host.offset_left + host.offset_right) / 2.0, (host.offset_top + host.offset_bottom) / 2.0)


func test_slot_hosts_2cols_3rows() -> void:
	var inst: Control = _instantiate_content()
	# 源 1-based i=1 中心 cocos(235,405) → Godot to_godot(235+80, 560-405)=(315,155)
	assert_almost_eq(_slot_center(inst, 0).x, 235.0, 0.5, "i=1 第1行左 (315,155)")
	assert_almost_eq(_slot_center(inst, 0).y, 75.0, 0.5, "i=1 第1行左 y=155")
	assert_almost_eq(_slot_center(inst, 1).x, 307.0, 0.5, "i=2 第1行右 (387,155)")
	assert_almost_eq(_slot_center(inst, 2).y, 147.0, 0.5, "i=3 第2行左 y=227")
	assert_almost_eq(_slot_center(inst, 3).x, 307.0, 0.5, "i=4 第2行右 (387,227)")
	assert_almost_eq(_slot_center(inst, 4).y, 219.0, 0.5, "i=5 第3行左 y=299")
	assert_almost_eq(_slot_center(inst, 5).x, 307.0, 0.5, "i=6 第3行右 (387,299)")


func test_slot_hosts_spacing() -> void:
	var inst: Control = _instantiate_content()
	# 列间距 dx=72：同行 i=0 vs i=1（源 getEquipPos:1568）
	var delta_x: float = _slot_center(inst, 1).x - _slot_center(inst, 0).x
	assert_almost_eq(delta_x, 72.0, 0.5, "列间距 dx=72（源 getEquipPos:1568）")
	# 行间距 dy=72：同列 i=0 vs i=2（Godot y 向下，行增 y 增 = 源 cocos y 减的镜像）
	var delta_y: float = _slot_center(inst, 2).y - _slot_center(inst, 0).y
	assert_almost_eq(delta_y, 72.0, 0.5, "行间距 dy=72")


# 6 槽 i=0..5 全覆盖，确认 2列3行无越界/重复。
func test_slot_hosts_all_6_unique() -> void:
	var inst: Control = _instantiate_content()
	var positions: Array[Vector2] = []
	for i in 6:
		positions.append(_slot_center(inst, i))
	# 6 个位置唯一（无重叠）
	var dup: int = 0
	for i in positions.size():
		for j in positions.size():
			if i != j and positions[i].is_equal_approx(positions[j]):
				dup += 1
	assert_eq(dup, 0, "6 槽位置全唯一（无重叠）")


# 源 createEquip:1595/1615 空槽 gocha.png 94×95（readnode 默认中心锚）→ 显示 94/CS×95/CS
func test_slot_empty_rect_gocha_size() -> void:
	var inst: Control = _instantiate_content()
	var empty: TextureRect = inst.get_node("%EquipSlot0/EmptyRect") as TextureRect
	assert_not_null(empty.texture, "空槽占位 gocha 贴图接线")
	assert_almost_eq(empty.offset_right - empty.offset_left, 94.0 / CS, 0.5, "空槽占位宽=94/CS")
	assert_almost_eq(empty.offset_bottom - empty.offset_top, 95.0 / CS, 0.5, "空槽占位高=95/CS")
