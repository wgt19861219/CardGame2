extends GutTest

## ui_scale9_button capInsets 垂直换算守卫（批 2，源 CCRect 左下原点）。
## 正确公式：top = H-y-h / bottom = y（对照 equipboard_panel.gd 先例，批 1 commit fde903b 同族修复）。

const BUTTON_SCRIPT := "res://scripts/ui/ui_scale9_button.gd"


func test_capinsets_vertical_formula() -> void:
	var text: String = FileAccess.get_file_as_string(BUTTON_SCRIPT)
	assert_not_null(text)
	# 正确公式：top = tex.h-y-h（源左下原点翻到 Godot 左上原点）；2026-08-22 巡检起四边
	# margin 再 ÷CS 取整（cap px 纹理口径→显示点，shortcut/battle_statistics 双先例）。
	assert_true(text.contains("- cap_insets.position.y - cap_insets.size.y"),
		"margin_top 须为 H-y-h 形态（当前疑似 top=y 的互换错误）")
	assert_true(text.contains("texture_margin_bottom = int(cap_insets.position.y / CONTENT_SCALE)"),
		"margin_bottom 须为 y÷CS 形态（防互换回退 + 防丢 ÷CS 回退）")
