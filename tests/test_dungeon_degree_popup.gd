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


# 照源 dungeon_map.lua:388-477 难度按钮只有 icon（无难度名 Label），难度区分由图标承担。
# 原项目自造 DIFF_LABELS/DIFF_COLORS + name_lbl 是无源发明，本轮照源移除。
func test_degree_button_has_no_name_label() -> void:
	var popup := DungeonDegreePopup.new("dungeonDegree", {})
	var vbox := popup._make_degree_button({"diff": 1, "unlock_level": 1, "vit": 10}, 1, true)
	# vbox 第 0 子是 TextureButton(btn)，btn 内只 icon(TextureRect)，不应有 Label
	var btn: TextureButton = vbox.get_child(0) as TextureButton
	assert_ne(btn, null, "vbox 首子为 TextureButton")
	var has_label_in_btn := false
	for i in range(btn.get_child_count()):
		if btn.get_child(i) is Label:
			has_label_in_btn = true
	assert_false(has_label_in_btn, "源 :388-477 难度按钮无难度名 Label（仅 icon + vit）")
	# btn 内有 icon TextureRect
	var has_icon := false
	for i in range(btn.get_child_count()):
		if btn.get_child(i) is TextureRect:
			has_icon = true
	assert_true(has_icon, "难度按钮含 icon TextureRect（源 :420-425）")
	popup.free()


# 照源 :376-382 text = boss.name or ""（无 fallback）；空名不显示"选择难度"自造文案。
func test_title_no_fallback_when_empty() -> void:
	var popup := DungeonDegreePopup.new("dungeonDegree", {})
	var diffs := [{"diff": 1, "unlock_level": 1, "vit": 10}]
	popup.setup_popup(1, "", diffs, 80)
	# container 首子是 frame Panel，frame 首子是 title Label
	var frame: Panel = popup.container.get_child(0) as Panel
	var title: Label = frame.get_child(0) as Label
	assert_eq(title.text, "", "源 :376-382 空名无 fallback（不自造选择难度）")
	popup.free()
