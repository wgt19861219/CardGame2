extends GutTest

## 主界面建筑 FCA/Spine 图标尺寸守卫（fca-scale-fix 专项）。
## 背景：源 main.lua:404 FCA_SCALE=0.9（commit f7ac295 2026-08-21"主界面建筑图标整体
## 缩小10%"）+ :419 createMainFca setScale((v.scale or 1)*FCA_SCALE)，对 Spine/FCA 两种
## node 都生效。Godot 端 MainButtonFactory._add_spine/_add_fca 需复刻同一净系数。

const SPINE_DIR: String = "res://assets/spine"

var _bmin: Vector2 = Vector2.ZERO
var _bmax: Vector2 = Vector2.ZERO


func _spine_bbox(res: String, extra_scale: float) -> Vector2:
	var host := Node2D.new()
	add_child_autofree(host)
	var sk := SpineSkeleton.new()
	host.add_child(sk)
	assert_true(sk.load_skeleton(SPINE_DIR + "/" + res, res), "load " + res)
	sk.position = Vector2(400, 240)
	sk.scale = Vector2(extra_scale, extra_scale)
	sk.play("Loop", true)
	await get_tree().process_frame
	await get_tree().process_frame
	_bmin = Vector2(1e9, 1e9)
	_bmax = Vector2(-1e9, -1e9)
	_walk_bbox(sk)
	return _bmax - _bmin


func _walk_bbox(node: Node) -> void:
	for c in node.get_children():
		var s := c as Sprite2D
		if s != null and s.visible and s.texture != null:
			var half: Vector2 = s.texture.get_size() * 0.5
			for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
					Vector2(-half.x, half.y), Vector2(half.x, half.y)]:
				var w: Vector2 = s.global_transform * corner
				_bmin = _bmin.min(w)
				_bmax = _bmax.max(w)
		_walk_bbox(c)


# 基准 bbox（sk_scale=1，无 FCA_SCALE）：修正后工厂净 scale=0.9，渲染尺寸应 = 基准 × 0.9。
func test_pve_spine_bbox_baseline() -> void:
	var sz: Vector2 = await _spine_bbox("eff_UI_Main_Pve", 1.0)
	gut.p("pve spine bbox(scale=1) = %.2f x %.2f" % [sz.x, sz.y])
	assert_gt(sz.x, 50.0, "pve 建筑渲染宽 > 50")
	assert_gt(sz.y, 50.0, "pve 建筑渲染高 > 50")
	var sz9: Vector2 = await _spine_bbox("eff_UI_Main_Pve", 0.9)
	gut.p("pve spine bbox(scale=0.9) = %.2f x %.2f" % [sz9.x, sz9.y])
	assert_almost_eq(sz9.x, sz.x * 0.9, 0.5, "0.9 后宽 = 基准 × 0.9")
	assert_almost_eq(sz9.y, sz.y * 0.9, 0.5, "0.9 后高 = 基准 × 0.9")


# 工厂净 scale 守卫：_add_spine 产出 SpineSkeleton.scale.x = sk_scale × FCA_SCALE(0.9)，
# FCA fallback 同理（_add_fca 净 = 0.39 × sk_scale × 0.9；FCA 走 starshop 资源验 fca.scale.x）。
func test_factory_applies_fca_scale() -> void:
	var btn := Button.new()
	add_child_autofree(btn)
	btn.size = Vector2(200, 200)
	var sk: Node2D = MainButtonFactory._add_spine(btn, {"res": "eff_UI_Main_Pve", "scale": 1.0})
	assert_not_null(sk, "pve spine 加载成功（主资源在）")
	assert_almost_eq(sk.scale.x, 0.9, 0.0001, "Spine 净 scale.x = 1.0 × FCA_SCALE(0.9)（源 main.lua:419）")
	assert_almost_eq(absf(sk.scale.y), 0.9, 0.0001, "Spine |scale.y| = 0.9（load_skeleton 翻 y）")

	var btn2 := Button.new()
	add_child_autofree(btn2)
	btn2.size = Vector2(200, 200)
	var fca: Node2D = MainButtonFactory._add_fca(btn2, "eff_UI_Main_Shop_Star", 0.8)
	if fca != null:
		# starshop v.scale=0.8：净 fca.scale.x = 0.39 × 0.8 × 0.9 = 0.2808
		assert_almost_eq(fca.scale.x, 0.39 * 0.8 * 0.9, 0.0001,
				"FCA 净 scale.x = 0.39 × v.scale × FCA_SCALE（源 :419 对 FCA node 同样 setScale）")
	else:
		gut.p("starshop FCA 资源缺（anim_frames/effect），跳过 FCA 分支断言")
