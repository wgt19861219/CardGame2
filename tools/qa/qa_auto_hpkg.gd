extends Node

## 一次性自动取证（英雄包裹 2026-08-28 根修验证；bridge 9081 被用户实例占用时用本脚本驱动）。
## install_override 装载 → 启动自动：注入全英雄 → 切 hero_scene（自动开 HeroPackagePanel）→
## 等 fill + deferred → 截图 ×2（首屏/滚一屏）+ dump 关键节点 global 坐标 print 到日志。

const QA_LEVEL: int = 99
const GmManager = preload("res://scripts/systems/gm_manager.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	if pd == null:
		push_error("QA_AUTO: player null")
		return
	pd.tutorial_manager.skip_all()
	pd.team_level = QA_LEVEL
	_fill_heroes(pd)
	await get_tree().create_timer(1.0).timeout   # 等 main_scene 建好
	SceneManager.change_scene("res://scenes/hero/hero_scene.tscn")
	await get_tree().create_timer(2.5).timeout   # 等面板入场 + fill + deferred relayout
	_shot_and_dump("auto_hpkg_r1")
	# 滚动一屏再取证（星星/裁剪多行验证）
	var scroll: ScrollContainer = _find_scroll()
	if scroll != null:
		scroll.scroll_vertical = 300
		await get_tree().create_timer(0.5).timeout
	_shot_and_dump("auto_hpkg_r2")
	print("QA_AUTO: DONE")


func _fill_heroes(pd: Variant) -> void:
	var cm: Variant = pd.cm
	GmManager.execute(pd, cm, {"_get_all_heroes": 1})
	var hero_list: Array = []
	var tids: Array = cm.get_raw_table("Unit").keys()
	var given_rank: Array = [3, 4, 5, 3, 4, 5]
	var n_set: int = 0
	for tid_str in tids:
		var row: Dictionary = cm.get_raw_table("Unit")[tid_str]
		if String(row.get("Unit Type", "")) == "Hero" and row.has("Portrait"):
			hero_list.append({
				"_tid": int(tid_str),
				"_rank": int(given_rank[n_set % given_rank.size()]),
				"_level": 37,
				"_stars": 3,
			})
			n_set += 1
			if n_set >= 6:
				break
	if not hero_list.is_empty():
		GmManager.execute(pd, cm, {"_set_hero_info": hero_list})


func _find_scroll() -> ScrollContainer:
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is ScrollContainer and String(n.name) == "HeroScroll":
			return n as ScrollContainer
	return null


func _shot_and_dump(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null:
		DirAccess.make_dir_recursive_absolute("user://qa_shots/")
		var err := img.save_png("user://qa_shots/" + tag + ".png")
		print("QA_AUTO shot ", tag, " err=", err)
	var scroll: ScrollContainer = _find_scroll()
	if scroll == null:
		print("QA_AUTO: no HeroScroll")
		return
	print("QA_AUTO scroll global=", scroll.global_position, " size=", scroll.size,
		" scrollY=", scroll.scroll_vertical)
	var grid: Control = scroll.get_node_or_null("%GridHost") as Control
	if grid != null:
		print("QA_AUTO grid global=", grid.global_position, " pos=", grid.position,
			" minsize=", grid.custom_minimum_size)
	var n_item: int = 0
	for c in grid.get_children():
		if not (c is Control) or n_item >= 2:
			continue
		var item: Control = c as Control
		var content: Node = item.get_child(0) if item.get_child_count() > 0 else null
		if content == null:
			continue
		n_item += 1
		var bg: Control = content.get_node_or_null("Bg") as Control
		var head_host: Control = content.get_node_or_null("%HeadHost") as Control
		var name_host: Control = content.get_node_or_null("%NameHost") as Control
		var slot1: Control = content.get_node_or_null("%EquipSlot1") as Control
		print("QA_AUTO item", n_item, " pos=", item.position, " scale=", item.scale,
			" bg.global=", bg.global_position if bg else null,
			" bg.size=", bg.size if bg else null,
			" head.global=", head_host.global_position if head_host else null,
			" namehost.global=", name_host.global_position if name_host else null,
			" slot1.global=", slot1.global_position if slot1 else null,
			" slot1.size=", slot1.size if slot1 else null)
		# 星星（ReadheroIcon stars 数组）首星全局坐标 + frame/portrait/level 精确 rect
		for hc in head_host.get_children():
			if hc.get("stars") != null:
				var stars: Array = hc.get("stars")
				if stars.size() > 0:
					var s0: Node2D = stars[0] as Node2D
					print("QA_AUTO item", n_item, " star0.global=", s0.global_position,
						" star0.scale=", s0.scale)
				var fr: Node2D = hc.get("frame")
				if fr != null:
					var ftex: Vector2 = fr.texture.get_size() if fr.texture != null else Vector2.ZERO
					print("QA_AUTO item", n_item, " frame.local_pos=", fr.position,
						" scale=", fr.scale, " disp_size=", ftex * fr.scale.x,
						" tex=", ftex)
				var oi: Node2D = hc.get("ori_icon")
				if oi != null and oi is Sprite2D:
					var osp: Sprite2D = oi as Sprite2D
					var ptex: Vector2 = osp.texture.get_size() if osp.texture != null else Vector2.ZERO
					print("QA_AUTO item", n_item, " portrait.local_pos=", osp.position,
						" scale=", osp.scale, " disp_size=", ptex * osp.scale.x, " tex=", ptex)
				var lv: Node2D = hc.get("level_label")
				if lv != null:
					print("QA_AUTO item", n_item, " level.local_pos=", lv.position)
				break
