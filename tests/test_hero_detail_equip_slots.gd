extends GutTest
## HeroDetailEquipSlots 装备槽 helper 单测（全 static，仿 task_panel helper 测试范式）。
##
## 范式风险说明（实现时确认）：GUT headless 下两类 mock 范式不可用——
## 1) InputEventMouseButton.new() 经 handler.call(ev) 直调 lambda 时，
##    Godot 4.7 lambda 捕获变量改写有静默不触发问题（诊断 _diag2.gd 已确认同景）。
## 2) Control.new() mock + %UniqueName 查找：get_node_or_null("%X") 需 set_owner 才能跨子树，
##    GUT fixture 无法为裸 Control mock 设 owner。
## → 此文件只覆盖无 mock 依赖的纯逻辑：create_equip_slot_icon 三态（核心覆盖）。
## 兜底覆盖说明（诚实标注 gap）：
## - show_equips 6 槽挂载：经 test_panel_shows_equip 兜底（.tscn 实例化路径，断言 equip_slot meta 数=6）
## - make_equip_click_handler 的 gui_input 连接：经 test_panel_shows_equip 兜底（6 槽 icon.gui_input.connect）
## - make_equip_click_handler 的 pressed 事件过滤（pressed=true 触发/false 忽略）：当前无单测覆盖
##   （GUT headless InputEvent 限制），靠代码审查 + 运行时点击行为保证
##
## 2026-07-26 适配新签名 create_equip_slot_icon(slot, ceid, eid, hero, cm, pd)：
## - eid==0 占位变更：画 lock 图标（_create_lock_icon），非空槽
## 2026-08-22 灰显语义修正：源 setSpriteGray = setCascadeColor ccc3(100,100,100)+opacity(180)
## 级联整树（含 frame，resource_manager.lua:871-876），旧"只灰子节点保彩框"系误读；
## 同批配方分支强制白框（源 :1124 createIcon(eid,nil,1) quality 覆写表品质）

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 三态1：已穿戴（ceid>0）→ icon 整体不灰显（白），有 equip_slot meta
func test_create_equip_slot_icon_worn() -> void:
	var hero := HeroInstance.new(1)
	hero.equip_slots[0] = 101   # 槽 0 已穿戴装备 101
	hero.equip_exp[0] = 0.0
	var icon: Control = HeroDetailEquipSlots.create_equip_slot_icon(0, 101, 0, hero, cm, null)
	assert_not_null(icon)
	assert_eq(icon.modulate, Color.WHITE, "已穿戴整体不灰显（白）")
	assert_true(icon.has_meta(&"equip_slot"), "标记 equip_slot meta（测试计数用）")
	icon.free()


# 三态2：未穿戴配方（ceid<=0 and eid>0）→ 强制白框 + 整树灰
# （源 :1124 createIcon(eid,nil,1) 覆写表品质——201 表 Quality=2 绿框被压成白框；
# :1125 setSpriteGray 级联 ccc3(100,100,100)+opacity(180) 含 frame，2026-08-22 修正旧误读）
func test_create_equip_slot_icon_unworn_recipe() -> void:
	var hero := HeroInstance.new(1)
	var icon: Control = HeroDetailEquipSlots.create_equip_slot_icon(0, 0, 201, hero, cm, null)
	assert_not_null(icon)
	assert_eq(icon.modulate, HeroDetailEquipSlots.EQUIP_GRAY_MODULATE, "未穿戴配方整树灰（源 setSpriteGray 级联，含 frame）")
	assert_eq(
		HeroDetailEquipSlots.EQUIP_GRAY_MODULATE,
		Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0),
		"灰化色照源 ccc3(100,100,100)+opacity(180)"
	)
	# frame 强制白框：201 表品质 2（绿）被 quality=1 覆写
	# frame 取画序末位 equip_frame* sprite（批 E E3 层序改 add 顺序后 child(0)=gocha 衬底）
	var frame: Sprite2D = null
	for c in icon.get_children():
		if c is Sprite2D and String((c as Sprite2D).texture.resource_path).find("equip_frame_") >= 0:
			frame = c as Sprite2D
	assert_not_null(frame, "存在 equip_frame 边框 Sprite2D")
	var frame_path: String = String(frame.texture.resource_path)
	assert_true(frame_path.ends_with("equip_frame_white.png"), "配方槽强制白框（源 :1124 quality=1），实际 %s" % frame_path)
	icon.free()


# 三态3：无穿戴无配方（eid==0）→ lock 占位（白框 + lock 图标子节点）
func test_create_equip_slot_icon_unknown_slot() -> void:
	var hero := HeroInstance.new(1)
	var icon: Control = HeroDetailEquipSlots.create_equip_slot_icon(0, 0, 0, hero, cm, null)
	assert_not_null(icon)
	assert_eq(icon.modulate, Color.WHITE, "lock 占位不灰显")
	assert_true(icon.has_meta(&"equip_slot"), "lock 占位也标记 equip_slot meta")
	# lock 图标挂为子节点（白框 frame Sprite2D 在 index 0，lock TextureRect 在之后）
	var lock_child: TextureRect = null
	for i in icon.get_child_count():
		var c: Node = icon.get_child(i)
		if c is TextureRect:
			lock_child = c as TextureRect
			break
	assert_not_null(lock_child, "lock 占位含 TextureRect 子节点（lock 图标）")
	# px 直抄回归守卫（2026-09-09 修复：旧 FRAME_TEX_SIZE=(94,95) 使 container 中心锚
	# 相对 frame 显示中心右下偏 +10.3/+10.4，用户实测未知槽图标偏右下）
	assert_almost_eq(icon.size.x, 94.0 / 1.28125, 0.1, "container 宽=frame 显示宽 73.37（÷CS）")
	assert_almost_eq(icon.size.y, 95.0 / 1.28125, 0.1, "container 高=frame 显示高 74.17（÷CS）")
	# 实际中心 = anchor 点(container 尺寸半分) + offset 中点（PRESET_CENTER anchor=0.5,0.5）
	var lock_center_x: float = icon.size.x * 0.5 + (lock_child.offset_left + lock_child.offset_right) * 0.5
	var lock_center_y: float = icon.size.y * 0.5 + (lock_child.offset_top + lock_child.offset_bottom) * 0.5
	assert_almost_eq(lock_center_x, icon.size.x * 0.5, 0.15, "lock 中心 x=frame 中心（源 ccp(0,2) 仅 y 上偏）")
	assert_almost_eq(lock_center_y, icon.size.y * 0.5 - 2.0, 0.15, "lock 中心 y=frame 中心-2（源 ccp(0,2) 上偏）")
	assert_almost_eq(lock_child.offset_right - lock_child.offset_left, 86.0 / 1.28125, 0.1, "lock 显示宽 67.1（86px÷CS，与 frame 86/94 同源比例）")
	icon.free()


func test_make_equip_click_handler_is_callable() -> void:
	# Fallback A（mock 范式不可用）：只断言 handler 是有效 Callable。
	# gui_input 连接经 test_panel_shows_equip 兜底（6 槽挂载）。
	# pressed 事件过滤逻辑（pressed=true 触发 / false 忽略）当前无单测覆盖（GUT headless 限制）。
	var on_open: Callable = func(slot: int) -> void: pass
	var handler: Callable = HeroDetailEquipSlots.make_equip_click_handler(2, on_open)
	assert_true(handler is Callable, "handler 是 Callable")
	assert_true(handler.is_valid(), "handler.is_valid()（闭包已构造）")
	assert_ne(handler, Callable(), "handler 非空 Callable（绑定有效）")
