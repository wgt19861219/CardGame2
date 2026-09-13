extends GutTest
# skinnedmesh 顶点蒙皮渲染测试（2026-09-12 信箱歪斜根修：region 整贴图降级 → MeshInstance2D 蒙皮网格）。
# 资源 eff_UI_Main_Mailbox（2 mesh）/ eff_UI_Main_Guild（1）/ eff_UI_Main_Volcano（3）。

const MAILBOX_DIR: String = "res://assets/spine/eff_UI_Main_Mailbox"
const MAILBOX_NAME: String = "eff_UI_Main_Mailbox"
const AXIS_TOLERANCE_DEG: float = 2.0     # setup 中轴角断言容差
const UV_TOP: float = 0.25                # 贴图顶部/底部判定的 uv.y 阈值
const UV_BOTTOM: float = 0.75


func _make_skeleton(dir: String, res_name: String) -> SpineSkeleton:
	var sk := SpineSkeleton.new()
	add_child(sk)
	assert_true(sk.load_skeleton(dir, res_name), "load_skeleton 成功: " + res_name)
	return sk


func test_mailbox_meshes_built() -> void:
	var sk := _make_skeleton(MAILBOX_DIR, MAILBOX_NAME)
	sk.play("Loop", true)
	assert_eq(sk._slot_meshes.size(), 2, "信箱 2 个 skinnedmesh 附件")
	assert_eq(sk._slot_sprites.size(), 0, "信箱无 region 附件（不再走整贴图降级）")
	var mi: MeshInstance2D = sk._slot_meshes[0]["mesh"]
	assert_not_null(mi.mesh, "主体 mesh 非空")
	var arrays: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	assert_eq((arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array).size(), 55, "主体 55 顶点")
	assert_eq((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 204, "主体 204 索引")
	sk.queue_free()


func test_mailbox_setup_pose_upright() -> void:
	# 蒙皮 setup 姿态 = 主体中轴近直立（数学模型 -4.4°；修复前整贴图降级歪 ~7° 且格纹斜 ~23°）
	var sk := _make_skeleton(MAILBOX_DIR, MAILBOX_NAME)
	sk.play("Loop", true)
	var angle: float = _mesh_axis_angle_deg(sk._slot_meshes[0])
	assert_almost_eq(angle, -4.40, AXIS_TOLERANCE_DEG, "主体中轴角 ≈ -4.4°（近直立）")
	sk.queue_free()


func test_mailbox_uv_flipped() -> void:
	# Spine uv(v=0 底) → Godot uv(y=0 顶) 需 v 翻转，否则贴图上下颠倒（2026-09-12 实机纠正）
	var sk := _make_skeleton(MAILBOX_DIR, MAILBOX_NAME)
	sk.play("Loop", true)
	var uvs: PackedVector2Array = sk._slot_meshes[0]["uvs"]
	var raw: PackedVector2Array = _raw_spine_uvs(0)
	assert_eq(uvs.size(), raw.size(), "uv 数量一致")
	for i in uvs.size():
		assert_almost_eq(uvs[i].y, 1.0 - raw[i].y, 0.001, "uv.y = 1 - spine_v（顶点 %d）" % i)
		assert_almost_eq(uvs[i].x, raw[i].x, 0.001, "uv.x 不变（顶点 %d）" % i)
	sk.queue_free()


func test_mesh_slot_draw_order() -> void:
	# 附件 z_index = slot 索引（1 起）：主体(槽 1) 在小图(槽 2) 之下
	var sk := _make_skeleton(MAILBOX_DIR, MAILBOX_NAME)
	sk.play("Loop", true)
	var first: MeshInstance2D = sk._slot_meshes[0]["mesh"]
	var second: MeshInstance2D = sk._slot_meshes[1]["mesh"]
	assert_eq(first.z_index, 1, "主体 z=1")
	assert_eq(second.z_index, 2, "小图 z=2")
	sk.queue_free()


func test_other_mesh_resources_smoke() -> void:
	# 同路径其他 skinnedmesh 资源：加载成功 + mesh 数量 + 有效 surface
	var expects: Dictionary = {
		"eff_UI_Main_Guild": 1,
		"eff_UI_Main_Volcano": 3,
		"eff_UI_Main_Skill": 1,
		"eff_UI_Main_Shop3": 1,
	}
	for res_name in expects:
		var sk := _make_skeleton("res://assets/spine/" + String(res_name), String(res_name))
		sk.play("Loop", true)
		assert_eq(sk._slot_meshes.size(), int(expects[res_name]), String(res_name) + " mesh 数")
		for m in sk._slot_meshes:
			assert_not_null((m["mesh"] as MeshInstance2D).mesh, String(res_name) + " mesh surface 有效")
		sk.queue_free()


# 主体 mesh 中轴角：按 uv 分贴图上/下两组，再按几何 y 大者为物理顶（本项目 spine 数据
# v 小侧贴几何顶部——与常规 spine 语义相反，rotate:true region 导出实测，勿按 v 语义定向）。
# 角度 = 顶组中心→底组中心连线相对竖直的偏角（Spine y-up：正=顶偏右）。
func _mesh_axis_angle_deg(m: Dictionary) -> float:
	var arrays: Array = ((m["mesh"] as MeshInstance2D).mesh as ArrayMesh).surface_get_arrays(0)
	var pts: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var acc_a := Vector2.ZERO
	var n_a: int = 0
	var acc_b := Vector2.ZERO
	var n_b: int = 0
	for i in pts.size():
		if uvs[i].y < UV_TOP:
			acc_a += pts[i]
			n_a += 1
		elif uvs[i].y > UV_BOTTOM:
			acc_b += pts[i]
			n_b += 1
	assert_gt(n_a, 0, "有贴图一组顶点")
	assert_gt(n_b, 0, "有贴图另一组顶点")
	var center_a: Vector2 = acc_a / n_a
	var center_b: Vector2 = acc_b / n_b
	var top: Vector2 = center_a if center_a.y > center_b.y else center_b
	var bot: Vector2 = center_b if top == center_a else center_a
	return rad_to_deg(atan2(top.x - bot.x, top.y - bot.y))


# 读 JSON 原始 spine uv（对照翻转断言用；顶点索引 0 的 uvs）。
func _raw_spine_uvs(vertex_offset: int) -> PackedVector2Array:
	var f: FileAccess = FileAccess.open(MAILBOX_DIR + "/" + MAILBOX_NAME + ".json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var att: Dictionary = data["skins"]["default"][String(data["slots"][vertex_offset]["name"])][String(data["slots"][vertex_offset]["attachment"])]
	var raw: Array = att["uvs"]
	var out := PackedVector2Array()
	for i in raw.size() / 2:
		out.append(Vector2(float(raw[i * 2]), float(raw[i * 2 + 1])))
	return out
