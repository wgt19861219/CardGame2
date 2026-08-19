class_name ReadheroIcon
extends Node2D

## 英雄头像图标（createIcon）— 照源 readhero.lua:307-435 翻译（Phase 4 子件）。
## hero_panel / 背包 / 商店等 UI 共用头像基础设施。container 104×104 + Portrait（mask 裁剪）
## + frame（getIconFrameByRank 按 rank 选 hero_icon_frame_N）+ stars（星级拼接）+ level。
## clipping：源 CCClippingNode + equip_stencil → Godot canvas_item shader（portrait_mask.gdshader）。
## Portrait 路径源 "UI/HERO/<name>.jpg"（Unit.Portrait 字段）→ res://assets/ui/HERO/<name>.jpg。

const PortraitMaskShader: Shader = preload("res://shaders/portrait_mask.gdshader")

const STENCIL_PATH: String = "res://assets/ui/alpha/HVGA/equip_stencil.png"
const STAR_PATH: String = "res://assets/ui/alpha/HVGA/heroselect_evolution_star.png"
const LEVEL_BG_PATH: String = "res://assets/ui/alpha/HVGA/heropackage_level_bg.png"
const UNKNOW_PATH: String = "res://assets/ui/alpha/HVGA/hero_icon_unknow.png"
const FRAME_PATH_FMT: String = "res://assets/ui/alpha/HVGA/hero_icon_frame_%d.png"

const CONTAINER_SIZE: Vector2 = Vector2(104.0, 104.0)
const FRAME_SCALE_PAD: float = 5.0
const ALPHA_THRESHOLD: float = 0.02
const STAR_DX: float = 12.0
const STAR_BASE_X: float = 47.0
# ⚠️源 y=6 是 cocos 左下原点（star 中心距底 6）→ Godot 左上原点 y = CONTAINER_SIZE.y - 6 = 98（修 2026-07-18 y 翻转 bug，
# 旧值 6=顶部，错；源本意 star 贴 container 底部）。
const STAR_Y: float = 98.0
const STAR_Z: int = 5
# ⚠️源 cocos 左下原点：bg y=15 anchor(0,0) → bg 下边距底 15，label y=26 anchor(0.5,0.5) → label 中心距底 26。
# Godot 左上原点翻转：bg 下边 y = CONTAINER_SIZE.y - 15 = 89（bg 高 34，上边 y=55）；label 中心 y = 104 - 26 = 78。
# （修 2026-07-18 y 翻转 bug，旧值 (2,15)/(18,26) 直接抄 cocos=顶部，错；源本意 level 贴 container 底部）。
const LEVEL_BG_POS: Vector2 = Vector2(2.0, 55.0)
const LEVEL_LABEL_POS: Vector2 = Vector2(18.0, 78.0)
const LEVEL_FONT_SIZE: int = 14
const LEVEL_Z: int = 25
const CLIP_PATH_PREFIX: String = "UI/"
const CLIP_PATH_REPLACE: String = "res://assets/ui/"
# 源 addHpInfo hp/mp 血条（crusade 资源，结算/crusade 显示战斗结束血量，源 readhero.lua:266-305）
const CRUSADE_DIR: String = "res://assets/ui/alpha/HVGA/crusade/"
const HP_BAR_BG_PATH: String = CRUSADE_DIR + "crusade_hp_bar_bg.png"
const HP_BAR_PATH: String = CRUSADE_DIR + "crusade_hp_bar.png"
const MP_BAR_BG_PATH: String = CRUSADE_DIR + "crusade_mp_bar_bg.png"
const MP_BAR_PATH: String = CRUSADE_DIR + "crusade_mp_bar.png"
const DEAD_PATH: String = CRUSADE_DIR + "crusade_text_dead.png"  # 照源 readhero.lua:238/274 引用；源项目亦缺此图（HVGA/crusade/ 27 资源无 dead），源 createSprite 缺图≈nil，_create_dead_shade 等价
const HP_BAR_POS: Vector2 = Vector2(11.0, 33.0)
const MP_BAR_POS: Vector2 = Vector2(11.0, 40.0)
const DEAD_POS: Vector2 = Vector2(44.0, 39.0)
const HP_PERC_DENOM: float = 10000.0
const SHADE_ALPHA: float = 150.0 / 255.0
const DEAD_Z: int = 10
# 贴图显示尺寸 = 原始像素 ÷ CS（源 createSprite 等价，照 readequip_icon 口径；crusade 条无 TextureConfig 条目）。
# 2026-08-19 修：原实现原尺寸显示致条粗 1.28×（10px 高 vs 源 7.8 点），血/蓝条中心距 7 < 条高 10
# 互相叠 3px 糊在头像上——源 7.8 高 vs 7 距仅微叠 0.8 点不可见。
const CONTENT_SCALE: float = 1.28125

const RANK_FRAME_IDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 11, 11, 11, 11, 11, 11, 11, 11, 12, 12]

var icon: Node2D = null
var ori_icon: Node2D = null
var frame: Sprite2D = null
var stars: Array = []
var level_label: Label = null


# cm：ConfigManager（查 Unit.Portrait；null 时 id==0 unknow 占位）。
static func create_icon_by_hero(hero: HeroInstance, cm: Variant) -> ReadheroIcon:
	var icon := ReadheroIcon.new()
	icon.setup({
		"id": int(hero.tid),
		"rank": int(hero.rank),
		"stars": int(hero.stars),
		"level": int(hero.level),
	}, cm)
	return icon


func setup(info: Dictionary, p_cm: Variant = null) -> void:
	var id: int = int(info.get("id", 0))
	var rank: int = int(info.get("rank", 1))
	var star_count: int = int(info.get("stars", 0))
	var is_hide_frame: bool = bool(info.get("isHideFrame", false))
	var level: Variant = info.get("level", null)
	var hp: Variant = info.get("hp", null)
	var mp: Variant = info.get("mp", null)
	icon = Node2D.new()
	add_child(icon)
	ori_icon = _create_portrait(id, p_cm)
	icon.add_child(ori_icon)
	frame = _create_frame(rank)
	if frame != null:
		icon.add_child(frame)
		frame.visible = not is_hide_frame
	_create_stars(star_count)
	if level != null:
		_create_level(int(level))
	_add_hp_info(hp, mp)


func _create_portrait(id: int, cm: Variant) -> Node2D:
	if id == 0 or cm == null:
		return _create_unknow()
	var portrait_res: Variant = cm.lookup("Unit", "Portrait", id)
	if portrait_res == null or not (portrait_res is String) or (portrait_res as String).is_empty():
		return _create_unknow()
	var path: String = (portrait_res as String).replace(CLIP_PATH_PREFIX, CLIP_PATH_REPLACE)
	var sprite := Sprite2D.new()
	sprite.texture = _load_tex(path)
	sprite.position = CONTAINER_SIZE * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = PortraitMaskShader
	mat.set_shader_parameter("mask_tex", _load_tex(STENCIL_PATH))
	mat.set_shader_parameter("alpha_threshold", ALPHA_THRESHOLD)
	sprite.material = mat
	return sprite


func _create_unknow() -> Node2D:
	var node := Node2D.new()
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 1.0)
	bg.size = CONTAINER_SIZE
	bg.position = Vector2.ZERO
	node.add_child(bg)
	var qm := Sprite2D.new()
	qm.texture = _load_tex(UNKNOW_PATH)
	qm.position = CONTAINER_SIZE * 0.5
	node.add_child(qm)
	return node


func _create_frame(rank: int) -> Sprite2D:
	var frame_id: int = _frame_id_by_rank(rank)
	var frame := Sprite2D.new()
	frame.texture = _load_tex(FRAME_PATH_FMT % frame_id)
	if frame.texture != null:
		var fw: float = float(frame.texture.get_width())
		frame.scale = Vector2((CONTAINER_SIZE.x + FRAME_SCALE_PAD) / fw, (CONTAINER_SIZE.y + FRAME_SCALE_PAD) / fw)
		frame.position = CONTAINER_SIZE * 0.5
	return frame


static func _frame_id_by_rank(rank: int) -> int:
	if rank < 1 or rank > RANK_FRAME_IDS.size():
		return 1   # 越界默认 frame_1
	return RANK_FRAME_IDS[rank - 1]


func _create_stars(star_count: int) -> void:
	stars.clear()
	if star_count <= 0:
		return
	var ci: float = float(star_count) / 2.0
	for i in range(star_count, 0, -1):
		var s := Sprite2D.new()
		s.texture = _load_tex(STAR_PATH)
		s.position = Vector2(STAR_BASE_X + STAR_DX * (float(i) - ci), STAR_Y)
		s.z_index = STAR_Z
		icon.add_child(s)
		stars.append(s)


# Godot Label position 是左上角无 anchor：size=bg_size 框 + position=LEVEL_LABEL_POS-bg_size/2 + CENTER 对齐
# 让文字中心 = 源中心 Godot (18,78)（104-26=78）。旧实现误用 LEVEL_BG_POS 致中心 (23.5,72) 偏 (+5.5,-6)。
func _create_level(level: int) -> void:
	var bg_tex: Texture2D = _load_tex(LEVEL_BG_PATH)
	var bg_size: Vector2 = bg_tex.get_size() if bg_tex != null else Vector2(43.0, 34.0)
	var bg := Sprite2D.new()
	bg.texture = bg_tex
	bg.centered = false
	bg.position = LEVEL_BG_POS
	icon.add_child(bg)
	var lbl := Label.new()
	level_label = lbl
	var ls := LabelSettings.new()
	ls.font_size = LEVEL_FONT_SIZE
	lbl.label_settings = ls
	lbl.text = str(level)
	lbl.size = bg_size
	lbl.position = LEVEL_LABEL_POS - bg_size / 2.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.z_index = LEVEL_Z
	icon.add_child(lbl)


func refresh_level(level: int) -> void:
	if level_label != null:
		level_label.text = str(level)


# hp 单位万分比（0-10000，源 _hp_perc，addHpInfo setScaleX(hp/10000)）；hp<=0 死亡标识；hp==null 不画。
func _add_hp_info(hp: Variant, mp: Variant) -> void:
	if hp == null:
		return
	var hp_val: int = int(hp)
	if hp_val <= 0:
		_create_dead_shade()
		return
	_create_bar(HP_BAR_BG_PATH, HP_BAR_PATH, HP_BAR_POS, float(hp_val) / HP_PERC_DENOM)
	if mp != null:
		_create_bar(MP_BAR_BG_PATH, MP_BAR_PATH, MP_BAR_POS, float(int(mp)) / HP_PERC_DENOM)


# dead 图源项目亦缺（readhero.lua:238/274 引用但 HVGA/crusade/ 无此文件），源 createSprite 缺图≈nil 同效果，shade 标识阵亡照源。
func _create_dead_shade() -> void:
	var dead_tex: Texture2D = _load_tex(DEAD_PATH)
	if dead_tex != null:
		var dead := Sprite2D.new()
		dead.texture = dead_tex
		dead.position = DEAD_POS
		dead.z_index = DEAD_Z
		icon.add_child(dead)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, SHADE_ALPHA)
	shade.size = CONTAINER_SIZE
	shade.position = Vector2.ZERO
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(shade)


# cocos setAnchorPoint(0,0.5) setPosition(x,y) → Godot centered=false + position(x, y-显示高/2) 等价
# （左边缘 x，垂直中心 y）。显示高 = 贴图高 ÷ CS（缩放后），见 CONTENT_SCALE 注释。
func _create_bar(bg_path: String, bar_path: String, pos: Vector2, perc: float) -> void:
	var bg_tex: Texture2D = _load_tex(bg_path)
	var bar_tex: Texture2D = _load_tex(bar_path)
	if bg_tex != null:
		var bar_bg := Sprite2D.new()
		bar_bg.texture = bg_tex
		bar_bg.centered = false
		bar_bg.scale = Vector2.ONE / CONTENT_SCALE
		bar_bg.position = Vector2(pos.x, pos.y - float(bg_tex.get_height()) / CONTENT_SCALE * 0.5)
		icon.add_child(bar_bg)
	if bar_tex != null:
		var bar := Sprite2D.new()
		bar.texture = bar_tex
		bar.centered = false
		bar.scale = Vector2(clampf(perc, 0.0, 1.0), 1.0) / CONTENT_SCALE
		bar.position = Vector2(pos.x, pos.y - float(bar_tex.get_height()) / CONTENT_SCALE * 0.5)
		icon.add_child(bar)


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
