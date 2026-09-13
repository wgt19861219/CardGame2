extends Node
## qa_evolve_anim：灵魂石进化表现链实机探针（2026-09-13 动画补全验证）。
## 流程：切 hero_scene → 补碎片/金币 → 开真实 HeroDetailPanel → perform_evolve →
## 分阶段采样（双 FCA / 飘字 Label / back 播完后 HeroEvolveAnnounce 结构）print 供 bridge 读。

func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file.call_deferred("res://scenes/hero/hero_scene.tscn")
	await get_tree().create_timer(2.0).timeout
	var panel := _find_package(get_tree().root)
	if panel == null:
		print("QA FAIL panel not found")
		return
	var mgr: HeroManager = panel._hero_mgr
	if mgr.heroes.is_empty():
		print("QA FAIL no owned hero")
		return
	# 选一个非满星英雄，补足碎片+金币（真实 PlayerData 上操作）
	var hero: HeroInstance = null
	for h in mgr.heroes.values():
		var cand := h as HeroInstance
		var data := HeroData.from_config(panel.cm, cand.tid)
		if cand.stars < data.max_stars:
			hero = cand
			break
	if hero == null:
		print("QA FAIL all heroes max stars")
		return
	var frag_id: int = panel.cm.get_int(&"Fragment", hero.tid, &"Fragment ID")
	var need: int = panel.cm.get_int(&"HeroStars", hero.stars + 1, &"Upgrade Fragments")
	mgr._add_fragment(frag_id, need + 10)
	mgr.gold += 100000
	print("QA hero tid=", hero.tid, " stars=", hero.stars, " frag_need=", need)
	# 真实链路：开详情面板（hero_package._on_hero_clicked 同款）
	panel._on_hero_clicked(hero)
	await get_tree().create_timer(0.5).timeout
	var detail := _find_detail(get_tree().root)
	if detail == null:
		print("QA FAIL detail panel not opened")
		return
	var stars_before: int = hero.stars
	var ok: bool = detail.perform_evolve()
	print("QA evolve ok=", ok, " stars ", stars_before, "->", hero.stars)
	if not ok:
		return
	# 阶段1：即时——双 FCA + 飘字已建
	await get_tree().create_timer(0.3).timeout
	var fcas: Array = detail.find_children("*", "FcaAnimation", true, false)
	var z_list: Array = []
	for f in fcas:
		z_list.append((f as FcaAnimation).z_index)
	var float_labels: Array = []
	for l in detail.find_children("*", "Label", true, false):
		var t: String = (l as Label).text
		if t.contains("+") and not t.begins_with("("):
			float_labels.append(t)
	print("QA stage1 fca_count=", fcas.size(), " z=", z_list, " float_labels=", float_labels.size(), " ", float_labels.slice(0, 3))
	# 阶段2：back FCA 播完（evolution_back 实测时长未知，等 8s 覆盖）→ 公告窗
	await get_tree().create_timer(8.0).timeout
	var announce := _find_announce(get_tree().root)
	if announce == null:
		print("QA FAIL announce not shown after 8s")
	else:
		var labels: Array = []
		for l in announce.find_children("*", "Label", true, false):
			labels.append((l as Label).text)
		var icons: int = announce.find_children("*", "ReadheroIcon", true, false).size()
		var close_btn: int = announce.find_children("*", "TextureButton", true, false).size()
		var light: int = announce.find_children("*", "Sprite2D", true, false).size()
		print("QA stage2 announce OK close=", close_btn, " icons=", icons, " light=", light)
		print("QA stage2 labels=", labels)
	print("QA DONE")
	# 停住供 bridge 进一步检查（watch/properties）


func _find_package(node: Node) -> HeroPackagePanel:
	if node is HeroPackagePanel:
		return node
	for c in node.get_children():
		var found := _find_package(c)
		if found != null:
			return found
	return null


func _find_detail(node: Node) -> HeroDetailPanel:
	if node is HeroDetailPanel:
		return node
	for c in node.get_children():
		var found := _find_detail(c)
		if found != null:
			return found
	return null


func _find_announce(node: Node) -> HeroEvolveAnnounce:
	if node is HeroEvolveAnnounce:
		return node
	for c in node.get_children():
		var found := _find_announce(c)
		if found != null:
			return found
	return null
