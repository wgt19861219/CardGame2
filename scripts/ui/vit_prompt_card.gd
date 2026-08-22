class_name VitPromptCard
extends RefCounted

## 体力恢复提示卡（View helper）— 照源 ui/framework.lua:67-160 翻译。
## 按住 vit_bg 显示（createVitalityPrompt），松开销毁（destroyPromptCard），
## 每 1 秒刷新文本（refreshVitalityPromptHandler :136-151）。
## createPromptCard@91-112 用 main_vit_tips.png Scale9Sprite（九宫格 CCRect(15,20,45,15)）+ Label。
##

const TIPS_BG_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const POS_CENTER_TOP: Vector2 = Vector2(480.0, 160.0)
const FONT_SIZE: int = 20
const REFRESH_INTERVAL: float = 1.0
const BG_PADDING: Vector2 = Vector2(30.0, 28.0)
const LABEL_VERT_OFFSET: float = 24.0

static var _active: Dictionary = {}  # 当前活动提示卡 ref（单实例，源 destroyPromptCard 守卫）


# 返回 ref Dictionary 供 destroy_prompt 销毁；vip_buy_max 由调用方查 VIP 表传入。
static func show(parent: Control, player: PlayerData, cm: ConfigManager) -> Dictionary:
	destroy_prompt()
	if parent == null or not is_instance_valid(parent):
		return {}
	var container := Control.new()
	container.name = "VitPromptCard"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)
	var bg := NinePatchRect.new()
	bg.texture = load(TIPS_BG_RES)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# NinePatchRect 九宫格：源 framework.lua:96 CCRectMake(15,20,45,15)，贴图 103×61 PIL 实测，
	# 纹理px L15/T26/R43/B20（批 1 fde903b 公式）；patch 须 ÷CS 取整 → L12/T20/R34/B16。
	bg.patch_margin_left = 12
	bg.patch_margin_top = 20
	bg.patch_margin_right = 34
	bg.patch_margin_bottom = 16
	container.add_child(bg)
	var lbl := Label.new()
	lbl.text = _build_text(player, cm)
	lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl)
	# Godot Label.get_combined_minimum_size 同步返回（Godot 4 不需等帧）
	var lbl_size: Vector2 = lbl.get_combined_minimum_size()
	if lbl_size == Vector2.ZERO:
		lbl_size = Vector2(220.0, 100.0)  # fallback（首次 build 可能未排版）
	bg.size = lbl_size + BG_PADDING
	bg.position = Vector2(POS_CENTER_TOP.x - bg.size.x / 2.0, POS_CENTER_TOP.y - bg.size.y)
	lbl.position = Vector2(POS_CENTER_TOP.x - lbl_size.x / 2.0, POS_CENTER_TOP.y - (lbl_size.y + LABEL_VERT_OFFSET) / 2.0 - lbl_size.y / 2.0)
	var timer := Timer.new()
	timer.wait_time = REFRESH_INTERVAL
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(lbl):
			return
		lbl.text = _build_text(player, cm))
	container.add_child(timer)
	_active = {"node": container, "label": lbl, "timer": timer}
	return _active


static func destroy_prompt(_ref: Dictionary = {}) -> void:
	# 优先用 _active（单实例）；_ref 兼容显式传 ref（lambda capture）
	var ref: Dictionary = _active if _ref.is_empty() else _ref
	if ref.is_empty():
		return
	var node: Node = ref.get("node", null)
	if node != null and is_instance_valid(node):
		node.queue_free()
	if ref == _active:
		_active.clear()


static func _build_text(player: PlayerData, cm: ConfigManager) -> String:
	var gap: int = VitalityManager.RECOVER_INTERVAL
	var max_vit: int = player.vitality_max
	var cur_vit: int = player.vitality
	var lt: int = max(max_vit - cur_vit - 1, 0)
	var vnu: int = _seconds_to_next_update(player)
	var total_secs: int = gap * lt + vnu
	var gap_min: int = int(gap / 60)
	var buy_max: int = int(VipData.get_vip_field(player.vip_level, "Buy Vit Max", cm))
	var prompt: String = cm.get_lstr("FRAMEWORK.CURRENT_TIME") + _hms_now() + "\n"
	var buy_fmt: String = cm.get_lstr("FRAMEWORK.BOUGHT_ENERGY_TIMES___D_D")
	prompt += buy_fmt % [player.vitality_today_buy, buy_max] + "\n"
	if max_vit <= cur_vit:
		prompt += cm.get_lstr("FRAMEWORK.ALREADY_BACK_TO_FULL_STRENGTH")
	else:
		prompt += cm.get_lstr("FRAMEWORK.ENERGY_BACKS_IN__") + _hms(vnu) + "\n"
		prompt += cm.get_lstr("FRAMEWORK.RESTORE_FULL_STRENGTH_") + _hms(total_secs) + "\n"
		prompt += cm.get_lstr("FRAMEWORK.RECOVERY_INTERVAL_") + str(gap_min) + cm.get_lstr("TIME.MINUTE")
	return prompt


static func _seconds_to_next_update(player: PlayerData) -> int:
	var now: int = int(Time.get_unix_time_from_system())
	var dt: int = VitalityManager.RECOVER_INTERVAL - (now - player.vitality_last_recover)
	return max(dt, 0)


static func _hms(secs: int) -> String:
	var h: int = secs / 3600
	var m: int = (secs % 3600) / 60
	var s: int = secs % 60
	return "%02d:%02d:%02d" % [h, m, s]


static func _hms_now() -> String:
	var d: Dictionary = Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [int(d["hour"]), int(d["minute"]), int(d["second"])]
