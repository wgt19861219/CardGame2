class_name MailPanel
extends PopWindow

## 信箱列表面板（View 层）— 照源 ui/mailbox.lua create:594 + createListLayer:251 + createMail:445。
## frame + close + title_bg + 「信箱」+ 邮件列表（ScrollContainer+VBox + TopMask/BottomMask）。
## 点击单封 → MailDetailPanel。单机化：源 draglist 自定义滚动 → ScrollContainer；联机
## get_maillist → MailData 本地。
##
## 批 2 两件套改造（2026-08-16，star_shop 范式）：chrome 静态化进 scenes/ui/mail_content.tscn
## （frame/title/close/scroll/上下渐变遮罩 rect 固化）；邮件行走 mail_item.tscn 行模板
## （createMail:445-592 行结构直译），panel 仅 fill（bg un/read 换图、icon 三分支、
## name/from/date 文案）+ press setScale(0.95) 反馈。
## 源 cocos(800×480 左下) → Godot(800×480 左上)：(cx, 480-cy)，显示尺寸=纹理px/CS(1.28125)。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/mail_content.tscn")
const ITEM_SCENE: PackedScene = preload("res://scenes/ui/mail_item.tscn")
const MailDetailPanel = preload("res://scripts/ui/mail_detail_panel.gd")
# 显示尺寸换算 CS（源 hello.lua:311 setContentScaleFactor(615/480)）
const CS: float = 1.28125
# P1（2026-07-16）：UI 文案 cm.get_lstr 化（源 LSTR key，GameData.config 解析，fallback 中文兜底）。
const LSTR_TITLE_KEY: String = "MAILBOX.MAILBOX"
const TITLE_FALLBACK: String = "信箱"
const LSTR_FROM_KEY: String = "MAILBOX.FROM_"
const FROM_FALLBACK: String = "发件人："
const READ_BG_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_maillist_read_bg.png"
const UNREAD_BG_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_maillist_unread_bg.png"
# 行内 icon 等比显示（源 createMail 无 fix_wh → 显示=纹理px/CS）
const ICON_BG_CENTER: Vector2 = Vector2(45.0, 45.0)
# 装备 icon（源 mailbox.lua:559-561 createIcon(iconid) 无 length 无 setScale → 显示原
# 尺寸 94/CS≈73.37，与同行 IconBg 同宽；中心 (45,46)。产物 container 72 居中于 EquipHost
# 中心 (45,44) → position = (45,44)-(36,36)-(21.6,20.6)。2026-08-22 巡检修订：旧 scale 0.65
# 缩到 47.7 比源小 35% 且无源依据）。
const EQUIP_ICON_LOCAL: Vector2 = Vector2(-12.6, -12.6)
# 源 mailbox.lua:126-132 行 press setScale(0.95)（press→缩 0.95，release→回弹 1.0）。
const ROW_PRESS_SCALE: Vector2 = Vector2(0.95, 0.95)
const ROW_PRESS_SEC: float = 0.1

var pd: PlayerData
var _mail_list: VBoxContainer = null   # .tscn %MailList（邮件行容器）


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = GameData.config
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


func setup_panel(p_pd: PlayerData) -> void:
	pd = p_pd
	setup()   # HUD 版式不随弹窗切（源 mail z=160 scene 级盖 HUD，通用遮蔽接管，2026-09-08）
	_build_content()


# 建 UI：chrome 从 .tscn instantiate（rect 固化），邮件行走 mail_item.tscn 模板 fill。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	_mail_list = content.get_node("%MailList") as VBoxContainer
	(content.get_node("%Title") as Label).text = _lstr(LSTR_TITLE_KEY, TITLE_FALLBACK)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	for mail in pd.mailbox.ordered_mails():
		_add_mail_row(mail)


# 邮件行装配（源 createMail:445-592）：模板实例 + fill。icon 三分支（:556 iconid 装备 /
# :563 iconres+frame / 无 icon）；bg un/read 换 texture_normal。
func _add_mail_row(mail: Dictionary) -> void:
	var row := ITEM_SCENE.instantiate() as TextureButton
	var is_unread: bool = String(mail["status"]) == "unread"
	row.texture_normal = load(UNREAD_BG_TEX if is_unread else READ_BG_TEX) as Texture2D
	_fill_icon(row, mail)
	(row.get_node("%Name") as Label).text = String(mail["name"])
	(row.get_node("%FromTitle") as Label).text = _lstr(LSTR_FROM_KEY, FROM_FALLBACK) + " "
	(row.get_node("%From") as Label).text = String(mail["from"])
	(row.get_node("%Date") as Label).text = String(mail["date"])
	row.pressed.connect(_on_mail_clicked.bind(int(mail["id"])))
	# 源 mailbox.lua:126-132 行 press setScale(0.95)：button_down→缩，button_up→回弹。
	row.button_down.connect(_tween_row_scale.bind(row, ROW_PRESS_SCALE))
	row.button_up.connect(_tween_row_scale.bind(row, Vector2.ONE))
	_mail_list.add_child(row)


# icon 三分支 fill（源 :556-588）：iconid>0 装备 icon / iconres 信封+框（read 态换 open 图）。
func _fill_icon(row: TextureButton, mail: Dictionary) -> void:
	# icon_bg：fill 换装备形状框（getShapeFrameRes）或默认 task_icon_bg，等比显示=纹理px/CS
	var icon_bg: TextureRect = row.get_node("%IconBg") as TextureRect
	icon_bg.texture = load(String(mail.get("iconbg", ""))) as Texture2D
	var bg_size: Vector2 = icon_bg.texture.get_size() / CS
	icon_bg.size = bg_size
	icon_bg.position = ICON_BG_CENTER - bg_size * 0.5
	var iconid: int = int(mail.get("iconid", 0))
	if iconid > 0:
		var equip_icon: Control = ReadequipIcon.create_icon(iconid, 1, pd.cm)
		equip_icon.position = EQUIP_ICON_LOCAL
		equip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		(row.get_node("%EquipHost") as Control).add_child(equip_icon)
		(row.get_node("%EquipHost") as CanvasItem).visible = true
	elif mail.has("iconres") and String(mail["iconres"]).length() > 0:
		(row.get_node("%IconFrame") as CanvasItem).visible = true
		var letter: TextureRect = row.get_node("%LetterIcon") as TextureRect
		letter.texture = load(String(mail["iconres"])) as Texture2D
		letter.visible = true


# 行按下/松开 scale Tween（源 mailbox.lua:126-132 setScale 0.95 视觉反馈）。
func _tween_row_scale(row: TextureButton, target: Vector2) -> void:
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
