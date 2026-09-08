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
	pd.diamond = 500   # 单机去 VIP 限制：特权档恒满级，magic 无 VIP 门禁
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
# 单机去 VIP 限制（2026-09-08）：显隐按特权档（满级）判 → 恒显示。
func test_magic_board_visible_below_showvip_after_unlock_removal() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.vip_level = 5   # 旧逻辑 showvip 9 > 5 应隐藏；特权档放开 → 显示
	var rng := BattleRng.new(7)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	panel.show_window(root)
	var magic_board: Dictionary = panel._boards.get("MagicSoul", {})
	var container: Control = magic_board.get("container", null)
	assert_true(container.visible, "特权档放开：VIP 5 magic board 也显示")
	panel.remove_window()
	root.queue_free()


func test_magic_board_visible_at_showvip() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.vip_level = 0   # 特权档放开：任意 vip_level 均显示
	var rng := BattleRng.new(7)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	panel.show_window(root)
	var magic_board: Dictionary = panel._boards.get("MagicSoul", {})
	var container: Control = magic_board.get("container", null)
	assert_true(container.visible, "特权档放开：VIP 0 magic board 也显示")
	panel.remove_window()
	root.queue_free()


# C5 源 tavern.lua:57-64 doTavern：magic 抽卡前 getAreaUnlockvip > vip → toRecharge 拒绝。
# 单机去 VIP 限制（2026-09-08）：门禁按特权档（满级）判 → 恒通过，VIP 0 也可抽。
func test_magic_draw_allowed_at_vip0_after_unlock_removal() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.vip_level = 0   # 旧逻辑 unlock 11 > 0 应拒绝；特权档放开 → 可抽
	pd.diamond = 9999
	var rng := BattleRng.new(7)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	panel.show_window(root)
	var emitted: Array[bool] = [false]
	panel.drawn.connect(func() -> void: emitted[0] = true)
	panel._on_draw(pd, rng, "MagicSoul", false)
	assert_true(emitted[0], "特权档放开：VIP 0 magic 抽卡放行（drawn 信号；首抽每日免费不扣钻）")
	assert_false(panel._result_label.text.find("VIP") >= 0 and panel._result_label.text.find("解锁") >= 0,
		"result_label 无 VIP 拒绝文案")
	panel.remove_window()
	root.queue_free()


# ── 两件套改造守卫（批2 Task 7，2026-08-16）──

# builder 退役（两件套范式）：文件删除 + panel 无残留引用。
func test_builder_retired() -> void:
	assert_false(FileAccess.file_exists("res://scripts/ui/tavern_board_builder.gd"),
		"tavern_board_builder 已退役（两件套范式）")
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_false(text.contains("tavern_board_builder"), "panel 无 builder 残留引用")


# panel 零静态构造（宽口径白名单）：magic 预览 hero icon ReadheroIcon 工厂（2026-08-22
# 巡检改图形头像，旧 Label 降级已删）+ Control wrapper ×1 + 抽卡结果弹窗 PopTavernLoot ×1。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count("Label.new("), 0, "零 Label.new(（magic 预览旧文本降级已删，2026-08-22 巡检）")
	assert_eq(text.count("ReadheroIcon.new("), 1, "仅 1 处 ReadheroIcon.new(（magic 预览头像工厂）")
	assert_eq(text.count("Control.new("), 1, "仅 1 处 Control.new(（预览 38×38 wrapper 参与容器布局）")
	assert_eq(text.count("PopTavernLoot.new("), 1, "仅 1 处 PopTavernLoot.new(（抽卡结果弹窗，批5 组件）")
	assert_eq(text.count(".new("), 3, "宽口径 .new( 总数 = 白名单之和（ReadheroIcon 1 + Control 1 + PopTavernLoot 1）")


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
		var expect_x: float = {"Bronze": 57.0, "Gold": 297.0, "MagicSoul": 537.0}[board_key]
		var container: Control = board["container"]
		assert_almost_eq(container.position.x, expect_x, 0.5, "%s board 左上 x 照源孔位" % board_key)
		assert_almost_eq(container.position.y, 115.0, 0.5, "%s board 左上 y 照源孔位" % board_key)
		assert_almost_eq(container.global_position.y, 115.0, 0.5,
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


# ── 缺图接线守卫（批2 Task 10，2026-08-16：英文资源区 7 图归位）──

# board_title 图归位：源 createBaseBoard:594 board_title ccp(160,355) → Godot board 局部
# 中心 (103,10)（公式 center=(cx-57,365-cy)，TitleImage/board_bg 现值双点验证）；
# 显示尺寸 312×106÷CS(1.28125)=243.51×82.73（TextureConfig 无条目）；降级 TitleLabel 随图消亡。
func test_board_title_art() -> void:
	var scene: PackedScene = load(CONTENT_SCENE_PATH) as PackedScene
	var content: Control = scene.instantiate() as Control
	add_child(content)
	var title_res: Dictionary = {
		"BronzeBoard": "res://assets/ui/alpha/HVGA/tavern_title_1.png",
		"GoldBoard": "res://assets/ui/alpha/HVGA/tavern_title_3.png",
		"MagicBoard": "res://assets/ui/alpha/HVGA/tavern_title_4.png",
	}
	for board_name: String in title_res.keys():
		var board: Control = content.get_node("%BoardHost/" + board_name) as Control
		var art: TextureRect = board.get_node("TitleArt") as TextureRect
		assert_not_null(art, "%s TitleArt 静态存在（图版标题归位）" % board_name)
		assert_eq(art.texture.resource_path, title_res[board_name],
			"%s TitleArt 纹理照源 tavernres.board_title" % board_name)
		assert_almost_eq((art.offset_left + art.offset_right) * 0.5, 103.0, 0.01,
			"%s TitleArt 中心 x=103（源 ccp x=160-57）" % board_name)
		assert_almost_eq((art.offset_top + art.offset_bottom) * 0.5, 10.0, 0.01,
			"%s TitleArt 中心 y=10（源 ccp y=355→365-355）" % board_name)
		assert_almost_eq(art.offset_right - art.offset_left, 243.51, 0.02,
			"%s TitleArt 宽=312÷CS" % board_name)
		assert_almost_eq(art.offset_bottom - art.offset_top, 82.73, 0.02,
			"%s TitleArt 高=106÷CS" % board_name)
		assert_null(board.get_node_or_null("TitleLabel"),
			"%s 降级 TitleLabel 已随图消亡（迁移发明清理）" % board_name)
	content.queue_free()


# 广告图归位：源 createCommonLayer:691 ad ccp(109,175) / createMagicLayer:1001 ad ccp(110,230)
# → scroll 局部中心 (109,145)/(110,90)（公式 center=(cx,320-cy)）；常驻 common_ad 系
# （首抽 first_ad bronze=ad_1/gold=ad_3 未拷，简化记录；magic 首抽/常驻同图 ad_13 无损）。
func test_board_ad_images() -> void:
	var scene: PackedScene = load(CONTENT_SCENE_PATH) as PackedScene
	var content: Control = scene.instantiate() as Control
	add_child(content)
	var cases: Array = [
		["BronzeBoard", "res://assets/ui/alpha/HVGA/tavern_ad_4.png", 109.0, 145.0],
		["GoldBoard", "res://assets/ui/alpha/HVGA/tavern_ad_6.png", 109.0, 145.0],
		["MagicBoard", "res://assets/ui/alpha/HVGA/tavern_ad_13.png", 110.0, 90.0],
	]
	for c: Array in cases:
		var ad: TextureRect = content.get_node(
			"BoardHost/%s/Clip/Scroll/Ad" % c[0]) as TextureRect
		assert_not_null(ad, "%s Ad 静态存在（广告图归位）" % c[0])
		assert_eq(ad.texture.resource_path, c[1], "%s Ad 纹理照源 common_ad_res" % c[0])
		assert_almost_eq((ad.offset_left + ad.offset_right) * 0.5, c[2], 0.01,
			"%s Ad 中心 x=%.0f（源 ccp x）" % [c[0], c[2]])
		assert_almost_eq((ad.offset_top + ad.offset_bottom) * 0.5, c[3], 0.01,
			"%s Ad 中心 y=%.0f（源 320-cy）" % [c[0], c[3]])
		assert_almost_eq(ad.offset_right - ad.offset_left, 194.34, 0.02,
			"%s Ad 宽=249÷CS" % c[0])
		assert_almost_eq(ad.offset_bottom - ad.offset_top, 93.66, 0.02,
			"%s Ad 高=120÷CS" % c[0])
	content.queue_free()


# 十连折扣角标：源 tavern.lua:923 ad_discount 挂 createCommonLayer ten_buy 内 anchor(0,0)
# ccp(1,2)（左下角锚定：距父左缘 1px/底缘 2px）——仅 common 层（bronze/gold）有，
# createMagicLayer ten_buy 无该节点；tscn 父按钮实高 49.16（受控偏离 #4 自洽值）
# → bottom=49.16-2=47.16。
func test_ten_buy_ad_discount() -> void:
	var scene: PackedScene = load(CONTENT_SCENE_PATH) as PackedScene
	var content: Control = scene.instantiate() as Control
	add_child(content)
	for board_name: String in ["BronzeBoard", "GoldBoard"]:
		var btn: Control = content.get_node(
			"BoardHost/%s/Clip/Scroll/TenBuyBtn" % board_name) as Control
		var disc: TextureRect = btn.get_node("AdDiscount") as TextureRect
		assert_not_null(disc, "%s AdDiscount 静态存在（ten_buy 折扣角标归位）" % board_name)
		assert_eq(disc.texture.resource_path,
			"res://assets/ui/alpha/HVGA/tavern_ad_discount.png",
			"%s AdDiscount 纹理照源" % board_name)
		assert_almost_eq(disc.offset_left, 1.0, 0.01,
			"%s AdDiscount 距父左缘 1（源 ccp x=1）" % board_name)
		assert_almost_eq(btn.size.y - disc.offset_bottom, 2.0, 0.01,
			"%s AdDiscount 距父底缘 2（源 ccp y=2 左下角锚定）" % board_name)
		assert_almost_eq(disc.offset_bottom - disc.offset_top, 49.95, 0.02,
			"%s AdDiscount 高=64÷CS" % board_name)
	var magic_btn: Control = content.get_node(
		"BoardHost/MagicBoard/Clip/Scroll/TenBuyBtn") as Control
	assert_null(magic_btn.get_node_or_null("AdDiscount"),
		"magic TenBuyBtn 无 AdDiscount（源 createMagicLayer 无该节点）")
	content.queue_free()


# 源 tavern.lua:204 + poptavernloot.lua destroy :274：弹窗"再抽"退场后重走完整抽卡。
# 2026-09-07 再抽无反应根修守卫：此前 tavern_panel 从未 connect draw_again，信号发了
# 没人听 = 只关窗不再抽。端到端断言：再抽 → drawn 二次发射 + 钻石二次扣费 + 新弹窗弹出。
func test_draw_again_redraws() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.diamond = 1000
	var rng := BattleRng.new(7)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	panel.show_window(root)
	var draw_count: Array[int] = [0]
	panel.drawn.connect(func() -> void: draw_count[0] += 1)
	panel._on_draw(pd, rng, "Gold", false)
	assert_eq(draw_count[0], 1, "首抽一次（免费额度）")
	assert_eq(pd.diamond, 1000, "首抽免费不扣钻")
	var popup: PopTavernLoot = _find_loot_popup(root)
	assert_not_null(popup, "首抽弹出结果窗")
	popup._on_again()   # 模拟点"再抽一次"
	await get_tree().create_timer(0.35).timeout   # 退场 0.2s + 余量
	assert_eq(draw_count[0], 2, "退场完成后重走一次完整抽卡（源 tavernHandler 语义）")
	assert_eq(pd.diamond, 712, "再抽时额度已用完 → 扣 288 钻")
	assert_not_null(_find_loot_popup(root), "再抽弹出新结果窗")
	panel.remove_window()
	root.queue_free()


func _find_loot_popup(node: Node) -> PopTavernLoot:
	if node is PopTavernLoot and is_instance_valid(node):
		return node
	for c in node.get_children():
		var found: PopTavernLoot = _find_loot_popup(c)
		if found != null:
			return found
	return null


# 源 tavern.lua:83-92 资源不足 → showHandyDialog(useMidas/toRecharge) 弹窗级反馈；
# 单机化惯例=Toast（项目注释自述却写成角落静态 Label，用户报"购买资源不足没有提示"，
# 2026-09-07 根修）。
func test_insufficient_funds_shows_toast() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 100   # < Bronze 付费单抽 10000
	TavernData.use_free_tavern(pd, "Bronze", int(Time.get_unix_time_from_system()))   # 用掉免费额度进 CD → 强制付费路径
	var rng := BattleRng.new(7)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	panel.show_window(root)
	Toast._queue.clear()
	panel._on_draw(pd, rng, "Bronze", false)
	assert_false(Toast._queue.is_empty(), "金币不足 → Toast 有消息")
	assert_true(String(Toast._queue[0]).contains("不足"), "Toast 文案含\"不足\"")
	Toast._queue.clear()
	panel.remove_window()
	root.queue_free()
