extends GutTest

## FCA 散件 ÷ContentScale 守卫（船长详情比例修复专项 2026-09-03）。
## FCA 散件纹理系 1.28× 高清资产，线性系数须 = 1/_coord_scale/PART_CONTENT_SCALE(1.28125)；
## 缺 ÷CS 时人物横向系统性偏宽（帽宽/身高 1.00 vs 原版 0.72，验收记录-船长详情动画比例调查）。
## 骨架间距 tx/ty 不除 CS（散件中心锚原样）。

const COCO_DIR: String = "res://assets/anim_frames/Coco"


func test_part_linear_scale_divides_content_scale() -> void:
	var atlas := AtlasSprite.new()
	assert_true(atlas.load_atlas(COCO_DIR + "/sheet.plist"), "Coco atlas 加载")
	var fca := FcaAnimation.new()
	add_child_autofree(fca)
	assert_true(fca.load_from_ani("Coco", atlas), "Coco.ani 加载")

	# 定位无旋转散件 TorsoTop（_sprites 建序与 _elements 同）
	var idx: int = -1
	for i: int in fca.get_child_count():
		if (fca.get_child(i) as Node).name == "TorsoTop":
			idx = i
			break
	assert_gt(idx, -1, "TorsoTop 散件存在")

	# 伪造单位仿射帧（a=d=1, b=c=0）：断言线性系数与 origin 语义
	var frame: Dictionary = {"elements": [
		{"idx": idx + 1, "alpha": 255, "a": 1.0, "b": 0.0, "c": 0.0, "d": 1.0, "tx": 100.0, "ty": 50.0},
	]}
	fca._apply_frame(frame)
	var s: Sprite2D = fca.get_child(idx) as Sprite2D
	var expected: float = 1.0 / FcaAnimation.BATTLE_SCALE / FcaAnimation.PART_CONTENT_SCALE
	assert_almost_eq(s.transform.x.x, expected, 0.0001, "线性 x.x = 1/0.09/CS（散件÷CS）")
	assert_almost_eq(s.transform.y.y, expected, 0.0001, "线性 y.y = 1/0.09/CS")
	assert_almost_eq(s.transform.x.y, 0.0, 0.0001, "b 分量原样（无翻转）")
	assert_almost_eq(s.transform.origin.x, 100.0, 0.0001, "tx 不除 CS（骨架间距原样）")
	assert_almost_eq(s.transform.origin.y, 50.0, 0.0001, "ty 不除 CS")


func test_content_scale_constant_is_128125() -> void:
	# 系数与项目 ContentScaleFactor 同源（100/78.048775…，TextureConfig 体系）；防误改成 1.0/1.28 等
	assert_almost_eq(FcaAnimation.PART_CONTENT_SCALE, 1.28125, 0.00001, "PART_CONTENT_SCALE = 1.28125")
