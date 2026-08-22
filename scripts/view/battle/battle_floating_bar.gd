class_name BattleFloatingBar
extends Node2D

## 浮动血条（View 层）— 照源 hp_bar.lua FloatingBar(:381-514) + FloatingBarGroup(:515-541) + proto(:542-602)。
## 单位头顶小血条（HP 绿/红 + Shield 护盾），actor 用 Group 管理多 bar + 共享 hide_timer。
## proto 抽象：HP = unit.hp/attribs.HP；Shield = sum(buff.shield)；ShieldBoss 同 Shield（guild 资源缺降级）。
## 平滑逻辑同 BattleHpBar（减血立即/回血渐增/mid 滞后）。HpBar（大血条 hero_panel 用）与 FloatingBar（小血条单位用）并存。

const ALPHA_HVGA_DIR: String = "res://assets/ui/alpha/HVGA/"
const CONTENT_SCALE: float = 1.28125   # 源 createSprite 显示=px÷CS（floating 条族无条目）
const EPSILON: float = 0.001
const HIDE_DELAY: float = 1.5
const DEATH_HIDE_CAP: float = 0.5

# 源 floating_bar_settings（:340-380）。fg 按 camp（1 玩家绿 / -1,0 敌红）。ShieldBoss 用 guild 资源（:367-379）。
const SETTINGS: Dictionary = {
	"HP": {"bg": "hp_black_small.png", "mid": "hp_yellow_small.png", "fg": {"1": "hp_green_small.png", "-1": "hp_red_small.png", "0": "hp_red_small.png"}, "inc_speed": 0.8, "auto_hide": true},
	"Mana": {"bg": "hp_black_small.png", "mid": "hp_yellow_small.png", "fg": {"1": "mp_mana.png", "-1": "mp_mana.png", "0": "mp_mana.png"}, "inc_speed": 2.0, "auto_hide": true},
	"Energy": {"bg": "hp_black_small.png", "mid": "hp_yellow_small.png", "fg": {"1": "mp_energy.png", "-1": "mp_energy.png", "0": "mp_energy.png"}, "inc_speed": 2.0, "auto_hide": true},
	"Rage": {"bg": "hp_black_small.png", "mid": "hp_yellow_small.png", "fg": {"1": "mp_rage.png", "-1": "mp_rage.png", "0": "mp_rage.png"}, "inc_speed": 2.0, "auto_hide": true},
	"Shield": {"bg": "hp_shield_bg.png", "mid": "hp_yellow_shield.png", "fg": {"1": "hp_shield.png", "-1": "hp_shield.png", "0": "hp_shield.png"}, "inc_speed": 1.0, "auto_hide": true},
	"ShieldBoss": {"bg": "guild/guildraid_hpbar_boss_shield_bg.png", "mid": "guild/guildraid_hpbar_transition_shield.png", "fg": {"1": "guild/guildraid_hpbar_boss_shield.png", "-1": "guild/guildraid_hpbar_boss_shield.png", "0": "guild/guildraid_hpbar_boss_shield.png"}, "inc_speed": 0.5, "auto_hide": false},
}

var _unit: Variant = null
var _type: String = "HP"
var _inc_speed: float = 0.8
var auto_hide: bool = true
var _background: Sprite2D = null
var _foreground: Sprite2D = null
var _midlayer: Sprite2D = null
var _percent: float = 1.0
var _fore_length: float = 1.0
var _mid_length: float = 1.0
var _value: float = 0.0          # proto GetValue（HP=hp / Shield=sum buff.shield）
var _value_max: float = 1.0      # proto GetValueMax
var _hide_timer: float = 0.0


static func create(unit: Variant, bar_type: String) -> BattleFloatingBar:
	var bar := BattleFloatingBar.new()
	bar._setup(unit, bar_type)
	return bar


static func create_group() -> Group:
	return Group.new()


func _setup(unit: Variant, bar_type: String) -> void:
	_unit = unit
	_type = bar_type
	var cfg: Dictionary = SETTINGS.get(bar_type, SETTINGS["HP"])
	_inc_speed = float(cfg.get("inc_speed", 0.8))
	auto_hide = bool(cfg.get("auto_hide", true))
	_background = _load_sprite(String(cfg.get("bg", "")))
	if _background:
		add_child(_background)
		var camp_key: String = str(int(_unit.camp))
		_midlayer = _load_sprite(String(cfg.get("mid", "")))
		_foreground = _load_sprite(String((cfg.get("fg", {}) as Dictionary).get(camp_key, "")))
		# ÷CS：源 createSprite 显示=px÷CS（2026-08-22 巡检根修，旧原像素直显偏大 1.28×）；
		# bg.scale 级联子层，子局部坐标即点空间。
		_background.scale = Vector2.ONE / CONTENT_SCALE
		# bg centered=true（原点在贴图中心）；fg/mid centered=false 需左对齐 bg：
		# position = -bg显示/2，让 fg 左上角对齐 bg 左上角（否则 fg 从 bg 中心向右画只显示右半）。
		var bg_tex: Texture2D = _background.texture
		var bg_half: Vector2 = (bg_tex.get_size() / CONTENT_SCALE * 0.5) if bg_tex != null else Vector2.ZERO
		if _midlayer:
			_midlayer.centered = false
			_midlayer.position = -bg_half
			_background.add_child(_midlayer)
		if _foreground:
			_foreground.centered = false
			_foreground.position = -bg_half
			_background.add_child(_foreground)
	_refresh_percent()
	_fore_length = _percent
	_mid_length = _percent
	if _foreground:
		_foreground.scale.x = _percent
	if _midlayer:
		_midlayer.scale.x = _percent


func update(dt: float) -> float:
	if _foreground == null:
		return 0.0
	if not bool(_unit.is_alive()):
		_percent = 0.0
	else:
		_refresh_percent()
	if _fore_length < _percent - EPSILON:
		_fore_length = _fore_length + _inc_speed * dt
		if _percent < _fore_length:
			_fore_length = _percent
		_foreground.scale.x = _fore_length
		_hide_timer = HIDE_DELAY
	elif _fore_length > _percent + EPSILON:
		_fore_length = _percent
		_foreground.scale.x = _percent
	if _mid_length < _fore_length - EPSILON:
		_mid_length = _fore_length
		if _midlayer:
			_midlayer.scale.x = _mid_length
	elif _mid_length > _fore_length:
		_mid_length = _mid_length - _inc_speed * dt
		if _midlayer:
			_midlayer.scale.x = _mid_length
		_hide_timer = HIDE_DELAY
	if _percent == 0.0:
		_hide_timer = 0.0
		if auto_hide:
			visible = false
	if not bool(_unit.is_alive()):
		_hide_timer = minf(DEATH_HIDE_CAP, _hide_timer)
	_hide_timer -= dt
	return _hide_timer


func can_be_seen() -> bool:
	return _percent != 0.0


func _refresh_percent() -> void:
	_value = _get_value()
	_value_max = _get_value_max()
	if _value_max == 0.0:
		_percent = 0.0
		return
	_percent = clampf(_value / _value_max, 0.0, 1.0)


func _get_value() -> float:
	if _type == "HP":
		return float(_unit.hp)
	if _type == "Mana" or _type == "Energy" or _type == "Rage":
		return float(_unit.mp)
	var total: float = 0.0   # Shield/ShieldBoss：累加 buff.shield（源 :568-572）
	for buff in _unit.buff_list:
		var sv: Variant = buff.get("shield")
		if sv != null:
			total += float(sv)
	return total


func _get_value_max() -> float:
	if _type == "HP":
		return float(_unit.attribs.get("HP", 1.0))
	if _type == "Mana" or _type == "Energy" or _type == "Rage":
		return float(_unit.attribs.get("MP", 1.0))
	if _type == "ShieldBoss":
		var ms: Variant = _unit.get("max_shield")
		if ms != null:
			return float(ms)
		return float(_unit.attribs.get("HP", 1.0))
	# Shield：value 涨则 max 跟涨，value==0 则 max=0（源 :575-582）
	if _value > _value_max:
		_value_max = _value
	elif _value == 0.0:
		_value_max = 0.0
	return _value_max


func _load_sprite(res: String) -> Sprite2D:
	if res.is_empty():
		return null
	var path: String = ALPHA_HVGA_DIR + res
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	return s


# ── FloatingBarGroup（源 :515-541）：管理多 bar + 共享 hide_timer + CanBeSeen 控显。
class Group:
	extends RefCounted
	var bars: Dictionary = {}   # name → BattleFloatingBar

	static func create() -> Group:
		return Group.new()

	func add_bar(name: String, bar: BattleFloatingBar) -> void:
		bars[name] = bar

	func update(dt: float) -> void:
		var hide_timer: float = 0.0
		for bar in bars.values():
			hide_timer = maxf(hide_timer, float(bar.update(dt)))
		for bar in bars.values():
			if bar.can_be_seen():
				bar.visible = not bar.auto_hide or hide_timer > 0.0
