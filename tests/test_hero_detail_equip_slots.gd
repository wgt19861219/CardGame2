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
## - 灰显行为变更：icon 整体 modulate 保持白，只灰子节点（源 setSpriteGray(icon) 语义）
## - eid==0 占位变更：画 lock 图标（_create_lock_icon），非空槽

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


# 三态2：未穿戴配方（ceid<=0 and eid>0）→ icon 整体白，子节点灰（源 setSpriteGray 只灰 icon 不灰 frame）
func test_create_equip_slot_icon_unworn_recipe() -> void:
	var hero := HeroInstance.new(1)
	var icon: Control = HeroDetailEquipSlots.create_equip_slot_icon(0, 0, 201, hero, cm, null)
	assert_not_null(icon)
	# 修正：源 setSpriteGray(icon) 只灰 icon 子节点，frame 保持彩色 → icon 整体 modulate 仍是白
	assert_eq(icon.modulate, Color.WHITE, "未穿戴配方 icon 整体不灰（frame 保彩色），灰显下沉到子节点")
	# 子节点（icon Sprite2D）应被灰化，frame（第 0 个子）不灰
	assert_gt(icon.get_child_count(), 1, "有 frame + icon 子节点")
	var frame := icon.get_child(0)
	var icon_child := icon.get_child(1)
	if frame is CanvasItem:
		assert_eq((frame as CanvasItem).modulate, Color.WHITE, "frame 保持彩色不灰")
	if icon_child is CanvasItem:
		assert_eq((icon_child as CanvasItem).modulate, HeroDetailEquipSlots.EQUIP_GRAY_MODULATE, "icon 子节点灰显")
	icon.free()


# 三态3：无穿戴无配方（eid==0）→ lock 占位（白框 + lock 图标子节点）
func test_create_equip_slot_icon_unknown_slot() -> void:
	var hero := HeroInstance.new(1)
	var icon: Control = HeroDetailEquipSlots.create_equip_slot_icon(0, 0, 0, hero, cm, null)
	assert_not_null(icon)
	assert_eq(icon.modulate, Color.WHITE, "lock 占位不灰显")
	assert_true(icon.has_meta(&"equip_slot"), "lock 占位也标记 equip_slot meta")
	# lock 图标挂为子节点（白框 frame Sprite2D 在 index 0，lock TextureRect 在之后）
	var has_lock_child: bool = false
	for i in icon.get_child_count():
		var c: Node = icon.get_child(i)
		if c is TextureRect:
			has_lock_child = true
			break
	assert_true(has_lock_child, "lock 占位含 TextureRect 子节点（lock 图标）")
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
