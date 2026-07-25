class_name StageDoneAnimator
extends RefCounted

## stagedone 胜利结算入场动画（View 层）— 照源 ui/stagedone.lua playEnterAnim 8 子动画翻译（2026-07-03，第二十一轮）。
## 由 StageDoneScene 持有，操作 scene 装配好的节点（light/star/hero/loot/button/label）跑 Tween 序列。
## 单机化：去 FCA 特效（playCastAnim eff_UI_battle_skill_cast / playLevelupEffect eff_UI_levelup，项目无 FCA
##   系统降级 skip，照 battle_hero_panel.gd:155/160）/draglist 滚动/getNewHero announce/guildDataAnimation
##   公会数据/bestRankReward PVP/isMaxLevel full bar 替换（is_max_level 兜底 false）。
## speedDiv=1（无战斗速度系统）：anim_delay=1.5/hero_show_gap=0.1/loot_show_gap=0.2/number_jump_gap=1.0。
## GDScript lambda 捕获循环变量陷阱（for 内 var 共享引用）用 Callable.bind 即时求值 + 方法引用规避。

const ANIM_DELAY: float = 1.5
const HERO_SHOW_GAP: float = 0.1
const HERO_BAR_STEP: float = 0.05
const LOOT_SHOW_GAP: float = 0.2
const STAR_DELAY_BASE: float = 0.5
const STAR_DELAY_STEP: float = 0.4
const STAR_SCALE_DUR: float = 0.5
const FADE_DUR: float = 0.2
const LIGHT_FADE_DUR: float = 0.2
const ROTATE_DUR: float = 5.0
const WIN_SCALE_DUR: float = 0.2
const HERO_LEVEL_DUR: float = 0.5
const NUMBER_JUMP_DUR: float = 1.0
const ALPHA_HVGA_DIR: String = "res://assets/ui/alpha/HVGA/"
const WIN_TAG_POS: Vector2 = Vector2(378.0, 410.0)
const WIN_TAG_TEX: String = "stagedone_win_tag.png"
const WIN_TAG_LIGHT_TEX: String = "stagedone_win_tag_light.png"

var _s: Control = null    # StageDoneScene（持有方，操作其装配节点）
var _tweens: Array = []   # 活跃 Tween（skip 时 kill）


func _init(scene: Control) -> void:
	_s = scene


func play_enter() -> void:
	_s._anim_playing = true
	AudioPlayer.play_sfx("battle_win")
	_play_light()
	_play_info_bg()
	_play_level()
	_play_hero()
	_play_number_jump()
	if bool(_s._param.get("is_key_stage", false)):
		_play_star()
	else:
		_play_win()


func _play_light() -> void:
	var light: Sprite2D = _s._light
	var tw: Tween = _new_tween()
	tw.tween_property(light, "modulate:a", 1.0, LIGHT_FADE_DUR)
	tw.tween_callback(_start_light_rotate)


func _start_light_rotate() -> void:
	var rot: Tween = _new_tween().set_loops()
	rot.tween_property(_s._light, "rotation", TAU, ROTATE_DUR)


func _play_info_bg() -> void:
	var tw: Tween = _new_tween()
	tw.tween_property(_s._info_bg, "modulate:a", 1.0, FADE_DUR)
	if _s._battle_statist_node != null:
		var tw2: Tween = _new_tween()
		tw2.tween_property(_s._battle_statist_node, "modulate:a", 1.0, FADE_DUR)


func _play_level() -> void:
	var player_info: Dictionary = _s._param.get("player_info", {})
	var anim_list: Array = player_info.get("anim_list", [])
	if anim_list.size() > 1:
		_s._lv_label.text = str(int(player_info.get("level", 1)))


func _play_star() -> void:
	var stars: int = int(_s._param.get("stars", 0))
	for i in range(stars):
		if i >= _s._star_nodes.size():
			break
		var star: Sprite2D = _s._star_nodes[i]
		star.scale = Vector2.ZERO
		var tw: Tween = _new_tween()
		tw.tween_interval(STAR_DELAY_BASE + STAR_DELAY_STEP * i)
		tw.tween_property(star, "scale", Vector2.ONE, STAR_SCALE_DUR) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		if i == 0:
			tw.tween_callback(_play_sfx_star_one)


func _play_sfx_star_one() -> void:
	AudioPlayer.play_sfx("battledown_star_one")


func _play_win() -> void:
	var win := Sprite2D.new()
	win.texture = _load(ALPHA_HVGA_DIR + WIN_TAG_TEX)
	win.position = WIN_TAG_POS
	win.scale = Vector2.ZERO
	_s.add_child(win)
	var tw: Tween = _new_tween()
	tw.tween_property(win, "scale", Vector2.ONE, WIN_SCALE_DUR) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_spawn_win_light.bind(win))


func _spawn_win_light(_win: Sprite2D) -> void:
	var wl := Sprite2D.new()
	wl.texture = _load(ALPHA_HVGA_DIR + WIN_TAG_LIGHT_TEX)
	wl.position = WIN_TAG_POS
	_s.add_child(wl)
	var wl_tw: Tween = _new_tween()
	wl_tw.parallel().tween_property(wl, "modulate:a", 0.0, WIN_SCALE_DUR)
	wl_tw.parallel().tween_property(wl, "scale", Vector2.ONE * 2.0, WIN_SCALE_DUR)
	wl_tw.tween_callback(wl.queue_free)


# 最后一个 fade 完成触发 playLootAnim。
func _play_hero() -> void:
	var n: int = _s._hero_icon_nodes.size()
	for i in range(n):
		var ri: ReadheroIcon = _s._hero_icon_nodes[i]
		ri.icon.modulate.a = 0.0
		var tw: Tween = _new_tween()
		tw.tween_interval(ANIM_DELAY + HERO_SHOW_GAP * i)
		tw.tween_property(ri.icon, "modulate:a", 1.0, FADE_DUR)
		if i == n - 1:
			tw.tween_callback(_play_loot)
	_play_hero_bar()


# 单机化：去 playLevelupEffect FCA / isMaxLevel full bar 替换 / guildInstanceData 分支。
func _play_hero_bar() -> void:
	var n: int = _s._hero_icon_nodes.size()
	var dt: float = ANIM_DELAY + HERO_BAR_STEP * max(n - 1, 0)
	var heroes: Array = _s._param.get("heroes", [])
	for i in range(n):
		if i >= _s._hero_bars.size() or i >= heroes.size():
			break
		var ri: ReadheroIcon = _s._hero_icon_nodes[i]
		var bar: Sprite2D = _s._hero_bars[i]
		var hinfo: Dictionary = heroes[i]
		var pre_level: int = int(hinfo.get("level", 1))
		var t_level: int = int(hinfo.get("t_level", pre_level))
		var t_exp: int = int(hinfo.get("t_exp", 0))
		var t_max: int = int(hinfo.get("t_max_exp", 1))
		var tw: Tween = _new_tween()
		tw.tween_interval(dt)
		tw.tween_callback(_play_sfx_exp_up)
		for j in range(t_level - pre_level):
			tw.tween_property(bar, "scale:x", 1.0, HERO_LEVEL_DUR)
			# bind 即时求值 bar/ri/pre_level+j+1，规避 for-var 闭包陷阱
			tw.tween_callback(_on_hero_levelup.bind(bar, ri, pre_level + j + 1))
		var final_x: float = clampf(float(t_exp) / float(max(t_max, 1)), 0.0, 1.0)
		tw.tween_property(bar, "scale:x", final_x, FADE_DUR)


func _on_hero_levelup(bar: Sprite2D, icon: ReadheroIcon, level: int) -> void:
	AudioPlayer.play_sfx("common_hero_lvlup")
	bar.scale.x = 0.0
	icon.refresh_level(level)


func _play_sfx_exp_up() -> void:
	# common_exp_up 源 deo=nil 占位未实现（soundres:37），未注册则静音不调（避 push_error 噪音）
	if AudioPlayer.am != null and AudioPlayer.am.has_sfx(&"common_exp_up"):
		AudioPlayer.play_sfx("common_exp_up")


func _play_loot() -> void:
	var n: int = _s._loot_icon_nodes.size()
	if n == 0:
		play_button()
		return
	for i in range(n):
		var icon: Control = _s._loot_icon_nodes[i]
		icon.scale = Vector2.ZERO
		var tw: Tween = _new_tween()
		tw.tween_interval(LOOT_SHOW_GAP * i)
		if i == n - 1:
			tw.tween_callback(play_button)
		tw.tween_property(icon, "scale", Vector2.ONE, FADE_DUR) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func play_button() -> void:
	if _s._next_btn.modulate.a > 0.0:
		return
	var is_key: bool = bool(_s._param.get("is_key_stage", false))
	_s._replay_btn.visible = is_key
	_s._replay_btn.modulate.a = 0.0
	_s._next_btn.visible = true
	_s._next_btn.modulate.a = 0.0
	if is_key:
		var tw1: Tween = _new_tween()
		tw1.tween_property(_s._replay_btn, "modulate:a", 1.0, FADE_DUR)
	var tw2: Tween = _new_tween()
	tw2.tween_property(_s._next_btn, "modulate:a", 1.0, FADE_DUR)
	_s._anim_playing = false


func _play_number_jump() -> void:
	var exp_val: int = int(_s._param.get("exp", 0))
	var gold_val: int = int(_s._param.get("gold", 0))
	var tw: Tween = _new_tween()
	tw.tween_interval(ANIM_DELAY)
	# 从 0→1 插值，t*exp/gold 即当前数（源 floor(speed*count)，speed=exp/gap）
	tw.tween_method(_update_number_labels.bind(exp_val, gold_val), 0.0, 1.0, NUMBER_JUMP_DUR)


func _update_number_labels(t: float, exp_val: int, gold_val: int) -> void:
	var e: int = int(round(t * float(exp_val)))
	var g: int = int(round(t * float(gold_val)))
	_s._exp_label.text = "+" + str(e)
	_s._gold_label.text = "+" + str(g)


# kill 所有活跃 tween（skipAnim 调）。
func kill() -> void:
	for tw in _tweens:
		var t: Tween = tw
		if t != null and t.is_running():
			t.kill()
	_tweens.clear()


func _new_tween() -> Tween:
	var tw: Tween = _s.create_tween()
	_tweens.append(tw)
	return tw


func _load(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
