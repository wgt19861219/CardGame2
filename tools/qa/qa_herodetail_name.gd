extends Node

## 一次性取证:英雄详情名称标题居中 + 属性图标位置(免 bridge 自动截图+dump)。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.5).timeout
	var scene: Node = get_tree().current_scene
	DirAccess.make_dir_recursive_absolute("user://qa_shots/")
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break
	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.show_window(scene)
	await get_tree().create_timer(1.2).timeout
	var base: Control = dp._base_layer
	for nm in ["NameBg", "NameFrame", "TypeIcon", "NameLabel"]:
		var n: Control = base.get_node("%" + nm) as Control
		var is_tr: bool = n is TextureRect
		var tex: Texture2D = n.get("texture") if is_tr else null
		print("QAHN ", nm, " gp=", n.global_position, " size=", n.size,
			" tex=", (tex.get_size() if tex != null else Vector2.ZERO),
			" stretch=", (n.stretch_mode if is_tr else -1),
			" expand=", (n.expand_mode if is_tr else -1),
			" visible=", n.visible)
	var lbl: Label = base.get_node("%NameLabel") as Label
	var font: Font = lbl.get_theme_font(&"font")
	var fs: int = lbl.get_theme_font_size(&"font_size")
	print("QAHN label text=", lbl.text, " hal=", lbl.horizontal_alignment,
		" val=", lbl.vertical_alignment, " text_px=", font.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs))
	get_viewport().get_texture().get_image().save_png("user://qa_shots/herodetail_name.png")
	print("QAHN DONE")
