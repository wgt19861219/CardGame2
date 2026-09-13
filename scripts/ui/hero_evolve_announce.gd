class_name HeroEvolveAnnounce
extends Control

## 灵魂石进化成长公告窗（照源 ui/announce/announce.lua heroEvolve :785-1010 补译）。
## 触发：进化 back FCA 播完后弹出（源 registerEvolveAnim 等 back isTerminated → announce）。
## 结构：shade + main_vit_tips 底板 410×290 + 顶部标题/lettherebelight 旋转光 +
## 旧星→新星图标对比行 + STR/INT/AGI 三行成长对比（紫条/金名/旧值→新值/绿增量）+ 右上 close。
## 受控偏离：源标题图 herodetail_popup_evolution_title.png 在源 res（Axmol @bf79ee2）与
## 本项目均缺失 → Label 文字「进化」替代；标题入场动画（Scale 1.5→1 BackOut 0.2s → 光
## 延迟显示）与光旋转（5s/圈循环）照源保留。
## 坐标：源 announce bg 内 cocos 坐标 → godot bg 局部 y=290-y，bg 左上全局 (195,95)。

const BG_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const LIGHT_RES: String = "res://assets/ui/alpha/HVGA/lettherebelight.png"
const ARROW_RES: String = "res://assets/ui/alpha/HVGA/player_levelup_arrow.png"
const BAR_RES: String = "res://assets/ui/alpha/HVGA/announce_text_bg_purple.png"
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/common/common_tips_button_close_1.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/common/common_tips_button_close_2.png"
const CS: float = 1.28125   # hello.lua:311 ContentScaleFactor（贴图显示尺寸=px÷CS）
# 源 create(:911-915) bg Scale9 main_vit_tips cap(10,10,58,26) 410×290 中心 ccp(400,240)。
const BG_SIZE: Vector2 = Vector2(410.0, 290.0)
const BG_TOPLEFT: Vector2 = Vector2(195.0, 95.0)
const BG_PATCH: Rect2 = Rect2(10.0, 25.0, 58.0, 26.0)   # cap(10,10,58,26)→godot top=61-10-26=25（avatar 同款）
# 源 light/title 同点 ccp(205,290)（bg 顶部中央）；light 385×385 原尺寸（get_new_hero 同款不缩放）。
const TOP_CENTER: Vector2 = Vector2(205.0, 0.0)
const TITLE_FONT: int = 22
const TITLE_SCALE_FROM: float = 1.5   # 源 titleAnimHandler :996-1010 Scale 1.5→1 BackOut 0.2s
const TITLE_TWEEN_SEC: float = 0.2
const LIGHT_ROTATE_SEC: float = 5.0   # 源 CCRotateBy(5,360) RepeatForever
# 源 close ccp(400,270)（bg 内右上），65×66px ÷CS。
const CLOSE_CENTER: Vector2 = Vector2(400.0, 20.0)
const CLOSE_SIZE: Vector2 = Vector2(65.0 / CS, 66.0 / CS)
# 图标对比行（源 create :955-968）：preIcon 中心 ccp(145,195)，arrow/icon 依次右排（右缘续接）。
const ICON_ROW_Y: float = 95.0   # 290-195
const PRE_ICON_CENTER_X: float = 145.0
const ICON_SIZE: float = 104.0   # ReadheroIcon 名义容器尺寸（CONTAINER_SIZE）
const ARROW_SIZE: Vector2 = Vector2(37.0 / CS, 35.0 / CS)
# 三行成长（源 createGrowth :793-887）：STR/INT/AGI y=120/80/40（cocos）→ godot 170/210/250。
const GROWTH_KEYS: Array[String] = ["STR", "INT", "AGI"]
const GROWTH_ROW_Y: Array[float] = [170.0, 210.0, 250.0]
# 行内 x（源 ofx=10 前置含）：紫条 400×40 中心(200,y)；名右对齐 140；pre 中心 175；
# arrow 中心 220；新值中心 265；增量左对齐 295。
const BAR_SIZE: Vector2 = Vector2(400.0, 40.0)
const NAME_RIGHT_X: float = 140.0
const PRE_VAL_X: float = 175.0
const ARROW_X: float = 220.0
const NEW_VAL_X: float = 265.0
const ADD_LEFT_X: float = 295.0
const NAME_FONT: int = 20
const VAL_FONT: int = 18
const ADD_FONT: int = 16
const NAME_COLOR: Color = Color(241.0 / 255.0, 193.0 / 255.0, 113.0 / 255.0)   # 源 ccc3(241,193,113)
const VAL_COLOR: Color = Color(255.0 / 255.0, 234.0 / 255.0, 198.0 / 255.0)   # 源 ccc3(255,234,198)
const ADD_COLOR: Color = Color(0.0, 1.0, 0.0)   # 源 ccc3(0,255,0)
# 成长名 LSTR（源 keys 用 HERO_EQUIP.*：力量/智力/敏捷）。
const GROWTH_LSTR: Dictionary = {
	"STR": "HERO_EQUIP.STRENGTH", "INT": "HERO_EQUIP.INTELLIGENCE", "AGI": "HERO_EQUIP.AGILITY",
}
const TITLE_FALLBACK: String = "进化"
const SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 150.0 / 255.0)   # 项目弹窗统一遮罩深度


## 入口：parent（detail 面板宿主，后加盖其上）挂公告窗。att_delta 为进化前后属性差
## （{key: int}，HeroDetailEvolveFx._att_delta 口径；源绿增量=att-preAtt.all 等价）。
## 先 add_child 再 _build：_build 内 create_tween 依赖节点已入树。
static func show_announce(parent: Node, hero: HeroInstance, att_delta: Dictionary, cm: Variant) -> void:
	if parent == null or hero == null:
		return
	var popup := HeroEvolveAnnounce.new()
	parent.add_child(popup)
	popup._build(hero, att_delta, cm)


var _light: Sprite2D = null
var _title: Label = null
var _rotate_tween: Tween = null


func _build(hero: HeroInstance, att_delta: Dictionary, cm: Variant) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.color = SHADE_COLOR
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP   # 源 setClickDestroyEnabled(false)：吞点击不关
	add_child(shade)
	var bg := NinePatchRect.new()
	bg.texture = load(BG_RES) as Texture2D
	bg.patch_margin_left = BG_PATCH.position.x
	bg.patch_margin_top = BG_PATCH.position.y
	bg.patch_margin_right = BG_PATCH.end.x - BG_PATCH.position.x
	bg.patch_margin_bottom = BG_PATCH.end.y - BG_PATCH.position.y
	bg.position = BG_TOPLEFT
	bg.size = BG_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_add_top_anim(bg)
	_add_close(bg)
	_add_icon_row(bg, hero, cm)
	_add_growth_rows(bg, hero, att_delta, cm)


# 顶部标题（文字替代缺图）+ 旋转光（源 titleAnimHandler：窗显示后 title Scale 1.5→1
# BackOut 0.2s，完成时 light 显；light 5s/圈永续旋转）。
func _add_top_anim(bg: Control) -> void:
	_light = Sprite2D.new()
	_light.texture = load(LIGHT_RES) as Texture2D
	_light.position = TOP_CENTER
	_light.visible = false
	bg.add_child(_light)
	_title = Label.new()
	_title.text = TITLE_FALLBACK
	_title.add_theme_font_size_override("font_size", TITLE_FONT)
	_title.add_theme_color_override("font_color", NAME_COLOR)
	_title.position = TOP_CENTER + Vector2(-100.0, -14.0)
	_title.size = Vector2(200.0, 28.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.visible = false
	_title.pivot_offset = _title.size * 0.5
	bg.add_child(_title)
	_title.visible = true
	_title.scale = Vector2(TITLE_SCALE_FROM, TITLE_SCALE_FROM)
	var tw := create_tween()
	tw.tween_property(_title, "scale", Vector2.ONE, TITLE_TWEEN_SEC)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _light.visible = true)
	_rotate_tween = create_tween().set_loops()
	_rotate_tween.tween_property(_light, "rotation", TAU, LIGHT_ROTATE_SEC)


# 右上关闭（源 create :928-949 close/close_press 两态 + doCloseTouch → 销毁）。
func _add_close(bg: Control) -> void:
	var btn := TextureButton.new()
	btn.texture_normal = load(CLOSE_RES) as Texture2D
	btn.texture_pressed = load(CLOSE_PRESS_RES) as Texture2D
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.position = CLOSE_CENTER - CLOSE_SIZE * 0.5
	btn.size = CLOSE_SIZE
	btn.pressed.connect(queue_free)
	bg.add_child(btn)


# 旧星→新星图标对比行（源 :955-968 createIconByID addStar=-1 / 默认，右缘续接排开）。
func _add_icon_row(bg: Control, hero: HeroInstance, cm: Variant) -> void:
	var old_stars: int = int(hero.stars) - 1
	var pre_icon := ReadheroIcon.new()
	pre_icon.setup({"id": int(hero.tid), "rank": int(hero.rank), "stars": old_stars,
		"level": int(hero.level)}, cm)
	pre_icon.position = Vector2(PRE_ICON_CENTER_X - ICON_SIZE * 0.5, ICON_ROW_Y - ICON_SIZE * 0.5)
	bg.add_child(pre_icon)
	var arrow := TextureRect.new()
	arrow.texture = load(ARROW_RES) as Texture2D
	var arrow_x: float = PRE_ICON_CENTER_X + ICON_SIZE * 0.5   # preIcon 右缘（源 getRightSidePos）
	arrow.position = Vector2(arrow_x, ICON_ROW_Y - ARROW_SIZE.y * 0.5)
	arrow.size = ARROW_SIZE
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(arrow)
	var new_icon := ReadheroIcon.new()
	new_icon.setup({"id": int(hero.tid), "rank": int(hero.rank), "stars": int(hero.stars),
		"level": int(hero.level)}, cm)
	new_icon.position = Vector2(arrow_x + ARROW_SIZE.x, ICON_ROW_Y - ICON_SIZE * 0.5)
	bg.add_child(new_icon)


# 三行成长对比（源 createGrowth :793-887）：奇数行（i=1/3 即 STR/AGI）紫条底 +
# 「名 成长:」金字右对齐 + 旧值 → 箭头 → 新值 + 「(名+Δ)」绿增量。
func _add_growth_rows(bg: Control, hero: HeroInstance, att_delta: Dictionary, cm: Variant) -> void:
	var new_growth: Dictionary = ReadheroData.get_growth(int(hero.tid), int(hero.stars), cm)
	var old_growth: Dictionary = ReadheroData.get_growth(int(hero.tid), int(hero.stars) - 1, cm)
	for i in GROWTH_KEYS.size():
		var key: String = GROWTH_KEYS[i]
		var y: float = GROWTH_ROW_Y[i]
		if i % 2 == 0:   # 源 i%2==1（lua 1-based）→ godot i%2==0：第 1/3 行（STR/AGI）紫条
			var bar := TextureRect.new()
			bar.texture = load(BAR_RES) as Texture2D
			bar.position = Vector2(0.0, y - BAR_SIZE.y * 0.5)
			bar.size = BAR_SIZE
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg.add_child(bar)
		var name_text: String = HeroDetailAttribs.get_lstr_fallback(
			String(GROWTH_LSTR.get(key, "")), key, cm)
		var name_lbl := _make_label(NAME_FONT, NAME_COLOR)
		name_lbl.text = name_text + " " + _growth_suffix(cm)
		name_lbl.position = Vector2(NAME_RIGHT_X - 120.0, y - 12.0)
		name_lbl.size = Vector2(120.0, 24.0)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bg.add_child(name_lbl)
		var pre_lbl := _make_label(VAL_FONT, VAL_COLOR)
		pre_lbl.text = _fmt_growth(float(old_growth.get(key, 0)))
		pre_lbl.position = Vector2(PRE_VAL_X - 40.0, y - 11.0)
		pre_lbl.size = Vector2(80.0, 22.0)
		pre_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bg.add_child(pre_lbl)
		var arrow := TextureRect.new()
		arrow.texture = load(ARROW_RES) as Texture2D
		arrow.position = Vector2(ARROW_X - ARROW_SIZE.x * 0.5, y - ARROW_SIZE.y * 0.5)
		arrow.size = ARROW_SIZE
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(arrow)
		var new_lbl := _make_label(VAL_FONT, VAL_COLOR)
		new_lbl.text = _fmt_growth(float(new_growth.get(key, 0)))
		new_lbl.position = Vector2(NEW_VAL_X - 40.0, y - 11.0)
		new_lbl.size = Vector2(80.0, 22.0)
		new_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bg.add_child(new_lbl)
		var delta: int = int(att_delta.get(key, 0))
		if delta > 0:   # 源无判（属性必增）；防御负值不显绿字
			var add_lbl := _make_label(ADD_FONT, ADD_COLOR)
			add_lbl.text = "(%s+%d)" % [name_text, delta]
			add_lbl.position = Vector2(ADD_LEFT_X, y - 10.0)
			add_lbl.size = Vector2(110.0, 20.0)
			bg.add_child(add_lbl)


# 「成长:」后缀 LSTR（源 ANNOUNCE.GROWTH_）。
static func _growth_suffix(cm: Variant) -> String:
	if cm != null and cm.has_method(&"get_lstr"):
		var s: String = String(cm.get_lstr("ANNOUNCE.GROWTH_"))
		if not s.is_empty() and s != "ANNOUNCE.GROWTH_":
			return s
	return "成长:"


# 成长值展示（源 preGrowth/growth 原值直出，表值一位小数 → 去尾零整显）。
static func _fmt_growth(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, float(int(v))) else "%.1f" % v


func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _exit_tree() -> void:
	if _rotate_tween != null and _rotate_tween.is_valid():
		_rotate_tween.kill()
