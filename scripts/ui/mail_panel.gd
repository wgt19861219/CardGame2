class_name MailPanel
extends PopWindow

## 信箱列表面板（View 层）— 照源 ui/mailbox.lua create:594 + createListLayer:251 + createMail:445。
## frame + close + title_bg + 「信箱」+ 邮件列表（ScrollContainer+VBox，单封 bg+icon+name+from+date）。
## 点击单封 → MailDetailPanel。单机化：源 draglist 自定义滚动 → ScrollContainer；联机 get_maillist → MailData 本地。

# 全局 contentScaleFactor（源 hello.lua:311 setContentScaleFactor(1.28125)）：
# Cocos Sprite 无 fix_size 时显示 = 纹理/CS；Godot TextureRect 用 tex.get_size() 偏大 1.28。
const CONTENT_SCALE: float = 1.28125
const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_frame.png"
const TITLE_BG_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_title_bg.png"
const CLOSE_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_P_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const READ_BG_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_maillist_read_bg.png"
const UNREAD_BG_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_maillist_unread_bg.png"
# P1（2026-07-16）：UI 文案 cm.get_lstr 化（源 LSTR key，GameData.config 解析，fallback 中文兜底）。
const LSTR_TITLE_KEY: String = "MAILBOX.MAILBOX"   # 源 mailbox.lua:662
const TITLE_FALLBACK: String = "信箱"
const LSTR_FROM_KEY: String = "MAILBOX.FROM_"      # 源 mailbox.lua:509 T(LSTR).." "（照源加空格）
const FROM_FALLBACK: String = "发件人："
const ROW_SIZE: Vector2 = Vector2(340.0, 90.0)
const ICON_SIZE: Vector2 = Vector2(40.0, 40.0)
const NAME_FONT: int = 20                # 源 createMail:495 size 20
const SMALL_FONT: int = 18               # 源 createMail:510/538 size 18
const MailDetailPanel = preload("res://scripts/ui/mail_detail_panel.gd")

var pd: PlayerData
var _list_vbox: VBoxContainer


# 源 LSTR 走 GameData.config（autoload）；未初始化（headless 测试）fallback 中文兜底。
func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = GameData.config
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


func setup_panel(p_pd: PlayerData) -> void:
	pd = p_pd
	setup()
	_build_ui()


func _build_ui() -> void:
	var frame_tex: Texture2D = load(FRAME_TEX)
	var frame := TextureRect.new()
	frame.texture = frame_tex
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # [[texture-rect-expand-ignore-size]]
	frame.size = frame_tex.get_size() / CONTENT_SCALE   # 源 mailbox.lua:608 config={} 无 fix
	frame.position = Vector2(960.0 * 0.5 - frame.size.x * 0.5, 640.0 * 0.5 - frame.size.y * 0.5)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	_add_close(frame)
	_add_title(frame)
	_add_list(frame)


func _add_close(frame: TextureRect) -> void:
	var close := TextureButton.new()
	close.texture_normal = load(CLOSE_TEX)
	close.texture_pressed = load(CLOSE_P_TEX)
	close.ignore_texture_size = true
	close.custom_minimum_size = Vector2(40, 40)
	close.size = Vector2(40, 40)
	close.position = Vector2(frame.size.x - 50, 12)
	close.pressed.connect(remove_window)
	frame.add_child(close)


func _add_title(frame: TextureRect) -> void:
	var tb_tex: Texture2D = load(TITLE_BG_TEX)
	var title_bg := TextureRect.new()
	title_bg.texture = tb_tex
	title_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_bg.size = tb_tex.get_size() / CONTENT_SCALE   # 源 mailbox.lua:647 config={} 无 fix
	title_bg.position = Vector2(frame.size.x * 0.5 - title_bg.size.x * 0.5, 10)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title_bg)
	var label := Label.new()
	label.text = _lstr(LSTR_TITLE_KEY, TITLE_FALLBACK)
	label.size = title_bg.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font", 22)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bg.add_child(label)


func _add_list(frame: TextureRect) -> void:
	var sc := ScrollContainer.new()
	sc.size = Vector2(frame.size.x - 40, frame.size.y - 100)
	sc.position = Vector2(20, 60)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	frame.add_child(sc)
	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 6)
	sc.add_child(_list_vbox)
	for mail in pd.mailbox.ordered_mails():
		_add_mail_row(mail)


func _add_mail_row(mail: Dictionary) -> void:
	var row := Button.new()
	row.custom_minimum_size = ROW_SIZE
	row.size = ROW_SIZE
	var bg_tex: Texture2D = load(UNREAD_BG_TEX if String(mail["status"]) == "unread" else READ_BG_TEX)
	var sb := StyleBoxTexture.new()
	sb.texture = bg_tex
	row.add_theme_stylebox_override("normal", sb)
	row.add_theme_stylebox_override("hover", sb)
	row.add_theme_stylebox_override("pressed", sb)
	# P1-17：照源 mailbox.lua:556-588 icon 三分支（iconid 装备/iconres+frame/无 icon）
	var iconid: int = int(mail.get("iconid", 0))
	if iconid > 0:
		# 源 :556 info.iconid → readequip.createIcon（装备图标）
		var equip_icon: Control = ReadequipIcon.create_icon(iconid, 1, pd.cm)
		equip_icon.position = Vector2(15, 20)
		equip_icon.scale = Vector2(0.65, 0.65)
		row.add_child(equip_icon)
	elif mail.has("iconres") and String(mail["iconres"]).length() > 0:
		# 源 :563 info.iconres → icon_frame(gocha) + icon(iconres)
		var icon := TextureRect.new()
		icon.texture = load(String(mail["iconres"]))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = ICON_SIZE
		icon.position = Vector2(15, 25)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	# else：源无 iconid/iconres → 不显示 icon（只 bg）
	var name_l := Label.new()
	name_l.text = String(mail["name"])
	name_l.position = Vector2(70, 12)
	name_l.size = Vector2(250, 24)
	name_l.add_theme_font_size_override("font", NAME_FONT)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_l)
	var from_l := Label.new()
	from_l.text = _lstr(LSTR_FROM_KEY, FROM_FALLBACK) + " " + String(mail["from"])
	from_l.position = Vector2(70, 38)
	from_l.size = Vector2(250, 20)
	from_l.add_theme_font_size_override("font", SMALL_FONT)
	from_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(from_l)
	var date_l := Label.new()
	date_l.text = String(mail["date"])
	date_l.position = Vector2(70, 60)
	date_l.size = Vector2(250, 20)
	date_l.add_theme_font_size_override("font", SMALL_FONT)
	date_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(date_l)
	row.pressed.connect(_on_mail_clicked.bind(int(mail["id"])))
	_list_vbox.add_child(row)


func _on_mail_clicked(mail_id: int) -> void:
	var detail := MailDetailPanel.new("mail_detail", {})
	detail.setup_panel(pd, mail_id, _on_detail_closed)
	detail.show_window(get_parent())


# 详情关闭后刷新列表（领取后 status/附件变化）。
func _on_detail_closed() -> void:
	for c in _list_vbox.get_children():
		c.free()
	for mail in pd.mailbox.ordered_mails():
		_add_mail_row(mail)
