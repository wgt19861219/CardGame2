class_name LanguageEntry
extends RefCounted

## 语言切换入口按钮（i18n 闭环，照源 configure 设置）→ LanguageChangePanel。
## 提取自 main_scene 控行数（main_scene.gd ≤400）。attach 建"语言"按钮 + 点击弹 LanguageChangePanel。

static func attach(parent: Control, bar: Control) -> void:
	var btn := Button.new()
	btn.text = "语言"
	btn.position = Vector2(910.0, 10.0)
	btn.size = Vector2(50.0, 32.0)
	btn.pressed.connect(_open.bind(parent))
	bar.add_child(btn)


static func _open(parent: Control) -> void:
	var pd: Variant = GameData.player
	if pd == null or pd.get("cm") == null:
		return
	var lm: Variant = pd.cm.get("_lang")
	if lm == null:
		return
	var panel := LanguageChangePanel.new()
	panel.setup_panel(lm)
	panel.show_window(parent)
