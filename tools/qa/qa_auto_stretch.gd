extends Node

## 一次性自动取证（全库 TextureButton stretch_mode 清偿 2026-08-31）。
## install_override 装载 → 构造 hero_package / handbook / hero_split 三代表面板 →
## dump 各目标按钮 stretch_mode + size（tab 切换前后双态）→ 验证渲染口径=源（px÷CS / fix_wh）。

const HeroManagerScript = preload("res://scripts/systems/hero_manager.gd")
const HeroPackagePanelScript = preload("res://scripts/ui/hero_package_panel.gd")
const HandbookPanelScript = preload("res://scripts/ui/handbook_panel.gd")
const HeroSplitWindowScript = preload("res://scripts/ui/hero_split_window.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	if pd == null:
		push_error("QA_AUTO: player null")
		return
	var cm: Variant = pd.cm
	var mgr := HeroManagerScript.new(cm)

	# 1) hero_package：tab 双态 + close
	var pkg: Control = HeroPackagePanelScript.new()
	pkg.setup_panel(mgr, cm, pd)
	get_tree().root.add_child(pkg)
	await get_tree().create_timer(1.2).timeout
	var tab_keys: Array = pkg.get("_tabs").keys() if pkg.get("_tabs") != null else []
	var tabs: Dictionary = pkg.get("_tabs") as Dictionary
	if tab_keys.has("all"):
		_dump_node(tabs["all"] as TextureButton, "pkg.TabAll(未选)")
	_find_dump(pkg, "CloseBtn", "pkg.Close")
	print("QA_AUTO: tab_keys=", tab_keys)
	if tab_keys.size() >= 2:
		pkg._on_tab_pressed(tab_keys[1])
		await get_tree().create_timer(0.5).timeout
		_dump_node(tabs["front"] as TextureButton, "pkg.TabFront(选中)")
		_dump_node(tabs["all"] as TextureButton, "pkg.TabAll(切回未选)")

	# 2) handbook：tag/back/箭头
	var hb: Control = HandbookPanelScript.new()
	hb.setup_panel(pd)
	get_tree().root.add_child(hb)
	await get_tree().create_timer(1.2).timeout
	_find_dump(hb, "Tag1Btn", "hb.Tag1")
	_find_dump(hb, "Tag12Btn", "hb.Tag12")
	_find_dump(hb, "BackBtn", "hb.Back")
	_find_dump(hb, "ArrowLeftBtn", "hb.ArrowL")

	# 3) hero_split 三窗 close（源 fix_wh 口径）
	var win := HeroSplitWindowScript.new("herosplit", {})
	win.setup_panel(mgr, cm, pd)
	win.show_window(get_tree().root)
	await get_tree().create_timer(0.6).timeout
	_find_dump(win, "CloseBtn", "split.Window.Close")
	win.remove_window()

	# confirm/explain：CloseBtn 属性为 tscn 固化值，直接 instantiate 静态验证
	var cf_scene: PackedScene = load("res://scenes/ui/hero_split_confirm_content.tscn")
	var cf_inst: Control = cf_scene.instantiate() as Control
	get_tree().root.add_child(cf_inst)
	await get_tree().create_timer(0.3).timeout
	_find_dump(cf_inst, "CloseBtn", "split.Confirm.Close")
	cf_inst.queue_free()

	var ex_scene: PackedScene = load("res://scenes/ui/hero_split_explain_content.tscn")
	var ex_inst: Control = ex_scene.instantiate() as Control
	get_tree().root.add_child(ex_inst)
	await get_tree().create_timer(0.3).timeout
	_find_dump(ex_inst, "CloseBtn", "split.Explain.Close")
	ex_inst.queue_free()

	print("QA_AUTO: DONE")


func _find_dump(root: Node, node_name: String, tag: String) -> void:
	var hits: Array = root.find_children(node_name, "TextureButton", true, false)
	if hits.is_empty():
		print("QA_AUTO: %s 未找到" % tag)
		return
	_dump_node(hits[0] as TextureButton, tag)


func _dump_node(btn: TextureButton, tag: String) -> void:
	if btn == null:
		print("QA_AUTO: %s null" % tag)
		return
	var tex: Texture2D = btn.texture_normal
	var tex_sz: Vector2 = tex.get_size() if tex != null else Vector2.ZERO
	print("QA_AUTO: %s stretch=%d size=(%.2f,%.2f) tex=%s tex_px=(%d,%d) ÷CS=(%.2f,%.2f)" % [
		tag, btn.stretch_mode, btn.size.x, btn.size.y, tex.resource_path,
		int(tex_sz.x), int(tex_sz.y), tex_sz.x / 1.28125, tex_sz.y / 1.28125])
