class_name BattleHeroPanel
extends Control

## 英雄头像面板（HUD）— 照源 hero_panel.lua:8-78 HeroPanelCreate + :93-150 update 翻译（Phase 4）。
## hp_bar/mp_bar（FloatingBar）+ portrait（ReadheroIcon，createIcon isHideFrame）+ frame_btn（点放大招
## castHandler，hero_panel 自加 frame 边框）+ container herobucket + redmask hp_low 红闪。
## update 每 tick 检查 can_cast_manual/current_skill:can_trigger → state cast/trigger/switch +
## FCA skill_ready 降级 stub（.abc 缺）+ 死亡变灰 setColor(100,100,100) + auto_combat 自动放。
##
## 重构（2026-07-18，hero_detail 范式）：静态节点（FrameBtn/Redmask/Container + 3 Host 位置）从
## battle_hero_panel_content.tscn instantiate（位置/size 可视化）；动态 portrait/hp_bar/mp_bar 挂 %Host。

const CONTENT_SCENE: PackedScene = preload("res://scenes/battle/battle_hero_panel_content.tscn")
const ReadheroIcon: Script = preload("res://scripts/ui/readhero_icon.gd")
const BattleFloatingBar: Script = preload("res://scripts/view/battle/battle_floating_bar.gd")
const BattleEffect: Script = preload("res://scripts/view/battle/battle_effect.gd")

# frame_btn texture_normal 按 rank 动态 fill（FRAME_PATH_FMT % frame_id）。位置/size 在 .tscn。
const FRAME_PATH_FMT: String = "res://assets/ui/alpha/HVGA/hero_icon_frame_%d.png"

# redmask FadeTo 闪烁 loop（源 :75-76）。位置/texture/初始 visible 在 .tscn。
const REDMASK_FADE_LOW: float = 64.0 / 255.0
const DEAD_COLOR: Color = Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0)
const AUTO_CAST_INTERVAL: float = 0.5
const MP_CAST_THRESHOLD: int = 1000
const TICK_INTERVAL: float = 0.033

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
var scene: Variant = null
var portrait: ReadheroIcon = null
var hp_bar: BattleHpBar = null
var mp_bar: BattleHpBar = null
var frame_btn: TextureButton = null
var redmask: Sprite2D = null
var _state: String = STATE_NONE
var _ticks: int = -1
var _skill_ready_timer: float = 0.0
var _skill_ready_effect: Variant = null
var _skill_ready_eff: Variant = null   # _skill_ready_effect 的 BattleEffect 包装（切速 set_speed 用）
var _skill_cast_eff: Variant = null    # cast 光圈包装引用（防 RefCounted 析构秒删，见 _play_skill_cast_effect）


# 动态 portrait/hp_bar/mp_bar 挂 %Host（位置在 .tscn，子组件局部坐标系不变）。
func setup(p_unit: Variant, p_cm: Variant, p_scene: Variant = null) -> void:
	unit = p_unit
	cm = p_cm
	scene = p_scene
	var content := CONTENT_SCENE.instantiate()
	add_child(content)   # Control 组件，content 挂 panel 自身（坑 7）
	frame_btn = content.get_node("%FrameBtn") as TextureButton
	redmask = content.get_node("%Redmask") as Sprite2D
	var portrait_host: Control = content.get_node("%PortraitHost") as Control
	var hp_bar_host: Control = content.get_node("%HpBarHost") as Control
	var mp_bar_host: Control = content.get_node("%MpBarHost") as Control
	var rank: int = int(unit.rank)
	var frame_id: int = ReadheroIcon._frame_id_by_rank(rank)
	frame_btn.texture_normal = _load_tex(FRAME_PATH_FMT % frame_id)
	frame_btn.pressed.connect(_on_frame_pressed)
	portrait = ReadheroIcon.new()
	portrait.setup({"id": int(unit.tid), "stars": int(unit.stars), "isHideFrame": true}, cm)
	portrait_host.add_child(portrait)
	portrait_host.move_child(portrait, 0)   # 让 portrait 在 FrameBtn 之下（视觉等价源 add 顺序）
	# 源 hero_panel.lua:15-16 两条均 HpBar 大条（bg 119px）——旧版误用 FloatingBar 小条
	# （bg 89px < mp_mana.png 104px 满格超框"变长"，2026-08-18 修）。
	hp_bar = BattleHpBar.create(unit, "HP")
	hp_bar.auto_hide = false
	hp_bar_host.add_child(hp_bar)
	# 受控偏离（用户观感验收 2026-08-19）：bg 119 比头像 110 宽出头 → 整条 ×0.92 缩至齐宽。
	hp_bar.scale = Vector2(0.92, 0.92)
	hp_bar.position = Vector2(59.5, 8.5)
	var mp_type: String = str(unit.info.get("MP Type", "Mana"))
	mp_bar = BattleHpBar.create(unit, mp_type)
	mp_bar.auto_hide = false
	mp_bar_host.add_child(mp_bar)
	mp_bar.scale = Vector2(0.92, 0.92)   # 同 HP 齐宽
	mp_bar.position = Vector2(59.5, 8.5)
	_start_redmask_flicker()
	frame_btn.disabled = true


# hp_bar/mp_bar 的 update 由 ui_list 链路驱动（scene._advance_ui_list 加速 dt → update 末尾），
# 不写 _process：Godot 原始 delta 不含战斗加速倍率，双驱动会稀释倍率
# （2x 下每帧推进 INC*(delta+2delta)=3 份 vs 1x 的 2 份，观感仅 1.5x，2026-08-19 修）。
func _start_redmask_flicker() -> void:
	if redmask == null:
		return
	var t := create_tween().set_loops()
	t.tween_property(redmask, "modulate:a", REDMASK_FADE_LOW, 0.8)
	t.tween_property(redmask, "modulate:a", 1.0, 0.2)


func _on_frame_pressed() -> void:
	if unit == null or unit.engine == null:
		return
	if not bool(unit.engine.running):
		return
	unit.cast_manual_skill()
	frame_btn.disabled = true
	_play_skill_cast_effect()


func update(dt: float) -> void:
	if unit == null or unit.engine == null:
		return
	var eng: Variant = unit.engine
	if _ticks != int(eng.ticks) and not bool(eng.arena_mode) and not bool(eng.replay_mode):
		_ticks = int(eng.ticks)
		var new_state: String = STATE_NONE
		if bool(unit.can_cast_manual) and bool(eng.running):
			new_state = STATE_CAST
		var cs: Variant = unit.current_skill
		if cs != null and cs.has_method("can_trigger") and bool(cs.can_trigger()):
			new_state = STATE_TRIGGER
		if new_state == STATE_CAST and int(unit.mp) < MP_CAST_THRESHOLD:
			new_state = STATE_SWITCH
		frame_btn.disabled = (new_state == STATE_NONE)
		if _state != new_state:
			_play_skill_ready(new_state)
			_state = new_state
		redmask.visible = bool(unit.hp_low)
		if not bool(unit.is_alive()):
			redmask.visible = false
			_set_portrait_gray()
		if (new_state == STATE_CAST or new_state == STATE_SWITCH) and _is_auto_combat():
			_skill_ready_timer += TICK_INTERVAL
			var ms: Variant = unit.manual_skill
			if _skill_ready_timer > AUTO_CAST_INTERVAL and ms != null and bool(ms.will_cast()):
				_on_frame_pressed()
				_skill_ready_timer = 0.0
	hp_bar.update(dt)
	mp_bar.update(dt)


# 光圈挂载点：frame_btn（源 hero_panel.lua:157/172 self.btn:addChild）。定位按各 FCA 帧内容
# 中心实测校准（headless 逐帧观察 2026-08-19）：内容中心相对节点原点系统性偏上——ready/
# switch/trigger 光圈 Loop 期 (5.4,-17.1)、cast 全程 (-3.1,-33.9)。定位 = frame 贴图中心
# (53,53) − 内容中心，使内容中心与按钮中心重合（源 ccp(36,31) 系对源 C++ FCA 原点的补偿，
# 本项目 FCA 内容中心≈原点系实测，直译源数值不等效）。
const GLOW_POS: Vector2 = Vector2(47.6, 70.1)       # ready/switch/trigger（Loop 期校准，Start 期 0.63s 过渡偏差 ~14px 可接受）
const GLOW_CAST_POS: Vector2 = Vector2(56.1, 86.9)  # cast 施法光圈（内容中心 -3.1,-33.9）

func _play_skill_ready(state: String) -> void:
	_skill_ready_timer = 0.0
	if state == STATE_NONE:
		# 源 update newState==nil 分支调 disable_cast 清 ready 光圈（本项目漏译致放完大招紫圈残留）
		_clear_skill_glow()
		return
	if state == STATE_CAST:
		AudioPlayer.play_sfx("battle_fury_full")
	_clear_skill_glow()
	var res: String = FCA_READY if state == STATE_CAST else (FCA_TRIGGER if state == STATE_TRIGGER else FCA_SWITCH)
	var eff: Variant = BattleEffect.create(res)
	if eff != null:
		eff.play()
		_apply_scene_speed(eff)
		_skill_ready_eff = eff
		_skill_ready_effect = eff.get_node()
		frame_btn.add_child(_skill_ready_effect)
		_skill_ready_effect.position = GLOW_POS


# FCA 光圈特效跟随战斗加速（scene 切速经 apply_speed 同步 _skill_ready_effect；cast 短效创建时即时补偿）。
func _apply_scene_speed(eff: Variant) -> void:
	if scene != null and scene.has_method("current_speed"):
		eff.set_speed(float(scene.call("current_speed")))


func apply_speed(spd: float) -> void:
	if _skill_ready_eff != null and _skill_ready_eff.has_method("set_speed"):
		_skill_ready_eff.set_speed(spd)


func _play_skill_cast_effect() -> void:
	_clear_skill_glow()   # 源 play_skill_cast_effect 开头 disable_cast（清 ready 光圈）
	var eff: Variant = BattleEffect.create(FCA_CAST)
	if eff != null:
		eff.play()
		_apply_scene_speed(eff)
		_skill_cast_eff = eff   # 持引用：BattleEffect 是 RefCounted，局部引用归零即 PREDELETE 秒删节点（曾致 cast 光圈从未显示）
		var n: Node2D = eff.get_node()
		frame_btn.add_child(n)
		n.position = GLOW_CAST_POS
		# cast 特效不持久，1s 后清（hero_panel 不在 effect_list，手动回收节点+释放包装引用）
		if is_inside_tree():
			get_tree().create_timer(1.0).timeout.connect(func():
				if is_instance_valid(n):
					n.queue_free()
				_skill_cast_eff = null)


# 源 disable_cast（hero_panel.lua:178-187）：清 ready 光圈节点与包装引用。
func _clear_skill_glow() -> void:
	if _skill_ready_effect != null and is_instance_valid(_skill_ready_effect):
		_skill_ready_effect.queue_free()
	_skill_ready_effect = null
	_skill_ready_eff = null


func _set_portrait_gray() -> void:
	if portrait != null and portrait.ori_icon != null:
		portrait.ori_icon.modulate = DEAD_COLOR


func _is_auto_combat() -> bool:
	if scene != null and scene.get("auto_combat") != null:
		return bool(scene.auto_combat)
	return false


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
