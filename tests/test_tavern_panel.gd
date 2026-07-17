extends GutTest
# Phase 5.3 UI TavernPanel 测试（per-board scroll_board 滑动 + magic drop_bg 4 组预览，2026-07-13）。
# 照源 tavern.lua：3 board × per-board check/arrow/one_buy/ten_buy + magic drop_bg 4 组 heroIcons
# （源 doRefrehMagicHeroIcon:1290 left3+right1+day3+month1）。magic 源无单抽 → once_btn==null。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel(root: Node) -> TavernPanel:
	var pd := PlayerData.new(cm)
	pd.diamond = 5000
	var rng := BattleRng.new(7)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	panel.show_window(root)
	return panel


func test_panel_assembles() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	# .tscn 重构：container 直接子 = content（.tscn root），panel 层节点在 content 内，
	# board 卡片挂 %BoardHost 下（3 个 board container）。递归扫全子树 + 锚定 _boards 字典。
	assert_eq(panel.container.get_child_count(), 1, "container 直接子 = content（.tscn instantiate）")
	assert_eq(panel._boards.size(), 3, "3 board 装配（bronze/gold/magic）")
	assert_not_null(panel._result_label, "ResultLabel 装配")
	assert_not_null(panel._status_label, "StatusLabel 装配")
	assert_not_null(panel._preview_container, "PreviewContainer 装配")
	assert_not_null(panel._preview_label, "PreviewLabel 装配")
	assert_not_null(panel._board_host, "BoardHost 装配")
	assert_eq(panel._board_host.get_child_count(), 3, "BoardHost 含 3 board container")
	panel.remove_window()
	root.queue_free()


# 选 Bronze → status label 显示剩余免费次数（源 getCountdownText bronze）。
func test_status_label_bronze() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	assert_true(String(panel._status_label.text).find("剩余免费次数") >= 0, "Bronze status 显示剩余免费次数")
	panel.remove_window()
	root.queue_free()


# 默认选 Bronze（金币池）→ Bronze board 单抽 cost 10000 金币（源 Cost Type=Gold）
func test_default_bronze() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	assert_eq(panel._current_pool, "Bronze", "默认 Bronze 卡池")
	var bronze: Dictionary = panel._boards["Bronze"]
	assert_true(bronze["once_btn"] != null, "Bronze 有单抽按钮")
	assert_eq((bronze["once_cost_lbl"] as Label).text, "10000", "Bronze 单抽 10000 金币")
	panel.remove_window()
	root.queue_free()


# MagicSoul 源无单抽 → once_btn 为 null + 十连 400 钻
func test_magicsoul_no_once() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	var magic: Dictionary = panel._boards["MagicSoul"]
	assert_true(magic["once_btn"] == null, "MagicSoul 无单抽按钮（源无单抽条目）")
	assert_eq((magic["ten_cost_lbl"] as Label).text, "400", "MagicSoul 十连 400 钻")
	panel.remove_window()
	root.queue_free()


# Gold 单抽 288 钻 / 十连 2590 钻（Cost Type=Diamond）
func test_gold_cost() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	var gold: Dictionary = panel._boards["Gold"]
	assert_true(gold["once_btn"] != null, "Gold 有单抽按钮")
	assert_eq((gold["once_cost_lbl"] as Label).text, "288", "Gold 单抽 288 钻")
	assert_eq((gold["ten_cost_lbl"] as Label).text, "2590", "Gold 十连 2590 钻")
	panel.remove_window()
	root.queue_free()


# 点 check → scroll_board 上滑展开（position.y 从 0 → -320，源 doClickCheck:1576）
func test_check_expands_scroll() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	var gold: Dictionary = panel._boards["Gold"]
	var scroll: Control = gold["scroll_board"]
	assert_eq(scroll.position.y, 0.0, "展开前 scroll_board position.y=0")
	panel._on_check_pressed("Gold")
	await get_tree().process_frame   # 让 tween 启动（create_tween 首帧设目标）
	assert_true(scroll.position.y < 0.0, "点 check 后 scroll_board 上滑 position.y<0")
	panel.remove_window()
	root.queue_free()


# 源 createMagicLayer:1068-1147 + doRefrehMagicHeroIcon:1290 — magic scroll_board drop_bg 4 组 + heroIcons 4 组。
func test_magic_dropbg_heroicons() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	panel._select_pool("MagicSoul")   # 触发 _fill_magic_heroicons
	var magic: Dictionary = panel._boards["MagicSoul"]
	var scroll: Control = magic["scroll_board"]
	var dropbg_count: int = 0
	var icon_count: int = 0
	for c in scroll.get_children():
		if String(c.name).begins_with("drop_bg"):
			dropbg_count += 1
		if c.has_meta("magic_icon"):
			icon_count += 1
	assert_eq(dropbg_count, 4, "magic drop_bg 4 组（left/right/day/month）")
	assert_eq(icon_count, 8, "magic heroIcons 4 组（left3+right1+day3+month1）")
	panel.remove_window()
	root.queue_free()


func test_draw_produces() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.diamond = 500
	var rng := BattleRng.new(7)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	panel.show_window(root)
	var emitted: Array[bool] = [false]
	panel.drawn.connect(func() -> void: emitted[0] = true)
	panel._on_draw(pd, rng, "MagicSoul", true)
	assert_eq(emitted[0], true, "MagicSoul 十连 → drawn 信号")
	assert_eq(pd.diamond, 500, "MagicSoul 首次十连免费（magic 例外 isShowFree）不扣钻")
	assert_eq(int(pd.tavern_record["MagicSoul"]["left_cnt"]), 0, "免费额度 1→0")
	panel.remove_window()
	root.queue_free()


# Bronze 金币单抽（Cost Type=Gold 扣金币非钻石）
func test_bronze_draw_produces() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 50000
	var rng := BattleRng.new(7)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	panel.show_window(root)
	var emitted: Array[bool] = [false]
	panel.drawn.connect(func() -> void: emitted[0] = true)
	panel._on_draw(pd, rng, "Bronze", false)
	assert_eq(emitted[0], true, "Bronze 单抽 → drawn 信号")
	assert_eq(pd.hero_manager.gold, 50000, "Bronze 首次单抽免费（消耗免费额度）不扣金币")
	assert_eq(int(pd.tavern_record["Bronze"]["left_cnt"]), 4, "免费额度 5→4")
	panel.remove_window()
	root.queue_free()


# Gold 钻石单抽（288 钻）
func test_gold_draw_produces() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.diamond = 1000
	var rng := BattleRng.new(7)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	panel.show_window(root)
	var emitted: Array[bool] = [false]
	panel.drawn.connect(func() -> void: emitted[0] = true)
	# Gold 单抽首次免费（源 tl.gold=1，消耗额度）
	panel._on_draw(pd, rng, "Gold", false)
	assert_eq(emitted[0], true, "Gold 单抽 → drawn 信号")
	assert_eq(pd.diamond, 1000, "Gold 首次单抽免费不扣钻")
	assert_eq(int(pd.tavern_record["Gold"]["left_cnt"]), 0, "免费额度 1→0")
	# 额度用完再单抽花钱（源 isShowFree false → 扣 288 钻）
	panel._on_draw(pd, rng, "Gold", false)
	assert_eq(pd.diamond, 712, "额度用完扣 288 钻")
	panel.remove_window()
	root.queue_free()


# 源 LSTR 文案注入 builder（照源 tavern.lua + tavernres.lua）：
# check_label=RECHARGE.VIEW "查看" / ten_label=TAVERN.BUY__D%10 "购买10个" /
# ten_prompt_text=TAVERNRES.HERO_IS "十连抽必得英雄"（gold）。
func test_board_texts_lstr_injection() -> void:
	var panel := _make_panel(Node.new())
	var texts: Dictionary = panel._build_board_texts("gold")
	assert_eq(String(texts["check_label"]), "查看", "check_label = RECHARGE.VIEW 译文")
	assert_eq(String(texts["once_label"]), "购买1个", "once_label = TAVERN.BUY__D % 1")
	assert_eq(String(texts["ten_label"]), "购买10个", "ten_label = TAVERN.BUY__D % 10")
	assert_eq(String(texts["day_title"]), "今日热点", "day_title = TAVERN.TODAYS_HIGHLIGHT")
	assert_eq(String(texts["month_title"]), "本周热点", "month_title = TAVERN.HOT_IN_THIS_WEEK")
	assert_eq(String(texts["ten_prompt_text"]), "十连抽必得英雄", "ten_prompt_text = TAVERNRES.HERO_IS_...")
	panel.queue_free()


# 源 playLightAnim :577-590 — gold/magic light CCRotateBy(5,360) RepeatForever。
func test_light_rotate_anim_running() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	var gold: Dictionary = panel._boards["Gold"]
	var light: TextureRect = gold.get("light", null)
	assert_not_null(light, "Gold board 有 light 节点（源 is_light_visible=true）")
	await get_tree().create_timer(0.2).timeout   # 让 light rotation tween 跑几帧
	assert_true(light.rotation > 0.0, "Gold light 旋转动画启动（rotation > 0）")
	var bronze: Dictionary = panel._boards["Bronze"]
	var bronze_light: TextureRect = bronze.get("light", null)
	assert_null(bronze_light, "Bronze board 无 light 节点（源 is_light_visible=false）")
	panel.remove_window()
	root.queue_free()
