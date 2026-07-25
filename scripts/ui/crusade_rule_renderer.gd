class_name CrusadeRuleRenderer
extends RefCounted

## CrusadePanel 规则页渲染 helper（照源 crusade.lua:543-610 initRuleLayer + crusadeconfig.lua:1535 ruleLayer）。
## 从 crusade_panel.gd 抽出以控 LINT005 ≤400。全 static + cm: Variant 参数化（对齐 midas_renderer 范式）。
## 不反向引用 CrusadePanel（container/scene 经参数传入）。

const RULE_FRAME_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const RULE_FRAME_CAP: int = 15
const RULE_FRAME_SIZE: Vector2 = Vector2(500.0, 400.0)
const RULE_SHADE_ALPHA: float = 190.0 / 255.0
const RULE_LABEL_FONT_SIZE: int = 18
const RULE_SEP_HEIGHT: float = 10.0
const VIEWPORT_SIZE: Vector2 = Vector2(960.0, 640.0)

# 源 initRuleLayer 17 项：6 叙事(dark_white) + 1 间隔 + 战斗规则标题 + 7 规则(normalButton) + 2 间隔
const RULE_LSTR_KEYS: Array[String] = [
	"CRUSADE.TEXT_DARK_WHITE_MOLTEN_VOLCANIC_BURST",
	"CRUSADE.TEXT_DARK_WHITE_DRAGON_TREASURE_REVEALS_TO_THE_WORLD",
	"CRUSADE.TEXT_DARK_WHITE_DREAMER_BEWARE_OF_YOUR_GREED",
	"CRUSADE.TEXT_DARK_WHITE_BECAUSE_THE_MORE_DANGEROUS_MAN_THAN_ARALIA",
	"CRUSADE.TEXT_DARK_WHITE_IS_THE_TREASURE_HUNTER_WITH_YOU",
	"CRUSADE.TEXT_DARK_WHITE_PROPHECY_OF_FIRE_VOLUME_VII",
	"",
	"CRUSADE.TEXT_NORMALBUTTON_BATTLE_RULES_",
	"CRUSADE.TEXT___NORMALBUTTON___ABOVE_1_LEVEL_20+_HEROES_CAN_PARTICIPATE_IN_THE_EXPEDITION",
	"CRUSADE.TEXT___NORMALBUTTON___2_DURING_THE_EXPEDITION_HP_AND_ENERGY_OF_BOTH_SIDE_WILL_NOT_RECOVER_AND_RESET",
	"CRUSADE.TEXT___NORMALBUTTON___3_DIED_HEROES_WILL_NOT_BE_RESURRECTED",
	"CRUSADE.TEXT___NORMALBUTTON___4_IF_THE_FIGHT_IS_NOT_OVER_IN_DUE_TIME_ALL_HEROES_OF_BOTH_SIDE_SHALL_BE_COUNTED_AS_DEAD",
	"CRUSADE.TEXT___NORMALBUTTON___5_PLAYERS_CAN_PARTICIPATE_THE_EXPEDITION_ONCE_A_DAY_VIP10_OR_HIGHER_CAN_PARTICIPATE_MULTIPLE_TIMES_A_DAY",
	"CRUSADE.TEXT_NORMALBUTTON_6_AFTER_DEFEATING_EVERY_WAVE_OF_ENEMY_YOU_CAN_OPEN_CHEST_TO_GET_GREATER_REWARDS_REWARDS",
	"CRUSADE.TEXT_NORMALBUTTON_7_YOU_CAN_ALSO_GET_DRAGONSCALE_COINS_FROM_THE_CHEST_WITH_THE_FIRST_RESET_OF_THE_EXPEDITION_DRAGONSCALE_COINS",
	"",
	"",
]


# 规则页层（全屏遮罩 + 背景框 + VBox 17 条规则文本，照源 initRuleLayer + crusadeconfig ruleLayer 配置）。
static func build_rule_layer(container: Control, cm: Variant, on_close: Callable) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(layer)
	# 黑色半透明遮罩（照源 layerColor ccc4(0,0,0,190)），点击关闭
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, RULE_SHADE_ALPHA)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			on_close.call())
	layer.add_child(shade)
	# 背景框（照源 ruleInfo Scale9Sprite main_vit_tips.png，居中）
	var frame_pos: Vector2 = (VIEWPORT_SIZE - RULE_FRAME_SIZE) * 0.5
	var frame := NinePatchRect.new()
	if ResourceLoader.exists(RULE_FRAME_RES):
		frame.texture = load(RULE_FRAME_RES) as Texture2D
	frame.position = frame_pos
	frame.size = RULE_FRAME_SIZE
	frame.patch_margin_left = RULE_FRAME_CAP
	frame.patch_margin_top = RULE_FRAME_CAP
	frame.patch_margin_right = RULE_FRAME_CAP
	frame.patch_margin_bottom = RULE_FRAME_CAP
	layer.add_child(frame)
	# ScrollContainer + VBox（照源 listview 竖排 17 项）
	var scroll := ScrollContainer.new()
	scroll.position = frame_pos + Vector2(20.0, 20.0)
	scroll.size = RULE_FRAME_SIZE - Vector2(40.0, 40.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	# 17 条规则文本（照源 initRuleLayer 顺序）
	for key in RULE_LSTR_KEYS:
		if key == "":
			var sep := Control.new()
			sep.custom_minimum_size = Vector2(0.0, RULE_SEP_HEIGHT)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(sep)
		else:
			var raw: String = cm.get_lstr(key)
			var text: String = strip_text_tag(raw)
			var lbl := Label.new()
			lbl.text = text
			lbl.add_theme_font_size_override("font_size", RULE_LABEL_FONT_SIZE)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(lbl)
	return layer


# strip <text|xxx|> 富文本标记前缀（源 LSTR 带 dark_white/normalButton 样式标记，本项目 Label 纯文本）。
static func strip_text_tag(raw: String) -> String:
	var s := raw
	var idx := s.find("|")
	if idx != -1:
		var idx2 := s.find("|", idx + 1)
		if idx2 != -1:
			s = s.substr(idx2 + 1)
	return s
