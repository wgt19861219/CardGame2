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

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_create_equip_slot_icon_worn() -> void:
	# 三态1：已穿戴（ceid>0）→ 正常 modulate（白）
	var icon: Control = HeroDetailEquipSlots.create_equip_slot_icon(101, 0, cm)
	assert_not_null(icon)
	assert_eq(icon.modulate, Color.WHITE, "已穿戴不灰显")
	assert_true(icon.has_meta(&"equip_slot"), "标记 equip_slot meta（测试计数用）")
	icon.free()


func test_create_equip_slot_icon_unworn_recipe() -> void:
	# 三态2：未穿戴配方（ceid<=0 and eid>0）→ 灰显
	var icon: Control = HeroDetailEquipSlots.create_equip_slot_icon(0, 201, cm)
	assert_not_null(icon)
	assert_eq(icon.modulate, HeroDetailEquipSlots.EQUIP_GRAY_MODULATE, "未穿戴配方灰显")
	icon.free()


func test_create_equip_slot_icon_unknown_slot() -> void:
	# 三态3：无穿戴无配方（ceid=0 eid=0）→ icon_id=0 占位，正常 modulate
	var icon: Control = HeroDetailEquipSlots.create_equip_slot_icon(0, 0, cm)
	assert_not_null(icon)
	assert_eq(icon.modulate, Color.WHITE, "无配方占位不灰显（仅 ceid<=0 and eid>0 才灰）")
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
