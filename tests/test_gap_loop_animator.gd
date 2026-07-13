extends GutTest
# GapLoopAnimator resetGap 公式测试（照源 ui/main.lua:455-460）。
# _reset_gap 不依赖 SpineSkeleton（_sk=null），可 headless 纯 Logic 测。

# shop: gap 2.75-2.75（gg=0 无 spread），loop_gap 1.71 × 2-6 次。
func test_reset_gap_shop_no_spread() -> void:
	var anim := GapLoopAnimator.new()
	anim.setup(null, 2.75, 2.75, 1.71, 2, 6)
	anim._reset_gap()
	# gg=0 → gt=0；timer = 0 + 2.75 + 1.71*random(2,6) ∈ [6.17, 13.01]
	assert_between(anim._timer, 6.16, 13.02, "shop gap timer（gg=0 + loop）")


# ssshop: gap 2-4（gg=2 spread），loop_gap 0。
func test_reset_gap_ssshop_spread_no_loop() -> void:
	var anim := GapLoopAnimator.new()
	anim.setup(null, 2.0, 4.0, 0.0, 0, 0)
	anim._reset_gap()
	# gg=2 → gt=random(0,2)；lt=0；timer = 2*gt + 2 + 0 ∈ [2, 6]
	assert_between(anim._timer, 2.0, 6.0, "ssshop gap timer（gg=2 spread）")


# sshop: gap 1.46-1.46 + loop_gap 1.46 × 1-6。
func test_reset_gap_sshop_loop() -> void:
	var anim := GapLoopAnimator.new()
	anim.setup(null, 1.46, 1.46, 1.46, 1, 6)
	anim._reset_gap()
	# gg=0 → gt=0；timer = 0 + 1.46 + 1.46*random(1,6) ∈ [2.92, 10.22]
	assert_between(anim._timer, 2.91, 10.23, "sshop gap timer（loop）")


# 边界：全 0（无 gap 无 loop，真实不建 animator，验证公式鲁棒）。
func test_reset_gap_zero() -> void:
	var anim := GapLoopAnimator.new()
	anim.setup(null, 0.0, 0.0, 0.0, 0, 0)
	anim._reset_gap()
	assert_eq(anim._timer, 0.0, "无 gap 无 loop timer=0")
