class_name HeroAwakePanel
extends PopWindow

## 觉醒展示弹窗（View 层）— 照源 ui/popwindow/popheroawake.lua 两件套改造（批 1 Task 4，
## 2026-08-15）。静态树（bg 居中底板/light 光圈/FCA 双宿主/卡宿主）全在
## hero_awake_content.tscn；本文件只做 bg 三色 fill、卡实例挂载、动画时序、点击关闭。
## 动画序列（源 showCardui :9-47）：
##   1. bg CCFadeIn(0.4)（:147）
##   2. light CCFadeIn(0.4) → CCRotateBy(5,360)×CCRepeat×3（:11-18，360° 旋转 3 圈共 15s）
##   3. cardui CCDelayTime(0.4) → CCFadeIn(0.2) + add bubble FCA（:21-36）
##   4. add card_<color> FCA at z=10 scale=1.5（:38-44）
##   5. 点击任意处关闭（:45-46 + doClickLayer :49-72；觉醒恒单卡，源多卡残留分支不迁移）
## FCA 资源 eff_UI_tavern_bubble / eff_UI_tavern_card_<color> 在 assets/anim_frames/effect/。

signal awake_shown   # 展示动画启动（点击关闭前的视觉完成节点）
signal closed        # 用户点击关闭

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_awake_content.tscn")
const CARD_SCENE: PackedScene = preload("res://scenes/ui/hero_detail_card_tab.tscn")

const LIGHT_ROTATE_SEC: float = 5.0
const LIGHT_REPEAT: int = 3
const FADE_IN_SEC: float = 0.4
const CARD_FADE_SEC: float = 0.2
const CARD_FADE_DELAY: float = 0.4
const CARD_HOST_SHIFT_X: float = 200.0   # card_tab 原居左，设 offset 200 让 CardFrame center 落屏幕 (480,320)

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
var _bubble_host: Node2D = null
var _card_fca_host: Node2D = null
var _close_handler: Callable = Callable()


# 本项目单机化直接调 setup_awake + show_window 后开动画（无 announce 中介）。
func setup_awake(hero: HeroInstance, cm: Variant) -> void:
	transparent_shade = true   # 源 noShade=true（shade 全透不吞点击，基类 T4 样板字段）
	_hero = hero
	_cm = cm
	_color = _resolve_color(cm, hero)
	setup()
	_build_content()


func _resolve_color(cm: Variant, hero: HeroInstance) -> String:
	if cm == null or hero == null:
		return "red"
	var c: String = String(cm.get_raw_table(&"Unit").get(str(hero.tid), {}).get(&"Bg Color", "red"))
	return c if BG_RES_MAP.has(c) else "red"


# 绑定 .tscn 静态节点 + fill bg 三色贴图（源 :146 res=bg_res[color] 运行时选图；
# _resolve_color 已兜底 red，三图齐备无降级路径——原迁移期 fallback 循环删除，见任务报告）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_bg = _content.get_node("%BgRect") as TextureRect
	_light = _content.get_node("%LightSprite") as Sprite2D
	_card_host = _content.get_node("%CardHost") as Control
	_bubble_host = _content.get_node("%FcaBubbleHost") as Node2D
	_card_fca_host = _content.get_node("%FcaCardHost") as Node2D
	_bg.texture = load(String(BG_RES_MAP[_color])) as Texture2D
	_build_hero_card()


# 卡牌视觉（源 :136 ed.readhero.getHeroCard(hid, {disableswap=true, showAwake=true}).container）。
# 复用 hero_detail_card_tab.tscn（CardFrame + Art + Name + stars + type icon，HeroDetailTabs.fill_card_view 填数据）。
# card_tab 原为 hero_detail 设计（CardFrame center 205,320），觉醒弹窗居中需 offset 200 → center (480,320)。
func _build_hero_card() -> void:
	if _hero == null or _cm == null:
		return
	var card: Control = CARD_SCENE.instantiate() as Control
	card.visible = true   # .tscn 默认 visible=false，强制显示
	card.offset_left = CARD_HOST_SHIFT_X
	card.offset_right = CARD_HOST_SHIFT_X
	card.modulate.a = 0.0   # 源 :142 config opacity=0（外部场景实例，初始态由 fill 设）
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
	_add_fca(BUBBLE_RES, _bubble_host)


func _add_card_fca() -> void:
	_add_fca(CARD_FCA_PREFIX + _color, _card_fca_host)


# 加 FCA 光效（.abc zip 在 effect/ 子目录，atlas.load_atlas_from_ani 路径含 effect/ 前缀）。
# 挂静态宿主（位置/scale 已进 tscn）；缺资源静默跳过（照源 xpcall 容错 + 项目 .abc 加载失败降级范式）。
func _add_fca(resource: String, host: Node2D) -> void:
	if host == null:
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
	host.add_child(fca)
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
