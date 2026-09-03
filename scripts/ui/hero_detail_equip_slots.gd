class_name HeroDetailEquipSlots
extends RefCounted

## HeroDetailPanel 装备槽 helper（批次 1 第 2 拆分 2026-07-24）。
## 从 hero_detail_panel.gd 外迁的 5 装备槽函数，全 static + 状态参数化（对齐 attribs/tabs/builder 范式）。
## 不含 panel 状态，依赖（hero/cm/pd/base_layer/回调）全经参数传入；不反向引用 HeroDetailPanel class_name
## （on_equip_craft_jump 用 Node 弱类型，规避 AGENTS.md class_name 跨脚本反模式）。
##
## 2026-07-26 装备槽显示逻辑对齐源（herodetail/window.lua:1110-1156 createEquipIcon + :995-1064 createEquipTag）：
## 三态显示（已穿星级 / 未解锁 lock / 未穿灰显）+ 状态角标（wear/cannotwear）+ eid==0 Toast。
## 源 4 张 tagText 横幅素材（herodetail-equip-nowned 等）源 res 缺失 → 不画横幅（忠实源运行时表现）。

const EQUIP_SLOT_COUNT: int = 6
# 源 setSpriteGray（resource_manager.lua:871-876）：setCascadeColorEnabled(true) + ccc3(100,100,100)
# + setOpacity(180) —— 级联整棵子树（含 frame）。Godot modulate 天生级联子节点，一式等价。
const EQUIP_GRAY_MODULATE: Color = Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0)
# TexDisplaySize SOP 口径（2026-08-22）：源 createSprite 对无 TextureConfig 条目纹理
# 显示=纹理÷CS（setContentScaleFactor 615/480 下 getContentSize 返回点尺寸），equip_frame
# 94×95 显示 73.37×74.17。ReadequipIcon 的 frame Sprite2D 系原尺寸渲染（全局口径债），
# 本面板挂载处对 icon 整树 ×1/CS 补偿（等价源 bg:setScale 缩整树），视觉对齐槽 host。
const CONTENT_SCALE: float = 1.28125

# 装备图标 container 逻辑尺寸（与 ReadequipIcon.ICON_SIZE 对齐）
const ICON_SIZE: float = 72.0
# frame texture 实际尺寸（equip_frame_*.png 94×95，Sprite2D centered=false scale=1.0 原尺寸渲染，溢出 container 72）
# lock 居中 / tagIcon 坐标换算都基于 frame 实际渲染区，非 container 逻辑尺寸。源 getCenterPos=node texture/2。
const FRAME_TEX_SIZE: Vector2 = Vector2(94.0, 95.0)
# 源 tagIcon 角标素材 + 坐标（herodetail/window.lua:1051-1061 + param.lua:9-13）
const TAG_ICON_WEAR_RES: String = "res://assets/ui/alpha/HVGA/herodetail-equipadd.png"
const TAG_ICON_CANNOTWEAR_RES: String = "res://assets/ui/alpha/HVGA/herodetail_icon_plus_yellow.png"
const TAG_ICON_SIZE: Vector2 = Vector2(37.0, 39.0)
# 源 eid==0 lock 占位素材（readequip.lua:604-629 getUnknownIcon）
const LOCK_ICON_RES: String = "res://assets/ui/alpha/HVGA/handbook_icon_lock.png"
const LOCK_ICON_SIZE: Vector2 = Vector2(86.0, 86.0)
# eid==0 点击 Toast 文案（源 LSTR window.1.10.1.001 缺失，用硬编码 fallback）
const LOCK_TOAST_TEXT: String = "该装备槽尚未解锁"


# createEquipIcons（herodetail/window.lua:1071-1098）6 槽全显示 + createEquipIcon（:1110-1135）三态：
# ceid>0 已穿戴（画强化星级）/ eid>0 未穿戴配方强制白框整树灰 / eid==0 无配方 lock 占位。
# createEquipTag（:995-1064）状态角标：ceid<=0 and eid>0 时按 getHeroEquipState 画 wear/cannotwear 角标。
static func show_equips(hero: HeroInstance, cm: Variant, pd: PlayerData, base_layer: Control, on_open: Callable) -> void:
	if hero == null:
		return
	var rank_equip: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	for i in EQUIP_SLOT_COUNT:
		var ceid: int = int(hero.equip_slots[i]) if i < hero.equip_slots.size() else 0   # 已穿戴
		var eid: int = int(rank_equip.get("Equip" + str(i + 1) + " ID", 0))              # Hero_equip 配方
		var icon: Control = create_equip_slot_icon(i, ceid, eid, hero, cm, pd)
		# 装备槽静态化进 .tscn（EquipSlot1-6 挂 EquipSlotHost VBox）：挂 icon 到静态槽
		# （position=0 相对槽本地坐标 + 清占位 texture 避免双框，不设 icon.size 避免干扰 VBox 布局）。
		var slot_host: TextureRect = base_layer.get_node_or_null("%EquipSlot" + str(i + 1)) as TextureRect
		if slot_host == null:
			icon.free()
			continue
		slot_host.texture = null
		icon.position = Vector2.ZERO
		# frame ÷CS 显示口径：create_icon 内部 _load_sprite 已统一 ÷CS（2026-08-22 根修），
		# frame 视觉 94/CS × 95/CS = 73.37×74.17 = 槽 host 尺寸（.tscn 源直译），此处不再二次 ÷CS。
		# 状态角标（源 createEquipTag：仅 ceid<=0 and eid>0 时画，isEquiped/ignore 不画）
		if ceid <= 0 and eid > 0:
			var state: Dictionary = EquipdetailQuery.get_hero_equip_state(hero, i, cm, pd)
			_add_tag_icon(icon, String(state.get("eti", "")))
		icon.gui_input.connect(make_equip_click_handler(i, on_open))
		slot_host.add_child(icon)


# createEquipIcon 三态（herodetail/window.lua:1110-1135）：
# ceid>0：createHeroItem 画强化星级（源 :1119 createHeroItem + :1120 getEquipLevel，本项目传 level 给 create_icon）
# eid==0：getUnknownIcon lock 占位（源 :1122，本项目 _create_lock_icon）
# 其他（eid>0 且 ceid==0）：createIcon(eid,nil,1) 强制白框 + setSpriteGray 整树灰
# （源 :1124-1125；2026-08-22 修正——旧实现"只灰子节点保彩框"系对 setSpriteGray 级联语义的误读）
static func create_equip_slot_icon(slot: int, ceid: int, eid: int, hero: HeroInstance, cm: Variant, pd: PlayerData) -> Control:
	if ceid > 0:
		# 已穿戴：传 level 画强化蓝星（源 createHeroItem 第3参 nil → show_gray=false，只画蓝星不画灰星）
		var lvl: int = int(ReadequipData.get_equip_level(ceid, float(hero.equip_exp[slot]), cm).get("level", 0))
		var icon: Control = ReadequipIcon.create_icon(ceid, 1, cm, lvl, false)
		icon.set_meta(&"equip_slot", true)
		return icon
	elif eid == 0:
		# 未解锁槽位：lock 占位（白框 + gocha 内底 + lock 图标），照源 getUnknownIcon
		var lock_icon: Control = _create_lock_icon(cm)
		lock_icon.set_meta(&"equip_slot", true)
		return lock_icon
	# 有配方未装：强制白框（源 :1124 createIcon(eid,nil,1) quality 覆写表品质）+ 整树灰（源 :1125）
	var icon: Control = ReadequipIcon.create_icon(eid, 1, cm, 0, false, 1)
	icon.set_meta(&"equip_slot", true)
	_apply_gray(icon)
	return icon


# eid==0 未解锁槽位占位（源 readequip.lua:604-629 getUnknownIcon）：
# 白框（equip_frame_white）+ gocha 内底 + handbook_icon_lock 居中。源光晕 setVisible(false) 永不显示 → 不画。
static func _create_lock_icon(cm: Variant) -> Control:
	# 复用 create_icon(id=0) 拿白框（id=0 → quality=1 白框，无 icon 路径 → 空槽）
	var container: Control = ReadequipIcon.create_icon(0, 1, cm)
	# 补 lock 图标（居中略上偏 2px，照源 getCenterPos(bg)+ccp(0,2)；lock 86>frame 72 允许溢出）
	if ResourceLoader.exists(LOCK_ICON_RES):
		# 让 container size = frame 渲染区（94×95），使 anchor 相对的父尺寸 = frame 视觉区
		# （create_icon 默认 container 72×72，但 frame Sprite2D 渲染 94×95 溢出 container；
		# 不改 container size 则 anchor 算的中心是 36,36 而非 frame 中心 47,47.5，lock 会偏）
		container.size = FRAME_TEX_SIZE
		container.custom_minimum_size = FRAME_TEX_SIZE
		# lock 用 TextureRect + anchors_preset=CENTER：引擎自动让节点中心对齐父(container=frame区)中心
		# offsets 设为 ±LOCK_ICON_SIZE/2，使节点尺寸=lock 大小，中心锚定父中心
		var lock_tex := TextureRect.new()
		lock_tex.texture = load(LOCK_ICON_RES) as Texture2D
		lock_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_tex.set_anchors_preset(Control.PRESET_CENTER)
		var half_w: float = LOCK_ICON_SIZE.x * 0.5
		var half_h: float = LOCK_ICON_SIZE.y * 0.5
		lock_tex.offset_left = -half_w
		lock_tex.offset_right = half_w
		lock_tex.offset_top = -half_h - 2.0   # 源 ccp(0,2) 上偏 → Godot y 减 2
		lock_tex.offset_bottom = half_h - 2.0
		lock_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(lock_tex)
	return container


# 源 setSpriteGray 级联等价（resource_manager.lua:871-876）：整树含 frame 一并灰化暗化。
static func _apply_gray(container: Control) -> void:
	container.modulate = EQUIP_GRAY_MODULATE


# 状态角标（源 herodetail/window.lua:1051-1061 createEquipTag tagIcon）：
# eti="wear" → herodetail-equipadd（可穿/可合成可穿）；eti="cannotwear" → herodetail_icon_plus_yellow（不可穿）。
# 用户期望居中显示（空槽时 + 号在正中提示"可装备"）。
# 用 Sprite2D centered=true：position 是相对 container 原点，frame 也在 container 原点渲染，
# frame 中心 = FRAME_TEX_SIZE/2，角标 centered=true 自动以 texture 中心对齐到 position（无坐标系歧义）。
static func _add_tag_icon(container: Control, eti: String) -> void:
	if eti == "":
		return
	var res_path: String = TAG_ICON_WEAR_RES if eti == "wear" else TAG_ICON_CANNOTWEAR_RES
	if not ResourceLoader.exists(res_path):
		return
	var spr := Sprite2D.new()
	spr.texture = load(res_path) as Texture2D
	spr.centered = true
	spr.position = Vector2(FRAME_TEX_SIZE.x * 0.5, FRAME_TEX_SIZE.y * 0.5)
	container.add_child(spr)


# 点装备槽图标（gui_input）→ 转发到 on_open(slot) → 弹 EquipCraftPanel。
static func make_equip_click_handler(slot: int, on_open: Callable) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			on_open.call(slot)


# doClickEquip（herodetail/window.lua:247-276）：item_id = ceid（已穿戴）or eid（配方），传 equipcraft 合成/查看。
# eid==0 时源 :1147-1148 弹 Toast（LSTR window.1.10.1.001），不进 doClickEquip。
static func open_equip_craft(slot: int, hero: HeroInstance, cm: Variant, pd: PlayerData,
		parent: Node, on_changed: Callable, on_jump: Callable) -> void:
	if hero == null:
		return
	var ceid: int = int(hero.equip_slots[slot]) if slot >= 0 and slot < hero.equip_slots.size() else 0
	var rank_equip: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	var eid: int = int(rank_equip.get("Equip" + str(slot + 1) + " ID", 0))
	var item_id: int = ceid if ceid > 0 else eid
	if item_id <= 0:
		# eid==0 未解锁槽位：弹 Toast 提示（源 :1148 ed.showToast），不弹 equipcraft 面板
		Toast.show_message(LOCK_TOAST_TEXT)
		return
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(item_id, cm, pd, hero, "heroDetail", slot)
	panel.equipped_changed.connect(on_changed)
	panel.jump_to_stage.connect(on_jump)
	panel.show_window(parent)
	# 层级：动态 z 栈自动置顶（2026-09-03 方案 B）——后开弹窗基准恒高于英雄详情整棵子树
	#（原显式 z=200 抬升已废弃：动态基准下 hero_detail 子树 effective ≤ 基准+13 < 下层基准）。


# 装备进阶列表点图标（源 evolveequip.lua:81 equipcraft.create{context="handbook"}）：
# hero 不传照源——handbook 上下文无穿戴入口；z=200 置顶同 open_equip_craft。
static func open_equip_craft_by_id(eid: int, cm: Variant, pd: PlayerData, parent: Node, panel: Node) -> void:
	if eid <= 0:
		return
	AudioPlayer.play_sfx("common_click_feedback")
	var p := EquipCraftPanel.new("equipcraft", {})
	p.setup_panel(eid, cm, pd, null, "handbook")
	p.jump_to_stage.connect(func(stage_id: int) -> void: on_equip_craft_jump(stage_id, panel))
	p.show_window(parent)
	# 层级同 open_equip_craft：动态 z 栈自动置顶（原显式 z=200 已废弃）。


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
