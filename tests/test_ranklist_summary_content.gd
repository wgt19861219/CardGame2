extends GutTest
## ranklist_summary_content.tscn 守卫。
## 源 userpvpsummary.lua:18-207：frame Scale9Sprite main_vit_tips.png
## capInsets DGRectMake(20,20,55,25) = CCRectMake(15.625,15.625,42.969,19.531)，贴图 103×61 PIL 实测
## → left=15.625≈16 / bottom=15.625≈16 / right=103-15.625-42.969≈44 / top=61-15.625-19.531≈26（批 1 fde903b 公式）。
## 批4 Task 8 修正（批2 滚清单"ranklist Frame DG 直译尺寸复核"落地）：
## scaleSize = ed.DGSizeMake(345,305) = (269.53,238.28) 点（readnode.lua:178-179 setContentSize
## 直译，DGSizeMake ×0.78125 已含）→ 旧 345×305 为 DG 值未乘系数，本批修正为 270×238。
## 子元素同口径：DGccp(x,y)=(x,y)×0.78125 点 + content 层 y-up → Godot y_down = 238.28-y_up。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/ranklist_summary_content.tscn")
const THEME_PATH: String = "res://resources/themes/default_theme.tres"


func _instantiate() -> Control:
	var content := CONTENT_SCENE.instantiate() as Control
	add_child(content)
	return content


func test_frame_is_ninepatch_with_source_margins() -> void:
	var content := _instantiate()
	var frame: NinePatchRect = content.get_node("Frame") as NinePatchRect
	assert_not_null(frame, "Frame 节点为 NinePatchRect（源 Scale9Sprite 九宫格）")
	assert_eq(frame.patch_margin_left, 16, "patch_margin_left=16（DG cap x=15.625）")
	assert_eq(frame.patch_margin_top, 26, "patch_margin_top=26（H-y-h=61-15.625-19.531）")
	assert_eq(frame.patch_margin_right, 44, "patch_margin_right=44（W-x-w=103-15.625-42.969）")
	assert_eq(frame.patch_margin_bottom, 16, "patch_margin_bottom=16（DG cap y=15.625）")
	assert_eq(frame.size, Vector2(270.0, 238.0), "显示尺寸 270×238（源 DGSizeMake(345,305)×0.78125=269.53×238.28）")
	content.queue_free()


# 源 frame pos ccp(400,240) 中心锚 → Godot 中心 (480,320) → rect (345.23,200.86)-(614.77,439.14)。
func test_frame_position_centered() -> void:
	var content := _instantiate()
	var frame: NinePatchRect = content.get_node("Frame") as NinePatchRect
	assert_eq(frame.position, Vector2(345.0, 201.0), "frame 左上 (345,201)（中心 (480,320)）")
	content.queue_free()


# 子元素坐标 = DGccp×0.78125 点 + y 翻转（content 层 y-up，Frame 高 238.28）：
# head DGccp(52,272)=(40.63,212.5) 中心 → (15.24,0.39)-(66.02,51.17)；
# gsTitle DGccp(30,134)=(23.44,104.69) 左中 → 中心线 y=238.28-104.69=133.59 → top=121.59；
# gs DGccp(162,134)=(126.56,104.69) 左中 → (126.56,121.59)。
func test_summary_children_source_layout() -> void:
	var content := _instantiate()
	var frame: NinePatchRect = content.get_node("Frame") as NinePatchRect
	var host: Control = frame.get_node("%AvatarHost") as Control
	assert_not_null(host, "AvatarHost 存在（head 动态挂载位）")
	assert_almost_eq(host.position.x, 15.24, 0.5, "AvatarHost x≈15.24（源 DGccp(52,272)×0.78125）")
	assert_almost_eq(host.position.y, 0.39, 0.5, "AvatarHost y≈0.39（y 翻转 238.28-212.5-25.39）")
	assert_eq(host.size, Vector2(51.0, 51.0), "AvatarHost 51×51（源 fix_size DGSizeMake(65,65)×0.78125）")
	var power_title: Label = frame.get_node("%PowerTitleLabel") as Label
	assert_almost_eq(power_title.position.x, 23.44, 0.5,
		"总战力 title x≈23.44（源 DGccp(30,134)×0.78125 左锚）")
	assert_almost_eq(power_title.position.y, 121.59, 0.5,
		"总战力 title y≈121.59（y 翻转 238.28-104.69-12）")
	var power_value: Label = frame.get_node("%PowerValueLabel") as Label
	assert_almost_eq(power_value.position.x, 126.56, 0.5, "总战力 value x≈126.56（源 DGccp(162,134)）")
	content.queue_free()


# 两件套 SOP：字号/颜色走 theme_type_variation，tscn theme_override 清零。
# 源色：title 系 ccc3(255,204,118)、value 系 ccc3(247,236,198)、name 白 18（无描边）。
func test_summary_labels_use_variations() -> void:
	var content := _instantiate()
	var frame: NinePatchRect = content.get_node("Frame") as NinePatchRect
	assert_eq(String((frame.get_node("%LastRankTitleLabel") as Label).theme_type_variation),
		"RanklistSummaryTitleLabel", "上轮排名 title 走 variation")
	assert_eq(String((frame.get_node("%PowerTitleLabel") as Label).theme_type_variation),
		"RanklistSummaryTitleLabel", "总战力 title 走 variation")
	assert_eq(String((frame.get_node("%LastRankValueLabel") as Label).theme_type_variation),
		"RanklistSummaryValueLabel", "排名 value 走 variation")
	assert_eq(String((frame.get_node("%PowerValueLabel") as Label).theme_type_variation),
		"RanklistSummaryValueLabel", "战力 value 走 variation")
	assert_eq(String((frame.get_node("%NameLabel") as Label).theme_type_variation),
		"RanklistWhiteLabel18", "name 白 18 走 variation（无描边，非 WhiteLabel18）")
	content.queue_free()
	var tscn_text: String = FileAccess.get_file_as_string("res://scenes/ui/ranklist_summary_content.tscn")
	assert_eq(tscn_text.count("theme_override_colors"), 0, "tscn 无 font_color override")
	assert_eq(tscn_text.count("theme_override_font_sizes"), 0, "tscn 无 font_size override")
