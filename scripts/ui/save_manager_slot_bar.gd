class_name SaveManagerSlotBar
extends RefCounted

## 存档管理档位条 helper（View 层静态工具）— 多档位 UI，Godot 原生阶段受控增强
## （源单账号无对应物；从 SaveManagerPanel 下沉控行数，范式同 SaveManagerSnapshots）。
## 三档胶囊横排（SaveManager.SLOT_NAMES 顺序）：有档显「档N / Lv.X」、当前档金色高亮；
## 空档副行显「新建」即该档新建入口。点击非当前档 → on_pick(slot, exists)；
## 点击当前档不触发（无操作）。metas 由 GameData.slot_metas() 供给（测试可自造）。

const SaveManagerScript = preload("res://scripts/data/save_manager.gd")

# 胶囊布局：三胶囊均布 frame（467 宽）内，中心 x 360/480/600、y 150（快照行区上收后对齐）。
const CHIP_SIZE: Vector2 = Vector2(105.0, 52.0)
const CHIP_CENTERS: Array[Vector2] = [
	Vector2(360.0, 150.0), Vector2(480.0, 150.0), Vector2(600.0, 150.0),
]
const NAME_FONT_SIZE: int = 15
const SUB_FONT_SIZE: int = 13
const ACTIVE_COLOR: Color = Color(1.0, 220.0 / 255.0, 100.0 / 255.0)   # 当前档金（同快照 Lv 色）
const IDLE_COLOR: Color = Color(235.0 / 255.0, 223.0 / 255.0, 207.0 / 255.0)   # 同面板按钮字色
const EMPTY_SUB_TEXT: String = "新建"

## 档位显示名（auto→档1/save_1→档2/save_2→档3；未知槽名原样返回，守卫用）。
static func slot_display(slot: String) -> String:
	var idx := SaveManagerScript.SLOT_NAMES.find(slot)
	return "档%d" % (idx + 1) if idx >= 0 else slot


## 构建档位条：每 meta {slot,exists,level,active} 一胶囊。
static func build(metas: Array, on_pick: Callable) -> Control:
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in range(metas.size()):
		var meta: Dictionary = metas[i]
		if i >= CHIP_CENTERS.size():
			break
		var slot := String(meta.get("slot", ""))
		var exists := bool(meta.get("exists", false))
		var active := bool(meta.get("active", false))
		var chip := Button.new()
		chip.theme_type_variation = &"ConfigureActionBtn"
		chip.position = CHIP_CENTERS[i] - CHIP_SIZE * 0.5
		chip.size = CHIP_SIZE
		var color: Color = ACTIVE_COLOR if active else IDLE_COLOR
		# 当前档不触发回调（点自己无操作）；其余档点击回调面板接确认层。
		if not active:
			chip.pressed.connect(func() -> void: on_pick.call(slot, exists))
		host.add_child(chip)
		var name_lbl := Label.new()
		name_lbl.text = slot_display(slot)
		name_lbl.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
		name_lbl.add_theme_color_override("font_color", color)
		name_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		name_lbl.add_theme_constant_override("shadow_offset_y", 1)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(name_lbl)
		name_lbl.position = Vector2(0.0, 7.0)
		name_lbl.size = Vector2(CHIP_SIZE.x, 20.0)
		var sub_lbl := Label.new()
		sub_lbl.text = ("Lv.%d" % int(meta.get("level", 1))) if exists else EMPTY_SUB_TEXT
		sub_lbl.add_theme_font_size_override("font_size", SUB_FONT_SIZE)
		sub_lbl.add_theme_color_override("font_color", color)
		sub_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		sub_lbl.add_theme_constant_override("shadow_offset_y", 1)
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(sub_lbl)
		sub_lbl.position = Vector2(0.0, 27.0)
		sub_lbl.size = Vector2(CHIP_SIZE.x, 18.0)
	return host
