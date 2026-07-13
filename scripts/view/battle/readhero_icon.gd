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

const CONTAINER_SIZE: Vector2 = Vector2(104.0, 104.0)   # 源 :326 DGSizeMake(104,104)
const FRAME_SCALE_PAD: float = 5.0                      # 源 :368 (size.width+5)/frame.width
const ALPHA_THRESHOLD: float = 0.02                     # 源 createClippingNode :346 0.02
const STAR_DX: float = 12.0                             # 源 :385 dx=12
const STAR_BASE_X: float = 47.0                         # 源 :386 size.width/2-5 = 52-5
const STAR_Y: float = 6.0                               # 源 :386 y=6
const STAR_Z: int = 5                                   # 源 :396 addChild(s, 5)
const LEVEL_BG_POS: Vector2 = Vector2(2.0, 15.0)        # 源 :358
const LEVEL_LABEL_POS: Vector2 = Vector2(18.0, 26.0)    # 源 :363
const LEVEL_FONT_SIZE: int = 14                         # 源 :361 createttf(level,14)
const LEVEL_Z: int = 25                                 # 源 :364 addChild(label, 25)
const CLIP_PATH_PREFIX: String = "UI/"                  # 源路径前缀 → res://assets/ui/
const CLIP_PATH_REPLACE: String = "res://assets/ui/"
# 源 addHpInfo hp/mp 血条（crusade 资源，结算/crusade 显示战斗结束血量，源 readhero.lua:266-305）
const CRUSADE_DIR: String = "res://assets/ui/alpha/HVGA/crusade/"
const HP_BAR_BG_PATH: String = CRUSADE_DIR + "crusade_hp_bar_bg.png"
const HP_BAR_PATH: String = CRUSADE_DIR + "crusade_hp_bar.png"
const MP_BAR_BG_PATH: String = CRUSADE_DIR + "crusade_mp_bar_bg.png"
const MP_BAR_PATH: String = CRUSADE_DIR + "crusade_mp_bar.png"
const DEAD_PATH: String = CRUSADE_DIR + "crusade_text_dead.png"  # 照源 readhero.lua:238/274 引用；源项目亦缺此图（HVGA/crusade/ 27 资源无 dead），源 createSprite 缺图≈nil，_create_dead_shade 等价
const HP_BAR_POS: Vector2 = Vector2(11.0, 71.0)   # 源 :285 ccp(11,71) 锚点(0,0.5)
const MP_BAR_POS: Vector2 = Vector2(11.0, 64.0)   # 源 :295 ccp(11,64)
const DEAD_POS: Vector2 = Vector2(44.0, 65.0)     # 源 :275 ccp(44,65)
const HP_PERC_DENOM: float = 10000.0              # 源 setScaleX(hp/10000)，hp 0-10000 万分比
const SHADE_ALPHA: float = 150.0 / 255.0          # 源 :277 ccc4(0,0,0,150)
const DEAD_Z: int = 10                            # 源 :276 addChild(die, 10)

# 源 player.lua:2090-2114 frames 表（rank 1-22 → hero_icon_frame_N，0-indexed 数组）。
const RANK_FRAME_IDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 11, 11, 11, 11, 11, 11, 11, 11, 12, 12]

var icon: Node2D = null        # 源 self.icon（container，外部 addChild 用）
var ori_icon: Node2D = null    # 源 self.ori_icon（Portrait sprite，死亡变灰setColor 用）
var frame: Sprite2D = null     # 源 self.frame
var stars: Array = []          # 源 self.stars
var level_label: Label = null  # 源 self.levelLabel（refreshLevel 用）


# 源 createIcon(info) — info: {id, rank=1, stars=0, isHideFrame=false, level=null}。
# cm：ConfigManager（查 Unit.Portrait；null 时 id==0 unknow 占位）。
# 源 readhero.lua:465 createIconByHero — hero→info 转换 + setup（createIcon 包装）。
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
	var hp: Variant = info.get("hp", null)      # 源 :360 info.hp（addHpInfo 守卫，null 不画血条）
	var mp: Variant = info.get("mp", null)      # 源 :361 info.mp
	icon = Node2D.new()
	add_child(icon)
	ori_icon = _create_portrait(id, p_cm)
	icon.add_child(ori_icon)
	frame = _create_frame(rank)
	if frame != null:
		icon.add_child(frame)
		frame.visible = not is_hide_frame   # 源 :372-374 isHideFrame→setVisible(false)
	_create_stars(star_count)
	if level != null:
		_create_level(int(level))
	_add_hp_info(hp, mp)   # 源 :430 addHpInfo（hp 守卫，仅传 hp 时画血条/死亡标识）


# 源 :330-349 — id==0 占位（黑底 + unknow）；id>0 Portrait + clipping（equip_stencil mask）。
func _create_portrait(id: int, cm: Variant) -> Node2D:
	if id == 0 or cm == null:
		return _create_unknow()
	var portrait_res: Variant = cm.lookup("Unit", "Portrait", id)
	if portrait_res == null or not (portrait_res is String) or (portrait_res as String).is_empty():
		return _create_unknow()
	var path: String = (portrait_res as String).replace(CLIP_PATH_PREFIX, CLIP_PATH_REPLACE)
	var sprite := Sprite2D.new()
	sprite.texture = _load_tex(path)
	# 源 :351 icon setPosition(size/2) + sprite anchor(0.5,0.5) → Portrait 中心在 container 中心
	sprite.position = CONTAINER_SIZE * 0.5
	# 源 createClippingNode：equip_stencil mask + alphaThreshold=0.02 裁剪 Portrait
	var mat := ShaderMaterial.new()
	mat.shader = PortraitMaskShader
	mat.set_shader_parameter("mask_tex", _load_tex(STENCIL_PATH))
	mat.set_shader_parameter("alpha_threshold", ALPHA_THRESHOLD)
	sprite.material = mat
	return sprite


# 源 :330-341 id==0 → 黑底 CCLayerColor + unknow 占位。
func _create_unknow() -> Node2D:
	var node := Node2D.new()
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 1.0)
	bg.size = CONTAINER_SIZE
	bg.position = Vector2.ZERO
	node.add_child(bg)
	var qm := Sprite2D.new()
	qm.texture = _load_tex(UNKNOW_PATH)
	qm.position = CONTAINER_SIZE * 0.5   # 源 :338 getCenterPos
	node.add_child(qm)
	return node


# 源 :367-371 frame = createSprite(getIconFrameByRank(rank))，scale=(size+5)/frame_size，居中。
func _create_frame(rank: int) -> Sprite2D:
	var frame_id: int = _frame_id_by_rank(rank)
	var frame := Sprite2D.new()
	frame.texture = _load_tex(FRAME_PATH_FMT % frame_id)
	if frame.texture != null:
		var fw: float = float(frame.texture.get_width())
		frame.scale = Vector2((CONTAINER_SIZE.x + FRAME_SCALE_PAD) / fw, (CONTAINER_SIZE.y + FRAME_SCALE_PAD) / fw)
		frame.position = CONTAINER_SIZE * 0.5   # 源 :369 setPosition(size/2)
	return frame


# 源 player.lua:2119-2121 getIconFrameByRank(rank) → frames[rank]（Lua 1-indexed → GDScript 0-indexed）。
static func _frame_id_by_rank(rank: int) -> int:
	if rank < 1 or rank > RANK_FRAME_IDS.size():
		return 1   # 越界默认 frame_1
	return RANK_FRAME_IDS[rank - 1]


# 源 :384-398 stars 拼接：i 从 star_count 倒序到 1，x = base + dx*(i - stars/2)，y=6。
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


# 源 :355-366 level：heropackage_level_bg(@2,15) + levelLabel(@18,26, size14)。
func _create_level(level: int) -> void:
	var bg := Sprite2D.new()
	bg.texture = _load_tex(LEVEL_BG_PATH)
	bg.centered = false
	bg.position = LEVEL_BG_POS
	icon.add_child(bg)
	var lbl := Label.new()
	level_label = lbl   # 源 self.levelLabel（refreshLevel 读）
	var ls := LabelSettings.new()
	ls.font_size = LEVEL_FONT_SIZE
	lbl.label_settings = ls
	lbl.text = str(level)
	lbl.position = LEVEL_LABEL_POS
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.z_index = LEVEL_Z
	icon.add_child(lbl)


# 源 readhero.lua:591-594 refreshLevel — setString(self.levelLabel, level)。stagedone 升级动画用。
func refresh_level(level: int) -> void:
	if level_label != null:
		level_label.text = str(level)


# 源 readhero.lua:266-305 addHpInfo — hp/mp 血条（icon 内部，结算/crusade 显示战斗结束血量）。
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


# 源 :272-279 hp<=0 死亡标识：crusade_text_dead.png（44,65）+ 黑 shade（150 alpha 覆盖 icon）。
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


# 源 :281-300 hp/mp 条：bg + bar，锚点 (0,0.5)，bar scaleX = perc（0-1，从左边缘缩放）。
# cocos setAnchorPoint(0,0.5) setPosition(x,y) → Godot centered=false + position(x, y-h/2) 等价（左边缘 x，垂直中心 y）。
func _create_bar(bg_path: String, bar_path: String, pos: Vector2, perc: float) -> void:
	var bg_tex: Texture2D = _load_tex(bg_path)
	var bar_tex: Texture2D = _load_tex(bar_path)
	if bg_tex != null:
		var bar_bg := Sprite2D.new()
		bar_bg.texture = bg_tex
		bar_bg.centered = false
		bar_bg.position = Vector2(pos.x, pos.y - float(bg_tex.get_height()) * 0.5)
		icon.add_child(bar_bg)
	if bar_tex != null:
		var bar := Sprite2D.new()
		bar.texture = bar_tex
		bar.centered = false
		bar.position = Vector2(pos.x, pos.y - float(bar_tex.get_height()) * 0.5)
		bar.scale.x = clampf(perc, 0.0, 1.0)
		icon.add_child(bar)


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
