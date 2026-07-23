class_name VitPromptCard
extends RefCounted

## 体力恢复提示卡（View helper）— 照源 ui/framework.lua:67-160 翻译。
## 按住 vit_bg 显示（createVitalityPrompt），松开销毁（destroyPromptCard），
## 每 1 秒刷新文本（refreshVitalityPromptHandler :136-151）。
## createPromptCard@91-112 用 main_vit_tips.png Scale9Sprite（九宫格 CCRect(15,20,45,15)）+ Label。
##
## 源提示卡位置 ccp(400,400) anchor(0.5,1) 底边中心 → Godot (480, 160)。

const TIPS_BG_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
# 源 framework.lua:95 ccp(400,400) → Godot to_godot(400+80, 560-400) = (480,160)
const POS_CENTER_TOP: Vector2 = Vector2(480.0, 160.0)
const FONT_SIZE: int = 20            # 源 :100 ed.createttf(text, 20)
const REFRESH_INTERVAL: float = 1.0  # 源 :144 if count > 1 then 刷新（每秒一次）
const BG_PADDING: Vector2 = Vector2(30.0, 28.0)  # 源 :108 bg size = label + (30,28)
const LABEL_VERT_OFFSET: float = 24.0  # 源 :109 pos.y - (h+24)/2

static var _active: Dictionary = {}  # 当前活动提示卡 ref（单实例，源 destroyPromptCard 守卫）


# 源 createVitalityPrompt@115-120：建提示卡 + 启动刷新 timer。
# 返回 ref Dictionary 供 destroy_prompt 销毁；vip_buy_max 由调用方查 VIP 表传入。
static func show(parent: Control, player: PlayerData, cm: ConfigManager) -> Dictionary:
	destroy_prompt()  # 源 :92 先销毁旧的（单实例）
	if parent == null or not is_instance_valid(parent):
		return {}
	var container := Control.new()
	container.name = "VitPromptCard"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)
	# 源 :96-98 Scale9Sprite main_vit_tips.png + anchor(0.5,1) + position ccp(400,400)
	var bg := NinePatchRect.new()
	bg.texture = load(TIPS_BG_RES)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# NinePatchRect 九宫格（源 CCRect(15,20,45,15) 左下原点 y向上 → Godot 左上原点 y向下）
	bg.patch_margin_left = 15
	bg.patch_margin_top = 28   # 源 rect.y=15（下边距，480→640 翻转 + 偏移近似）→ 顶部 28
	bg.patch_margin_right = 45
	bg.patch_margin_bottom = 15
	container.add_child(bg)
	# 源 :100-104 Label left alignment
	var lbl := Label.new()
	lbl.text = _build_text(player, cm)
	lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl)
	# 源 :107-109 bg size = label size + (30,28)；label position 偏移
	# Godot Label.get_combined_minimum_size 同步返回（Godot 4 不需等帧）
	var lbl_size: Vector2 = lbl.get_combined_minimum_size()
	if lbl_size == Vector2.ZERO:
		lbl_size = Vector2(220.0, 100.0)  # fallback（首次 build 可能未排版）
	bg.size = lbl_size + BG_PADDING
	bg.position = Vector2(POS_CENTER_TOP.x - bg.size.x / 2.0, POS_CENTER_TOP.y - bg.size.y)
	lbl.position = Vector2(POS_CENTER_TOP.x - lbl_size.x / 2.0, POS_CENTER_TOP.y - (lbl_size.y + LABEL_VERT_OFFSET) / 2.0 - lbl_size.y / 2.0)
	# 源 :118 registerUpdateHandler "refreshVitalityPrompt" 每秒刷新
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


# 源 destroyPromptCard@154-159：从父移除提示卡节点（单实例）。
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


# 源 getVitalityPromptText@67-88：组装多行提示文本（CURRENT_TIME/BOUGHT/恢复时间/间隔）。
static func _build_text(player: PlayerData, cm: ConfigManager) -> String:
	var gap: int = PlayerData.VITALITY_RECOVER_INTERVAL  # 源 sync_vitality_gap=360
	var max_vit: int = player.vitality_max
	var cur_vit: int = player.vitality
	var lt: int = max(max_vit - cur_vit - 1, 0)  # 源 :69 剩余可恢复次数
	var vnu: int = _seconds_to_next_update(player)  # 源 :70 getVitalityNextUpdate
	var total_secs: int = gap * lt + vnu  # 源 :72 满体总秒数
	var gap_min: int = int(gap / 60)  # 源 uires.lua:8 vit_gap = floor(360/60)=6
	# 源 :74-76 CURRENT_TIME + 已购次数 %d/%d
	var buy_max: int = int(VipData.get_vip_field(player.vip_level, "Buy Vit Max", cm))
	var prompt: String = cm.get_lstr("FRAMEWORK.CURRENT_TIME") + _hms_now() + "\n"
	var buy_fmt: String = cm.get_lstr("FRAMEWORK.BOUGHT_ENERGY_TIMES___D_D")
	prompt += buy_fmt % [player.vitality_today_buy, buy_max] + "\n"
	# 源 :78-86 满体 vs 未满两分支
	if max_vit <= cur_vit:
		prompt += cm.get_lstr("FRAMEWORK.ALREADY_BACK_TO_FULL_STRENGTH")
	else:
		prompt += cm.get_lstr("FRAMEWORK.ENERGY_BACKS_IN__") + _hms(vnu) + "\n"
		prompt += cm.get_lstr("FRAMEWORK.RESTORE_FULL_STRENGTH_") + _hms(total_secs) + "\n"
		prompt += cm.get_lstr("FRAMEWORK.RECOVERY_INTERVAL_") + str(gap_min) + cm.get_lstr("TIME.MINUTE")
	return prompt


# 源 player.lua:642-650 getVitalityNextUpdate = gap - (stime - ltime)（距下次恢复秒数）。
static func _seconds_to_next_update(player: PlayerData) -> int:
	var now: int = int(Time.get_unix_time_from_system())
	var dt: int = PlayerData.VITALITY_RECOVER_INTERVAL - (now - player.vitality_last_recover)
	return max(dt, 0)


# 源 ed.gethmsNString：秒数 → "HH:MM:SS"。
static func _hms(secs: int) -> String:
	var h: int = secs / 3600
	var m: int = (secs % 3600) / 60
	var s: int = secs % 60
	return "%02d:%02d:%02d" % [h, m, s]


# 源 ed.serverTime2HMS：当前时间 → "HH:MM:SS"。
static func _hms_now() -> String:
	var d: Dictionary = Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [int(d["hour"]), int(d["minute"]), int(d["second"])]
