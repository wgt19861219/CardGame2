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
const LSTR_TITLE_KEY: String = "MAILBOX.MAILBOX"   # 源 mailbox.lua:662
const TITLE_FALLBACK: String = "信箱"
const LSTR_FROM_KEY: String = "MAILBOX.FROM_"      # 源 mailbox.lua:509 T(LSTR).." "（照源加空格）
const FROM_FALLBACK: String = "发件人："
const READ_BG_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_maillist_read_bg.png"
const UNREAD_BG_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_maillist_unread_bg.png"
const ROW_SIZE: Vector2 = Vector2(340.0, 90.0)   # 源 createMail:451 board setContentSize(340, 90)
const ICON_SIZE: Vector2 = Vector2(40.0, 40.0)
const NAME_FONT: int = 20                # 源 createMail:495 size 20
const SMALL_FONT: int = 18               # 源 createMail:510/538 size 18
const MailDetailPanel = preload("res://scripts/ui/mail_detail_panel.gd")

var pd: PlayerData
var _mail_list: VBoxContainer = null   # .tscn %MailList（邮件行容器）


# 源 LSTR 走 GameData.config（autoload）；未初始化（headless 测试）fallback 中文兜底。
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
# 源 create:594 + createListLayer:251。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	_mail_list = content.get_node("%MailList") as VBoxContainer
	(content.get_node("%Title") as Label).text = _lstr(LSTR_TITLE_KEY, TITLE_FALLBACK)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	for mail in pd.mailbox.ordered_mails():
		_add_mail_row(mail)


# 源 createMail:445：单封邮件行（Button + StyleBoxTexture bg + icon + name/from/date Label）。
# bg 源 :460-469 Sprite mediate（行居中）；本项目用 Button+StyleBoxTexture（点击区+九宫格视觉等价）。
# icon 三分支（:556 iconid 装备 / :563 iconres+frame / 无 icon）。
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
	_mail_list.add_child(row)


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
