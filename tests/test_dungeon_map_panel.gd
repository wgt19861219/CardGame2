extends GutTest

## DungeonMapPanel UI 装配验证（headless 逻辑视觉验收，替 bridge 交互截图）。
# bridge ACL 坑无法交互截图，用节点结构断言验证 Panel 装配正确。
# P1-13（2026-07-11）：3×5 固定坐标 + 宝箱手动开 + 迷雾 FadeOut + 难度弹窗 vit。

func test_panel_assembles_em() -> void:
	var player: PlayerData = GameData.player
	var mgr := StageManager.new(GameData.config)
	var panel := DungeonMapPanel.new("dungeonMap", {})
	panel.setup_panel(player, mgr, BattleRng.new(randi()), "em", [50005, 50006, 50007])
	# em 模式：3 组 × 3 boss = 9 boss（50005/50006/50007 各 3 boss）
	assert_true(panel.bosses.size() > 0, "em 模式收集到 boss（9 期望）")
	assert_eq(panel.boss_buttons.size(), panel.bosses.size(), "boss 按钮数 == boss 数")
	assert_eq(panel.fog_rects.size(), 3, "3 section 迷雾")
	assert_eq(panel.group_counts.size(), 3, "3 组 group_counts")
	panel.free()


func test_panel_assembles_equip() -> void:
	var mgr := StageManager.new(GameData.config)
	var panel := DungeonMapPanel.new("dungeonMap", {})
	panel.setup_panel(GameData.player, mgr, BattleRng.new(randi()), "equip", [50001, 50002, 50003, 50004])
	# equip 模式：4 组 × 3 boss = 12 boss
	assert_true(panel.bosses.size() > 0, "equip 模式收集到 boss（12 期望）")
	assert_eq(panel.group_counts.size(), 4, "4 组 group_counts")
	# section 分配：12 boss → ceil(12/5)=3 section（前 2 section 各 5，第 3 section 2）
	var s3_count := 0
	for b in panel.bosses:
		if int(b["section_idx"]) == 3:
			s3_count += 1
	assert_true(s3_count > 0 and s3_count <= 5, "section 3 boss 数在 1-5")
	panel.free()


func test_panel_boss_unlocked_first() -> void:
	var mgr := StageManager.new(GameData.config)
	var panel := DungeonMapPanel.new("dungeonMap", {})
	panel.setup_panel(GameData.player, mgr, BattleRng.new(randi()), "em", [50005, 50006, 50007])
	# 首关恒解锁（modulate 白色，非灰）
	var first_btn: TextureButton = panel.boss_buttons[0]
	assert_eq(first_btn.modulate, Color(1, 1, 1), "首关 unlocked（白色 modulate）")
	# 第 2 关未解锁（progress 空，前置未通关）→ 灰
	var second_btn: TextureButton = panel.boss_buttons[1]
	assert_eq(second_btn.modulate, Color(0.4, 0.4, 0.4), "第 2 关 locked（灰色 modulate）")
	panel.free()


# P1-13：源 box%d{bossIdx=(s-1)*5+b} 稀疏映射（原紧凑 box_rects Array 改 Dictionary）。
func test_box_rects_sparse_mapping() -> void:
	var mgr := StageManager.new(GameData.config)
	var panel := DungeonMapPanel.new("dungeonMap", {})
	panel.setup_panel(GameData.player, mgr, BattleRng.new(randi()), "em", [50005, 50006, 50007])
	assert_true(panel.box_rects_by_idx is Dictionary, "box_rects_by_idx 是 Dictionary")
	assert_true(panel.box_rects_by_idx.size() > 0, "宝箱稀疏映射非空")
	# section1（boss 1-5）crusadeBoxPos[0] 只 4 个 → box idx 1-4，无 idx 5
	assert_true(panel.box_rects_by_idx.has(1), "section1 首宝箱 idx 1 存在")
	assert_false(panel.box_rects_by_idx.has(5), "section1 第 5 宝箱不存在（crusadeBoxPos[0] 只 4）")
	panel.free()


# P1-13：3×5 固定坐标（源 crusadeBossPos，原顺序布局是审查指出的偏离）。
func test_boss_positions_use_crusade_pos() -> void:
	var mgr := StageManager.new(GameData.config)
	var panel := DungeonMapPanel.new("dungeonMap", {})
	panel.setup_panel(GameData.player, mgr, BattleRng.new(randi()), "em", [50005, 50006, 50007])
	# 源 crusadeBossPos[0][0]=(135,260) anchor 0.5 → Godot 左上 (135-55, 350-260-55)=(80,35)
	var first_btn: TextureButton = panel.boss_buttons[0]
	assert_eq(first_btn.position, Vector2(80.0, 35.0), "首 boss 用 crusadeBossPos[0][0] 固定坐标（非线性）")
	panel.free()


# P1-13：宝箱手动开（源 :271 cleared+openedChests 才 open，原 cleared 自动开是 bug）。
func test_refresh_keeps_box_closed_when_not_cleared() -> void:
	var mgr := StageManager.new(GameData.config)
	var panel := DungeonMapPanel.new("dungeonMap", {})
	panel.setup_panel(GameData.player, mgr, BattleRng.new(randi()), "em", [50005, 50006, 50007])
	assert_true(panel.box_rects_by_idx.size() > 0, "有宝箱可验（防 0 循环 risky）")
	var open_tex: Variant = panel._load_tex(panel.BOX_OPEN_TEX)
	for key in panel.box_rects_by_idx:
		var box: TextureRect = panel.box_rects_by_idx[key]
		assert_ne(box.texture, open_tex, "未 cleared 时 box 不自动开（手动开箱守卫）")
	panel.free()


# P1-13：迷雾 FadeOut 0.5s（源 :286-289 CCFadeOut+setVisible(false)）。
func test_fade_out_fog_immediate_when_not_in_tree() -> void:
	var mgr := StageManager.new(GameData.config)
	var panel := DungeonMapPanel.new("dungeonMap", {})
	panel.setup_panel(GameData.player, mgr, BattleRng.new(randi()), "em", [50005, 50006, 50007])
	var fog: TextureRect = panel.fog_rects[0]
	fog.visible = true
	fog.modulate.a = 1.0
	# panel 未 add_child 到场景树 → is_inside_tree() false → _fade_out_fog 走立即隐分支
	panel._fade_out_fog(fog)
	assert_false(fog.visible, "未入树时 _fade_out_fog 立即 visible=false")
	assert_eq(fog.modulate.a, 0.0, "未入树时 _fade_out_fog 立即 a=0")
	panel.free()
