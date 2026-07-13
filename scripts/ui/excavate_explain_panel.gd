class_name ExcavateExplainPanel
extends PopWindow

## 藏宝地穴玩法说明（View 层）— 照源 ui/popwindow/excavateexplain.lua createContent:4。
## 纯文本（背景故事 + 10 条规则，LSTR EXCAVATEEXPLAIN.* 照译）。无联机依赖，直接复用。
## 联机相关条（保护期/被攻击/邀请公会）单机化裁剪机制，但说明文本照源保留。

const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_frame.png"
const CLOSE_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_P_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const TITLE_TEXT: String = "藏宝地穴说明"
const COLOR_STORY: Color = Color(1.0, 1.0, 221.0 / 255.0)   # 源 ccc3(255,255,221) 故事段
const COLOR_RULE: Color = Color(238.0 / 255.0, 204.0 / 255.0, 119.0 / 255.0)  # 源 ccc3(238,204,119) 规则段
const FONT_SIZE: int = 16    # 源 ed.createttf(v, 16)
const TITLE_FONT: int = 22
const FRAME_W: float = 600.0
const FRAME_H: float = 480.0
const CONTENT_W: float = 500.0

# 背景故事段（照 text_list_1 + text_2 标题，LSTR EXCAVATEEXPLAIN.* 译）
const STORY_LINES: Array[String] = [
	"黑铁矮人的王国在地底建造了错综复杂的洞穴，盘根错节如世界树之根。",
	"但它的历史比世界树本身还要久远。当这些沉睡了百万年的厚重宝藏",
	"重见天日时，探险者们惊喜地发现了黄金与钻石，还有矮人们永不过时的、",
	"纤尘不染的工艺，以及如黄金般永恒的人类的贪婪与掠夺。",
]
const STORY_TITLE: String = "— 安奥巴尔之战"

# 规则段（照 text_list_3，10 条；联机相关条照源保留文本，机制单机裁剪）
const RULE_LINES: Array[String] = [
	"1. 在藏宝地穴中可以发现多种资源点，包括黄金、钻石和实验室。",
	"2. 你可以对资源点发起多次攻击，每次攻击消耗部分能量，并获得对应的战队经验。攻防双方英雄的生命和能量值在所有战斗结束前不会重置。",
	"3. 在限时内击败所有防守者即可占领资源点，占领后将持续产出资源。",
	"4. 新占领的宝藏视类型有保护期，保护期内不会被搜索和攻击。",
	"5. 占领资源点后需派英雄驻防，驻防英雄越多，资源开采越快。",
	"6. 驻防期间英雄不能参加其他战斗，但可以随时替换驻防英雄。",
	"7. 资源点总储量有限，采完后英雄会将所有资源运回你的仓库。",
	"8. 若采集过程中防守失败，可能失去部分资源，已开采的剩余资源将运回仓库。",
	"9. 部分大型资源点可容纳多名防守者共同开采。",
	"10. 藏宝地穴战斗中，驻防英雄会获得部分初始能量。",
]


func setup_panel() -> void:
	setup()
	_build_ui()


func _build_ui() -> void:
	var frame := TextureRect.new()
	frame.texture = load(FRAME_TEX)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # [[texture-rect-expand-ignore-size]]
	frame.size = Vector2(FRAME_W, FRAME_H)
	frame.position = Vector2(960.0 * 0.5 - FRAME_W * 0.5, 640.0 * 0.5 - FRAME_H * 0.5)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	_add_close(frame)
	_add_title(frame)
	_add_content(frame)


func _add_close(frame: TextureRect) -> void:
	var close := TextureButton.new()
	close.texture_normal = load(CLOSE_TEX)
	close.texture_pressed = load(CLOSE_P_TEX)
	close.ignore_texture_size = true
	close.size = Vector2(40, 40)
	close.position = Vector2(frame.size.x - 50, 12)
	close.pressed.connect(remove_window)
	frame.add_child(close)


func _add_title(frame: TextureRect) -> void:
	var label := Label.new()
	label.text = TITLE_TEXT
	label.size = Vector2(frame.size.x, 40)
	label.position = Vector2(0, 15)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font", TITLE_FONT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(label)


func _add_content(frame: TextureRect) -> void:
	var sc := ScrollContainer.new()
	sc.size = Vector2(frame.size.x - 60, frame.size.y - 90)
	sc.position = Vector2(30, 65)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	frame.add_child(sc)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	sc.add_child(vbox)
	for line in STORY_LINES:
		vbox.add_child(_make_label(line, COLOR_STORY))
	vbox.add_child(_make_label(STORY_TITLE, COLOR_STORY, HORIZONTAL_ALIGNMENT_RIGHT))
	for line in RULE_LINES:
		vbox.add_child(_make_label(line, COLOR_RULE))


func _make_label(text: String, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(CONTENT_W, 0)
	l.add_theme_font_size_override("font", FONT_SIZE)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
