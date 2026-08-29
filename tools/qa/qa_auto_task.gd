extends Node

## 一次性自动取证（任务行 2026-08-28 照源修验证；免 bridge，同 qa_auto_hpkg 范式）。
## 构造 working（含 Item 奖励链）+ completed 两态样本行挂当前场景 → 截图 + 坐标 dump 到日志。

const TaskRowBuilder = preload("res://scripts/ui/task_row_builder.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	await get_tree().create_timer(1.5).timeout   # 等 main_scene 建好
	var scene: Node = get_tree().current_scene
	var cm: Variant = GameData.player.cm
	var host := Control.new()
	host.position = Vector2(30.0, 120.0)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(host)
	# working 行：Coin + Item(102) + Diamond 三段奖励链 + 12/30 progress
	var row1: Control = TaskRowBuilder.make_task_row({
		"kind": "task", "name": "拥有六件装备可以进阶", "detail": "为任意英雄穿满 6 件装备",
		"target": 30, "progress": 12, "isFinished": false, "icon": "",
		"reward": [
			{"type": "Coin", "id": 0, "amount": 5000},
			{"type": "Item", "id": 102, "amount": 2},
			{"type": "Diamond", "id": 0, "amount": 50},
		],
	}, Callable(), "奖励:", "前往", Callable(), cm)
	row1.position = Vector2(0.0, 0.0)
	host.add_child(row1)
	# completed 行：触发 completeTag 原尺寸路径
	var row2: Control = TaskRowBuilder.make_task_row({
		"kind": "task", "name": "通关第一章第一关", "detail": "完成新手引导关卡",
		"target": 1, "progress": 1, "isFinished": false, "icon": "",
		"reward": [{"type": "Coin", "id": 0, "amount": 3000}],
	}, Callable(), "奖励:", "前往", Callable(), cm)
	row2.position = Vector2(0.0, 130.0)
	host.add_child(row2)
	await get_tree().create_timer(0.6).timeout   # 等 ready relayout
	var img := get_viewport().get_texture().get_image()
	if img != null:
		DirAccess.make_dir_recursive_absolute("user://qa_shots/")
		var err := img.save_png("user://qa_shots/auto_task_r1.png")
		print("QA_TASK shot err=", err)
	_dump_row(row1, "working")
	_dump_row(row2, "completed")
	print("QA_TASK: DONE")


func _dump_row(row: Control, tag: String) -> void:
	for c in row.get_children():
		if c is Label and (c as Label).text == "12/30":
			var l: Label = c as Label
			print("QA_TASK ", tag, " progress center x=", l.position.x + l.get_minimum_size().x * 0.5,
				" (期望 450 中心锚)")
		if c is TextureButton:
			var b: TextureButton = c as TextureButton
			print("QA_TASK ", tag, " btn size=", b.size, " center=(",
				b.position.x + b.size.x * 0.5, ", ", b.position.y + b.size.y * 0.5,
				") tex=", b.texture_normal.resource_path.get_file())
	# reward 链 x 序列（icon Control 非 Label / amt Label / TextureRect）
	var xs: Array = []
	for c in row.get_children():
		if (c is Control) and not (c is TextureButton) and c.position.y > 60.0 and c.position.y < 90.0:
			xs.append(String(c.name) + "@x" + str(snappedf(c.position.x, 0.1)))
	print("QA_TASK ", tag, " reward chain(y 60~90): ", ", ".join(xs))
