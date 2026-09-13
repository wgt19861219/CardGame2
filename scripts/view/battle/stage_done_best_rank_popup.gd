extends Control

## PVP 最高排名奖励弹窗（View 层）— 照源 ui/stagedone.lua:988-1284 createPvpRankReward +
## :829-847 playEnterAnim（Timer 3s 后弹出）翻译（2026-09-13 PVP 结算补全）。
## 触发：PVP 胜利且 best_rank_reward>0（刷新历史最高排名，LadderManager._cmd_end_battle 拍板 20 钻石）。
## 结构：黑幕(0,0,0,150) + 面板 + 光效旋转 + 星饰×5 + 历史最高/当前排名对比 + 可获奖励行 + 确定钮。
## 受控偏离（缺图降级）：面板底 serverselect_serverlist_bg / 标题 pvp_result_highest → 深色底+Label；
## 排名行 RichText sprite 嵌图（pvp_up）→ 文本"↑"；源奖励邮件发放文案（联机语义）不译。

const PVP_TEX_DIR: String = "res://assets/ui/alpha/HVGA/pvp/"
const ALPHA_HVGA_DIR: String = "res://assets/ui/alpha/HVGA/"
const CONTENT_SCALE: float = 1.28125   # 贴图显示尺寸=像素÷CS（同 stage_done_scene 口径）
# 源坐标换算：bg 390×450 中心锚 (400,240) → Godot 左上 (205,15)；bg 内子节点 y 翻转 +该偏移。
const BG_POS: Vector2 = Vector2(205.0, 15.0)
const BG_SIZE: Vector2 = Vector2(390.0, 450.0)
const LIGHT_POS: Vector2 = Vector2(400.0, 115.0)      # 源 bg 内 (195,350) 中心锚 scale 2
const LIGHT_SCALE: float = 2.0
const LIGHT_ROTATE_SEC: float = 5.0                    # 源 CCRotateBy(5,360) 循环
const STARS: Array[Dictionary] = [                     # 源 bg 内中心锚 (200,310)s1/(250,400)s1/(140,400)s2/(180,390)s1/(100,310)s1
	{"pos": Vector2(405.0, 155.0), "s": 1.0}, {"pos": Vector2(455.0, 65.0), "s": 1.0},
	{"pos": Vector2(345.0, 65.0), "s": 2.0}, {"pos": Vector2(385.0, 75.0), "s": 1.0},
	{"pos": Vector2(305.0, 155.0), "s": 1.0},
]
const INFO_POS: Vector2 = Vector2(205.0, 269.0)       # 源 heroInfo tip_detail_bg 390×60 中心 (195,166)bg 内
const INFO_SIZE: Vector2 = Vector2(390.0, 60.0)
const BTN_POS: Vector2 = Vector2(340.0, 396.0)        # 源 closeRewardInfo 120×50 中心 (195,44)bg 内
const BTN_SIZE: Vector2 = Vector2(120.0, 50.0)
const RANK_X: float = 265.0                            # 源 historyRank/currentRank 左中锚 (60,274/224)bg 内 → 全局 x
const RANK_HISTORY_Y: float = 191.0
const RANK_CURRENT_Y: float = 241.0
const TITLE_FONT: int = 26
const RANK_FONT: int = 18
const CLOSE_BTN_CAP: Rect2 = Rect2(14.0, 10.0, 100.0, 29.0)   # 源 tavern_button_normal cap(14,10,100,29)
const GOLD_TEXT: Color = Color(0.945, 0.757, 0.443)   # 源 (241,193,113)


var _light: Sprite2D = null
var _rotate_tween: Tween = null


func _init(param: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # 全屏模态（源触摸 -100 吞底层，3s 锁定语义）
	visible = false
	modulate.a = 0.0
	_build(param)


func _build(param: Dictionary) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 150.0 / 255.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# 面板底（源 Scale9 serverselect_serverlist_bg 390×450；缺图 → 深色底降级，受控偏离记录）
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.12, 0.07, 0.97)
	bg.position = BG_POS
	bg.size = BG_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_light = Sprite2D.new()
	_light.texture = StageSettlementCommon.load_texture(PVP_TEX_DIR + "pvp_rank_1st_light.png")
	_light.centered = true
	_light.position = LIGHT_POS
	_light.scale = Vector2(LIGHT_SCALE, LIGHT_SCALE) / CONTENT_SCALE
	add_child(_light)
	# 标题（源 pvp_result_highest.png 缺图 → Label 降级，压光效之上）
	var title := Label.new()
	title.text = "最高排名"
	title.add_theme_font_size_override("font_size", TITLE_FONT)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = LIGHT_POS - Vector2(120.0, 22.0)
	title.size = Vector2(240.0, 44.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)
	for s in STARS:
		var star := Sprite2D.new()
		star.texture = StageSettlementCommon.load_texture(PVP_TEX_DIR + "pvp_rank_1st_star.png")
		star.centered = true
		star.position = s["pos"]
		star.scale = Vector2(s["s"], s["s"]) / CONTENT_SCALE
		add_child(star)
	# 排名对比（源 RichText historyRank/currentRank；sprite 嵌图 pvp_up → 文本"↑"降级）
	var best_rank: int = int(param.get("best_rank", 0))
	var cur_rank: int = int(param.get("cur_rank", 0))
	_add_rank_label("历史最高排名: %d" % best_rank, Vector2(RANK_X, RANK_HISTORY_Y), GOLD_TEXT)
	_add_rank_label("当前排名: %d (↑%d)" % [cur_rank, maxi(best_rank - cur_rank, 0)], Vector2(RANK_X, RANK_CURRENT_Y), GOLD_TEXT)
	# 可获奖励行（源 heroInfo tip_detail_bg + "可获奖励:" + rmbicon 0.8 + 数字）
	var info := TextureRect.new()
	info.texture = StageSettlementCommon.load_texture(ALPHA_HVGA_DIR + "tip_detail_bg.png")
	info.stretch_mode = TextureRect.STRETCH_SCALE
	info.position = INFO_POS
	info.size = INFO_SIZE
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	var reward_lbl := Label.new()
	reward_lbl.text = "可获奖励:"
	reward_lbl.add_theme_font_size_override("font_size", 20)
	reward_lbl.add_theme_color_override("font_color", GOLD_TEXT)
	reward_lbl.position = Vector2(46.0, 20.0)
	reward_lbl.size = Vector2(90.0, 20.0)
	info.add_child(reward_lbl)
	var icon := Sprite2D.new()
	icon.texture = StageSettlementCommon.load_texture(ALPHA_HVGA_DIR + "rmbicon.png")
	icon.centered = false
	icon.position = Vector2(142.0, 14.0)
	icon.scale = Vector2(0.8, 0.8) / CONTENT_SCALE
	info.add_child(icon)
	var num_lbl := Label.new()
	num_lbl.text = str(int(param.get("best_rank_reward", 0)))
	num_lbl.add_theme_font_size_override("font_size", 20)
	num_lbl.add_theme_color_override("font_color", Color(0.914, 0.588, 0.173))
	num_lbl.position = Vector2(178.0, 20.0)
	num_lbl.size = Vector2(120.0, 20.0)
	info.add_child(num_lbl)
	# 确定钮（源 closeRewardInfo tavern_button_normal_1/2 Scale9 120×50 + CHATCONFIG.CONFIRM）
	var btn := Button.new()
	btn.position = BTN_POS
	btn.size = BTN_SIZE
	UiScale9Button.apply_with_label(
		btn, ALPHA_HVGA_DIR + "tavern_button_normal_1.png",
		ALPHA_HVGA_DIR + "tavern_button_normal_2.png", CLOSE_BTN_CAP, "确定")
	btn.pressed.connect(_on_close_pressed)
	add_child(btn)


func _add_rank_label(text: String, pos: Vector2, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", RANK_FONT)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = pos - Vector2(0.0, 12.0)
	lbl.size = Vector2(260.0, 24.0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(lbl)


## 弹出（源 :836-846：scale 0.5→1 EaseBackOut 0.5s + light CCRepeatForever 旋转 + visible）。
func popup() -> void:
	visible = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)
	var s := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	s.tween_property(self, "scale", Vector2.ONE, 0.5).from(Vector2(0.5, 0.5))
	_rotate_tween = create_tween().set_loops()
	_rotate_tween.tween_property(_light, "rotation", TAU, LIGHT_ROTATE_SEC)


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if _rotate_tween != null and _rotate_tween.is_valid():
		_rotate_tween.kill()
	queue_free()
