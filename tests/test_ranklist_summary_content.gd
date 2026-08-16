extends GutTest
## ranklist_summary_content.tscn 守卫（批 2 Task 8：Frame NinePatch 化）。
## 源 userpvpsummary.lua:29 Scale9Sprite main_vit_tips.png capInsets DGRectMake(20,20,55,25)×0.78125
## = CCRectMake(15.625,15.625,42.969,19.531)，贴图 103×61 PIL 实测
## → left=15.625≈16 / bottom=15.625≈16 / right=103-15.625-42.969≈44 / top=61-15.625-19.531≈26（批 1 fde903b 公式）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/ranklist_summary_content.tscn")


func test_frame_is_ninepatch_with_source_margins() -> void:
	var content := CONTENT_SCENE.instantiate() as Control
	add_child(content)
	var frame: NinePatchRect = content.get_node("Frame") as NinePatchRect
	assert_not_null(frame, "Frame 节点为 NinePatchRect（源 Scale9Sprite 九宫格）")
	assert_eq(frame.patch_margin_left, 16, "patch_margin_left=16（DG cap x=15.625）")
	assert_eq(frame.patch_margin_top, 26, "patch_margin_top=26（H-y-h=61-15.625-19.531）")
	assert_eq(frame.patch_margin_right, 44, "patch_margin_right=44（W-x-w=103-15.625-42.969）")
	assert_eq(frame.patch_margin_bottom, 16, "patch_margin_bottom=16（DG cap y=15.625）")
	assert_eq(frame.size, Vector2(345.0, 305.0), "显示尺寸 345×305 保持（源 DGSizeMake(345,305)）")
	content.queue_free()
