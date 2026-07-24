class_name HeroDetailEquipSlots
extends RefCounted

## HeroDetailPanel 装备槽 helper（批次 1 第 2 拆分 2026-07-24）。
## 从 hero_detail_panel.gd 外迁的 5 装备槽函数，全 static + 状态参数化（对齐 attribs/tabs/builder 范式）。
## 不含 panel 状态，依赖（hero/cm/pd/base_layer/回调）全经参数传入；不反向引用 HeroDetailPanel class_name
## （on_equip_craft_jump 用 Node 弱类型，规避 AGENTS.md class_name 跨脚本反模式）。

const EQUIP_SLOT_COUNT: int = 6
const EQUIP_GRAY_MODULATE: Color = Color(0.4, 0.4, 0.4, 1.0)


# createEquipIcons（herodetail/window.lua:1071-1098）6 槽全显示 + createEquipIcon（:1110-1135）三态：
# ceid>0 已穿戴 / eid>0 未穿戴配方灰显 / eid==0 无配方 unknown 占位。
static func show_equips(hero: HeroInstance, cm: Variant, base_layer: Control, on_open: Callable) -> void:
	if hero == null:
		return
	var rank_equip: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	for i in EQUIP_SLOT_COUNT:
		var ceid: int = int(hero.equip_slots[i]) if i < hero.equip_slots.size() else 0   # 已穿戴
		var eid: int = int(rank_equip.get("Equip" + str(i + 1) + " ID", 0))              # Hero_equip 配方
		var icon: Control = create_equip_slot_icon(ceid, eid, cm)
		# 装备槽静态化进 .tscn（EquipSlot1-6 挂 EquipSlotHost VBox）：挂 icon 到静态槽
		# （position=0 相对槽本地坐标 + 清占位 texture 避免双框，不设 icon.size 避免干扰 VBox 布局）。
		var slot_host: TextureRect = base_layer.get_node_or_null("%EquipSlot" + str(i + 1)) as TextureRect
		if slot_host == null:
			icon.free()
			continue
		slot_host.texture = null
		icon.position = Vector2.ZERO
		icon.gui_input.connect(make_equip_click_handler(i, on_open))
		slot_host.add_child(icon)


# createEquipIcon 三态：icon_id = ceid or eid；未穿戴配方（ceid<=0 and eid>0）灰显 setSpriteGray。
static func create_equip_slot_icon(ceid: int, eid: int, cm: Variant) -> Control:
	var icon_id: int = ceid if ceid > 0 else eid
	var icon: Control = ReadequipIcon.create_icon(icon_id, 1, cm)
	icon.set_meta(&"equip_slot", true)
	if ceid <= 0 and eid > 0:
		icon.modulate = EQUIP_GRAY_MODULATE
	return icon


# 点装备槽图标（gui_input）→ 转发到 on_open(slot) → 弹 EquipCraftPanel。
static func make_equip_click_handler(slot: int, on_open: Callable) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			on_open.call(slot)


# doClickEquip（herodetail/window.lua:247-276）：item_id = ceid（已穿戴）or eid（配方），传 equipcraft 合成/查看。
static func open_equip_craft(slot: int, hero: HeroInstance, cm: Variant, pd: PlayerData,
		parent: Node, on_changed: Callable, on_jump: Callable) -> void:
	if hero == null:
		return
	var ceid: int = int(hero.equip_slots[slot]) if slot >= 0 and slot < hero.equip_slots.size() else 0
	var rank_equip: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	var eid: int = int(rank_equip.get("Equip" + str(slot + 1) + " ID", 0))
	var item_id: int = ceid if ceid > 0 else eid
	if item_id <= 0:
		return   # 无配方无穿戴（eid==0 unknown 占位），不弹
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(item_id, cm, pd, hero, "heroDetail", slot)
	panel.equipped_changed.connect(on_changed)
	panel.jump_to_stage.connect(on_jump)
	panel.show_window(parent)


# P1-10 源 equipcraft doClickGetWay :83 pushScene(stageselect.createByStage(id))。
# panel 用 Node 弱类型（非 HeroDetailPanel），调 remove_window + get_tree（Node 链路方法）。
static func on_equip_craft_jump(stage_id: int, panel: Node) -> void:
	if panel == null or not panel.has_method(&"remove_window"):
		return
	panel.remove_window()
	var tree: SceneTree = panel.get_tree()
	if tree == null or tree.current_scene == null:
		return
	var ms: Node = tree.current_scene
	if ms != null and ms.has_method(&"open_stage_select_by_stage"):
		ms.open_stage_select_by_stage(stage_id)
