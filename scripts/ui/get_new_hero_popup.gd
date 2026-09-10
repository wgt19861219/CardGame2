class_name GetNewHeroPopup
extends PopWindow

## 新英雄获得展示弹窗（View 层）— 照源 announce.lua getNewHero（:225-365）。
## 召唤动画链第二环（2026-09-09 补全）：源 heropackage doSummonReply → announce
## popHeroCard（卡展示=HeroAwakePanel 复用）→ 点击 → getNewHero 大立绘展示 → 确定。
## 静态树 get_new_hero_content.tscn（light/name_bg/名字/立绘宿主/ok 按钮）；title
## get_new_hero_title.png 源 res 缺图照源省略（cocos 加载失败不渲染同效）。
## 单机化：announce 队列中介省略直接实例化（HeroAwakePanel 同款范式）。

signal closed

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/get_new_hero_content.tscn")
const CONFIRM_LSTR: String = "CHATCONFIG.CONFIRM"
const CONFIRM_FALLBACK: String = "确定"
# 源 :347-348 CCRotateBy(5, 370) × CCRepeat×3
const LIGHT_ROTATE_SEC: float = 5.0
const LIGHT_ROTATE_DEG: float = 370.0
const LIGHT_REPEAT: int = 3
# 降级静态立绘（hero_detail 详情页同款口径）：Portrait 等比上限。
const PORTRAIT_MAX: Vector2 = Vector2(240.0, 320.0)
const PORTRAIT_PREFIX: String = "UI/"
const PORTRAIT_REPLACE: String = "res://assets/ui/"
# FCA 立绘缩放（hero_detail_fills.HERO_FCA_SCALE 同值；cha_scale 自含勿另乘）。
const HERO_FCA_SCALE: float = 1.5

const AtlasSprite = preload("res://scripts/ui/atlas_sprite.gd")
const FcaAnimation = preload("res://scripts/ui/fca_animation.gd")

var _tid: int = 0
var _cm: Variant = null
var _content: Control = null


func setup_popup(p_tid: int, p_cm: Variant) -> void:
	shade_close_on_click = false   # 源 setClickDestroyEnabled(false)：仅 ok 按钮关闭
	_tid = p_tid
	_cm = p_cm
	setup()
	_build_content()


func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	# 名字（源 :276-292 Display Name ui_herotitle_stroke 30 → variation GetNewHeroNameLabel）
	(_content.get_node("%NameLbl") as Label).text = _hero_display_name()
	# ok 按钮文字（源 :297-340 Scale9 + CONFIRM；动态挂 fast button 惯例）
	var ok: TextureButton = _content.get_node("%OkBtn") as TextureButton
	ok.pressed.connect(_on_ok)
	var lbl := Label.new()
	lbl.text = _lstr(CONFIRM_LSTR, CONFIRM_FALLBACK)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(100.0, 50.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ok.add_child(lbl)
	# 立绘（源 :349-355 getActor(hid, "Move")；FCA 缺降级 Portrait 静态）
	_fill_actor(_content.get_node("%ActorHost") as Node2D)


func show_window(parent: Node) -> void:
	super.show_window(parent)
	_play_light_anim()


# light 旋转（源 :347-348）：370°/5s × 3 圈。
func _play_light_anim() -> void:
	if not is_inside_tree():
		return
	var light: Sprite2D = _content.get_node_or_null("LightSprite") as Sprite2D
	if light == null:
		return
	var tw: Tween = create_tween()
	var total_deg: float = LIGHT_ROTATE_DEG * float(LIGHT_REPEAT)
	tw.tween_property(light, "rotation", deg_to_rad(total_deg),
		LIGHT_ROTATE_SEC * float(LIGHT_REPEAT))


func _hero_display_name() -> String:
	if _cm == null:
		return str(_tid)
	var key: String = String(_cm.get_raw_table(&"Unit").get(str(_tid), {}).get(&"Display Name", str(_tid)))
	return String(_cm.get_lstr(key))


func _lstr(key: String, fallback: String) -> String:
	if _cm != null and _cm.has_method("get_lstr"):
		var s: String = String(_cm.get_lstr(key))
		return s if s != key else fallback
	return fallback


# 立绘：Puppet 表 FCA play("Move")（源 :349-355）；缺资源降级 Unit.Portrait 静态
#（hero_detail 详情页同款降级口径，受控偏离见验收记录）。
func _fill_actor(host: Node2D) -> void:
	if host == null or _cm == null:
		return
	if _try_add_actor_fca(host):
		return
	_add_portrait_fallback(host)


func _try_add_actor_fca(host: Node2D) -> bool:
	var puppet_name: String = String(_cm.lookup("Unit", "Puppet", _tid))
	if puppet_name.is_empty():
		return false
	var resource: String = String(_cm.get_raw_table(&"Puppet").get(puppet_name, {}).get(&"Resource", ""))
	if resource.is_empty():
		return false
	var atlas := AtlasSprite.new()
	if not atlas.load_atlas("res://assets/anim_frames/" + resource + "/sheet.plist"):
		return false
	var fca := FcaAnimation.new()
	if not fca.load_from_ani(resource, atlas):
		fca.queue_free()
		return false
	var parts := Node2D.new()
	parts.scale = Vector2(HERO_FCA_SCALE, HERO_FCA_SCALE)
	parts.add_child(fca)
	host.add_child(parts)
	var actions: PackedStringArray = fca.get_action_names()
	if actions.has("Move"):
		fca.play("Move")
	elif actions.size() > 0:
		fca.play(actions[0])
	return true


func _add_portrait_fallback(host: Node2D) -> void:
	var portrait_res: String = String(_cm.lookup("Unit", "Portrait", _tid))
	if portrait_res.is_empty():
		return
	var path: String = portrait_res.replace(PORTRAIT_PREFIX, PORTRAIT_REPLACE)
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	var sp := TextureRect.new()
	sp.texture = tex
	sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var scale: float = min(PORTRAIT_MAX.x / tex.get_size().x, PORTRAIT_MAX.y / tex.get_size().y)
	sp.size = tex.get_size() * min(scale, 1.0)
	sp.position = -sp.size * 0.5
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(sp)


func _on_ok() -> void:
	closed.emit()
	remove_window()
