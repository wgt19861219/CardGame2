extends GutTest
# rotate timeline 角度最短路径插值测试。
# 根因：spine_skeleton 数值线性插值，帧对 [0→347.45] 被当 +347.45° 绕远路旋转
# （实测 shop bone2 每 6 秒狂扫 354°），Spine 官方 runtime（spine-c RotateTimeline）
# 语义是最短路径（diff 归一化 [-180,180)，0→347.45 走 -12.55°）。
# 受影响资产（相邻帧差>180 扫描）：eff_UI_Main_Shop/Shop2/Mailbox/Guard + tutorial_head_cm。

const SPINE_DIR: String = "res://assets/spine/eff_UI_Main_Shop"
const RES_NAME: String = "eff_UI_Main_Shop"


func _shop_bone2_timeline() -> Array:
	var sk := SpineSkeleton.new()
	add_child(sk)
	assert_true(sk.load_skeleton(SPINE_DIR, RES_NAME), "load_skeleton 成功")
	var anim: Dictionary = sk._data.animations.get("Loop", {})
	var timeline: Array = anim.get("bones", {}).get("bone2", {}).get("rotate", [])
	assert_eq(timeline.size(), 12, "shop bone2 rotate 12 帧")
	sk.queue_free()
	return timeline


func test_wrap_pair_interpolates_shortest_path() -> void:
	# 帧对 [t=0:0°, t=1:347.45°]（shop 实测帧）：中点插值必在 [-12.55°, 0] 内，
	# 线性插值 bug 版会扫过 100°+（视觉即建筑抽搐自旋）。
	var timeline: Array = _shop_bone2_timeline()
	var mid: float = SpineSkeleton.new()._interp_angle(timeline, 0.5)
	assert_between(mid, -12.55, 0.0, "中点插值走最短路径 [-12.55, 0]")


func test_wrap_pair_end_value_wrapped() -> void:
	# t 越过帧 1（347.45°）后进入帧 2（358.45°）区间：358.45-347.45=11 无环绕，直接线性
	var timeline: Array = _shop_bone2_timeline()
	var v: float = SpineSkeleton.new()._interp_angle(timeline, 1.25)
	assert_between(v, 347.45, 358.45, "无环绕帧对正常线性")


func test_backward_wrap() -> void:
	# 反向环绕：[-342°, 0°]（tutorial_head_cm 实测帧对）差值 -355.9 等效 +4.1，
	# 最短路径 = -18°（-342-18=-360≡0），中点 = -342-9 = -351
	var timeline: Array = [
		{"time": 0.0, "angle": -342.0, "curve": "linear"},
		{"time": 1.0, "angle": 0.0, "curve": "linear"},
	]
	var sk := SpineSkeleton.new()
	var mid: float = sk._interp_angle(timeline, 0.5)
	assert_almost_eq(mid, -351.0, 0.001, "反向环绕走 -18° 最短路径")


func test_normal_pair_no_wrap() -> void:
	var timeline: Array = [
		{"time": 0.0, "angle": 10.0, "curve": "linear"},
		{"time": 2.0, "angle": 40.0, "curve": "linear"},
	]
	var sk := SpineSkeleton.new()
	assert_almost_eq(sk._interp_angle(timeline, 1.0), 25.0, 0.001, "普通帧对不受影响")
	assert_almost_eq(sk._interp_angle(timeline, 0.5), 17.5, 0.001, "前半段")
	assert_almost_eq(sk._interp_angle(timeline, 2.0), 40.0, 0.001, "末帧")


func test_full_circle_increment() -> void:
	# 摆动模式（mailbox bone3 / Shop2 bone：0↔355.9 反复）官方语义 = 在 0° 与 -4.1° 间
	# 来回摆动（两段都走最短 ±4.1°），修复前每段狂扫 355.9°
	var timeline: Array = [
		{"time": 0.0, "angle": 0.0, "curve": "linear"},
		{"time": 1.0, "angle": 355.9, "curve": "linear"},
		{"time": 2.0, "angle": 0.0, "curve": "linear"},
	]
	var sk := SpineSkeleton.new()
	assert_between(sk._interp_angle(timeline, 0.5), -4.1, 0.0, "第一段 0→355.9 走 -4.1°")
	assert_between(sk._interp_angle(timeline, 1.5), 355.9, 360.0, "第二段 355.9→0 走 +4.1° 回摆")


func test_setup_plus_interp_applied_to_bone() -> void:
	# 集成：play 后 _apply 应用最短路径插值到骨骼（setup bone2=-90.45°，t=0.5 时
	# rotation ∈ setup+[-12.55°, 0]），bug 版会到 setup+170°+
	var sk := SpineSkeleton.new()
	add_child(sk)
	sk.load_skeleton(SPINE_DIR, RES_NAME)
	sk.play("Loop", true)
	sk._apply(0.5)
	var bone2: Node2D = sk._bone_nodes["bone2"]
	var setup_deg: float = rad_to_deg(float(sk._setup_rot["bone2"]))
	var cur_deg: float = rad_to_deg(bone2.rotation)
	var delta_deg: float = cur_deg - setup_deg
	assert_between(delta_deg, -13.0, 0.5, "骨骼应用插值后相对 setup 在 [-13°, 0.5°]")
	sk.queue_free()
