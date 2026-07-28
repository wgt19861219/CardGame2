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


# 源 throwLoots :167-200：仅 shuffle 不合并同 id（10 个相同 equip 显 10 icon，非聚合 1 个）。
# 3 loot（2 个同 id 101 + 1 个 102）→ 3 个独立 icon（P1-C4 修复，旧版按 id 聚合是 bug）。
func test_setup_loot_no_merge() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}, {"id": 101, "amount": 2}, {"id": 102, "amount": 1}], cm, "bronze", "ten")
	popup.show_window(root)
	assert_eq(popup.container.get_child_count(), 1, "container 仅挂 Content")
	# 照源 throwLoots 不合并 → 3 个独立 icon（旧 _aggregate 聚合为 2 是偏离源）
	assert_eq(popup._loot_host.get_child_count(), 3, "不合并同 id → 3 loot icons（源 throwLoots 行为）")
	assert_eq(popup._cost_host.get_child_count(), 0, "无 cost_info → CostHost 空")
	popup.remove_window()
	root.queue_free()


# 源 poptavernloot.lua:287-296 BOX_FCA_MAP：补全 magic/starshop（P1-C2 修复）。
func test_box_fca_map_includes_magic_starshop() -> void:
	assert_true(PopTavernLoot.BOX_FCA_MAP.has("magic"), "BOX_FCA_MAP 含 magic")
	assert_true(PopTavernLoot.BOX_FCA_MAP.has("starshop"), "BOX_FCA_MAP 含 starshop")
	# starshop 复用 gold 资源（源 :292）
	assert_eq(String(PopTavernLoot.BOX_FCA_MAP["starshop"]), "effect/eff_UI_tarven_open_chest_gold",
		"starshop 复用 gold FCA 资源")
	# magic 资源名照源拼写（tavern 非 tarven）
	assert_eq(String(PopTavernLoot.BOX_FCA_MAP["magic"]), "effect/eff_UI_tavern_open_magicsoul",
		"magic FCA 资源照源拼写")


# 源 getLootPos :406-409 magic 分支：ccpAdd(matrix_center_pos, magic_loot_pos[index])（P1-C3 修复）。
func test_magic_circle_layout() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	# magic box 3 loot → 圆环前 3 个位置
	popup.setup_loot([{"id": 101, "amount": 1}, {"id": 102, "amount": 1}, {"id": 103, "amount": 1}], cm, "magic", "ten")
	popup.show_window(root)
	assert_eq(popup._loot_targets.size(), 3, "magic 3 loot targets")
	# 第 1 个 target 应在 matrix_center_pos + magic_loot_pos[0]（经 _g 坐标转换）
	var expected0 := popup._g(PopTavernLoot.MAGIC_CENTER_POS + PopTavernLoot.MAGIC_LOOT_POS[0])
	assert_almost_eq(popup._loot_targets[0].x, expected0.x, 0.5, "magic loot[0] x = center + magic_pos[0]")
	assert_almost_eq(popup._loot_targets[0].y, expected0.y, 0.5, "magic loot[0] y = center + magic_pos[0]")
	# 非 magic（bronze）回退 GRID 布局（2 loot → index 0 = GRID_ORIGIN）
	var popup2 := PopTavernLoot.new("poptavernloot", {})
	popup2.setup_loot([{"id": 101, "amount": 1}, {"id": 102, "amount": 1}], cm, "bronze", "ten")
	popup2.show_window(root)
	var bronze_expected := popup2._g(PopTavernLoot.GRID_ORIGIN)
	assert_almost_eq(popup2._loot_targets[0].x, bronze_expected.x, 0.5, "bronze loot[0] x = GRID_ORIGIN")
	popup.remove_window()
	popup2.remove_window()
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


# P0-4：源 poptavernloot.lua:340-343 + 378-405 magic box FCA 后建 matrixContainer（圆阵呼吸）。
# create_matrix_container_anim 在 _loot_host 加 Control > circle_1（tavern_magicsoul_circle_1.png）。
func test_magic_box_creates_circle() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "magic", "ten")
	popup.show_window(root)
	await popup.box_shown
	# 圆阵挂 _loot_host：递归找含 tavern_magicsoul_circle_1 的 TextureRect。
	var has_circle: bool = _has_texture_with_path(popup._loot_host, "tavern_magicsoul_circle_1")
	assert_true(has_circle, "magic box → matrixContainer 含 circle_1")
	popup.remove_window()
	root.queue_free()


# P0-5：源 poptavernloot.lua:430-461 playMagicLootShadeAnim magic 分支加 tavern_magicsoul_item_bg 阴影。
# 阴影挂 _loot_host（与 icon 同层），飞完后仍在（fadeout 1s），等待 loot_anim_done 后短窗口内可见。
func test_magic_loot_shade_anim() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "magic", "ten")
	popup.show_window(root)
	await popup.loot_anim_done
	var has_shade: bool = _has_texture_with_path(popup._loot_host, "tavern_magicsoul_item_bg")
	assert_true(has_shade, "magic loot → tavern_magicsoul_item_bg 阴影")
	popup.remove_window()
	root.queue_free()


# P0-6：源 poptavernloot.lua:629-636 loot 名字 Label（hero→Unit Display Name / equip→Equip Name）。
# 飞完后 _loot_host 加 Label，文字非空。
func test_loot_name_label_added() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	# 101 是装备 id（≥100）→ Equip.Name 经 LSTR
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "bronze", "one")
	popup.show_window(root)
	await popup.loot_anim_done
	var name_label: Label = null
	for c in popup._loot_host.get_children():
		if c is Label and String((c as Label).text).length() > 0:
			# 排除 cost_label（在 CostHost 不在 LootHost，但保险起见查文字非空且非 cost 数字）
			if not String((c as Label).text).is_valid_int():
				name_label = c as Label
				break
	assert_not_null(name_label, "loot 飞完后 _loot_host 加名字 Label")
	popup.remove_window()
	root.queue_free()


# 递归扫子树找 TextureRect 含指定资源路径片段。
func _has_texture_with_path(node: Node, path_fragment: String) -> bool:
	if node is TextureRect and node.texture != null:
		if String(node.texture.resource_path).find(path_fragment) >= 0:
			return true
	for c in node.get_children():
		if _has_texture_with_path(c, path_fragment):
			return true
	return false
