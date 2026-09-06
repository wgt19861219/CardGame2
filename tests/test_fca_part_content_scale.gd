extends GutTest

## FCA 散件 ÷ContentScale 守卫（船长详情比例修复专项 2026-09-03；特效族回退 2026-09-06）。
## ÷CS 仅 unit 傀儡/立绘族：散件线性系数 = 1/_coord_scale/PART_CONTENT_SCALE(1.28125)
##（MuMu 原版标定，缺 ÷CS 时人物横向偏宽 1.28×，验收记录-船长详情动画比例调查）。
## 特效族（eff_ 前缀）不 ÷CS：源/本项目资产 plist 同源（非 1.28× 高清重制），÷CS 致特效
## 缩小 22% 多散件错位——2026-09-06 宙斯大招"技能动画错乱"回归根修。
## 骨架间距 tx/ty 两族均不除 CS（散件中心锚原样）。

const COCO_DIR: String = "res://assets/anim_frames/Coco"
const ZEUS_ULT_EFF: String = "res://assets/anim_frames/effect/eff_impact_Zeus_ult.abc"


func _first_sprite_by_name(fca: FcaAnimation, part_name: String) -> int:
	for i: int in fca.get_child_count():
		if (fca.get_child(i) as Node).name == part_name:
			return i
	return -1


func test_part_linear_scale_divides_content_scale() -> void:
	var atlas := AtlasSprite.new()
	assert_true(atlas.load_atlas(COCO_DIR + "/sheet.plist"), "Coco atlas 加载")
	var fca := FcaAnimation.new()
	add_child_autofree(fca)
	assert_true(fca.load_from_ani("Coco", atlas), "Coco.ani 加载")

	# 定位无旋转散件 TorsoTop（_sprites 建序与 _elements 同）
	var idx: int = _first_sprite_by_name(fca, "TorsoTop")
	assert_gt(idx, -1, "TorsoTop 散件存在")

	# 伪造单位仿射帧（a=d=1, b=c=0）：断言线性系数与 origin 语义
	var frame: Dictionary = {"elements": [
		{"idx": idx + 1, "alpha": 255, "a": 1.0, "b": 0.0, "c": 0.0, "d": 1.0, "tx": 100.0, "ty": 50.0},
	]}
	fca._apply_frame(frame)
	var s: Sprite2D = fca.get_child(idx) as Sprite2D
	var expected: float = 1.0 / FcaAnimation.BATTLE_SCALE / FcaAnimation.PART_CONTENT_SCALE
	assert_almost_eq(s.transform.x.x, expected, 0.0001, "unit 族线性 x.x = 1/0.09/CS（散件÷CS）")
	assert_almost_eq(s.transform.y.y, expected, 0.0001, "unit 族线性 y.y = 1/0.09/CS")
	assert_almost_eq(s.transform.x.y, 0.0, 0.0001, "b 分量原样（无翻转）")
	assert_almost_eq(s.transform.origin.x, 100.0, 0.0001, "tx 不除 CS（骨架间距原样）")
	assert_almost_eq(s.transform.origin.y, 50.0, 0.0001, "ty 不除 CS")


func test_effect_part_linear_scale_skips_content_scale() -> void:
	# 宙斯大招特效（eff_ 前缀，effect/ 目录）：线性系数不÷CS（2026-09-06 回归根修）
	var atlas := AtlasSprite.new()
	assert_true(atlas.load_atlas_from_ani(ZEUS_ULT_EFF), "Zeus ult atlas 加载")
	var fca := FcaAnimation.new()
	add_child_autofree(fca)
	assert_true(fca.load_from_ani("eff_impact_Zeus_ult", atlas), "eff_impact_Zeus_ult 加载")

	var idx: int = _first_sprite_by_name(fca, "dsgasdfhg")
	assert_gt(idx, -1, "首散件存在")

	var frame: Dictionary = {"elements": [
		{"idx": idx + 1, "alpha": 255, "a": 1.0, "b": 0.0, "c": 0.0, "d": 1.0, "tx": 100.0, "ty": 50.0},
	]}
	fca._apply_frame(frame)
	var s: Sprite2D = fca.get_child(idx) as Sprite2D
	var expected: float = 1.0 / FcaAnimation.BATTLE_SCALE
	assert_almost_eq(s.transform.x.x, expected, 0.0001, "特效族线性 x.x = 1/0.09（不÷CS）")
	assert_almost_eq(s.transform.y.y, expected, 0.0001, "特效族线性 y.y = 1/0.09")
	assert_almost_eq(s.transform.origin.x, 100.0, 0.0001, "tx 原样")
	assert_almost_eq(s.transform.origin.y, 50.0, 0.0001, "ty 原样")


func test_content_scale_constant_is_128125() -> void:
	# 系数与项目 ContentScaleFactor 同源（100/78.048775…，TextureConfig 体系）；防误改成 1.0/1.28 等
	assert_almost_eq(FcaAnimation.PART_CONTENT_SCALE, 1.28125, 0.00001, "PART_CONTENT_SCALE = 1.28125")
