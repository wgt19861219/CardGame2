class_name BattlePopup
extends Node2D

## 战斗飘字（View 层）— 照源 popup.lua(104) PopupCreate 翻译（Phase 4 子件，2026-07-02）。
## 源用 ed.createNumbers 数字精灵图 + CCSprite + CCMoveBy/FadeOut/ScaleBy 动作；
## 本项目 battletext/numbers 图片缺失 → Label + 主题字体适配（Cocos→Godot 引擎适配）。
## 四 style：damage（上飘+放大+淡出，crit 加成）/heal（上飘+淡出 绿）/gold（fade in+上飘 黄）/text（上飘+放大+淡出）。
## 挂 ui_layer（battle_scene 调）。依赖 BattleViewCoords.to_view_position。record[actor] 排队去重（同帧飘字延后 2 tick 入场，源 :81-100）。

const BattleViewCoords = preload("res://scripts/view/battle/battle_view_coords.gd")

const LIFE: float = 0.8                  # 源 :17 life
const DAMAGE_OFFSET_H: float = 75.0      # 源 :30 toViewPosition height 偏移
const HEAL_OFFSET_H: float = 100.0       # 源 :43
const GOLD_OFFSET_H: float = 30.0        # 源 :49
const TEXT_OFFSET_H_BASE: float = 100.0  # 源 :65 actor.height + 100
const DAMAGE_DIST_CRIT: float = 70.0     # 源 :34 crit 上飘
const DAMAGE_DIST: float = 45.0          # 源 :34 普通
const HEAL_DIST: float = 100.0           # 源 :46
const GOLD_DIST: float = 80.0            # 源 :54
const TEXT_DIST: float = 50.0            # 源 :68
const GOLD_FADE_DURATION: float = 0.625  # 源 :52
const DAMAGE_SCALE_BASE: float = 0.5     # 源 :31 setScale(0.5*(crit?1.2:0.75))
const CRIT_SCALE_MULT: float = 1.2
const NORMAL_SCALE_MULT: float = 0.75
const SCALE_BY: float = 2.0              # 源 :36/70 CCScaleBy(duration, 2)

var _label: Label = null
var _text: String = ""
var _style: String = "damage"
var _crit: bool = false
var _color: String = "white"
var _unit: Variant = null


# 源 PopupCreate(str, color, actor, crit, style)（popup.lua:9-102）。color 是数字图片色键（源
# battletext_<str>_<color>.png 图集），本项目 battletext 图缺 → Label + Color 适配（色键→RGB 映射）。
# unit = BattleUnit（Logic，position 是 Logic 坐标，_play 内 toViewPosition 转）；unit null 返 null。
# 源 record[actor]=tick（popup.lua:81-100 同帧飘字延后 2 tick 入场，避免同帧叠加）
static var _record: Dictionary = {}

static func create(text: String, unit: Variant, crit: bool, style: String, color: String, ui_layer: Node) -> Variant:
	if unit == null:
		return null
	var popup := BattlePopup.new()
	popup._setup(text, unit, crit, style, color)
	# 源 :81-89 同 actor 同 tick 飘字延后 2 tick 入场（delay = old+2-tick）
	var eng: Variant = unit.get("engine")
	var tick: int = int(eng.ticks) if eng != null else 0
	var old_tick: int = int(_record.get(unit, -1))
	var delay_ticks: int = 0
	if tick <= old_tick:
		delay_ticks = old_tick + 2 - tick
		tick += delay_ticks
	_record[unit] = tick
	if delay_ticks == 0:
		ui_layer.add_child(popup)   # 触发 _ready → _play（tween 自动跑）
	else:
		# 源 :93-99 延后 add_child；目标 SceneTreeTimer 延后（popup 未入树，timer 触发 add）
		var delay_sec: float = delay_ticks * BattleEngine.TICK_INTERVAL
		if ui_layer.is_inside_tree():
			ui_layer.get_tree().create_timer(delay_sec).timeout.connect(ui_layer.add_child.bind(popup))
	return popup


func _setup(text: String, unit: Variant, crit: bool, style: String, color: String) -> void:
	_text = text
	_unit = unit
	_crit = crit
	_style = style if style != "" else "damage"
	_color = color if color != "" else "white"
	_label = Label.new()
	_label.text = _text
	_label.modulate = _resolve_color()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


# 源 color 色键（数字图片后缀）→ Label Color。键集：blue/red/yellow/green/orange/golden/white
#（照源各调用点 camp/field 语义：mp=yellow、player 受伤=red、enemy 受伤=orange、heal=green、
# 金币=golden、文本类按 camp player→blue/enemy→red）。源 color 决定颜色，style 决定动作，互独立。
func _resolve_color() -> Color:
	match _color:
		"blue":
			return Color(0.35, 0.65, 1.0)
		"red":
			return Color(1.0, 0.35, 0.35)
		"yellow":
			return Color(1.0, 0.9, 0.2)
		"green":
			return Color(0.3, 0.95, 0.35)
		"orange":
			return Color(1.0, 0.6, 0.15)
		"golden":
			return Color(1.0, 0.85, 0.25)
		_:
			return Color.WHITE


func _ready() -> void:
	_play()


# 源 damage/heal/gold/text 四段动作（popup.lua:28-73）→ Godot Tween（parallel + chain）。
func _play() -> void:
	var pos: Vector2 = Vector2(float(_unit.position.x), float(_unit.position.y))
	match _style:
		"damage":
			_play_damage(pos)
		"heal":
			_play_heal(pos)
		"gold":
			_play_gold(pos)
		"text":
			_play_text(pos)
		_:
			_play_damage(pos)


# 源 :28-41 damage：setScale(0.5*(crit?1.2:0.75)) + Spawn(MoveBy 上飘, ScaleBy×2) + Spawn(MoveBy, FadeOut)
func _play_damage(pos: Vector2) -> void:
	position = BattleViewCoords.to_view_position(pos.x, pos.y, DAMAGE_OFFSET_H)
	var base_y: float = position.y
	var mult: float = CRIT_SCALE_MULT if _crit else NORMAL_SCALE_MULT
	var base_s: float = DAMAGE_SCALE_BASE * mult
	scale = Vector2(base_s, base_s)
	var dist: float = DAMAGE_DIST_CRIT if _crit else DAMAGE_DIST
	var dur1: float = LIFE * 0.2   # 源 popup.lua:32 duration = life*0.2
	var dur2: float = LIFE * 0.8   # 源 popup.lua:37 duration = life*0.8
	var t := create_tween()
	# 段1（dur1）：MoveBy 上飘 dist + EaseExponentialOut + ScaleBy×2 并行（源 :34-36）
	t.set_parallel(true)
	t.tween_property(self, "position:y", base_y - dist, dur1).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(base_s * SCALE_BY, base_s * SCALE_BY), dur1)
	# 段2（dur2）：续上飘 60 + EaseIn(rate3) + FadeOut 并行（源 :38-40）
	t.chain().set_parallel(true)
	t.tween_property(self, "position:y", base_y - dist - 60.0, dur2).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, dur2)
	t.chain().tween_callback(queue_free)


# 源 :42-47 heal：setScale(0.75) + Spawn(MoveBy 100, FadeOut)
func _play_heal(pos: Vector2) -> void:
	position = BattleViewCoords.to_view_position(pos.x, pos.y, HEAL_OFFSET_H)
	var base_y: float = position.y
	scale = Vector2(NORMAL_SCALE_MULT, NORMAL_SCALE_MULT)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position:y", base_y - HEAL_DIST, LIFE)
	t.tween_property(self, "modulate:a", 0.0, LIFE)
	t.chain().tween_callback(queue_free)


# 源 :48-63 gold：setOpacity(0) + Delay 0.3 + Spawn(MoveBy 80, FadeTo 255) + Delay 0.15 + FadeOut 0.1
func _play_gold(pos: Vector2) -> void:
	position = BattleViewCoords.to_view_position(pos.x, pos.y, GOLD_OFFSET_H)
	var base_y: float = position.y
	scale = Vector2(NORMAL_SCALE_MULT, NORMAL_SCALE_MULT)
	modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(0.3)
	t.set_parallel(true)
	t.tween_property(self, "position:y", base_y - GOLD_DIST, GOLD_FADE_DURATION).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, GOLD_FADE_DURATION)
	t.chain()
	t.tween_interval(0.15)
	t.tween_property(self, "modulate:a", 0.0, 0.1)
	t.tween_callback(queue_free)


# 源 :64-73 text：setScale(0.5) + Spawn(MoveBy 50, ScaleBy×2) + Delay + FadeOut
func _play_text(pos: Vector2) -> void:
	var height_val: Variant = _unit.get("height")
	var h: float = TEXT_OFFSET_H_BASE
	if height_val != null:
		h = float(height_val) + TEXT_OFFSET_H_BASE
	position = BattleViewCoords.to_view_position(pos.x, pos.y, h)
	var base_y: float = position.y
	scale = Vector2(DAMAGE_SCALE_BASE, DAMAGE_SCALE_BASE)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position:y", base_y - TEXT_DIST, LIFE * 0.2).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(DAMAGE_SCALE_BASE * SCALE_BY, DAMAGE_SCALE_BASE * SCALE_BY), LIFE * 0.2)
	t.chain()
	t.tween_interval(LIFE * 0.25)
	t.tween_property(self, "modulate:a", 0.0, LIFE * 0.4)
	t.tween_callback(queue_free)
