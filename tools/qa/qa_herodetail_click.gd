extends Node

## 一次性取证:英雄详情点击行为(shade_close_on_click=false 后)。
## ① 点内容区不关 ② 点 shade 黑边不关(源无点外关闭) ③ %CloseBtn 正常关。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.5).timeout
	DirAccess.make_dir_recursive_absolute("user://qa_shots/")
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break
	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(1.0).timeout
	print("QAC shade_close_on_click=", dp.shade_close_on_click,
		" shade_mf=", dp.shade_layer.mouse_filter, "(0=STOP)")

	# ① 点内容区(Bg 中部)——期望不关闭
	_click(Vector2(400, 300))
	await get_tree().create_timer(0.3).timeout
	print("QAC after_content_click alive=", dp.is_inside_tree(), "(期望 true)")

	# ② 点 shade 黑边(20,240)——期望不关闭(源 herodetail 无点外关闭)
	_click(Vector2(20, 240))
	await get_tree().create_timer(0.3).timeout
	print("QAC after_shade_click alive=", dp.is_inside_tree(), "(期望 true)")

	# ③ %CloseBtn 关闭——期望关闭(remove_window → queue_free,帧末删除;用弱引用断言)
	var close_btn: BaseButton = dp._base_layer.get_parent().get_node("%CloseBtn") as BaseButton
	print("QAC close_btn rect=", close_btn.get_global_rect())
	var alive_ref: WeakRef = weakref(dp)
	close_btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	var ref: Node = alive_ref.get_ref() as Node
	print("QAC after_close_btn alive=", ref != null and ref.is_inside_tree(), "(期望 false)")
	print("QAC DONE")


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		get_viewport().push_input(ev)
