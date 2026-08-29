extends Node

## 一次性自动走查（1 级档全功能入口验证；免 bridge，同 qa_auto_hpkg 范式）。
## 不注入等级/资源——验证"单机化功能门禁全放开后 1 级能进全部界面"。
## 遍历 main ENTRIES 15 入口 + 快捷栏 6 子面板：open → 等 fill → 记录+截图 → 关。

const MainSceneEntryRouter = preload("res://scripts/ui/main_scene_entry_router.gd")

const EXTRA_PAGES: Array = ["task", "daily", "package", "midas", "configure", "avatar"]
const WARMUP_SEC: float = 0.6
const COOLDOWN_SEC: float = 0.2
var _shot_dir: String = "user://qa_shots/"


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	await get_tree().create_timer(1.5).timeout   # 等 main_scene 建好
	var results: Array = []
	var pages: Array = _entry_ids() + EXTRA_PAGES
	for i in range(pages.size()):
		var page: String = String(pages[i])
		var rec: Dictionary = {"page": page}
		var t0 := Time.get_ticks_msec()
		rec["open"] = _open_page(page)
		await get_tree().create_timer(WARMUP_SEC).timeout
		var scene: Node = get_tree().current_scene
		var panels: int = 0
		for c in scene.get_children():
			if c is PopWindow and is_instance_valid(c):
				panels += 1
		rec["panels"] = panels
		rec["shot"] = _shot("lv1_%02d_%s" % [i, page])
		rec["ms"] = Time.get_ticks_msec() - t0
		results.append(rec)
		_close_all()
		await get_tree().create_timer(COOLDOWN_SEC).timeout
	var ok_n: int = 0
	for r in results:
		var ok: bool = String(r["open"]) == "OK" and int(r["panels"]) > 0
		if ok:
			ok_n += 1
		print("QA_LV1 ", r["page"], " open=", r["open"], " panels=", r["panels"], " ", "PASS" if ok else "**FAIL**")
	print("QA_LV1 SUMMARY level=", pd.team_level, " pass=", ok_n, "/", results.size())


func _entry_ids() -> Array:
	var ids: Array = []
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/main_scene_entries.gd")
	var re := RegEx.new()
	re.compile('"id":\\s*"([a-z]+)"')
	for m in re.search_all(script_text):
		ids.append(m.get_string(1))
	return ids


func _open_page(id: String) -> String:
	var scene: Node = get_tree().current_scene
	match id:
		"task":
			MainSceneEntryRouter.open_task(scene)
			return "OK"
		"daily":
			MainSceneEntryRouter.open_daily_login(scene)
			return "OK"
		"package":
			MainSceneEntryRouter.open_package(scene, "package")
			return "OK"
		"midas":
			MainSceneEntryRouter.open_midas(scene)
			return "OK"
		"configure":
			var ConfigurePanel = load("res://scripts/ui/configure_panel.gd")
			ConfigurePanel.open(scene)
			return "OK"
		"avatar":
			MainSceneEntryRouter.open_avatar(scene)
			return "OK"
		_:
			if scene.has_method("_on_entry_pressed"):
				return String(scene._on_entry_pressed(id))
			return "ERR: no _on_entry_pressed"


func _close_all() -> void:
	var scene: Node = get_tree().current_scene
	for c in scene.get_children():
		if c is PopWindow and is_instance_valid(c):
			c.remove_window()
	HudOverlay.apply_identity("main")


func _shot(name: String) -> String:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return ""
	var path := _shot_dir + name + ".png"
	return path if img.save_png(path) == OK else "ERR"
