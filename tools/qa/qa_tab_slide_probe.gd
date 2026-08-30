extends Node

## 探针：点 tab（等价 _on_tab_pressed 直调）滑入动画是否还在（用户反馈「tab 侧滑效果没了」）。
## 逐帧采样 offset_left：期望 400 → 递减 → -200（约 0.2s）；若恒 -200 = 动画没播。

const HeroDetailPanel = preload("res://scripts/ui/hero_detail_panel.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	await get_tree().create_timer(1.2).timeout
	var hero: Variant = null
	for inst_id in pd.hero_manager.heroes.keys():
		hero = pd.hero_manager.heroes[inst_id]
		break
	hero.level = 10

	var dp: Node = HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	dp.upgrade_skill_requested.connect(func(idx: int) -> void:
		if dp.perform_upgrade_skill(idx):
			dp.refresh_content())
	dp.show_window(get_tree().current_scene)
	await get_tree().create_timer(0.5).timeout
	print("QAT2 in_tree=", dp.is_inside_tree(), " current_tab=", dp._current_tab)

	# ① 点 skill tab（直调 _on_tab_pressed = 按钮同路径）
	dp._on_tab_pressed("skill")
	var sv: CanvasItem = dp._tab_views["skill"]
	var samples: Array[float] = []
	for i in range(14):
		await get_tree().process_frame
		samples.append(sv.offset_left)
	print("QAT2 skill 滑入采样=", samples)
	var animated: bool = samples.size() > 2 and samples[0] > -199.0
	print("QAT2 skill 点击滑入存在=", animated, "（首帧 400 起跳=有动画）")

	# ② 升级一次 → 重建（应无重滑：止态直设）
	var sv2: CanvasItem = dp._tab_views["skill"]
	(sv2.get_node("%Skill1Btn") as TextureButton).pressed.emit()
	await get_tree().create_timer(0.4).timeout
	var sv3: CanvasItem = dp._tab_views["skill"]
	var samples2: Array[float] = []
	for i in range(6):
		await get_tree().process_frame
		samples2.append(sv3.offset_left)
	print("QAT2 升级重建采样=", samples2,
		"（恒 -200=无重滑 ✓）")

	# ③ 关闭 tab 再点 skill（close→open 全路径）
	dp._on_tab_pressed("skill")   # 同 tab → close
	await get_tree().create_timer(0.3).timeout
	dp._on_tab_pressed("skill")   # 再开
	var sv4: CanvasItem = dp._tab_views["skill"]
	var samples3: Array[float] = []
	for i in range(14):
		await get_tree().process_frame
		samples3.append(sv4.offset_left)
	print("QAT2 关后重开采样=", samples3)
	var animated2: bool = samples3.size() > 2 and samples3[0] > -199.0
	print("QAT2 关后重开滑入存在=", animated2)
	print("QAT2 DONE")
