extends GutTest

## DungeonDegreePopup 难度弹窗验证。
# P1-13（2026-07-11）：vit_bg + vit_icon + ScaleTo 入场动画（源 dungeon_map.lua:427-489）。

# P1-13：vit 行含 vit_number(Label) + vit_bg(TextureRect) + vit_icon(TextureRect)。
func test_vit_row_has_three_nodes() -> void:
	var popup := DungeonDegreePopup.new("dungeonDegree", {})
	# _make_vit_row 不依赖 setup（不进树），直接测节点结构
	var row := popup._make_vit_row({"vit": 10}, true)
	assert_eq(row.get_child_count(), 3, "vit 行含 vit_num + vit_bg + vit_icon 3 节点")
	var has_label := false
	var tex_count := 0
	for i in range(row.get_child_count()):
		var child: Node = row.get_child(i)
		if child is Label:
			has_label = true
		elif child is TextureRect:
			tex_count += 1
	assert_true(has_label, "vit 行含体力数值 Label")
	assert_eq(tex_count, 2, "vit 行含 vit_bg + vit_icon 2 个 TextureRect")
	popup.free()


# P1-13：setup_popup 含 _play_entrance_scale（is_inside_tree 守卫，未入树跳过 tween）。
func test_setup_popup_does_not_crash() -> void:
	var popup := DungeonDegreePopup.new("dungeonDegree", {})
	var diffs := [{"diff": 1, "unlock_level": 1, "vit": 10}, {"diff": 2, "unlock_level": 1, "vit": 20}]
	popup.setup_popup(1, "test_boss", diffs, 80)
	assert_gt(popup.container.get_child_count(), 0, "setup_popup 装配子节点（frame/close/按钮/vit）")
	popup.free()
