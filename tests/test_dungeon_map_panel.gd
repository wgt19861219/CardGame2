extends GutTest

# DungeonMapPanel 守卫测试（批 3 Task 4 两件套，2026-08-16）。
# 照源 ui/dungeon_map.lua:538-676 create 主面板段 + gametable/dungeonmapconfig.lua
# buildUIRes（dragLayer: dragContainer+bg1-3+sub1-3 / mainLayer: light1-2+frame+
# titleBg+bottom(bottomframe)），:256-520 难度弹窗段已由 Task 2 dungeon_degree_popup
# 独立改造（本 panel 的 setup_popup 接口不得破坏）。
# 坐标口径：dragLayer=CCLayer 全屏 800×480 → Godot %Scroll 视口 (80,80)-(880,560)；
# 内容局部 (x,y) → (x, 480-y)（dragContainer 初始 (0,0) 与 dragLayer 原点重合，
# 内容局部经视口平移后场景位 = (x+80, 560-y) 与 to_godot 一致）。
# 贴图显示尺寸（本 task 实测 PIL + TextureConfig）：
#   - crusade 系 8 条条目全 Prescaled=false → 条目 CS 不施加（resource_manager.lua:50
#     EDFLAGWIN32 and not Prescaled → return 1；本项目资产即 win32 包），只算显式
#     setScale/readnode config.scale 累乘（readnode.lua:146-148 setScale(scale*os)）。
#   - bg1-3：467/465/348×254 px × layout scale 2.0 = 728.98/725.85/543.22 × 396.49。
#   - fog1-3：裸 CCSprite:create+setScale(4.0)（条目不参与）640×127 px → 1998.05×396.88。
#   - boss/box：裸 CCSprite:create 无条目 → 像素/CS（15 张 stage 图尺寸各异，fill 动态）；
#     box 另乘 setScale(0.8)，closed 89×84 → 55.57×52.44（rect 不随 open 图变，源 :212 只
#     setTexture 不改 contentSize）。
#   - frame 1029×566 / titleBg 510×118 / light 495×260 / backbtn 74×75 无条目 → 像素/CS。
# 守卫：tscn 静态树 rect / NinePatch cap 公式 / .new( 白名单 / builder 退役 /
# fill 语义（boss 动态尺寸/滚动内容宽=源 calcMaxRight 等价）/ 弹窗接口不破坏 /
# 迁移发明 ResultLabel 删除。

const CONTENT_PATH: String = "res://scenes/ui/dungeon_map_content.tscn"
const PANEL_PATH: String = "res://scripts/ui/dungeon_map_panel.gd"
const BUILDER_PATH: String = "res://scripts/ui/crusade_panel_builder.gd"
const CS: float = 1.28125


static func _make_panel(p_mode: String, p_groups: Array) -> DungeonMapPanel:
	var gi: Array[int] = []
	for g in p_groups:
		gi.append(int(g))
	var mgr := StageManager.new(GameData.config)
	var panel := DungeonMapPanel.new("dungeonMap", {})
	panel.setup_panel(GameData.player, mgr, BattleRng.new(randi()), p_mode, gi)
	return panel


# ── content tscn 静态树（源 dungeonmapconfig.lua dragLayer 段 + mainLayer 段）──

func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# Scroll（源 dragLayer 全屏 800×480 → 视口直译 (80,80)-(880,560)，只横滚）。
	var scroll: ScrollContainer = inst.get_node("%Scroll") as ScrollContainer
	assert_almost_eq(scroll.offset_left, 0.0, 0.1, "Scroll 左 = cocos x0+80")
	assert_almost_eq(scroll.offset_top, 0.0, 0.1, "Scroll 顶 = 560-480")
	assert_almost_eq(scroll.offset_right, 800.0, 0.1, "Scroll 右 = cocos x800+80")
	assert_almost_eq(scroll.offset_bottom, 480.0, 0.1, "Scroll 底 = 560-0")
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "竖滚禁用（源纯横向拖拽）")
	# ScrollContent（源 dragContainer：内容局部 y=480-cocos_y，初始内容 800×480）。
	var content: Control = inst.get_node("%ScrollContent") as Control
	assert_almost_eq(content.size.x, 800.0, 0.1, "ScrollContent 初始宽 800（fill 后按 boss 延伸）")
	assert_almost_eq(content.size.y, 480.0, 0.1, "ScrollContent 高 = 源 dragLayer 全屏 480")
	# Bg1-3（源 bg1-3 anchor(0,0.5) pos(25/752/1477,210) layout scale=2.0，
	# 条目 Prescaled=false 不施加 → 467/465/348×254px/CS×2）。
	var bg1: TextureRect = inst.get_node("%Bg1") as TextureRect
	assert_almost_eq(bg1.offset_left, 25.0, 0.1, "Bg1 左 = 源 anchor(0,0.5) x=25")
	assert_almost_eq(bg1.offset_top, 71.76, 0.1, "Bg1 顶 = 270-396.49/2（中心 y=480-210）")
	assert_almost_eq(bg1.offset_right - bg1.offset_left, 728.98, 0.1, "Bg1 宽 = 467/CS×2（layout scale 2.0）")
	assert_almost_eq(bg1.offset_bottom - bg1.offset_top, 396.49, 0.1, "Bg1 高 = 254/CS×2")
	var bg2: TextureRect = inst.get_node("%Bg2") as TextureRect
	assert_almost_eq(bg2.offset_left, 752.0, 0.1, "Bg2 左 = 源 x=752")
	assert_almost_eq(bg2.offset_right - bg2.offset_left, 725.85, 0.1, "Bg2 宽 = 465/CS×2")
	assert_almost_eq(bg2.offset_right, 1477.85, 0.1, "Bg2 右 = 752+725.85（与 Bg3 左 1477 近无缝衔接）")
	var bg3: TextureRect = inst.get_node("%Bg3") as TextureRect
	assert_almost_eq(bg3.offset_left, 1477.0, 0.1, "Bg3 左 = 源 x=1477")
	assert_almost_eq(bg3.offset_right - bg3.offset_left, 543.22, 0.1, "Bg3 宽 = 348/CS×2")
	for bg in [bg1, bg2, bg3]:
		assert_eq(bg.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Bg 装饰层不吞滚动")
	# Sub1-3（源 sub1-3 空容器中心 (25/752/1477,12) → marker 原点直译 (x, 480-12)）。
	assert_almost_eq((inst.get_node("%Sub1") as Control).position.x, 25.0, 0.1, "Sub1 原点 x = 源 sub 中心 x")
	assert_almost_eq((inst.get_node("%Sub1") as Control).position.y, 468.0, 0.1, "Sub1 原点 y = 480-12")
	assert_almost_eq((inst.get_node("%Sub2") as Control).position.x, 752.0, 0.1, "Sub2 原点 x = 752")
	assert_almost_eq((inst.get_node("%Sub3") as Control).position.x, 1477.0, 0.1, "Sub3 原点 x = 1477")
	# Fog1-3（源 fog 挂 dragContainer pos(subOffsetX[s],210) setScale(4.0)；
	# 640×127px/CS×4 = 1998.05×396.49，中心 y=270）。
	var fog1: TextureRect = inst.get_node("%Fog1") as TextureRect
	assert_almost_eq(fog1.offset_left, 25.0, 0.1, "Fog1 左 = 源 anchor(0,0.5) x=25")
	assert_almost_eq(fog1.offset_top, 71.76, 0.1, "Fog1 顶 = 270-396.49/2")
	assert_almost_eq(fog1.offset_right - fog1.offset_left, 1998.05, 0.1, "Fog1 宽 = 640/CS×4（源 setScale(4.0)）")
	assert_almost_eq(fog1.offset_bottom - fog1.offset_top, 396.49, 0.1, "Fog1 高 = 127/CS×4")
	assert_almost_eq((inst.get_node("%Fog2") as TextureRect).offset_left, 752.0, 0.1, "Fog2 左 = 752")
	assert_almost_eq((inst.get_node("%Fog3") as TextureRect).offset_left, 1477.0, 0.1, "Fog3 左 = 1477")
	assert_eq(fog1.get_parent().name, "ScrollContent", "Fog 挂 ScrollContent（源挂 dragContainer 与 sub 平级，非 sub 内）")


# ── mainLayer 静态层（源 dungeonmapconfig.lua mainLayer 段，场景空间 to_godot）──

func test_mainlayer_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# Light1/2（源 light 495×260px/CS pos(400,210) → 中心 (480,350) 386.44×202.93）。
	for light_name in ["%Light1", "%Light2"]:
		var light: TextureRect = inst.get_node(light_name) as TextureRect
		assert_almost_eq(light.position.x + light.size.x * 0.5, 400.0, 0.1,
			light_name + " 中心 x = to_godot(400,210).x")
		assert_almost_eq(light.position.y + light.size.y * 0.5, 270.0, 0.1,
			light_name + " 中心 y = to_godot(400,210).y")
		assert_almost_eq(light.size.x, 386.44, 0.1, light_name + " 宽 = 495/CS（条目 Prescaled=false 不施加）")
		assert_almost_eq(light.size.y, 202.93, 0.1, light_name + " 高 = 260/CS")
		assert_eq(light.mouse_filter, Control.MOUSE_FILTER_IGNORE, "光效装饰不吞点击")
	# Frame（源 crusade_map_frame 1029×566px 无条目 → 803.12×441.75 中心(480,350)）。
	var frame: TextureRect = inst.get_node("%Frame") as TextureRect
	assert_almost_eq(frame.position.x + frame.size.x * 0.5, 400.0, 0.1, "Frame 中心 x")
	assert_almost_eq(frame.position.y + frame.size.y * 0.5, 270.0, 0.1, "Frame 中心 y")
	assert_almost_eq(frame.size.x, 803.12, 0.1, "Frame 宽 = 1029/CS")
	assert_almost_eq(frame.size.y, 441.75, 0.1, "Frame 高 = 566/CS")
	# TitleBg（源 crusade_title_bg 510×118px → 398.05×92.10 中心(402,395.3)→(482,164.7)）。
	var title_bg: TextureRect = inst.get_node("%TitleBg") as TextureRect
	assert_almost_eq(title_bg.position.x + title_bg.size.x * 0.5, 402.0, 0.1, "TitleBg 中心 x = to_godot(402,·)")
	assert_almost_eq(title_bg.position.y + title_bg.size.y * 0.5, 84.7, 0.1, "TitleBg 中心 y = 560-395.3")
	assert_almost_eq(title_bg.size.x, 398.05, 0.1, "TitleBg 宽 = 510/CS")
	assert_almost_eq(title_bg.size.y, 92.10, 0.1, "TitleBg 高 = 118/CS")
	# BottomFrame（源 bottom(402,55) 空容器 + bottomframe Scale9 reset_bg cap(20,20,18,18)
	# scaleSize(560,58) → 中心(482,505)；批 1 cap 公式（贴图 75×75）：T=75-20-18=37）。
	var bottom: NinePatchRect = inst.get_node("%BottomFrame") as NinePatchRect
	assert_almost_eq(bottom.position.x + bottom.size.x * 0.5, 402.0, 0.1, "BottomFrame 中心 x = to_godot(402,55).x")
	assert_almost_eq(bottom.position.y + bottom.size.y * 0.5, 425.0, 0.1, "BottomFrame 中心 y = 560-55")
	assert_almost_eq(bottom.size.x, 560.0, 0.1, "BottomFrame 宽 = 源 scaleSize 直译")
	assert_almost_eq(bottom.size.y, 58.0, 0.1, "BottomFrame 高 = 源 scaleSize 直译")
	assert_eq(bottom.patch_margin_left, 20, "cap left = cap.x")
	assert_eq(bottom.patch_margin_top, 37, "cap top = H-y-h = 75-20-18")
	assert_eq(bottom.patch_margin_right, 37, "cap right = W-x-w = 75-20-18（水平不反转）")
	assert_eq(bottom.patch_margin_bottom, 20, "cap bottom = cap.y")
	# 绘制序（源 mainLayer 盖 dragLayer：mainLayer 静态层声明在 Scroll 之后）。
	assert_true((inst.get_node("%Scroll") as Control).get_index()
		< (inst.get_node("%Frame") as Control).get_index(), "Scroll 先声明（源 dragLayer 在 mainLayer 之下）")
	assert_true((inst.get_node("%Frame") as Control).get_index()
		< (inst.get_node("%TitleBg") as Control).get_index(), "TitleBg 压 Frame 之上（源声明序）")


# ── 项目适配层（非源，PackagePanel 范式保留）：FrameworkBg/TitleLabel/CloseBtn ──

func test_project_adaptation_layers() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	# CloseBtn（项目适配弹窗化退出途径；backbtn 74×75px/CS = 57.76×58.54）。
	var close_btn: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(close_btn.offset_right - close_btn.offset_left, 57.76, 0.1, "CloseBtn 宽 = 74/CS")
	assert_almost_eq(close_btn.offset_bottom - close_btn.offset_top, 58.54, 0.1, "CloseBtn 高 = 75/CS")
	assert_eq(close_btn.stretch_mode, TextureButton.STRETCH_SCALE, "TextureButton stretch_mode=0 显式（批 2 方法论）")
	# TitleLabel（项目适配模式区分文字，叠源 titleBg 中心 (482,164.7)，走 theme variation）。
	var title: Label = inst.get_node("%TitleLabel") as Label
	assert_almost_eq(title.position.x + title.size.x * 0.5, 402.0, 0.5, "TitleLabel 叠 TitleBg 中心")
	assert_almost_eq(title.position.y + title.size.y * 0.5, 84.7, 0.5, "TitleLabel 叠 TitleBg 中心")
	assert_eq(String(title.theme_type_variation), "TitleLabel", "TitleLabel 走 TitleLabel variation（字号/颜色禁 tscn 直写）")
	# 迁移发明 ResultLabel（源无"共 N 个 boss"对应物）已删。
	assert_false(inst.has_node("%ResultLabel"), "迁移发明 ResultLabel 已删（受控裁剪）")


# ── panel 装配（现存用例语义保留）──

func test_panel_assembles_em() -> void:
	var panel := _make_panel("em", [50005, 50006, 50007])
	# em 模式：3 组 × 3 boss = 9 boss（50005/50006/50007 各 3 boss）
	assert_true(panel.bosses.size() > 0, "em 模式收集到 boss（9 期望）")
	assert_eq(panel.boss_buttons.size(), panel.bosses.size(), "boss 按钮数 == boss 数")
	assert_eq(panel.fog_rects.size(), 3, "3 section 迷雾")
	assert_eq(panel.group_counts.size(), 3, "3 组 group_counts")
	panel.free()


func test_panel_assembles_equip() -> void:
	var panel := _make_panel("equip", [50001, 50002, 50003, 50004])
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
	var panel := _make_panel("em", [50005, 50006, 50007])
	# 首关恒解锁（modulate 白色，非灰）
	var first_btn: TextureButton = panel.boss_buttons[0]
	assert_eq(first_btn.modulate, Color(1, 1, 1), "首关 unlocked（白色 modulate）")
	# 第 2 关未解锁（progress 空，前置未通关）→ 灰
	var second_btn: TextureButton = panel.boss_buttons[1]
	assert_eq(second_btn.modulate, Color(0.4, 0.4, 0.4), "第 2 关 locked（灰色 modulate）")
	panel.free()


# 源 box%d{bossIdx=(s-1)*5+b} 稀疏映射。
func test_box_rects_sparse_mapping() -> void:
	var panel := _make_panel("em", [50005, 50006, 50007])
	assert_true(panel.box_rects_by_idx is Dictionary, "box_rects_by_idx 是 Dictionary")
	assert_true(panel.box_rects_by_idx.size() > 0, "宝箱稀疏映射非空")
	# section1（boss 1-5）crusadeBoxPos[0] 只 4 个 → box idx 1-4，无 idx 5
	assert_true(panel.box_rects_by_idx.has(1), "section1 首宝箱 idx 1 存在")
	assert_false(panel.box_rects_by_idx.has(5), "section1 第 5 宝箱不存在（crusadeBoxPos[0] 只 4）")
	panel.free()


# 3×5 固定坐标（源 crusadeBossPos）+ 点空间直译：boss1 中心 (135,260)（Sub1 内）→
# Sub1 原点 (25,468) + (135,-260) → 内容局部 (160,208) → 场景 (240,288)（视口 80,80）。
func test_boss_positions_use_crusade_pos() -> void:
	var panel := _make_panel("em", [50005, 50006, 50007])
	add_child_autofree(panel)
	var first_btn: TextureButton = panel.boss_buttons[0]
	# global 级防 parenting：boss1 显示尺寸 = crusade_stage_1 239×213px/CS = 186.54×166.24
	# → 中心 (240,288)（cocos 世界 (25+135,12+260)=(160,272) → to_godot=(240,288) 铁证）。
	var center: Vector2 = first_btn.global_position + first_btn.size * 0.5
	assert_almost_eq(center.x, 160.0, 0.1, "首 boss 中心 x = to_godot(160,·).x（crusadeBossPos[0][0]+sub 中心）")
	assert_almost_eq(center.y, 208.0, 0.1, "首 boss 中心 y = to_godot(·,272).y")
	# Sub 内相对定位（源 boss 挂 sub：bpos 相对 sub 中心，y 上正 → godot 负）。
	assert_almost_eq(first_btn.position.x, 135.0 - 186.54 * 0.5, 0.1, "boss Sub 内 x = bpos.x-半宽（中心锚）")
	assert_almost_eq(first_btn.position.y, -(260.0 + 166.24 * 0.5), 0.1, "boss Sub 内 y = -(bpos.y+半高)（cocos y 上正）")


# boss 显示尺寸动态（源裸 CCSprite:create 无 fix_size：15 张图各按像素/CS；
# 原 STAGE_SIZE=110 定值是迁移误差，照源改为 fill 时按贴图实测）。
func test_boss_display_size_dynamic() -> void:
	var panel := _make_panel("em", [50005, 50006, 50007])
	var first_btn: TextureButton = panel.boss_buttons[0]
	var expect_w: float = 239.0 / CS
	var expect_h: float = 213.0 / CS
	assert_almost_eq(first_btn.size.x, expect_w, 0.1, "boss1 宽 = crusade_stage_1 239px/CS（非 110 定值）")
	assert_almost_eq(first_btn.size.y, expect_h, 0.1, "boss1 高 = 213px/CS")
	# 宝箱（源 89×84px setScale(0.8)：rect 固定 closed 尺寸，open 只换图不改 rect）。
	var box: TextureRect = panel.box_rects_by_idx[1]
	assert_almost_eq(box.size.x, 89.0 / CS * 0.8, 0.1, "box 宽 = 89/CS×0.8（源 setScale(0.8)）")
	assert_almost_eq(box.size.y, 84.0 / CS * 0.8, 0.1, "box 高 = 84/CS×0.8")
	panel.free()


# 滚动内容宽 = 源 calcMaxRight 等价（:129-142 拖拽 x∈[min(0,660-maxX),0] 不留空白 →
# content_w = maxX+140；em 9 boss maxX=752+472=1224 → 1364；equip 12 boss maxX=1477+60=1537 → 1677）。
func test_scroll_content_width_source_equivalent() -> void:
	var em_panel := _make_panel("em", [50005, 50006, 50007])
	var em_content: Control = em_panel._content.get_node("%ScrollContent")
	# 断 custom_minimum_size（fill 直接产物；ScrollContainer 入树后才按 min 排布 size）
	assert_almost_eq(em_content.custom_minimum_size.x, 1224.0 + 140.0, 0.5,
		"em 内容宽 = maxX+140（源 calcMaxRight 无空白拖拽）")
	em_panel.free()
	var eq_panel := _make_panel("equip", [50001, 50002, 50003, 50004])
	var eq_content: Control = eq_panel._content.get_node("%ScrollContent")
	assert_almost_eq(eq_content.custom_minimum_size.x, 1537.0 + 140.0, 0.5,
		"equip 内容宽 = maxX+140（ScrollContainer 重排走 min 通道）")
	eq_panel.free()


# 宝箱手动开（源 :271 cleared+openedChests 才 open，cleared 自动开是 bug）。
func test_refresh_keeps_box_closed_when_not_cleared() -> void:
	var panel := _make_panel("em", [50005, 50006, 50007])
	assert_true(panel.box_rects_by_idx.size() > 0, "有宝箱可验（防 0 循环 risky）")
	var open_tex: Variant = panel._load_tex(panel.BOX_OPEN_TEX)
	for key in panel.box_rects_by_idx:
		var box: TextureRect = panel.box_rects_by_idx[key]
		assert_ne(box.texture, open_tex, "未 cleared 时 box 不自动开（手动开箱守卫）")
	panel.free()


# 迷雾 FadeOut 0.5s（源 :286-289 CCFadeOut+setVisible(false)）。
func test_fade_out_fog_immediate_when_not_in_tree() -> void:
	var panel := _make_panel("em", [50005, 50006, 50007])
	var fog: TextureRect = panel.fog_rects[0]
	fog.visible = true
	fog.modulate.a = 1.0
	# panel 未 add_child 到场景树 → is_inside_tree() false → _fade_out_fog 走立即隐分支
	panel._fade_out_fog(fog)
	assert_false(fog.visible, "未入树时 _fade_out_fog 立即 visible=false")
	assert_eq(fog.modulate.a, 0.0, "未入树时 _fade_out_fog 立即 a=0")
	panel.free()


# 照源 dungeon_map.lua:251-256 openChest reward 显示 Item 表 Display Name，无则 fallback。
func test_reward_display_name_fallback() -> void:
	var panel := _make_panel("em", [50005, 50006, 50007])
	assert_eq(panel._reward_display_name(99999), "Item:99999", "无 Item 表时 fallback Item:<id>（源 :255）")
	panel.free()


func test_reward_display_name_uses_item_table() -> void:
	var panel := _make_panel("em", [50005, 50006, 50007])
	var name: String = panel._reward_display_name(1)
	assert_true(name.length() > 0, "_reward_display_name 永返非空（源 :253-255 row or fallback）")
	panel.free()


# 静态美术层（2026-08-16 两件套）：原 CrusadePanelBuilder procedural 5 类美术
# 全部静态化进 tscn（%Bg1-3 挂 ScrollContent、%Light1/2/%Frame/%TitleBg/%BottomFrame
# 挂 content 根），builder 的 build_dungeon_map 退役。
func test_static_art_layers_present() -> void:
	var panel := _make_panel("em", [50005, 50006, 50007])
	var content: Control = panel._content
	# bg 三段挂 ScrollContent（源 bg 挂 dragContainer）且声明在 Sub 之前（z 序在下）。
	var scroll_content: Control = content.get_node("%ScrollContent")
	assert_true(scroll_content.get_node("%Bg1") is TextureRect, "Bg1 静态挂 ScrollContent")
	assert_true(scroll_content.get_node("%Bg2") is TextureRect, "Bg2 静态挂 ScrollContent")
	assert_true(scroll_content.get_node("%Bg3") is TextureRect, "Bg3 静态挂 ScrollContent")
	for bg_name in ["%Bg1", "%Bg2", "%Bg3"]:
		var bg: TextureRect = scroll_content.get_node(bg_name)
		assert_not_null(bg.texture, bg_name + " 纹理非空")
		assert_true(bg.get_index() < (scroll_content.get_node("%Sub1") as Control).get_index(),
			bg_name + " 声明在 Sub1 前（源 bg z=0 < boss z=10）")
	# fog 声明在 Sub 之后（源 fog z=20 > box z=11 > boss z=10，迷雾盖 boss）。
	for fog_name in ["%Fog1", "%Fog2", "%Fog3"]:
		var fog: TextureRect = scroll_content.get_node(fog_name)
		assert_true(fog.get_index() > (scroll_content.get_node("%Sub3") as Control).get_index(),
			fog_name + " 声明在 Sub 后（源 fog z=20 最上层）")
		assert_not_null(fog.texture, fog_name + " 纹理非空")
	# mainLayer 4 类挂 content 根。
	for node_name in ["%Light1", "%Light2", "%Frame", "%TitleBg", "%BottomFrame"]:
		assert_true(content.get_node(node_name) is Control, node_name + " 静态挂 content 根")
	panel.free()


# 两件套守卫：panel 源 .new( 白名单（boss/box 动态行 + Logic + 弹窗构造恰 4 处）+
# CrusadePanelBuilder 引用退役 + builder 侧 build_dungeon_map 删除。
func test_two_piece_guards() -> void:
	var panel_src: String = FileAccess.get_file_as_string(PANEL_PATH)
	var new_calls: PackedStringArray = []
	var idx: int = panel_src.find(".new(")
	while idx != -1:
		var line_start: int = panel_src.rfind("\n", idx) + 1
		var line_end: int = panel_src.find("\n", idx)
		new_calls.append(panel_src.substr(line_start, line_end - line_start).strip_edges())
		idx = panel_src.find(".new(", idx + 1)
	assert_eq(new_calls.size(), 4, "panel .new( 恰 4 处（ExerciseManager/TextureButton/TextureRect/DegreePopup）")
	var joined: String = "\n".join(new_calls)
	assert_true(joined.contains("ExerciseManager.new()"), "ExerciseManager（Logic）在白名单")
	assert_true(joined.contains("TextureButton.new()"), "TextureButton（boss 动态行）在白名单")
	assert_true(joined.contains("TextureRect.new()"), "TextureRect（box 动态行）在白名单")
	assert_true(joined.contains("DegreePopup.new("), "DegreePopup（弹窗构造，带参）在白名单")
	assert_false(panel_src.contains("crusade_panel_builder"), "panel 无 builder preload 引用（代码级守卫，头注不计）")
	var builder_src: String = FileAccess.get_file_as_string(BUILDER_PATH)
	assert_false(builder_src.contains("func build_dungeon_map"), "builder 侧 build_dungeon_map 函数定义已删（crusade 侧待 Task 5/6）")


# Task 2 接口不破坏：_open_degree_popup 调 dungeon_degree_popup.setup_popup
# （4 参签名）+ degree_selected/close_requested 信号接线 + show_window。
func test_degree_popup_interface_intact() -> void:
	var panel := _make_panel("em", [50005, 50006, 50007])
	add_child_autofree(panel)
	panel._open_degree_popup(1)
	assert_not_null(panel._active_popup, "弹窗实例已建（setup_popup 4 参签名未破坏）")
	assert_true(is_instance_valid(panel._active_popup), "弹窗有效")
	panel._close_degree_popup()
	assert_null(panel._active_popup, "关闭后 _active_popup 置空（close_requested 路径）")
