extends GutTest
# equipstrengthen 6 槽布局测试（照源 getEquipPos:1566-1575，2列3行）。
# 源 cocos (ox=235, oy=405) 左下原点 → Godot to_godot(cx+80, 560-cy)。i=1,2 第1行；3,4 第2行；5,6 第3行。

func test_get_equip_pos_2cols_3rows() -> void:
	var panel := EquipStrengthenPanel.new()
	# 源 1-based i=1 中心 cocos(235,405) → Godot to_godot(235+80, 560-405)=(315,155)
	assert_eq(EquipStrengthenAtt.get_equip_pos(0), Vector2(315.0, 155.0), "i=1 第1行左 (315,155)")
	assert_eq(EquipStrengthenAtt.get_equip_pos(1), Vector2(387.0, 155.0), "i=2 第1行右 (387,155)")
	assert_eq(EquipStrengthenAtt.get_equip_pos(2), Vector2(315.0, 227.0), "i=3 第2行左 (315,227)")
	assert_eq(EquipStrengthenAtt.get_equip_pos(3), Vector2(387.0, 227.0), "i=4 第2行右 (387,227)")
	assert_eq(EquipStrengthenAtt.get_equip_pos(4), Vector2(315.0, 299.0), "i=5 第3行左 (315,299)")
	assert_eq(EquipStrengthenAtt.get_equip_pos(5), Vector2(387.0, 299.0), "i=6 第3行右 (387,299)")
	panel.free()


func test_get_equip_pos_spacing() -> void:
	var panel := EquipStrengthenPanel.new()
	# 列间距 dx=72：同行 i=0 vs i=1
	var delta_x: float = EquipStrengthenAtt.get_equip_pos(1).x - EquipStrengthenAtt.get_equip_pos(0).x
	assert_eq(delta_x, 72.0, "列间距 dx=72（源 getEquipPos:1568）")
	# 行间距 dy=72：同列 i=0 vs i=2（Godot y 向下，行增 y 增 = 源 cocos y 减的镜像）
	var delta_y: float = EquipStrengthenAtt.get_equip_pos(2).y - EquipStrengthenAtt.get_equip_pos(0).y
	assert_eq(delta_y, 72.0, "行间距 dy=72")
	panel.free()


# 6 槽 i=0..5 全覆盖，确认 2列3行无越界/重复。
func test_get_equip_pos_all_6_slots() -> void:
	var panel := EquipStrengthenPanel.new()
	var positions: Array[Vector2] = []
	for i in 6:
		positions.append(EquipStrengthenAtt.get_equip_pos(i))
	# 6 个位置唯一（无重叠）
	var unique: int = 0
	for i in positions.size():
		for j in positions.size():
			if i != j and positions[i].is_equal_approx(positions[j]):
				unique += 1
	assert_eq(unique, 0, "6 槽位置全唯一（无重叠）")
	panel.free()
