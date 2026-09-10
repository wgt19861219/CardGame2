extends GutTest
# HeroPackageItem 测试（P0-1 整行卡片重建）：照源 heroitem.lua baseheroitem + packageheroitem。
# 已拥有→装备槽路径；未拥有→灵魂石进度条路径。is_miss/tid 字段 + bg 子节点结构验证。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 baseheroitem create + packageheroitem create（拥有分支）：createHeroEquips。
func test_item_owned_is_not_miss() -> void:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var hero: HeroInstance = mgr.find_hero_by_tid(1)
	assert_not_null(hero, "tid=1 英雄应存在")
	var item := HeroPackageItem.create_from_entry(hero, cm, mgr)
	assert_false(item.is_miss, "已拥有英雄 → is_miss=false")
	assert_eq(item.tid, 1, "tid 从 HeroInstance 传递")
	assert_eq(item.custom_minimum_size, HeroPackageItem.CELL_SIZE, "cell 最小尺寸 = 260×100")


# 源 packageheroitem create（miss 分支）：setSpriteGray + createHeroStone。
func test_item_miss_has_stone_bar() -> void:
	var entry: Dictionary = {"tid": 2, "miss": true}
	var mgr := HeroManager.new(cm)
	var item := HeroPackageItem.create_from_entry(entry, cm, mgr)
	assert_true(item.is_miss, "未拥有 dict → is_miss=true")
	assert_eq(item.tid, 2, "tid 从 miss dict 取")
	assert_not_null(item.head, "miss 路径仍建 head ReadheroIcon")


# 源 baseheroitem :20-25 — miss 用 createIcon{id,rank=1}（无 level/stars），ori_icon 灰化。
func test_item_miss_head_grayed() -> void:
	var entry: Dictionary = {"tid": 2, "miss": true}
	var mgr := HeroManager.new(cm)
	var item := HeroPackageItem.create_from_entry(entry, cm, mgr)
	if item.head == null or item.head.ori_icon == null:
		pending("head/ori_icon 未建（纹理缺失），跳过灰化检查")
		return
	assert_eq(item.head.ori_icon.modulate, HeroPackageItem.GRAY_MODULATE, "未拥有头像灰化")


# bg TextureRect 应作为首子节点（源 baseheroitem bg 为容器根）。
func test_item_has_bg_texture() -> void:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var hero: HeroInstance = mgr.find_hero_by_tid(1)
	var item := HeroPackageItem.create_from_entry(hero, cm, mgr)
	# Phase A 重构（2026-07-18）：bg 在 content 子场景下，递归扫描（坑 6 .tscn 多一层 content）。
	var bg: TextureRect = _find_first_texture_rect(item)
	assert_not_null(bg, "item 应含 TextureRect bg 子节点（content 下）")


# 子节点全部 mouse_filter=IGNORE（装饰不吞点击），唯 item 自身 STOP（源 bg 点击由 draglist 捕获）。
func test_item_decorations_ignore_mouse() -> void:
	var entry: Dictionary = {"tid": 2, "miss": true}
	var mgr := HeroManager.new(cm)
	var item := HeroPackageItem.create_from_entry(entry, cm, mgr)
	# Phase A 重构（2026-07-18）：装饰在 content 子树，递归收集 Control（head 是 Node2D 自动断链不进）。
	var decos: Array = []
	_collect_controls(item, decos)
	for c in decos:
		assert_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "装饰子节点应 IGNORE 鼠标")
	assert_gt(decos.size(), 5, "应收集多个装饰节点（bg/name/mark/slot/bar 等）")


# Phase A 重构辅助：递归找首个 TextureRect（.tscn 多一层 content，坑 6）。
static func _find_first_texture_rect(node: Node) -> TextureRect:
	for c in node.get_children():
		if c is TextureRect:
			return c as TextureRect
		var sub: TextureRect = _find_first_texture_rect(c)
		if sub != null:
			return sub
	return null


# Phase A 重构辅助：递归收集 Control（head 是 Node2D 自动断链不进 head 子树）。
static func _collect_controls(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Control:
			out.append(c)
			_collect_controls(c, out)


# ── 两件套守卫（批 1 Task 9，2026-08-15）：theme variation 接线 + mark 等比 + 零静态 .new() 白名单 ──

const CS: float = 1.28125


# item 内容场景实例（.tscn 直查静态树）。
func _instantiate_item_content() -> Control:
	var scene: PackedScene = load("res://scenes/ui/hero_package_item_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	return inst


# 名字/后缀走 HeroPackageNameLabel variation（源 heroitem.lua:32 size20 白+黑阴影(0,2)，
# readhero.createHeroNameByInfo 同规格），tscn 不再 theme_override_*。
# 石头进度文字走 HeroPackageStoneLabel size18（源 :151 createttf(text,18)，旧 14 随手值修正）。
func test_item_theme_variations() -> void:
	var inst: Control = _instantiate_item_content()
	var name_lbl: Label = inst.get_node("%NameHost/NameLabel") as Label
	assert_eq(name_lbl.theme_type_variation, &"HeroPackageNameLabel", "NameLabel 走 variation")
	assert_false(name_lbl.has_theme_font_size_override("font_size"), "NameLabel 无字号 override")
	assert_false(name_lbl.has_theme_color_override("font_shadow_color"), "NameLabel 无阴影色 override")
	var suffix_lbl: Label = inst.get_node("%NameHost/SuffixLabel") as Label
	assert_eq(suffix_lbl.theme_type_variation, &"HeroPackageNameLabel", "SuffixLabel 走 variation（色 fill 动态 override）")
	var stone_lbl: Label = inst.get_node("%StoneGroup/StoneLabel") as Label
	assert_eq(stone_lbl.theme_type_variation, &"HeroPackageStoneLabel", "StoneLabel 走 variation")
	assert_false(stone_lbl.has_theme_font_size_override("font_size"), "StoneLabel 无字号 override")


# mark 等比（源 heroitem.lua:38-42 markIcon scale 0.8 等比）：纹理 59×59 → 显示 59/CS×0.8=36.8 方形。
# 旧 tscn 37×32 非等比拉伸变形 → 本批修正为等比（位置保留 d50674d 照源验收值）。
func test_item_mark_rect_aspect() -> void:
	var inst: Control = _instantiate_item_content()
	var mark: TextureRect = inst.get_node("%MarkRect") as TextureRect
	assert_almost_eq(mark.offset_right - mark.offset_left, 59.0 / CS * 0.8, 0.1, "mark 宽=59/CS×0.8 等比")
	assert_almost_eq(mark.offset_bottom - mark.offset_top, 59.0 / CS * 0.8, 0.1, "mark 高=59/CS×0.8 等比")


# 白名单式 .new( 断言：HeroPackageItem.new（自身工厂）+ ReadheroIcon（head 动态工厂）+
# TextureRect（plusSign/equip icon 动态数据图标，源运行时按槽位状态创建）+ AtlasTexture（进度条
# 纹理按 ratio 动态截取，照源 setTextureRect 语义）。静态结构（bg/slot/bar 组）零 .new(。
func test_item_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_package_item.gd")
	assert_eq(text.count(".new("), text.count("HeroPackageItem.new(") + text.count("ReadheroIcon.new(")
		+ text.count("TextureRect.new(") + text.count("AtlasTexture.new("),
		"静态节点零 .new(，仅工厂与动态图标/动态纹理白名单")


# ── 卡片红点 canDealTag（2026-08-18 修复轮 A：快捷栏红点亮但卡片无红点）──
# 判据与快捷栏 heroPackage 红点同源（EquipdetailQuery.is_slot_ready_to_wear，
# 源 readhero.lua:734-750 checkEquipableProp 单英雄粒度）；贴图 main_deal_tag（源 heroitem :243-248）。

# 可穿装备（持有 eid + level≥LvReq）→ 拥有卡片 TipHost 亮。
# hero1 rank1 slot1 eid=102（LvReq=2）：pd.items[102]=1（has 路径 craftable）+ hero.level=2 → ready。
func test_item_deal_tag_shown_when_wearable() -> void:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var hero: HeroInstance = mgr.find_hero_by_tid(1)
	hero.level = 2
	var pd := PlayerData.new(cm)
	var eid: int = EquipdetailQuery.get_slot_expected_equip(hero, 1, cm)
	assert_gt(eid, 0, "hero1 rank1 slot1 应有配方 eid")
	pd.items[eid] = 1   # 背包持有 → is_equip_craftable has 路径 true
	var item := HeroPackageItem.create_from_entry(hero, cm, mgr, pd)
	var tip_host: Control = _find_node_by_name(item, "TipHost")
	assert_not_null(tip_host, "TipHost 应存在")
	assert_true(EquipdetailQuery.is_slot_ready_to_wear(hero, 0, cm, pd), "前置：slot1 判定 ready（与快捷栏同判据）")
	assert_true(tip_host.visible, "可穿装备英雄卡片红点亮（修复前 _build 末尾覆盖 visible 恒灭）")


# 全穿好（6 槽 isEquiped）→ 卡片红点不亮。
func test_item_deal_tag_hidden_when_all_equipped() -> void:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var hero: HeroInstance = mgr.find_hero_by_tid(1)
	hero.level = 2
	var pd := PlayerData.new(cm)
	hero.equip_slots = [102, 102, 111, 107, 108, 109]   # 6 槽全穿（hero1 rank1 配方）
	var item := HeroPackageItem.create_from_entry(hero, cm, mgr, pd)
	var tip_host: Control = _find_node_by_name(item, "TipHost")
	assert_not_null(tip_host, "TipHost 应存在")
	assert_false(tip_host.visible, "全穿好不亮（已穿戴槽 eti 为空）")


# 持有但等级不够（level 1 < LvReq 2）→ 不亮（can_wear false）。
func test_item_deal_tag_hidden_when_level_too_low() -> void:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var hero: HeroInstance = mgr.find_hero_by_tid(1)
	hero.level = 1
	var pd := PlayerData.new(cm)
	pd.items[102] = 1
	var item := HeroPackageItem.create_from_entry(hero, cm, mgr, pd)
	var tip_host: Control = _find_node_by_name(item, "TipHost")
	assert_not_null(tip_host, "TipHost 应存在")
	assert_false(tip_host.visible, "等级不够穿不亮")


# miss 卡片红点必隐（未拥有无装备可穿，SummonLight 呼吸光效是源对可召唤的表达）。
func test_item_deal_tag_hidden_on_miss() -> void:
	var entry: Dictionary = {"tid": 2, "miss": true}
	var mgr := HeroManager.new(cm)
	var item := HeroPackageItem.create_from_entry(entry, cm, mgr)
	var tip_host: Control = _find_node_by_name(item, "TipHost")
	assert_not_null(tip_host, "TipHost 应存在")
	assert_false(tip_host.visible, "miss 卡片红点必隐")


# 递归找名（TipHost 在 content 子场景层下）。
static func _find_node_by_name(node: Node, node_name: String) -> Control:
	for c in node.get_children():
		if c.name == node_name:
			return c as Control
		var sub: Control = _find_node_by_name(c, node_name)
		if sub != null:
			return sub
	return null


# 2026-08-28 +N 叠字修复守卫：NameLabel/SuffixLabel 必须左对齐（HORIZONTAL_ALIGNMENT_LEFT）。
# 居中对齐下 fill 的 suffix 定位基准（控件左缘+minimum_size）与 text 实际起点错位 → "+1"叠进名字
# （4 字名最重，实测恶魔巫师"+1"插名字中间/叠末字）。源 baseheroitem 名字锚 (0,0.5) 左起语义。
func test_item_name_labels_left_aligned() -> void:
	var inst: Control = _instantiate_item_content()
	var name_lbl: Label = inst.get_node("%NameHost/NameLabel") as Label
	var suffix_lbl: Label = inst.get_node("%NameHost/SuffixLabel") as Label
	assert_eq(name_lbl.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "NameLabel 左对齐（suffix 定位基准）")
	assert_eq(suffix_lbl.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "SuffixLabel 左对齐")


# suffix 定位在 name 渲染右缘之外（挂树后 deferred 重摆效果；GUT 同帧直查仅验首摆不叠：
# start_x ≥ 0 且 suffix.x = start_x + name 显示宽 + GAP ≥ name 右缘）。
func test_item_suffix_positioned_after_name() -> void:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var hero: HeroInstance = mgr.find_hero_by_tid(1)
	hero.rank = 3   # hero_star[3]=1 → "+1" 后缀可见（rank1 默认无后缀走不进断言）
	var item := HeroPackageItem.create_from_entry(hero, cm, mgr)
	add_child_autofree(item)
	var name_lbl: Label = _find_node_by_name(item, "NameLabel") as Label
	var suffix_lbl: Label = _find_node_by_name(item, "SuffixLabel") as Label
	assert_not_null(name_lbl, "NameLabel 应存在")
	assert_not_null(suffix_lbl, "SuffixLabel 应存在")
	if star_by_rank(hero.rank) > 0:
		assert_true(suffix_lbl.visible, "rank 有星 → suffix 可见")
		# suffix 起点 ≥ name 起点 + name 显示宽（scale 后）+ 间距，不叠字。
		var scale_val: float = name_lbl.scale.x
		assert_almost_eq(suffix_lbl.scale.x, scale_val, 0.01, "suffix 与 name 同 scale")
		var name_render_w: float = name_lbl.get_minimum_size().x * scale_val
		assert_gt(suffix_lbl.position.x, name_lbl.position.x + name_render_w - 1.0,
			"suffix 起点在 name 渲染右缘之后（允许 1px 容差）")


# 源 player.lua hero_star：rank→星数（"+N" 的 N）；只取本用例所需档位防表漂移全量复制。
static func star_by_rank(rank: int) -> int:
	var table: Array[int] = [0, 0, 1, 0, 1, 2, 0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 5]
	if rank < 1 or rank >= table.size():
		return 0
	return table[rank - 1]


# ── 2026-08-28 根修守卫：点空间直译口径（废 root scale 1/CS + 元素×CS 烘焙双重变换链）──
# 源 heroitem.lua bg=package_hero_bg 313×123px 无 TextureConfig 条目 → 显示=px÷CS=244.34×96.00，
# 居中 cell 260×100 → bg rect (7.83,2)~(252.17,98)。旧口径 313×123 直显（编辑器 313/运行 0.78 缩）。
func test_item_bg_display_size_divided_by_cs() -> void:
	var inst: Control = _instantiate_item_content()
	var bg: TextureRect = inst.get_node("Bg") as TextureRect
	assert_almost_eq(bg.offset_right - bg.offset_left, 313.0 / CS, 0.1, "bg 显示宽=313/CS=244.34")
	assert_almost_eq(bg.offset_bottom - bg.offset_top, 123.0 / CS, 0.1, "bg 显示高=123/CS=96.00")
	assert_almost_eq((bg.offset_left + bg.offset_right) * 0.5, 130.0, 0.1, "bg 中心 x=cell 中心 130")
	assert_almost_eq((bg.offset_top + bg.offset_bottom) * 0.5, 50.0, 0.1, "bg 中心 y=cell 中心 50")


# 源 heroitem.lua:27-28 head anchor(0,0)@(7,9) bg 局部 → head 底=cell y 2+96−9=89、顶=89−104=−15
# （head 顶溢出 cell/bg 顶=源真容，原版头像框上缘溢出卡背）。旧值 y=0.03 系 ×CS 烘焙漏 y 翻转
# → head 整体下偏 26 点 → 星星压下一行卡顶（2026-08-28 实测定罪根修）。
func test_item_head_host_y_flipped_from_source() -> void:
	var inst: Control = _instantiate_item_content()
	var host: Control = inst.get_node("%HeadHost") as Control
	assert_almost_eq(host.offset_left, 7.83 + 7.0, 0.1, "head 左=bg 局部 7 直译=14.83")
	assert_almost_eq(host.offset_top, 2.0 + 96.0 - 9.0 - 104.0, 0.1, "head 顶=bg(96)−9−104=−15（y 翻转，源真容溢出）")
	assert_almost_eq(host.offset_bottom, 2.0 + 96.0 - 9.0, 0.1, "head 底=bg 局部 y9 直译=89")


# 源 heroitem.lua:222-228 equipBg setScale(22/w) → 22×22 方；中心 (105+22*(i-1),18) bg 局部。
# 旧 28 系缩放链补偿值（28×0.78≈21.8 视觉碰巧≈源 22），根修后直接 22 视觉不变。
func test_item_equip_slot_22_and_source_positions() -> void:
	var inst: Control = _instantiate_item_content()
	var group: Control = inst.get_node("%EquipGroup") as Control
	for i in range(6):
		var slot: TextureRect = inst.get_node("%EquipSlot" + str(i + 1)) as TextureRect
		assert_almost_eq(slot.offset_right - slot.offset_left, 22.0, 0.1, "slot%d 宽=22（源 setScale(22/w)）" % (i + 1))
		assert_almost_eq(slot.offset_bottom - slot.offset_top, 22.0, 0.1, "slot%d 高=22" % (i + 1))
		# 槽 i 中心全局（group 基准 + slot offset）= bg 局部 (105+22i, 18) 直译 = (112.83+22i, 80)
		var cx: float = group.offset_left + (slot.offset_left + slot.offset_right) * 0.5
		var cy: float = group.offset_top + (slot.offset_top + slot.offset_bottom) * 0.5
		assert_almost_eq(cx, 7.83 + 105.0 + 22.0 * i, 0.15, "slot%d 中心 x=bg 局部 %d 直译" % [i + 1, 105 + 22 * i])
		assert_almost_eq(cy, 2.0 + 96.0 - 18.0, 0.15, "slot%d 中心 y=80（bg 局部 18 翻转）" % (i + 1))


# 源 heroitem.lua:30-36/107 名字中心恒 bg 局部 (177,72)（scale 压缩至 ow=100 内居中）。
# NameHost 中心=(7.83+177, 2+96−72)=(184.83,26)、宽=ow=100。旧中心 163 系手工调值（上轮遗留偏左 14px 同根因）。
func test_item_name_host_centered_at_source_177() -> void:
	var inst: Control = _instantiate_item_content()
	var host: Control = inst.get_node("%NameHost") as Control
	assert_almost_eq((host.offset_left + host.offset_right) * 0.5, 7.83 + 177.0, 0.1, "NameHost 中心 x=bg 局部 177 直译=184.83")
	assert_almost_eq((host.offset_top + host.offset_bottom) * 0.5, 2.0 + 96.0 - 72.0, 0.1, "NameHost 中心 y=26（bg 局部 72 翻转）")
	assert_almost_eq(host.offset_right - host.offset_left, 100.0, 0.1, "NameHost 宽=源 ow=100")


# 源 heropackage.lua:761 draglist cliprect=CCRect(0,45,800,348) 全屏宽视觉裁剪 → Godot (0,87,800,435)。
# 旧 (105,95,625,443) 误用源 rect（触摸区）口径且窄 275 → 左右列卡 bg 外缘各被裁 26.5（用户"裁剪"主诉）。
# GridHost 内容基准 105（GRID_ORIGIN_X）：首列 bg 左缘=105+7.83=112.83≈源 112.84（源 getpos 首列中心 235）。
func test_scroll_cliprect_fullwidth_and_grid_origin() -> void:
	var scene: PackedScene = load("res://scenes/ui/hero_package_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	var scroll: ScrollContainer = inst.get_node("%HeroScroll") as ScrollContainer
	assert_almost_eq(scroll.offset_left, 0.0, 0.1, "scroll 左缘 0（源 cliprect x=0 全宽）")
	assert_almost_eq(scroll.offset_top, 480.0 - 45.0 - 348.0, 0.1, "scroll 顶=480−45−348=87（源 cliprect y 翻转）")
	assert_almost_eq(scroll.offset_right, 800.0, 0.1, "scroll 右缘 800（源 cliprect 全宽）")
	assert_almost_eq(scroll.offset_bottom, 435.0, 0.1, "scroll 底=87+348=435")
	assert_almost_eq(HeroPackagePanel.GRID_ORIGIN.x + 7.83, 235.0 - 313.0 / CS / 2.0, 0.1,
		"首列 bg 左缘=源 112.84（GRID_ORIGIN.x 承载源 offsetx+rect 基准）")
	assert_almost_eq(87.0 + HeroPackagePanel.GRID_ORIGIN.y + 2.0, 480.0 - 335.0 - 96.0 / 2.0, 0.1,
		"首行 bg 顶=源 97（源 getpos toy=335 全屏 cocos → 480−335−48）")


# ── 灵魂石进度条贴合守卫（2026-09-10 根修）──
# 源 heroitem.lua:147 bar setTextureRect(150,26) 漏考虑父 barBg scaleX0.93 级联：满宽 139.5
# vs 框 147.9 右侧空 8.4（实机 VisualCoding 实测 ≈6% 框宽），「可召唤」100% 视觉像 94%。
# 根修：fill 几何从 BarBg offset 推导四边贴合框（对齐 hero_detail StoneBar 满宽=框宽范式）。

# 满进度（sa=sn，可召唤）：BarFill 四边贴合 BarBg。
func test_item_stone_bar_fill_fits_bar_bg_at_full() -> void:
	var entry: Dictionary = {"tid": 2, "miss": true}
	var mgr := HeroManager.new(cm)
	var sid: int = ReadheroHandbook.get_stone_id(2, cm)
	var need: int = ReadheroHandbook.get_stone_need(2, cm, mgr)
	if need <= 0:
		pending("tid=2 无召唤需求数据，跳过")
		return
	mgr.add_fragment(sid, need)
	var item := HeroPackageItem.create_from_entry(entry, cm, mgr)
	var stone: Control = (item.get_child(0) as Control).get_node("%StoneGroup") as Control
	var bar_bg: TextureRect = stone.get_node("BarBg") as TextureRect
	var fill: TextureRect = stone.get_node("%BarFill") as TextureRect
	assert_almost_eq(fill.offset_left, bar_bg.offset_left, 0.01, "fill 左缘=框左缘")
	assert_almost_eq(fill.offset_top, bar_bg.offset_top, 0.01, "fill 顶缘=框顶缘")
	assert_almost_eq(fill.offset_right, bar_bg.offset_right, 0.01, "满进度 fill 右缘=框右缘（治右侧空 8.4）")
	assert_almost_eq(fill.offset_bottom, bar_bg.offset_bottom, 0.01, "fill 底缘=框底缘")
	var lbl: Label = stone.get_node("%StoneLabel") as Label
	var ls: Vector2 = lbl.get_minimum_size()
	assert_almost_eq(lbl.position.x + ls.x * 0.5, (bar_bg.offset_left + bar_bg.offset_right) * 0.5, 0.01,
		"进度文字中心 x=框中心（源 setPosition(80,13) 系未缩放宽 159.2 坐标系的居中意图，80 直译偏右 6）")


# 部分进度（0<sa<sn）：fill 左缘贴框、宽度按 sa/sn 比例落框内、右缘不越框。
func test_item_stone_bar_fill_partial_ratio_in_frame() -> void:
	var entry: Dictionary = {"tid": 2, "miss": true}
	var mgr := HeroManager.new(cm)
	var sid: int = ReadheroHandbook.get_stone_id(2, cm)
	var need: int = ReadheroHandbook.get_stone_need(2, cm, mgr)
	if need <= 0:
		pending("tid=2 无召唤需求数据，跳过")
		return
	var sa: int = maxi(1, int(need / 2))
	mgr.add_fragment(sid, sa)
	var item := HeroPackageItem.create_from_entry(entry, cm, mgr)
	var stone: Control = (item.get_child(0) as Control).get_node("%StoneGroup") as Control
	var bar_bg: TextureRect = stone.get_node("BarBg") as TextureRect
	var fill: TextureRect = stone.get_node("%BarFill") as TextureRect
	var frame_w: float = bar_bg.offset_right - bar_bg.offset_left
	assert_almost_eq(fill.offset_left, bar_bg.offset_left, 0.01, "fill 左缘=框左缘")
	assert_almost_eq(fill.offset_right - fill.offset_left, frame_w * float(sa) / float(need), 0.01,
		"部分进度 fill 宽=框宽×sa/sn")
	assert_lt(fill.offset_right, bar_bg.offset_right + 0.01, "部分进度 fill 右缘不超框")
	# 2026-09-10 二轮根修：纹理照源 setTextureRect 截取左段（AtlasTexture region）。SCALE 整条压缩
	# 会把条左端 13px 透明带随 ratio 缩小（9.4×ratio），小比例时条内容起点左移出框描边（框透明带恒
	# 8.7 点）→「数量小时左边不对齐边框」；截取后 region 与 rect 同比例，压缩比恒=框，任意比例对齐。
	assert_true(fill.texture is AtlasTexture, "部分进度纹理走 AtlasTexture 截取（照源 setTextureRect 语义）")
	if fill.texture is AtlasTexture:
		var at: AtlasTexture = fill.texture as AtlasTexture
		var src_w: float = float(at.atlas.get_width())
		assert_almost_eq(at.region.size.x, src_w * float(sa) / float(need), 0.01,
			"region 宽=源纹理宽×sa/sn（纹理像素不随比例压缩变形）")
		assert_eq(at.region.position.x, 0.0, "region 从纹理左端截取（含左透明带，与框描边恒对齐）")
