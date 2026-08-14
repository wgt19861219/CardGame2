class_name HeroAwakePanel
extends PopWindow

## 觉醒展示弹窗（View 层）— 照源 ui/popwindow/popheroawake.lua 翻译。
## 动画序列（源 showCardui :9-47）：
##   1. bg CCFadeIn(0.4)（:147）
##   2. light CCFadeIn(0.4) → CCRotateBy(5,360)×CCRepeat×3（:11-18，360° 旋转 3 圈共 15s）
##   3. cardui CCDelayTime(0.4) → CCFadeIn(0.2) + add bubble FCA（:21-36）
##   4. add card_<color> FCA at z=10 scale=1.5（:38-44）
##   5. registerTouchHandler + 点击任意处关闭（:45-46 + doClickLayer :49-72）
## FCA 资源 eff_UI_tavern_bubble / eff_UI_tavern_card_<color> 在 assets/anim_frames/effect/。

signal awake_shown   # 展示动画启动（点击关闭前的视觉完成节点）
signal closed        # 用户点击关闭

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_awake_content.tscn")
const CARD_SCENE: PackedScene = preload("res://scenes/ui/hero_detail_card_tab.tscn")

const CENTER_COCOS: Vector2 = Vector2(400.0, 240.0)   # bg/cardui center
const LIGHT_COCOS: Vector2 = Vector2(400.0, 550.0)    # light
const LIGHT_SCALE: float = 6.0
const LIGHT_ROTATE_SEC: float = 5.0
const LIGHT_REPEAT: int = 3
const FADE_IN_SEC: float = 0.4
const CARD_FADE_SEC: float = 0.2
const CARD_FADE_DELAY: float = 0.4
const FCA_SCALE: float = 1.5
const CARD_HOST_SHIFT_X: float = 200.0                # card_tab 原居左，右移 200 让 CardFrame center 落屏幕 (480,320)

const BG_RES_MAP: Dictionary = {
	"red": "res://assets/ui/alpha/HVGA/tavern_get_hero_bg_red.jpg",
	"green": "res://assets/ui/alpha/HVGA/tavern_get_hero_bg_green.jpg",
	"blue": "res://assets/ui/alpha/HVGA/tavern_get_hero_bg_blue.jpg",
}
const FCA_BASE_DIR: String = "res://assets/anim_frames/effect/"
const BUBBLE_RES: String = "eff_UI_tavern_bubble"
const CARD_FCA_PREFIX: String = "eff_UI_tavern_card_"

const AtlasSprite = preload("res://scripts/ui/atlas_sprite.gd")
const FcaAnimation = preload("res://scripts/ui/fca_animation.gd")

var _hero: HeroInstance = null
var _cm: Variant = null
var _color: String = "red"
var _content: Control = null
var _bg: TextureRect = null
var _light: Sprite2D = null
var _card_host: Control = null
var _fca_host: Control = null
var _close_handler: Callable = Callable()


static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + 80.0, 560.0 - cy)


# 本项目单机化直接调 _build_content + show_window 后开动画（无 announce 中介）。
func setup_awake(hero: HeroInstance, cm: Variant) -> void:
	_hero = hero
	_cm = cm
	_color = _resolve_color(cm, hero)
	set_swallow(false)
	setup()
	# shade 透明（源 noShade=true 等价：不可见但仍占全屏接收点击）
	shade_layer.color = Color(0.0, 0.0, 0.0, 0.0)
	_build_content()


func _resolve_color(cm: Variant, hero: HeroInstance) -> String:
	if cm == null or hero == null:
		return "red"
	var c: String = String(cm.get_raw_table(&"Unit").get(str(hero.tid), {}).get(&"Bg Color", "red"))
	return c if BG_RES_MAP.has(c) else "red"


func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_bg = _content.get_node("%BgRect") as TextureRect
	_light = _content.get_node("%LightSprite") as Sprite2D
	_card_host = _content.get_node("%CardHost") as Control
	_fca_host = _content.get_node("%FcaHost") as Control
	var bg_res: String = _resolve_bg_res()
	if not bg_res.is_empty() and ResourceLoader.exists(bg_res):
		_bg.texture = load(bg_res) as Texture2D
	_bg.modulate.a = 0.0
	_light.scale = Vector2(LIGHT_SCALE, LIGHT_SCALE)
	_light.modulate.a = 0.0
	_build_hero_card()


func _resolve_bg_res() -> String:
	var res: String = BG_RES_MAP.get(_color, "")
	if ResourceLoader.exists(res):
		return res
	# 缺降级：依次试 red/blue/green 占位
	for color in ["red", "blue", "green"]:
		var fallback: String = BG_RES_MAP[color]
		if ResourceLoader.exists(fallback):
			return fallback
	return ""


# 卡牌视觉（源 :136 ed.readhero.getHeroCard(hid, {disableswap=true, showAwake=true}).container）。
# 复用 hero_detail_card_tab.tscn（CardFrame + Art + Name + stars + type icon，HeroDetailTabs.fill_card_view 填数据）。
# card_tab 原为 hero_detail 设计（CardFrame center 280,320），觉醒弹窗居中需右移 200 → center (480,320)。
func _build_hero_card() -> void:
	if _hero == null or _cm == null:
		return
	var card: Control = CARD_SCENE.instantiate() as Control
	card.visible = true   # .tscn 默认 visible=false，强制显示
	card.offset_left = CARD_HOST_SHIFT_X
	card.offset_right = CARD_HOST_SHIFT_X
	card.modulate.a = 0.0
	_card_host.add_child(card)
	HeroDetailTabs.fill_card_view(card, _hero, _cm)


func show_window(parent: Node) -> void:
	super.show_window(parent)
	_play_show_anim()


func _play_show_anim() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_bg, "modulate:a", 1.0, FADE_IN_SEC)
	tw.tween_callback(_show_card_ui)


func _show_card_ui() -> void:
	if not is_inside_tree():
		return
	_play_light_anim()
	_play_card_fade()
	_add_card_fca()
	awake_shown.emit()


func _play_light_anim() -> void:
	if _light == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(_light, "modulate:a", 1.0, FADE_IN_SEC)
	var total_sec: float = LIGHT_ROTATE_SEC * float(LIGHT_REPEAT)
	tw.tween_property(_light, "rotation", deg_to_rad(360.0 * float(LIGHT_REPEAT)), total_sec)


func _play_card_fade() -> void:
	if _card_host == null or _card_host.get_child_count() == 0:
		return
	var card: Control = _card_host.get_child(0) as Control
	var tw: Tween = create_tween()
	tw.tween_interval(CARD_FADE_DELAY)
	tw.tween_property(card, "modulate:a", 1.0, CARD_FADE_SEC)
	tw.tween_callback(_add_bubble_fca)


func _add_bubble_fca() -> void:
	_add_fca(BUBBLE_RES)


func _add_card_fca() -> void:
	_add_fca(CARD_FCA_PREFIX + _color)


# 加 FCA 光效（.abc zip 在 effect/ 子目录，atlas.load_atlas_from_ani 路径含 effect/ 前缀）。
# 缺资源静默跳过（照源 xpcall 容错 + 项目 .abc 加载失败降级范式）。
func _add_fca(resource: String) -> void:
	if _fca_host == null:
		return
	var zip_path: String = FCA_BASE_DIR + resource + ".abc"
	if not FileAccess.file_exists(zip_path):
		return   # 降级跳过（.abc 缺或无支持）
	var atlas := AtlasSprite.new()
	if not atlas.load_atlas_from_ani(zip_path):
		return
	var fca := FcaAnimation.new()
	if not fca.load_from_ani(resource, atlas):
		return
	var parts := Node2D.new()
	parts.position = to_godot(CENTER_COCOS.x, CENTER_COCOS.y)
	parts.scale = Vector2(FCA_SCALE, FCA_SCALE)
	parts.add_child(fca)
	_fca_host.add_child(parts)
	var actions: PackedStringArray = fca.get_action_names()
	if actions.size() > 0:
		fca.play(actions[0], true)


# 走 _unhandled_input（事件未被 GUI 内按钮消费才触发，本弹窗无按钮，等价全屏点击关闭）。
func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_on_click_layer()
		get_viewport().set_input_as_handled()


func _on_click_layer() -> void:
	if _close_handler.is_valid():
		_close_handler.call()
	closed.emit()
	remove_window()


func set_close_handler(handler: Callable) -> void:
	_close_handler = handler
