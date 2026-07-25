extends GutTest
## MidasRenderer 渲染 helper 单测（全 static，仿 hero_detail_equip_slots 测试范式）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_to_godot_conversion() -> void:
	assert_eq(MidasRenderer.to_godot(Vector2(400.0, 240.0)), Vector2(480.0, 320.0), "to_godot 坐标转换")

func test_center() -> void:
	assert_eq(MidasRenderer.center(Vector2(400.0, 240.0), Vector2(100.0, 50.0)), Vector2(430.0, 295.0), "center 居中偏移")

func test_left_mid() -> void:
	assert_eq(MidasRenderer.left_mid(Vector2(400.0, 240.0), 24.0), Vector2(480.0, 308.0), "left_mid 左中")

func test_make_label_builds_node() -> void:
	var parent := Control.new()
	add_child(parent)
	var lbl: Label = MidasRenderer.make_label(parent, "测试", Color.RED, Vector2(10, 20))
	assert_not_null(lbl)
	assert_eq(lbl.text, "测试")
	assert_eq(lbl.modulate, Color.RED)
	assert_eq(lbl.position, Vector2(10, 20))
	assert_true(lbl.theme_type_variation == &"MidasConfirmLabel", "make_label 走 MidasConfirmLabel variation")
	parent.free()

func test_make_texture_builds_node() -> void:
	var parent := Control.new()
	add_child(parent)
	var tr: TextureRect = MidasRenderer.make_texture(parent, "res://assets/ui/alpha/HVGA/task_rmb_icon_2.png", Vector2.ZERO, Vector2(28, 28))
	assert_not_null(tr)
	assert_not_null(tr.texture)
	parent.free()

func test_add_nine_patch_builds_node() -> void:
	var parent := Control.new()
	add_child(parent)
	var np: NinePatchRect = MidasRenderer.add_nine_patch(parent, "res://assets/ui/alpha/HVGA/main_vit_tips.png", Vector2.ZERO, Vector2(100, 50), 10)
	assert_not_null(np)
	parent.free()

func test_rebuild_history_empty() -> void:
	var host := Control.new()
	add_child(host)
	var resolver: Callable = func(_k: String) -> String: return "X"
	MidasRenderer.rebuild_history(host, [], resolver)
	assert_eq(host.get_child_count(), 0, "空 history 不挂载")
	host.free()

func test_rebuild_history_mounts_rows() -> void:
	# GDScript lambda 捕获 int 是值捕获，需数组包装才能跨闭包累计（参 test_task_row_builder 的 fast_called 范式）。
	var host := Control.new()
	add_child(host)
	var history: Array = [
		{"cost": 100, "acquire": 200, "ratio": 1},
		{"cost": 100, "acquire": 400, "ratio": 2},
		{"cost": 100, "acquire": 600, "ratio": 1},
	]
	var call_count: Array[int] = [0]
	var resolver: Callable = func(_k: String) -> String:
		call_count[0] += 1
		return "USE"
	MidasRenderer.rebuild_history(host, history, resolver)
	assert_eq(host.get_child_count(), 3, "3 行挂 3 HBox")
	assert_true(call_count[0] >= 3, "resolver 至少被调 3 次（每行 USE label）")
	host.free()

func test_add_history_label_uses_variation() -> void:
	var parent := HBoxContainer.new()
	add_child(parent)
	MidasRenderer.add_history_label(parent, "test", Color.WHITE)
	assert_eq(parent.get_child_count(), 1)
	var lbl: Label = parent.get_child(0) as Label
	assert_true(lbl.theme_type_variation == &"MidasHistoryLabel", "add_history_label 走 MidasHistoryLabel variation")
	parent.free()
