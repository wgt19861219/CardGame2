class_name MainButtonFactory
extends RefCounted

## 主界面入口按钮工厂（View 层 Step 13.2/13.5/press）— 照源 ui/main.lua:557 createMainButton + createMainFca。
## 按钮 = RoundButton 容器（flat 透明 + 圆形触摸 touchCenter/touchRadius，源 getMainButtonTouchConfig）
##       + press 光效（main_button_press.png × lightSize，按下显示，源 :592-604）
##       + Spine 动画图标（aniType=1，源 :413）+ title 背景图（main_title_a.png，源 :608 titleres）+ titleLabel（LSTR 中文，源 :622 font 17）。
## 从 main_scene.gd 抽出避超 400 行。坐标：源 ccp(左下) 已转 Godot(左上)，ENTRIES pos = 源中心点（CCSprite anchor 0.5）。

const SPINE_DIR: String = "res://assets/spine"
const LOOP_ACTION: String = "Loop"   # 源 SpineContainer default Start→Loop，主界面按钮 Loop 循环
const TITLE_BG: String = "res://assets/ui/alpha/HVGA/main_title_a.png"   # 源 mainres.titleres
const PRESS_TEX: String = "res://assets/ui/alpha/HVGA/main_button_press.png"   # 源 createMainButton:560 pressres
const LOCKED_ALPHA: float = 0.5       # 源 main.lua 未解锁按钮灰显 alpha
const TITLE_FONT_SIZE: int = 17       # 源 createMainButton:622 ui_main_button_normal 17
const TITLE_MAX_WIDTH: float = 100.0  # 源 :625 label 超 100 宽缩放
const TITLE_OFFSET_Y: float = 25.0    # 源 createMainFca:443 pos.y - 25（title 在图标下方，Godot y 下 → +25）
const DEFAULT_RADIUS: float = 56.0    # 无 radius 字段的默认触摸半径
const GapLoopAnimator = preload("res://scripts/ui/gap_loop_animator.gd")
const RoundButton = preload("res://scripts/ui/round_button.gd")
const FcaAnimation = preload("res://scripts/view/battle/fca_animation.gd")
const AtlasSprite = preload("res://scripts/view/battle/atlas_sprite.gd")
const FCA_ANI_DIR: String = "res://assets/anim_frames/effect/"   # eff_UI_*.ani FCA 序列帧目录


## 建入口按钮（照源 createMainButton + createMainFca）。e = ENTRIES 条目，on_pressed = 点击回调，is_locked = 未解锁灰显。
static func make_entry(e: Dictionary, on_pressed: Callable, is_locked: bool) -> Button:
	var btn := RoundButton.new()
	# 圆形触摸（照源 touchCenter/touchRadius）：size = 2×radius（方形），pos 中心对齐源 pos
	var radius: float = float(e.get("radius", DEFAULT_RADIUS))
	btn.size = Vector2(radius * 2.0, radius * 2.0)
	btn.position = Vector2(float(e["pos"][0]) - radius, float(e["pos"][1]) - radius)
	var touch: Array = e.get("touch", [0, 0])
	btn.touch_center = Vector2(float(touch[0]), float(touch[1]))
	# flat 透明底（照源 main_scene 无按钮底纹，icon=Spine，title=独立 TextureRect）
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	if is_locked:
		btn.modulate.a = LOCKED_ALPHA
	btn.pressed.connect(on_pressed)
	_add_press(btn, e)   # 光效最底层（源 press z=0，先 addChild 在 Spine/title 之下）
	var sk: Node2D = _add_spine(btn, e)
	_add_title(btn, String(e["title"]))
	_add_gap_loop(btn, sk, e)
	return btn


# press 光效（照源 createMainButton:592-604）。e["light"] = [lightPos_x, lightPos_y, lightSize_w, lightSize_h]（源 mainres.lightPos + lightSize）。
# 中心 = 按钮中心 + lightPos（源 y 上 → Godot y 下，翻 Y），尺寸 = lightSize × scale（源 setScale = lightSize*scale/size）。
# 默认隐藏，button_down 显示 / button_up 隐藏（源 btRegisterClick 按下 ui[key.."_press"]:setVisible(true)）。
# 源 :594-596 ssshop/estren tposition.y-30 是死代码（:598 setPos 仍用 br.lightPos），照源实际行为不修正。
static func _add_press(btn: Button, e: Dictionary) -> void:
	if not e.has("light"):
		return
	var tex: Texture2D = load(PRESS_TEX)
	if tex == null:
		return
	var l: Array = e["light"]
	var sk_scale: float = float(e.get("scale", 1.0))
	var press_size: Vector2 = Vector2(float(l[2]) * sk_scale, float(l[3]) * sk_scale)
	var press := TextureRect.new()
	press.texture = tex
	press.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # minimum 不让纹理撑大 size（源 CCSprite setScale 非等比缩放）
	press.size = press_size
	# 中心 = btn 中心 + lightPos（翻 Y）；左上 = 中心 - size/2
	press.position = Vector2(btn.size.x * 0.5 + float(l[0]) - press_size.x * 0.5, btn.size.y * 0.5 - float(l[1]) - press_size.y * 0.5)
	press.mouse_filter = Control.MOUSE_FILTER_IGNORE
	press.visible = false
	btn.add_child(press)
	btn.button_down.connect(func() -> void: press.visible = true)
	btn.button_up.connect(func() -> void: press.visible = false)


# Spine 动画图标（照源 ui/main.lua:413 createFcaNode aniType=1 + setAction Loop）。
# load_skeleton 失败（starshop Shop_Star spine/ 无资源，源走 FCA）静默降级（返 null）。
static func _add_spine(btn: Button, e: Dictionary) -> Node2D:
	if not e.has("res"):
		return null
	var sk_scale: float = float(e.get("scale", 1.0))
	var sk := SpineSkeleton.new()
	# 源 createMainFca:418 setScale(v.scale)。createAnimation 是 C++ SpineRuntime，不受 LegendSetAniScaleFactor 影响
	# （0.39 仅 LegendAminationEffect/.abc 自家系统用；createFcaNode:581 Type_Spine 走 createAnimation，:589 FCA 走 LegendAminationEffect）。
	sk.scale = Vector2(sk_scale, sk_scale)   # load_skeleton:37 自动翻 y（Spine y 上 → Godot y 下）
	btn.add_child(sk)
	if sk.load_skeleton(SPINE_DIR + "/" + String(e["res"]), String(e["res"])):
		sk.position = Vector2(btn.size.x * 0.5, btn.size.y * 0.5)   # Button 中心 = 源按钮 pos（CCSprite 中心点）
		sk.play(LOOP_ACTION, true)
		return sk
	sk.queue_free()
	# Spine 资源缺 → FCA fallback（源 aniType 未传走 FCA .ani，如 Shop_Star 星际商店）
	return _add_fca(btn, String(e["res"]), sk_scale)


# FCA 序列帧 fallback（Spine 资源缺的入口，照源 createFcaNode aniType 未传路径）。
static func _add_fca(btn: Button, res: String, sk_scale: float) -> Node2D:
	var atlas := AtlasSprite.new()
	if not atlas.load_atlas_from_ani(FCA_ANI_DIR + res + ".ani"):
		atlas.queue_free()
		return null
	var fca := FcaAnimation.new()
	if not fca.load_from_ani("effect/" + res, atlas):
		fca.queue_free()
		return null
	# 源 setScale(v.scale) 叠加在 cha_ui_scale 上（LegendAminationEffect 内部 base=cha_ui_scale × extra=v.scale，
	# 非 CC 标准覆盖）。_create_sprites 已设 fca.scale=_coord_scale(0.39)，此处 ×v.scale 叠加。
	# net a/b/c/d = (0.39×v.scale)/0.39 × 原始 = v.scale×原始（正常缩放，避反向 ×1/0.39 放大 2.05× 致 starshop 超大）。
	fca.scale = fca.scale * sk_scale
	btn.add_child(fca)
	fca.position = Vector2(btn.size.x * 0.5, btn.size.y * 0.5)
	fca.play(LOOP_ACTION, true)
	return fca


# gap/loop 间隙动画（照源 createMainFca:446-471）。e["gap"] = [gap_min, gap_max, loop_gap, loop_times_min, loop_times_max]。
# starshop spine/ 无资源 sk=null → 不挂 animator（数据照源，运行时降级）。
static func _add_gap_loop(btn: Button, sk: Node2D, e: Dictionary) -> void:
	if sk == null or not (sk is SpineSkeleton) or not e.has("gap"):
		return   # FCA(FcaAnimation)自带 Loop 动画，不挂 gap_loop
	var g: Array = e["gap"]
	var anim := GapLoopAnimator.new()
	btn.add_child(anim)
	anim.setup(sk, float(g[0]), float(g[1]), float(g[2]), int(g[3]), int(g[4]))


# title 背景图 + 标题文字（照源 createMainButton:607-630 titleres=main_title_a.png + label (60,18) font 17）。
# title 中心 = 按钮中心 x，下方 25（源 createMainFca:443 pos.y - 25 → Godot y 下 +25）。
static func _add_title(btn: Button, title_text: String) -> void:
	var tex: Texture2D = load(TITLE_BG)
	if tex == null:
		return
	var title := TextureRect.new()
	title.texture = tex
	title.size = tex.get_size()
	title.position = Vector2(btn.size.x * 0.5 - title.size.x * 0.5, btn.size.y * 0.5 + TITLE_OFFSET_Y - title.size.y * 0.5)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(title)
	var label := Label.new()
	label.text = title_text
	label.position = Vector2.ZERO
	label.size = title.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font", TITLE_FONT_SIZE)
	label.clip_text = true   # 源 :625-627 超 100 宽缩放（Label clip 避溢出 title 背景）
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(label)
