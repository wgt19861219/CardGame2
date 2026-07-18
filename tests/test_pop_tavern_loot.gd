extends GutTest
# PopTavernLoot 抽卡产出弹窗测试（照源 poptavernloot.lua）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# Phase A 静态化（2026-07-18）：chrome 搬进 pop_tavern_loot_content.tscn，
# container → Content → {LootHost/CostHost/RewardLabel/AgainBtn/CloseBtn}。
# 扫描层级改：container 1 子（Content），Content 5 静态子（不含 loot icons/cost_row，挂 host 内）。
func test_setup_loot_single() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "bronze", "one", {"pay": "Diamond", "number": 288})
	popup.show_window(root)
	assert_eq(popup.container.get_child_count(), 1, "container 仅挂 Content（.tscn 根）")
	var content: Control = popup.container.get_child(0)
	assert_eq(content.get_child_count(), 5, "Content 5 静态子（LootHost + CostHost + RewardLabel + AgainBtn + CloseBtn）")
	assert_eq(popup._loot_host.get_child_count(), 1, "单抽 LootHost 1 loot icon")
	assert_eq(popup._cost_host.get_child_count(), 2, "CostHost 2（cost_label + cost_icon）")
	popup.remove_window()
	root.queue_free()


func test_setup_loot_aggregates() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	# 同 id 101 两笔 → 聚合为 1 图标
	popup.setup_loot([{"id": 101, "amount": 1}, {"id": 101, "amount": 2}, {"id": 102, "amount": 1}], cm, "bronze", "ten")
	popup.show_window(root)
	assert_eq(popup.container.get_child_count(), 1, "container 仅挂 Content")
	# 聚合后 2 种（101/102），setup_loot 默认空 cost_info → cost 行跳过 → CostHost 0 子
	assert_eq(popup._loot_host.get_child_count(), 2, "聚合 LootHost 2 loot icons")
	assert_eq(popup._cost_host.get_child_count(), 0, "无 cost_info → CostHost 空")
	popup.remove_window()
	root.queue_free()


# 源 poptavernloot.lua :661-668 tvText 分支：one→DRAW_ONCE_AGAIN / ten→DRAW_10_AGAIN。
func test_tv_text_branch() -> void:
	var root := Node.new()
	add_child(root)
	var popup_once := PopTavernLoot.new("poptavernloot", {})
	popup_once.setup_loot([{"id": 101, "amount": 1}], cm, "bronze", "one")
	popup_once.show_window(root)
	# cm.get_lstr(DRAW_ONCE_AGAIN) = "再抽一次"
	var once_text: String = popup_once._tv_text()
	popup_once.remove_window()
	var popup_ten := PopTavernLoot.new("poptavernloot", {})
	popup_ten.setup_loot([{"id": 101, "amount": 1}], cm, "bronze", "ten")
	popup_ten.show_window(root)
	var ten_text: String = popup_ten._tv_text()
	popup_ten.remove_window()
	root.queue_free()
	assert_eq(once_text, "再抽一次", "单抽 → DRAW_ONCE_AGAIN")
	assert_eq(ten_text, "再抽十次", "十连 → DRAW_10_AGAIN")


# 源 playButtonAnim :781 tavern ccp(310,50) / :820 ok ccp(508,50) — to_godot 转换后按钮位置。
func test_button_position_to_godot() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "bronze")
	popup.show_window(root)
	# _g((310,50)) = (390, 510)；按钮中心 = position + size/2（.tscn offset 固化中心对齐）
	# Phase A：AgainBtn 在 Content 内（container → Content → AgainBtn），递归扫全子树。
	var again_btn: TextureButton = _find_texture_btn_recursive(popup.container, popup._on_again)
	assert_not_null(again_btn, "再抽按钮存在")
	# center_x 390 → position.x = 390 - size.x/2
	var again_center_x: float = again_btn.position.x + again_btn.size.x * 0.5
	assert_almost_eq(again_center_x, 390.0, 1.0, "再抽按钮中心 x≈390（源 310+80 to_godot）")
	popup.remove_window()
	root.queue_free()


func test_draw_again_signal() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm)
	popup.show_window(root)
	var emitted: Array[bool] = [false]
	popup.draw_again.connect(func() -> void: emitted[0] = true)
	popup._on_again()
	assert_eq(emitted[0], true, "再抽按钮 emit draw_again")
	root.queue_free()


# box_type="bronze" → 加载开箱 FCA（AtlasSprite zip + FcaAnimation）
func test_setup_loot_with_box_anim() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "bronze")
	popup.show_window(root)
	# _play_box_anim 在 show 入场（SHOW_SEC=0.2）完成后由 _after_show 异步触发；await 让 tween process。
	await popup.box_shown   # P2-GUT-2：信号等待（_after_show 里 box FCA 就位）
	# Phase A：FCA 挂 %LootHost（container → Content → LootHost → FCA），递归扫全子树。
	var has_fca: bool = _has_node_of_type(popup.container, FcaAnimation)
	assert_true(has_fca, "bronze box_type → 开箱 FCA 节点")
	popup.remove_window()
	root.queue_free()


# 源 createLootAnim :510-516：非 magic icon 飞出时加白光 shadow 子节点（FadeOut 与飞行并行）。
func test_fly_loot_adds_shadow() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "bronze")
	popup.show_window(root)
	await popup.loot_anim_done   # P2-GUT-2：信号等待（产出飞出 + shadow 加完）
	var icon: Control = popup._loot_icons[0]
	var has_shadow: bool = false
	for c in icon.get_children():
		if c is Sprite2D and c.texture != null and String(c.texture.resource_path).find("tavern_get_item_bg_light_white") >= 0:
			has_shadow = true
			break
	assert_true(has_shadow, "bronze 飞出后 icon 加白光 shadow")
	popup.remove_window()
	root.queue_free()


# 源 createLootAnim :573 + playBurst :468-489：hero loot → playBurst(icon,6) 橙色光效旋转。
func test_burst_on_hero_loot() -> void:
	var root := Node.new()
	add_child(root)
	var hero_id: int = int(TavernData._collect_valid_hero_ids(cm)[0])
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": hero_id, "amount": 1}], cm, "bronze")
	popup.show_window(root)
	await popup.loot_anim_done   # P2-GUT-2：信号等待（产出飞出 + burst 加完）
	var icon: Control = popup._loot_icons[0]
	var has_light: bool = false
	for c in icon.get_children():
		if c is Sprite2D and c.texture != null and String(c.texture.resource_path).find("tavern_get_item_bg_light_orange") >= 0:
			has_light = true
			break
	assert_true(has_light, "hero loot → 橙色品质光效（品质6）")
	popup.remove_window()
	root.queue_free()


# 递归扫子树找 TextureButton 且 pressed 连了 target_callable（Phase A：.tscn 多层 content 扫描）。
func _find_texture_btn_recursive(node: Node, target_callable: Callable) -> TextureButton:
	for c in node.get_children():
		if c is TextureButton and (c as TextureButton).pressed.is_connected(target_callable):
			return c
		var found: TextureButton = _find_texture_btn_recursive(c, target_callable)
		if found != null:
			return found
	return null


# 递归扫子树找指定类型节点（Phase A：FCA 挂 LootHost 内多层扫描）。
func _has_node_of_type(node: Node, type: GDScript) -> bool:
	if is_instance_of(node, type):
		return true
	for c in node.get_children():
		if _has_node_of_type(c, type):
			return true
	return false
