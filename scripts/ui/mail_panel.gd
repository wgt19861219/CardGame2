class_name MailPanel
extends PopWindow

## 信箱列表面板（View 层）— 照源 ui/mailbox.lua create:594 + createListLayer:251 + createMail:445。
## frame + close + title_bg + 「信箱」+ 邮件列表（ScrollContainer+VBox，单封 bg+icon+name+from+date）。
## 点击单封 → MailDetailPanel。单机化：源 draglist 自定义滚动 → ScrollContainer；联机 get_maillist → MailData 本地。
##
## 重构（2026-07-17，hero_detail 范式）：chrome（frame/title_bg/title/close/scroll）静态化进
## scenes/ui/mail_content.tscn（位置/size 编辑器可视化调）；邮件行（bg+icon+labels）数量随邮件变，
## 保留 procedural 挂 %MailList。源 cocos(800×480 左下) → Godot(960×640 左上)：(cx+80, 560-cy)，
## 纹理显示=纹理/CS（源 hello.lua:311 setContentScaleFactor(615/480)=1.28125，无 fix 时）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/mail_content.tscn")
# P1（2026-07-16）：UI 文案 cm.get_lstr 化（源 LSTR key，GameData.config 解析，fallback 中文兜底）。
const LSTR_TITLE_KEY: String = "MAILBOX.MAILBOX"
const TITLE_FALLBACK: String = "信箱"
const LSTR_FROM_KEY: String = "MAILBOX.FROM_"
const FROM_FALLBACK: String = "发件人："
const READ_BG_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_maillist_read_bg.png"
const UNREAD_BG_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_maillist_unread_bg.png"
const ROW_SIZE: Vector2 = Vector2(340.0, 90.0)
const ICON_SIZE: Vector2 = Vector2(40.0, 40.0)
const NAME_FONT: int = 20
const SMALL_FONT: int = 18
const ICON_BG_DEFAULT: String = "res://assets/ui/alpha/HVGA/task_icon_bg.png"
const ICON_BG_SIZE: Vector2 = Vector2(50.0, 50.0)
const ICON_BG_POS: Vector2 = Vector2(10.0, 15.0)
const ICON_FRAME_TEX: String = "res://assets/ui/alpha/HVGA/gocha.png"
const ICON_FRAME_SIZE: Vector2 = Vector2(50.0, 50.0)
const ICON_FRAME_POS: Vector2 = Vector2(10.0, 15.0)
const NAME_COLOR: Color = Color(67.0 / 255.0, 59.0 / 255.0, 56.0 / 255.0)
const FROM_COLOR: Color = Color(138.0 / 255.0, 56.0 / 255.0, 1.0 / 255.0)
const DATE_COLOR: Color = Color(157.0 / 255.0, 117.0 / 255.0, 89.0 / 255.0)
# 源 mailbox.lua:126-132 行 press setScale(0.95)（press→缩 0.95，release→回弹 1.0）。
const ROW_PRESS_SCALE: Vector2 = Vector2(0.95, 0.95)
const ROW_PRESS_SEC: float = 0.1
# P1 源 mailbox.lua:257-258 mailbox_mask_up/down 渐变遮罩（list 顶/底淡出）。
const MAIL_MASK_UP_RES: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_mask_up.png"
const MAIL_MASK_DOWN_RES: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_mask_down.png"
const MailDetailPanel = preload("res://scripts/ui/mail_detail_panel.gd")

var pd: PlayerData
var _mail_list: VBoxContainer = null   # .tscn %MailList（邮件行容器）


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = GameData.config
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


func setup_panel(p_pd: PlayerData) -> void:
	pd = p_pd
	setup()
	_build_content()


# 建 UI 内容：chrome 静态节点从 .tscn instantiate（位置/size 可视化），邮件行 procedural 挂 %MailList。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	_mail_list = content.get_node("%MailList") as VBoxContainer
	(content.get_node("%Title") as Label).text = _lstr(LSTR_TITLE_KEY, TITLE_FALLBACK)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	_add_scroll_masks(content)   # P1 源 mailbox.lua:257-258 顶/底渐变遮罩
	for mail in pd.mailbox.ordered_mails():
		_add_mail_row(mail)


# P1 源 mailbox.lua:257-258 mailbox_mask_up/down 渐变遮罩：list 顶/底内容淡出。
# 挂 content 根（MailScroll 之上，z 高），覆盖 ScrollContainer 上下边缘。
func _add_scroll_masks(content: Control) -> void:
	var scroll: ScrollContainer = content.get_node("%MailScroll") as ScrollContainer
	var scroll_rect: Rect2 = scroll.get_rect()
	# up mask：贴 ScrollContainer 顶部，宽度=scroll 宽，高度=纹理显示高。
	_add_mask(content, MAIL_MASK_UP_RES, Vector2(scroll_rect.position.x, scroll_rect.position.y), scroll_rect.size.x)
	var up_size: Vector2 = TexDisplaySize.display_size(MAIL_MASK_UP_RES) if ResourceLoader.exists(MAIL_MASK_UP_RES) else Vector2(360.0, 20.0)
	# down mask：贴底部（源 downShade 实为 mask_up 复用是源 bug，本项目用正确 mask_down）。
	_add_mask(content, MAIL_MASK_DOWN_RES, Vector2(scroll_rect.position.x, scroll_rect.position.y + scroll_rect.size.y - up_size.y), scroll_rect.size.x)


func _add_mask(content: Control, res_path: String, pos: Vector2, width: float) -> void:
	if not ResourceLoader.exists(res_path):
		return
	var mask := TextureRect.new()
	mask.texture = load(res_path) as Texture2D
	mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var sz: Vector2 = TexDisplaySize.display_size(res_path)
	mask.size = Vector2(width, sz.y)
	mask.position = pos
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(mask)


# bg 源 :460-469 Sprite mediate（行居中）；本项目用 Button+StyleBoxTexture（点击区+九宫格视觉等价）。
# icon 三分支（:556 iconid 装备 / :563 iconres+frame / 无 icon）。
func _add_mail_row(mail: Dictionary) -> void:
	var row := Button.new()
	row.custom_minimum_size = ROW_SIZE
	row.size = ROW_SIZE
	# pivot 居中：源行 anchor(0.5,0.5) 按中心 setScale → Godot Control scale 绕 pivot_offset。
	row.pivot_offset = ROW_SIZE * 0.5
	var bg_tex: Texture2D = load(UNREAD_BG_TEX if String(mail["status"]) == "unread" else READ_BG_TEX)
	var sb := StyleBoxTexture.new()
	sb.texture = bg_tex
	row.add_theme_stylebox_override("normal", sb)
	row.add_theme_stylebox_override("hover", sb)
	row.add_theme_stylebox_override("pressed", sb)
	var icon_bg := TextureRect.new()
	icon_bg.texture = load(String(mail.get("iconbg", ICON_BG_DEFAULT)))
	icon_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_bg.size = ICON_BG_SIZE
	icon_bg.position = ICON_BG_POS
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_bg)
	var iconid: int = int(mail.get("iconid", 0))
	if iconid > 0:
		var equip_icon: Control = ReadequipIcon.create_icon(iconid, 1, pd.cm)
		equip_icon.position = Vector2(15, 20)
		equip_icon.scale = Vector2(0.65, 0.65)
		row.add_child(equip_icon)
	elif mail.has("iconres") and String(mail["iconres"]).length() > 0:
		var icon_frame := TextureRect.new()
		icon_frame.texture = load(ICON_FRAME_TEX)
		icon_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_frame.size = ICON_FRAME_SIZE
		icon_frame.position = ICON_FRAME_POS
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_frame)
		var icon := TextureRect.new()
		icon.texture = load(String(mail["iconres"]))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = ICON_SIZE
		icon.position = Vector2(15, 25)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var name_l := Label.new()
	name_l.text = String(mail["name"])
	name_l.position = Vector2(70, 12)
	name_l.size = Vector2(250, 24)
	name_l.add_theme_font_size_override("font", NAME_FONT)
	name_l.add_theme_color_override("font_color", NAME_COLOR)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_l)
	var from_l := Label.new()
	from_l.text = _lstr(LSTR_FROM_KEY, FROM_FALLBACK) + " " + String(mail["from"])
	from_l.position = Vector2(70, 38)
	from_l.size = Vector2(250, 20)
	from_l.add_theme_font_size_override("font", SMALL_FONT)
	from_l.add_theme_color_override("font_color", FROM_COLOR)
	from_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(from_l)
	var date_l := Label.new()
	date_l.text = String(mail["date"])
	date_l.position = Vector2(70, 60)
	date_l.size = Vector2(250, 20)
	date_l.add_theme_font_size_override("font", SMALL_FONT)
	date_l.add_theme_color_override("font_color", DATE_COLOR)
	date_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(date_l)
	row.pressed.connect(_on_mail_clicked.bind(int(mail["id"])))
	# 源 mailbox.lua:126-132 行 press setScale(0.95)：button_down→缩，button_up→回弹。
	row.button_down.connect(_tween_row_scale.bind(row, ROW_PRESS_SCALE))
	row.button_up.connect(_tween_row_scale.bind(row, Vector2.ONE))
	_mail_list.add_child(row)


# 行按下/松开 scale Tween（源 mailbox.lua:126-132 setScale 0.95 视觉反馈）。
func _tween_row_scale(row: Button, target: Vector2) -> void:
	if not is_instance_valid(row):
		return
	var tw: Tween = create_tween()
	tw.tween_property(row, "scale", target, ROW_PRESS_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_mail_clicked(mail_id: int) -> void:
	var detail := MailDetailPanel.new("mail_detail", {})
	detail.setup_panel(pd, mail_id, _on_detail_closed)
	detail.show_window(get_parent())


# 详情关闭后刷新列表（领取后 status/附件变化）。
func _on_detail_closed() -> void:
	for c in _mail_list.get_children():
		c.free()
	for mail in pd.mailbox.ordered_mails():
		_add_mail_row(mail)
