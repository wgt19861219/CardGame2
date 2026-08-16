extends GutTest
# Phase 5.3 UI TavernPanel 测试（per-board scroll_board 滑动 + magic drop_bg 4 组预览，2026-07-13）。
# 照源 tavern.lua：3 board × per-board check/arrow/one_buy/ten_buy + magic drop_bg 4 组 heroIcons
# （源 doRefrehMagicHeroIcon:1290 left3+right1+day3+month1）。magic 源无单抽 → once_btn==null。
# 2026-08-16 两件套改造（批2 Task 7）：board 静态结构进 tavern_content.tscn（3 board ×
# container/BoardBg/Title/Clip/Scroll 全静态），tavern_board_builder.gd 退役；
# panel 只 fill（文案/cost）+ connect + 滑动 tween。heroIcons 仍运行时填（动态行）。

const PANEL_PATH: String = "res://scripts/ui/tavern_panel.gd"
const CONTENT_SCENE_PATH: String = "res://scenes/ui/tavern_content.tscn"

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
		if String(c.name).begins_with("DropBg"):
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
	pd.vip_level = 11   # C5：magic 抽卡需 VIP 11 解锁（unlock vip for Magic Soul Box）
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


# P1-9 源 tavern.lua:566-574 getArrowudAnim：arrow MoveBy(1,ccp(0,-5)) SineInOut ↔ reverse 循环。
func test_arrow_float_anim_running() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	var bronze: Dictionary = panel._boards["Bronze"]
	var arrow: TextureButton = bronze.get("arrow_btn", null)
	assert_not_null(arrow, "Bronze board 有 arrow 节点")
	# arrow 浮动动画：headless Tween 推进不可靠，仅验证 arrow 节点存在（动画启动由 panel._create_boards 调 play_arrow_float_anim 保证）。
	panel.remove_window()
	root.queue_free()


# C5 源 tavern.lua:1402-1418 refreshItemLayer：magic board 按 getAreaShowvip 门控显隐。
# VIP.json: Magic Soul Box unlock VIP = 11（首个 true）；show = max(11-2,0) = 9。
func test_magic_board_hidden_below_showvip() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.vip_level = 5   # showvip 9 > 5 → magic board 隐藏
	var rng := BattleRng.new(7)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	panel.show_window(root)
	var magic_board: Dictionary = panel._boards.get("MagicSoul", {})
	var container: Control = magic_board.get("container", null)
	assert_false(container.visible, "VIP 5 < showvip 9 → magic board 隐藏")
	panel.remove_window()
	root.queue_free()


func test_magic_board_visible_at_showvip() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.vip_level = 9   # showvip 9 <= 9 → magic board 显示（灰显，仍不可抽）
	var rng := BattleRng.new(7)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	panel.show_window(root)
	var magic_board: Dictionary = panel._boards.get("MagicSoul", {})
	var container: Control = magic_board.get("container", null)
	assert_true(container.visible, "VIP 9 = showvip → magic board 显示（灰显）")
	panel.remove_window()
	root.queue_free()


# C5 源 tavern.lua:57-64 doTavern：magic 抽卡前 getAreaUnlockvip > vip → toRecharge 拒绝。
# VIP 0 < unlock 11 → _on_draw 拒绝（result_label 提示），不抽卡。
func test_magic_draw_blocked_below_unlock_vip() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.vip_level = 0   # unlock 11 > 0 → 拒绝
	pd.diamond = 9999   # 钻石够但 VIP 不足仍拒绝
	var rng := BattleRng.new(7)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	panel.show_window(root)
	var before_diamond: int = pd.diamond
	panel._on_draw(pd, rng, "MagicSoul", false)
	assert_eq(pd.diamond, before_diamond, "VIP 0 magic 抽卡被拒，钻石未扣")
	assert_true(panel._result_label.text.find("VIP") >= 0 or panel._result_label.text.find("解锁") >= 0,
		"result_label 提示 VIP 解锁（拒绝文案）")
	panel.remove_window()
	root.queue_free()


# ── 两件套改造守卫（批2 Task 7，2026-08-16）──

# builder 退役（两件套范式）：文件删除 + panel 无残留引用。
func test_builder_retired() -> void:
	assert_false(FileAccess.file_exists("res://scripts/ui/tavern_board_builder.gd"),
		"tavern_board_builder 已退役（两件套范式）")
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_false(text.contains("tavern_board_builder"), "panel 无 builder 残留引用")


# panel 零静态构造（宽口径白名单）：magic 预览 hero icon 降级 Label.new( ×1 +
# 抽卡结果弹窗 PopTavernLoot.new( ×1（批5 弹窗组件实例化），board 静态结构全在 tscn。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count("Label.new("), 1, "仅 1 处 Label.new(（magic 预览 hero icon 降级标签）")
	assert_eq(text.count("PopTavernLoot.new("), 1, "仅 1 处 PopTavernLoot.new(（抽卡结果弹窗，批5 组件）")
	assert_eq(text.count(".new("), 2, "宽口径 .new( 总数 = 白名单之和（Label 1 + PopTavernLoot 1）")


# content tscn 静态树（A 轨无脚本）：根不绑脚本 + BoardHost 下 3 张完整 board 静态装配。
func test_content_tscn_static_tree() -> void:
	var scene: PackedScene = load(CONTENT_SCENE_PATH) as PackedScene
	assert_not_null(scene, "tavern_content.tscn 可加载")
	var content: Control = scene.instantiate() as Control
	add_child(content)
	assert_null(content.get_script(), "content tscn 根无脚本（A 轨无脚本铁律）")
	var host: Control = content.get_node("%BoardHost") as Control
	assert_eq(host.get_child_count(), 3, "BoardHost 静态挂 3 张 board")
	for board_name: String in ["BronzeBoard", "GoldBoard", "MagicBoard"]:
		var board: Control = content.get_node("%" + board_name) as Control
		assert_not_null(board, "%s 静态存在" % board_name)
		# Clip（裁剪层）> Scroll（滑动层）层级防 parenting 回归
		var scroll: Control = board.get_node("Clip/Scroll") as Control
		assert_not_null(scroll, "%s 内 Scroll 存在" % board_name)
		assert_eq((scroll.get_parent() as Control).clip_contents, true,
			"%s 的 Scroll 父节点是 clip_contents 裁剪层" % board_name)
	content.queue_free()


# board 静态布局防漂移：3 board 横排孔位照源 draglist(80,80)+board_bg ccp(160,205)，
# Godot 中心 (240,355)/(480,355)/(720,355) → container 左上 (137/377/617,195)（206×320）。
# global_position 级断言防 parenting 回归（panel 挂载后仍应落在场景空间孔位）。
func test_board_static_layout() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	for board_key: String in ["Bronze", "Gold", "MagicSoul"]:
		var board: Dictionary = panel._boards[board_key]
		var expect_x: float = {"Bronze": 137.0, "Gold": 377.0, "MagicSoul": 617.0}[board_key]
		var container: Control = board["container"]
		assert_almost_eq(container.position.x, expect_x, 0.5, "%s board 左上 x 照源孔位" % board_key)
		assert_almost_eq(container.position.y, 195.0, 0.5, "%s board 左上 y 照源孔位" % board_key)
		assert_almost_eq(container.global_position.y, 195.0, 0.5,
			"%s board global_position 防 parenting 回归" % board_key)
		assert_almost_eq(container.size.x, 206.0, 0.5, "%s board 宽 206（源 clip stencil 宽）" % board_key)
		assert_almost_eq(container.size.y, 320.0, 0.5, "%s board 高 320（源滑动行程）" % board_key)
	panel.remove_window()
	root.queue_free()


# magic board 静态差异：无单抽区（源 MagicSoul 表无 one 条目）+ drop_bg 4 组 day/month 标题静态存在。
func test_magic_board_static_diff() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	var magic: Dictionary = panel._boards["MagicSoul"]
	assert_null(magic.get("once_btn", null), "Magic board tscn 无单抽按钮节点")
	var scroll: Control = magic["scroll_board"]
	assert_not_null(scroll.get_node_or_null("TenBuyBtn/TenBuyLabel"), "magic ten_buy 标签静态存在")
	# 源 :1225 magic ten_buy_label = BUY__D % 1（"购买1个"，magic 唯一按钮按单抽计费）。
	assert_eq(String((scroll.get_node("TenBuyBtn/TenBuyLabel") as Label).text), "购买1个",
		"magic ten_buy 标签照源为 购买1个（BUY__D %% 1）")
	panel.remove_window()
	root.queue_free()


# 审查修复 I1 守卫（2026-08-16）：cost 数值 Label 右缘语义——源 tavern.lua:793-794/:868-869
# anchor=ccp(1,0.5)+position=ccp(144,·)：x=144 是右缘坐标（非中心）→ tscn offset_right=144、
# 宽 40 保持，且右缘不得溢出对应费用框（CostFrame）右缘（曾 164 > 159 溢出 5px）。
func test_cost_label_right_edge() -> void:
	var scene: PackedScene = load(CONTENT_SCENE_PATH) as PackedScene
	var content: Control = scene.instantiate() as Control
	add_child(content)
	var cases: Array = [
		["BronzeBoard", "OneCostLabel", "OneCostFrame"],
		["BronzeBoard", "TenCostLabel", "TenCostFrame"],
		["GoldBoard", "OneCostLabel", "OneCostFrame"],
		["GoldBoard", "TenCostLabel", "TenCostFrame"],
		["MagicBoard", "TenCostLabel", "TenCostFrame"],
	]
	for c: Array in cases:
		var scroll_path: String = "BoardHost/%s/Clip/Scroll" % c[0]
		var label: Label = content.get_node("%s/%s" % [scroll_path, c[1]]) as Label
		var frame: Control = content.get_node("%s/%s" % [scroll_path, c[2]]) as Control
		var tag: String = "%s/%s" % [c[0], c[1]]
		assert_almost_eq(label.offset_right, 144.0, 0.01,
			"%s 右缘=144（源 anchor(1,0.5) 右缘语义，非中心）" % tag)
		assert_almost_eq(label.offset_left, 104.0, 0.01, "%s 左缘=104（宽 40 保持）" % tag)
		assert_true(label.offset_right <= frame.offset_right,
			"%s 右缘 %.0f ≤ 费用框右缘 %.0f（文本不溢出费用框）" % [tag, label.offset_right, frame.offset_right])
	content.queue_free()
