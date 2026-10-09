extends Control

## PVP 最高排名奖励弹窗（View 层）— 照源 ui/stagedone.lua:988-1284 createPvpRankReward +
## :829-847 playEnterAnim（Timer 3s 后弹出）翻译（2026-09-13 PVP 结算补全）。
## 触发：PVP 胜利且 best_rank_reward>0（刷新历史最高排名，LadderManager._cmd_end_battle 拍板 20 钻石）。
## 结构：黑幕(0,0,0,150) + 面板 + 光效旋转 + 星饰×5 + 历史最高/当前排名对比 + 可获奖励行 + 确定钮。
## 2026-10-09 改版（用户反馈样式优化 + 结算页等级标签穿透）：
## - 层级修复：root _init 未设 rect（size=0）→ shade 的 FULL_RECT 锚塌成 0×0，黑幕失效，
##   结算页弹窗外区域裸露（与 ladder_buy_confirm set_anchors 坑同族）。root 显式 800×480，
##   scale 弹出动画 pivot 取屏中心（原默认 (0,0) 从左上角缩放）。
## - 样式：源 serverselect_serverlist_bg（390×450）缺图原以纯 ColorRect 降级 → 改 main_vit_tips
##   九宫格 550×360 + pvp_tip_title_bg 标题条（LadderRulesPopup 同款 pvp 系弹窗视觉）。
## 受控偏离（缺图降级）：标题 pvp_result_highest → 标题条+Label；排名行 sprite 嵌图（pvp_up）
## → 文本"↑"；源奖励邮件发放文案（联机语义）不译。

const PVP_TEX_DIR: String = "res://assets/ui/alpha/HVGA/pvp/"
const ALPHA_HVGA_DIR: String = "res://assets/ui/alpha/HVGA/"
const CONTENT_SCALE: float = 1.28125   # 贴图显示尺寸=像素÷CS（同 stage_done_scene 口径）
const VIEW_SIZE: Vector2 = Vector2(800.0, 480.0)
# 底板 main_vit_tips（103×61 九宫格）拉伸 550×360 居屏（LadderRulesPopup 同款 cap）。
const BG_POS: Vector2 = Vector2(125.0, 60.0)
const BG_SIZE: Vector2 = Vector2(550.0, 360.0)
const BG_PATCH: Vector2i = Vector2i(11, 15)   # left/top（right=35/bottom=11，ladder_rules 先例）
# 标题条 pvp_tip_title_bg 474×44÷CS≈370×34，bg 内居中 y 25。
const TITLE_BG_RECT: Rect2 = Rect2(90.0, 25.0, 370.0, 34.0)
const TITLE_FONT: int = 22
# 光效 pvp_rank_1st_light 145×143÷CS≈113×112，scale 1.1，bg 内中心 (275,116)。
const LIGHT_POS: Vector2 = Vector2(275.0, 116.0)
const LIGHT_SCALE: float = 1.1
const LIGHT_ROTATE_SEC: float = 5.0                    # 源 CCRotateBy(5,360) 循环
# 星饰×5（源环绕光效布点，bg 内中心锚）：(280,82)s1/(328,158)s1/(222,158)s2/(262,150)s1/(194,82)s1。
const STARS: Array[Dictionary] = [
	{"pos": Vector2(280.0, 82.0), "s": 1.0}, {"pos": Vector2(328.0, 158.0), "s": 1.0},
	{"pos": Vector2(222.0, 158.0), "s": 2.0}, {"pos": Vector2(262.0, 150.0), "s": 1.0},
	{"pos": Vector2(194.0, 82.0), "s": 1.0},
]
const RANK_ROW_1: Rect2 = Rect2(105.0, 184.0, 340.0, 26.0)   # 历史最高排名行（bg 内）
const RANK_ROW_2: Rect2 = Rect2(105.0, 214.0, 340.0, 26.0)   # 当前行
const RANK_FONT: int = 20
# 奖励行 tip_detail_bg 拉伸 320×45（源 heroInfo tip_detail_bg 390×60 同为拉伸），bg 内中心 (275,268)。
const INFO_RECT: Rect2 = Rect2(115.0, 246.0, 320.0, 45.0)
# 确定钮（源 closeRewardInfo tavern_button_normal_1/2 Scale9 120×50）bg 内中心 (275,330)。
const BTN_RECT: Rect2 = Rect2(215.0, 305.0, 120.0, 50.0)
const CLOSE_BTN_CAP: Rect2 = Rect2(14.0, 10.0, 100.0, 29.0)   # 源 tavern_button_normal cap(14,10,100,29)
const GOLD_TEXT: Color = Color(0.945, 0.757, 0.443)   # 源 (241,193,113)
const TITLE_TEXT: Color = Color(0.984, 0.808, 0.063)  # ccc3(251,206,16)（ladder 系标题黄）


var _light: Sprite2D = null
var _rotate_tween: Tween = null


func _init(param: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # 全屏模态（源触摸 -100 吞底层，3s 锁定语义）
	# 压过结算页三星入场动画（Star1-3 z_index=100-102）与统计钮等高层装饰——2026-10-09 实测
	# 星星/等级标签渲染在 z=0 的弹窗之上即此因（同 CanvasLayer 内 z 全局比较）。
	z_index = 200
	visible = false
	modulate.a = 0.0
	# root 显式全屏 rect：shade 的 FULL_RECT 锚依父尺寸展开，size=0 会连坐塌成 0×0
	# （2026-10-09 修：黑幕失效致结算页等级标签裸露穿透）。
	size = VIEW_SIZE
	pivot_offset = VIEW_SIZE * 0.5   # scale 弹出动画围绕屏中心（源 EaseBackOut 中心弹出）
	_build(param)


func _build(param: Dictionary) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 150.0 / 255.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# 底板九宫格（main_vit_tips，LadderRulesPopup 同款 pvp 系弹窗底，cap 直译）。
	var bg := NinePatchRect.new()
	bg.texture = StageSettlementCommon.load_texture(ALPHA_HVGA_DIR + "main_vit_tips.png")
	bg.patch_margin_left = BG_PATCH.x
	bg.patch_margin_top = BG_PATCH.y
	bg.patch_margin_right = 35
	bg.patch_margin_bottom = 11
	bg.position = BG_POS
	bg.size = BG_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# 标题（源 pvp_result_highest.png 缺图 → pvp_tip_title_bg 标题条 + Label，2026-10-09 改版）。
	var title_bg := TextureRect.new()
	title_bg.texture = StageSettlementCommon.load_texture(PVP_TEX_DIR + "pvp_tip_title_bg.png")
	title_bg.stretch_mode = TextureRect.STRETCH_SCALE
	title_bg.position = TITLE_BG_RECT.position
	title_bg.size = TITLE_BG_RECT.size
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(title_bg)
	var title := Label.new()
	title.text = "最高排名"
	title.add_theme_font_size_override("font_size", TITLE_FONT)
	title.add_theme_color_override("font_color", TITLE_TEXT)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.position = Vector2.ZERO
	title.size = TITLE_BG_RECT.size   # 显式 rect（set_anchors_preset 进树后会保持 0 尺寸，同族坑）
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bg.add_child(title)
	_light = Sprite2D.new()
	_light.texture = StageSettlementCommon.load_texture(PVP_TEX_DIR + "pvp_rank_1st_light.png")
	_light.centered = true
	_light.position = LIGHT_POS
	_light.scale = Vector2(LIGHT_SCALE, LIGHT_SCALE) / CONTENT_SCALE
	bg.add_child(_light)
	for s in STARS:
		var star := Sprite2D.new()
		star.texture = StageSettlementCommon.load_texture(PVP_TEX_DIR + "pvp_rank_1st_star.png")
		star.centered = true
		star.position = s["pos"]
		star.scale = Vector2(s["s"], s["s"]) / CONTENT_SCALE
		bg.add_child(star)
	# 排名对比（源 RichText historyRank/currentRank；sprite 嵌图 pvp_up → 文本"↑"降级）。
	var best_rank: int = int(param.get("best_rank", 0))
	var cur_rank: int = int(param.get("cur_rank", 0))
	_add_rank_label(bg, "历史最高排名: %d" % best_rank, RANK_ROW_1)
	_add_rank_label(bg, "当前排名: %d (↑%d)" % [cur_rank, maxi(best_rank - cur_rank, 0)], RANK_ROW_2)
	# 可获奖励行（源 heroInfo tip_detail_bg + "可获奖励:" + rmbicon 0.8 + 数字）。
	var info := TextureRect.new()
	info.texture = StageSettlementCommon.load_texture(ALPHA_HVGA_DIR + "tip_detail_bg.png")
	info.stretch_mode = TextureRect.STRETCH_SCALE
	info.position = INFO_RECT.position
	info.size = INFO_RECT.size
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(info)
	var reward_lbl := Label.new()
	reward_lbl.text = "可获奖励:"
	reward_lbl.add_theme_font_size_override("font_size", 18)
	reward_lbl.add_theme_color_override("font_color", GOLD_TEXT)
	reward_lbl.position = Vector2(18.0, 12.0)
	reward_lbl.size = Vector2(110.0, 21.0)
	info.add_child(reward_lbl)
	var icon := Sprite2D.new()
	icon.texture = StageSettlementCommon.load_texture(ALPHA_HVGA_DIR + "rmbicon.png")
	icon.centered = false
	icon.position = Vector2(140.0, 9.0)
	icon.scale = Vector2(0.7, 0.7) / CONTENT_SCALE
	info.add_child(icon)
	var num_lbl := Label.new()
	num_lbl.text = str(int(param.get("best_rank_reward", 0)))
	num_lbl.add_theme_font_size_override("font_size", 20)
	num_lbl.add_theme_color_override("font_color", Color(0.914, 0.588, 0.173))
	num_lbl.position = Vector2(170.0, 11.0)
	num_lbl.size = Vector2(120.0, 22.0)
	info.add_child(num_lbl)
	# 确定钮（源 closeRewardInfo tavern_button_normal_1/2 Scale9 120×50 + CHATCONFIG.CONFIRM）。
	var btn := Button.new()
	btn.position = BTN_RECT.position
	btn.size = BTN_RECT.size
	UiScale9Button.apply_with_label(
		btn, ALPHA_HVGA_DIR + "tavern_button_normal_1.png",
		ALPHA_HVGA_DIR + "tavern_button_normal_2.png", CLOSE_BTN_CAP, "确定")
	btn.pressed.connect(_on_close_pressed)
	bg.add_child(btn)


func _add_rank_label(bg: Control, text: String, rect: Rect2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", RANK_FONT)
	lbl.add_theme_color_override("font_color", GOLD_TEXT)
	lbl.position = rect.position
	lbl.size = rect.size
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(lbl)   # rect 即 bg 内局部坐标


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
