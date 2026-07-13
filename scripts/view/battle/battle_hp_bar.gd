class_name BattleHpBar
extends Node2D

## 单条血/蓝条（View 层）— 照源 hp_bar.lua HpBar(:11-136) 翻译（Phase 4 子件，2026-07-02）。
## 三层 Sprite2D：background(灰底) + midlayer(黄滞后层) + foreground(绿/红前 HP / mana MP) + mask(低血红闪)。
## 平滑：fore_length 渐追 percent（减血立即、回血渐增）+ mid_length 滞后追 fore + auto_hide 计时。
## type：HP/Mana/Energy/Rage（源 MP Type 字段）。被 hero_panel + FloatingBar（血条组）依赖。
## BigHpBar（Boss 多血段 :137-384）+ FloatingBar 组（:385-602）后续会话。

const ALPHA_HVGA_DIR: String = "res://assets/ui/alpha/HVGA/"
const OFFSET: Vector2 = Vector2(6.0, 1.0)    # 源 :70/73 foreground/midlayer ccp(6,1)
const EPSILON: float = 0.001                 # 源 :6 epsilon
const HP_INC_SPEED: float = 0.5              # 源 :20 inc_speed（HP）
const MP_INC_SPEED: float = 2.0              # 源 :36/40 Mana/Energy/Rage inc_speed
const HIDE_TIMER_INIT: float = 1.5           # 源 :111/124 hide_timer=1.5
const DEATH_HIDE_CAP: float = 0.5            # 源 :133 min(0.5, hide_timer)
const STAR_OFFSET_X: float = 3.0             # 源 hp_bar.lua:128 star x = 3 + 84 * percent
const STAR_RANGE: float = 84.0               # 源 :128 star 滑动范围
const STAR_Y: float = 6.0                    # 源 :128 star y = 6

var _unit: Variant = null
var _type: String = "HP"
var _inc_speed: float = HP_INC_SPEED
var _background: Sprite2D = null
var _foreground: Sprite2D = null
var _midlayer: Sprite2D = null
var _mask: Sprite2D = null
var _percent: float = 1.0
var _fore_length: float = 1.0
var _mid_length: float = 1.0
var auto_hide: bool = true                   # 源 :21 auto_hide（hero_panel 设 false 常驻）
var _hide_timer: float = 0.0
var _star: Node2D = null   # 源 :45-48 Rage 条技能消耗星标（FCA eff_UI_battle_skill_cost 占位）


# 源 HpBar.create(unit, type, color)（hp_bar.lua:11-75）
static func create(unit: Variant, bar_type: String, color: String = "") -> BattleHpBar:
	var bar := BattleHpBar.new()
	bar._setup(unit, bar_type, color)
	return bar


func _setup(unit: Variant, bar_type: String, color: String) -> void:
	_unit = unit
	_type = bar_type
	_inc_speed = HP_INC_SPEED if bar_type == "HP" else MP_INC_SPEED
	# background（灰底，源 :16）
	_background = _load_sprite("hp_gray.png")
	if _background:
		add_child(_background)
		# midlayer/foreground/mask 是 background 子（源 :61/68/71）
		_midlayer = _load_sprite("hp_yellow.png")
		if _midlayer:
			_midlayer.centered = false
			_midlayer.position = OFFSET
			_background.add_child(_midlayer)
		_foreground = _load_sprite(_resolve_fg_res(bar_type, unit, color))
		if _foreground:
			_foreground.centered = false
			_foreground.position = OFFSET
			_background.add_child(_foreground)
		_mask = _load_sprite("hp_red_mask.png" if bar_type == "HP" else "mp_mana_mask.png")
		if _mask:
			_mask.centered = false
			_mask.visible = false
			_background.add_child(_mask)
	# 初始 percent + scale（源 :51-58）
	_percent = _initial_percent(unit, bar_type)
	_fore_length = _percent
	_mid_length = _percent
	if _foreground:
		_foreground.scale.x = _percent
	if _midlayer:
		_midlayer.scale.x = _percent
	# 源 hp_bar.lua:45-48 Rage 条装配 star（技能消耗星标，随 MP 滑动）
	if bar_type == "Rage":
		_star = _create_star()
		if _star:
			_background.add_child(_star)
			_star.visible = false   # 源 :47 初始隐藏（满 MP 可放大招时外部 setVisible）


func _ready() -> void:
	_play_mask_blink()


# 源 :29-44 foreground 资源（HP green/red by camp / Mana/Energy/Rage mp_*）
func _resolve_fg_res(bar_type: String, unit: Variant, color: String) -> String:
	match bar_type:
		"HP":
			var c: String = color if color != "" else ("green" if int(unit.camp) > 0 else "red")
			return "hp_" + c + ".png"
		"Mana":
			return "mp_mana.png"
		"Energy":
			return "mp_energy.png"
		"Rage":
			return "mp_rage.png"
		_:
			return "hp_green.png"


func _initial_percent(unit: Variant, bar_type: String) -> float:
	if bar_type == "HP":
		return float(unit.hp) / maxf(float(unit.attribs.get("HP", 1.0)), 1.0)
	return float(unit.mp) / maxf(float(unit.attribs.get("MP", 1.0)), 1.0)


# 源 :65-67 mask CCRepeatForever(FadeTo 0.5→0 / 0.5→255)，低血闪烁。
func _play_mask_blink() -> void:
	if _mask == null:
		return
	var t := create_tween().set_loops()
	t.tween_property(_mask, "modulate:a", 0.0, 0.5)
	t.tween_property(_mask, "modulate:a", 1.0, 0.5)


# 源 HpBar:update（hp_bar.lua:77-136）
func update(dt: float) -> void:
	var alive: bool = bool(_unit.is_alive())
	if not alive:
		_percent = 0.0
		if _mask:
			_mask.visible = false
	elif _type == "HP":
		_percent = float(_unit.hp) / maxf(float(_unit.attribs.get("HP", 1.0)), 1.0)
		if _mask:
			_mask.visible = bool(_unit.hp_low)
	else:
		_percent = float(_unit.mp) / maxf(float(_unit.attribs.get("MP", 1.0)), 1.0)
	# 源 :104-116 fore_length 平滑追 percent（回血渐增 inc_speed*dt，减血立即）
	if _fore_length < _percent - EPSILON:
		_fore_length = _fore_length + _inc_speed * dt
		if _percent < _fore_length:
			_fore_length = _percent
		if _foreground:
			_foreground.scale.x = _fore_length
		_hide_timer = HIDE_TIMER_INIT
	elif _fore_length > _percent + EPSILON:
		_fore_length = _percent
		if _foreground:
			_foreground.scale.x = _percent
	# 源 :117-125 mid_length 滞后追 fore（减血时黄层滞后露底）
	if _mid_length < _fore_length - EPSILON:
		_mid_length = _fore_length
		if _midlayer:
			_midlayer.scale.x = _mid_length
	elif _mid_length > _fore_length:
		_mid_length = _mid_length - _inc_speed * dt
		if _midlayer:
			_midlayer.scale.x = _mid_length
		_hide_timer = HIDE_TIMER_INIT
	# 源 :131-135 auto_hide
	if not alive:
		_hide_timer = minf(DEATH_HIDE_CAP, _hide_timer)
	visible = not auto_hide or _hide_timer > 0.0
	_hide_timer -= dt
	# 源 :126-129 star 随 MP 滑动（仅 Rage 条，x = 3 + 84 * foreground.scaleX）
	if _star != null and _star.visible:
		_star.position.x = STAR_OFFSET_X + STAR_RANGE * _fore_length


func _load_sprite(res: String) -> Sprite2D:
	var path: String = ALPHA_HVGA_DIR + res
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	return s


# 源 hp_bar.lua:45 createFcaNode("eff_UI_battle_skill_cost")。
# FCA 资源不在源仓库，用 Sprite2D 尝试加载同名 png，缺失用 Node2D+ColorRect 占位。
func _create_star() -> Node2D:
	var fca_png: String = ALPHA_HVGA_DIR + "eff_UI_battle_skill_cost.png"
	if ResourceLoader.exists(fca_png):
		var s := Sprite2D.new()
		s.texture = load(fca_png) as Texture2D
		s.position = Vector2(STAR_OFFSET_X, STAR_Y)
		return s
	# 占位：Node2D 包装 ColorRect（FCA 资源待后续）
	var wrapper := Node2D.new()
	wrapper.position = Vector2(STAR_OFFSET_X, STAR_Y)
	var placeholder := ColorRect.new()
	placeholder.color = Color.YELLOW
	placeholder.size = Vector2(8, 8)
	wrapper.add_child(placeholder)
	return wrapper
