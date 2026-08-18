extends GutTest
# PopTavernLoot 抽卡产出弹窗测试（照源 poptavernloot.lua）。

const THEME_PATH: String = "res://resources/themes/default_theme.tres"
const PANEL_PATH: String = "res://scripts/ui/pop_tavern_loot.gd"

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# Phase A 静态化（2026-07-18）+ 批5 两件套（2026-08-18）：chrome 搬进 pop_tavern_loot_content.tscn，
# container → Content → {LootHost/CostBg/CostIcon/CostLabel/AgainBtn/CloseBtn/RewardLabel}（照源 readnode 声明序）。
# 扫描层级：container 1 子（Content），Content 7 静态子（loot icons 挂 LootHost，cost 三节点静态化）。
func test_setup_loot_single() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "bronze", "one", {"pay": "Diamond", "number": 288})
	popup.show_window(root)
	assert_eq(popup.container.get_child_count(), 1, "container 仅挂 Content（.tscn 根）")
	var content: Control = popup.container.get_child(0)
	assert_eq(content.get_child_count(), 7, "Content 7 静态子（LootHost+CostBg+CostIcon+CostLabel+AgainBtn+CloseBtn+RewardLabel）")
	assert_eq(popup._loot_host.get_child_count(), 1, "单抽 LootHost 1 loot icon")
	# cost 三节点静态化后 fill 可见（源 status==0 readnode 全量建 cost 行）
	assert_true((content.get_node("%CostBg") as Control).visible, "CostBg fill 后可见")
	assert_true((content.get_node("%CostIcon") as Control).visible, "CostIcon fill 后可见")
	assert_true((content.get_node("%CostLabel") as Control).visible, "CostLabel fill 后可见")
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
	# 无 cost_info → 静态 cost 三节点隐藏（源 starshop/无 addition.cost 不建按钮层 cost 行）
	var content: Control = popup.container.get_child(0)
	assert_false((content.get_node("%CostBg") as Control).visible, "无 cost → CostBg 隐藏")
	assert_false((content.get_node("%CostIcon") as Control).visible, "无 cost → CostIcon 隐藏")
	assert_false((content.get_node("%CostLabel") as Control).visible, "无 cost → CostLabel 隐藏")
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


# ── 批5 两件套改造（2026-08-18）：费用行 chrome 静态化 + theme variation + 分支布局 ──
# 源 playButtonAnim status==0 readnode 声明表（poptavernloot.lua:738-864）：
# cost_bg(tip_detail_bg scalexy y=2) → cost_icon → cost → tavern → ok → reward_label；
# 本项目 box_type=stone_* 对应源 type="starshop" 分支（:679-731 ok 居中 ccp(400,50)、无 tavern/cost）。

# 静态树 + rect 值 + 绘制序守卫（声明序照源 readnode：cost_bg 先于按钮、reward_label 最后声明）。
func test_cost_chrome_static_layout() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "bronze", "one", {"pay": "Diamond", "number": 288})
	popup.show_window(root)
	var content: Control = popup._content
	var cost_bg: TextureRect = content.get_node("%CostBg") as TextureRect
	assert_not_null(cost_bg, "CostBg 静态节点存在")
	assert_eq(String(cost_bg.texture.resource_path), "res://assets/ui/alpha/HVGA/tip_detail_bg.png",
		"CostBg 贴图照源 tip_detail_bg")
	# tip_detail_bg 161×27 ÷CS(1.28125) 再源 scalexy y=2 → 125.61×42.15（rect 拉伸直译等效 scaleY）
	assert_almost_eq(cost_bg.size.x, 125.61, 0.1, "CostBg 宽=161/1.28125=125.61")
	assert_almost_eq(cost_bg.size.y, 42.15, 0.1, "CostBg 高=27/1.28125×2=42.15")
	# 绘制序（源声明序直译，防按钮被后声明层遮盖）
	assert_lt((content.get_node("%CostBg") as Control).get_index(), (content.get_node("%AgainBtn") as Control).get_index(),
		"CostBg 先于 AgainBtn（源 cost_bg 先声明）")
	assert_lt((content.get_node("%AgainBtn") as Control).get_index(), (content.get_node("%CloseBtn") as Control).get_index(),
		"AgainBtn 先于 CloseBtn（源 tavern 先于 ok 声明）")
	assert_lt((content.get_node("%CloseBtn") as Control).get_index(), (content.get_node("%RewardLabel") as Control).get_index(),
		"RewardLabel 最后声明（源 :850-863 reward_label 在 ok 后）")
	popup.remove_window()
	root.queue_free()


# 源 :1014-1022 cost 行重排：label 右缘 240（anchor(1,0.5)）/ icon 右缘紧贴 label 左缘 @y48 /
# bg 中心 = (240-(label_w+icon_w)/2, 50)。Godot：右缘/中心经 to_godot。
func test_cost_row_fill_layout() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "bronze", "one", {"pay": "Diamond", "number": 288})
	popup.show_window(root)
	var content: Control = popup._content
	var label: Label = content.get_node("%CostLabel") as Label
	assert_eq(label.text, "288", "cost 文本 = 数字")
	var icon: TextureRect = content.get_node("%CostIcon") as TextureRect
	assert_true(String(icon.texture.resource_path).find("task_rmb_icon_2") >= 0, "Diamond → rmb 图标（源 :756）")
	# label 右缘 = to_godot_x(240) = 320
	assert_almost_eq(label.position.x + label.size.x, 320.0, 0.5, "cost label 右缘 = 320（源 240）")
	assert_almost_eq(label.position.y + label.size.y * 0.5, 510.0, 0.5, "cost label 垂直中心 = 510（源 y50）")
	# icon 右缘紧贴 label 左缘（源 ci anchor(1,0.5)@(240-w,48)）
	assert_almost_eq(icon.position.x + icon.size.x, label.position.x, 0.5, "icon 右缘紧贴 label 左缘")
	# icon 显示尺寸 = 纹理原始像素 ÷ CS（35×33 → 27.32×25.76；批5 口径手算，不用 TexDisplaySize）
	assert_almost_eq(icon.size.x, 27.32, 0.06, "rmb icon 宽 = 35/1.28125 = 27.32")
	# bg 中心 = (320-(label_w+icon_w)/2, 510)（源 :1021-1022）
	var cost_bg: TextureRect = content.get_node("%CostBg") as TextureRect
	var total_w: float = label.size.x + icon.size.x
	assert_almost_eq(cost_bg.position.x + cost_bg.size.x * 0.5, 320.0 - total_w * 0.5, 0.5,
		"CostBg 中心 x = 320-总宽/2（源 240-w/2）")
	assert_almost_eq(cost_bg.position.y + cost_bg.size.y * 0.5, 510.0, 0.5, "CostBg 中心 y = 510（源 y50）")
	popup.remove_window()
	root.queue_free()


# Gold 分支 icon（源 :756 pay≠Diamond → task_gold_icon_2，41×37 → 32×28.88）。
func test_cost_row_gold_icon() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "bronze", "one", {"pay": "Gold", "number": 10000})
	popup.show_window(root)
	var icon: TextureRect = popup._content.get_node("%CostIcon") as TextureRect
	assert_true(String(icon.texture.resource_path).find("task_gold_icon_2") >= 0, "Gold → 金币图标")
	assert_almost_eq(icon.size.x, 32.0, 0.06, "gold icon 宽 = 41/1.28125 = 32.00")
	popup.remove_window()
	root.queue_free()


# 源 :678-731 starshop 分支（本项目 box_type=stone_*，star_shop_buy_window 传 stone_green/blue/purple）：
# ok 居中 ccp(400,50) → Godot 中心 (480,510)；无 tavern 再抽按钮；无 cost 行。
func test_starshop_layout_branch() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "stone_green")
	popup.show_window(root)
	var content: Control = popup._content
	assert_false((content.get_node("%AgainBtn") as Control).visible, "starshop 无再抽按钮（源 starshop 分支不建 tavern）")
	var close_btn: TextureButton = content.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(close_btn.position.x + close_btn.size.x * 0.5, 480.0, 0.5, "starshop ok 中心 x=480（源 400+80）")
	assert_almost_eq(close_btn.position.y + close_btn.size.y * 0.5, 510.0, 0.5, "starshop ok 中心 y=510（源 560-50）")
	assert_false((content.get_node("%CostBg") as Control).visible, "starshop 无 cost 行")
	popup.remove_window()
	root.queue_free()


# 源 :1036-1038 type=="magic" → reward_label:setVisible(false)。
func test_magic_hides_reward_label() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "magic", "one", {"pay": "Diamond", "number": 288})
	popup.show_window(root)
	assert_false((popup._content.get_node("%RewardLabel") as Control).visible, "magic → RewardLabel 隐藏（源 :1036-1038）")
	# 非 magic 保持可见
	var popup2 := PopTavernLoot.new("poptavernloot", {})
	popup2.setup_loot([{"id": 101, "amount": 1}], cm, "bronze", "one", {"pay": "Diamond", "number": 288})
	popup2.show_window(root)
	assert_true((popup2._content.get_node("%RewardLabel") as Control).visible, "bronze → RewardLabel 可见")
	popup.remove_window()
	popup2.remove_window()
	root.queue_free()


# 源 fca_res :293-295：stone_green/blue/purple → eff_UI_shop_star_box_*（green/blue 是 .abc zip、purple 是 .ani）。
func test_box_fca_map_includes_stone() -> void:
	assert_eq(String(PopTavernLoot.BOX_FCA_MAP.get("stone_green", "")), "effect/eff_UI_shop_star_box_green",
		"stone_green FCA 资源照源")
	assert_eq(String(PopTavernLoot.BOX_FCA_MAP.get("stone_blue", "")), "effect/eff_UI_shop_star_box_blue",
		"stone_blue FCA 资源照源")
	assert_eq(String(PopTavernLoot.BOX_FCA_MAP.get("stone_purple", "")), "effect/eff_UI_shop_star_box_purple",
		"stone_purple FCA 资源照源")


# theme variation 接线（GUT 下节点级不解析 variation，读 tres 文本表项 + 节点 theme_type_variation 断言）。
# 源 :799-812 tavern_label fontinfo ui_normal_button（fontconfigs.lua:23-31 size17 白，stroke 被注释）
# + config.color ccc3(231,206,19)；:837-849 ok_label ui_normal_button（17 白无描边）；
# :850-863 reward_label size18 ccc3(231,206,19)；:762-773 cost size18 白。旧实现 size18+outline 是迁移
# 发明（源 stroke 被注释，照批3 :408 先例 variation 化时删）。
func test_theme_variations_wired() -> void:
	var t: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(t.contains("TavernLootBtnGoldLabel/font_sizes/font_size = 17"), "再抽按钮金字 17 号（源 ui_normal_button）")
	assert_true(t.contains("TavernLootBtnGoldLabel/colors/font_color = Color(0.905882, 0.807843, 0.07451, 1)"),
		"再抽按钮金字 = ccc3(231,206,19)（源 :810）")
	assert_false(t.contains("TavernLootBtnGoldLabel/colors/font_outline_color"), "再抽按钮金字无描边（源 stroke 注释）")
	assert_true(t.contains("TavernLootBtnLabel/font_sizes/font_size = 17"), "确定按钮白字 17 号")
	assert_true(t.contains("TavernLootBtnLabel/colors/font_color = Color(1, 1, 1, 1)"), "确定按钮白字")
	assert_true(t.contains("TavernLootRewardLabel/font_sizes/font_size = 18"), "reward 18 号（源 :858 size=18）")
	assert_true(t.contains("TavernLootRewardLabel/colors/font_color = Color(0.905882, 0.807843, 0.07451, 1)"),
		"reward 金字 = ccc3(231,206,19)（源 :861）")
	assert_true(t.contains("TavernLootCostLabel/font_sizes/font_size = 18"), "cost 18 号（源 :767 size=18）")
	assert_true(t.contains("TavernLootCostLabel/colors/font_color = Color(1, 1, 1, 1)"), "cost 白字（CCLabelTTF 默认）")


# 费用行静态化守卫：panel 不再 procedural 建 Label/TextureRect（动态 Sprite2D/FCA/ReadequipIcon 保留）。
func test_no_procedural_cost_nodes() -> void:
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_false(text.contains("Label.new("), "无 Label.new（cost label 静态化进 tscn）")
	assert_false(text.contains("TextureRect.new("), "无 TextureRect.new（cost icon/bg 静态化进 tscn）")


# tscn variation 接线守卫：4 个静态文本节点走 theme_type_variation（禁内联 override）。
func test_tscn_variation_wiring() -> void:
	var root := Node.new()
	add_child(root)
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot([{"id": 101, "amount": 1}], cm, "bronze", "one", {"pay": "Diamond", "number": 288})
	popup.show_window(root)
	var content: Control = popup._content
	assert_eq(String((content.get_node("%AgainBtn/Label") as Label).theme_type_variation), "TavernLootBtnGoldLabel",
		"再抽按钮字走 variation")
	assert_eq(String((content.get_node("%CloseBtn/Label") as Label).theme_type_variation), "TavernLootBtnLabel",
		"确定按钮字走 variation")
	assert_eq(String((content.get_node("%RewardLabel") as Label).theme_type_variation), "TavernLootRewardLabel",
		"reward 走 variation")
	assert_eq(String((content.get_node("%CostLabel") as Label).theme_type_variation), "TavernLootCostLabel",
		"cost 走 variation")
	popup.remove_window()
	root.queue_free()
