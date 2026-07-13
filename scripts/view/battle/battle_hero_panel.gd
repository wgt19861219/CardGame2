class_name BattleHeroPanel
extends Control

## 英雄头像面板（HUD）— 照源 hero_panel.lua:8-78 HeroPanelCreate + :93-150 update 翻译（Phase 4）。
## hp_bar/mp_bar（FloatingBar）+ portrait（ReadheroIcon，createIcon isHideFrame）+ frame_btn（点放大招
## castHandler，hero_panel 自加 frame 边框）+ container herobucket + redmask hp_low 红闪。
## update 每 tick 检查 can_cast_manual/current_skill:can_trigger → state cast/trigger/switch +
## FCA skill_ready 降级 stub（.abc 缺）+ 死亡变灰 setColor(100,100,100) + auto_combat 自动放。

const ReadheroIcon: Script = preload("res://scripts/view/battle/readhero_icon.gd")
const BattleFloatingBar: Script = preload("res://scripts/view/battle/battle_floating_bar.gd")
const BattleEffect: Script = preload("res://scripts/view/battle/battle_effect.gd")

const CONTAINER_PATH: String = "res://assets/ui/alpha/HVGA/herobucket.png"
const REDMASK_PATH: String = "res://assets/ui/alpha/HVGA/portraitredmask.png"
const FRAME_PATH_FMT: String = "res://assets/ui/alpha/HVGA/hero_icon_frame_%d.png"

const PORTRAIT_POS: Vector2 = Vector2(0.0, 70.0)        # 源 :36 portrait.icon position
const HP_BAR_POS: Vector2 = Vector2(0.0, 21.0)          # 源 :67 hp_bar.node position
const MP_BAR_POS: Vector2 = Vector2(0.0, 8.0)           # 源 :70 mp_bar.node position
const FRAME_SIZE: Vector2 = Vector2(104.0, 104.0)       # frame_btn 盖 portrait（container 尺寸）
const FRAME_BTN_OFFSET: Vector2 = Vector2(-2.0, -2.0)   # 源 :42 menu ccp(-2,-2)
const REDMASK_FADE_LOW: float = 64.0 / 255.0            # 源 :75 FadeTo(0.8, 64)
const DEAD_COLOR: Color = Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0)  # 源 :125 ccc3(100,100,100)
const AUTO_CAST_INTERVAL: float = 0.5                   # 源 :129 skill_ready_timer > 0.5
const MP_CAST_THRESHOLD: int = 1000                     # 源 :103 mp < 1000 → switch
const TICK_INTERVAL: float = 0.033                      # 源 ed.tick_interval

const STATE_NONE: String = ""
const STATE_CAST: String = "cast"
const STATE_TRIGGER: String = "trigger"
const STATE_SWITCH: String = "switch"

# 源 hero_panel.lua:30-33 FCA 光圈资源名
const FCA_SWITCH: String = "effect/eff_UI_battle_skill_can_switch"
const FCA_READY: String = "effect/eff_UI_battle_skill_will_ready"
const FCA_CAST: String = "effect/eff_UI_battle_skill_cast"
const FCA_TRIGGER: String = "effect/eff_UI_battle_skill_activate"

var unit: Variant = null
var cm: Variant = null
var scene: Variant = null        # 源 ed.scene（auto_combat 访问）
var portrait: ReadheroIcon = null
var hp_bar: BattleFloatingBar = null
var mp_bar: BattleFloatingBar = null
var frame_btn: TextureButton = null
var redmask: Sprite2D = null
var _state: String = STATE_NONE
var _ticks: int = -1
var _skill_ready_timer: float = 0.0
var _skill_ready_effect: Variant = null  # 源 :27 skill_ready FCA 节点


# 源 HeroPanelCreate(unit, color)。
func setup(p_unit: Variant, p_cm: Variant, p_scene: Variant = null) -> void:
	unit = p_unit
	cm = p_cm
	scene = p_scene
	# 源 :17-22 portrait = createIcon({id, stars, isHideFrame=true})
	portrait = ReadheroIcon.new()
	portrait.setup({"id": int(unit.tid), "stars": int(unit.stars), "isHideFrame": true}, cm)
	portrait.icon.position = PORTRAIT_POS   # 源 :36
	add_child(portrait)
	_create_frame_button()   # 源 :38-44 hero_panel 自加 frame（castHandler 按钮）
	_create_container()      # 源 :63-65 herobucket
	# 源 :15-16 hp_bar = HpBarCreate(unit,"HP") / mp_bar = HpBarCreate(unit, MP Type)
	hp_bar = BattleFloatingBar.create(unit, "HP")
	hp_bar.auto_hide = false   # 源 :66
	hp_bar.position = HP_BAR_POS
	add_child(hp_bar)
	var mp_type: String = str(unit.info.get("MP Type", "MP"))
	mp_bar = BattleFloatingBar.create(unit, mp_type)
	mp_bar.auto_hide = false   # 源 :69
	mp_bar.position = MP_BAR_POS
	add_child(mp_bar)
	_create_redmask()   # 源 :72-76
	frame_btn.disabled = true   # 源 :62 setEnabled(false)


# 源 :38-44 frame = CCMenuItemImage(getIconFrameByRank(rank))。frame_btn 接 castHandler（点放大招）。
func _create_frame_button() -> void:
	frame_btn = TextureButton.new()
	var rank: int = int(unit.rank)
	var frame_id: int = ReadheroIcon._frame_id_by_rank(rank)
	frame_btn.texture_normal = _load_tex(FRAME_PATH_FMT % frame_id)
	frame_btn.size = FRAME_SIZE
	frame_btn.position = FRAME_BTN_OFFSET   # 源 menu ccpAdd(anchorPointInPoints, ccp(-2,-2))
	frame_btn.pressed.connect(_on_frame_pressed)
	portrait.icon.add_child(frame_btn)


# 源 :63-65 container = herobucket，portrait.icon addChild(-2) 装饰底。
func _create_container() -> void:
	var container := Sprite2D.new()
	container.texture = _load_tex(CONTAINER_PATH)
	container.z_index = -2
	portrait.icon.add_child(container)


# 源 :72-76 redmask = portraitredmask，frame addChild，setVisible(false) + FadeTo 闪烁 loop。
func _create_redmask() -> void:
	redmask = Sprite2D.new()
	redmask.texture = _load_tex(REDMASK_PATH)
	redmask.visible = false
	frame_btn.add_child(redmask)
	var t := create_tween().set_loops()   # 源 :75 CCRepeatForever FadeTo(0.8,64)+FadeTo(0.2,255)
	t.tween_property(redmask, "modulate:a", REDMASK_FADE_LOW, 0.8)
	t.tween_property(redmask, "modulate:a", 1.0, 0.2)


# 源 :45-58 castHandler：engine.running → manuallyCastSkill(unit) + btn disabled + play_skill_cast_effect。
func _on_frame_pressed() -> void:
	if unit == null or unit.engine == null:
		return
	if not bool(unit.engine.running):
		return
	unit.cast_manual_skill()   # 源 ed.engine:manuallyCastSkill(unit)（本项目 unit 侧等价 :284）
	frame_btn.disabled = true   # 源 :48 setEnabled(false)
	_play_skill_cast_effect()


# 源 update :93-150。名 update（被 scene ui_list 推进调 ui.update(dt)）。
func update(dt: float) -> void:
	if unit == null or unit.engine == null:
		return
	var eng: Variant = unit.engine
	# 源 :94 每逻辑 tick 检查（非 arena/replay 模式）
	if _ticks != int(eng.ticks) and not bool(eng.arena_mode) and not bool(eng.replay_mode):
		_ticks = int(eng.ticks)
		var new_state: String = STATE_NONE
		if bool(unit.can_cast_manual) and bool(eng.running):   # 源 :97-99
			new_state = STATE_CAST
		var cs: Variant = unit.current_skill
		if cs != null and cs.has_method("can_trigger") and bool(cs.can_trigger()):   # 源 :100-102
			new_state = STATE_TRIGGER
		if new_state == STATE_CAST and int(unit.mp) < MP_CAST_THRESHOLD:   # 源 :103-105
			new_state = STATE_SWITCH
		frame_btn.disabled = (new_state == STATE_NONE)   # 源 :106 setEnabled(newState!=nil)
		if _state != new_state:
			_play_skill_ready(new_state)   # 源 :108-119 FCA + teach
			_state = new_state
		redmask.visible = bool(unit.hp_low)   # 源 :122
		if not bool(unit.is_alive()):   # 源 :123-126 死亡变灰
			redmask.visible = false
			_set_portrait_gray()
		if (new_state == STATE_CAST or new_state == STATE_SWITCH) and _is_auto_combat():   # 源 :127-133
			_skill_ready_timer += TICK_INTERVAL
			var ms: Variant = unit.manual_skill
			if _skill_ready_timer > AUTO_CAST_INTERVAL and ms != null and bool(ms.will_cast()):
				_on_frame_pressed()
				_skill_ready_timer = 0.0
	hp_bar.update(dt)   # 源 :148
	mp_bar.update(dt)   # 源 :149


# 源 play_skill_ready :152-166 — FCA 光圈（createFcaNode 挂 hero_panel）。
func _play_skill_ready(state: String) -> void:
	_skill_ready_timer = 0.0
	if state == STATE_NONE:
		return
	if state == STATE_CAST:
		AudioPlayer.play_sfx("battle_fury_full")   # 源 battle.cdOver
	# 源 :153-160 清旧 skill_ready + createFcaNode(res) + addChild
	if _skill_ready_effect != null and is_instance_valid(_skill_ready_effect):
		_skill_ready_effect.queue_free()
	var res: String = FCA_READY if state == STATE_CAST else (FCA_TRIGGER if state == STATE_TRIGGER else FCA_SWITCH)
	var eff: Variant = BattleEffect.create(res)
	if eff != null:
		eff.play()
		_skill_ready_effect = eff.get_node()
		add_child(_skill_ready_effect)


# 源 play_skill_cast_effect :168-176 — FCA cast 特效（createFcaNode(fca_cast)）。
func _play_skill_cast_effect() -> void:
	var eff: Variant = BattleEffect.create(FCA_CAST)
	if eff != null:
		eff.play()
		var n: Node2D = eff.get_node()
		add_child(n)
		# cast 特效不持久，1s 后清（hero_panel 不在 effect_list，手动回收）
		if is_inside_tree():
			get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(n): n.queue_free())


# 源 :125 portrait.ori_icon setColor(100,100,100) — 死亡变灰。
func _set_portrait_gray() -> void:
	if portrait != null and portrait.ori_icon != null:
		portrait.ori_icon.modulate = DEAD_COLOR


# 源 :127 ed.scene.auto_combat — 单机化 scene.auto_combat（默认 false）。
func _is_auto_combat() -> bool:
	if scene != null and scene.get("auto_combat") != null:
		return bool(scene.auto_combat)
	return false


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
