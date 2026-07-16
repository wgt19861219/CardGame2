class_name MailDetailPanel
extends PopWindow

## 邮件详情面板（View 层）— 照源 ui/mail/content.lua create:385 + createContent:277 + doReadMail:494。
## frame（mailbox_letter_bg）+ ok 按钮（领取/关闭）+ title/body/from + splitLine + attach（common 货币）。
## ok 点击：未读+有附件 → claim_attach；未读无附件 → mark_read；已读 → 关闭。单机化裁源 read_mail 联机。

const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_letter_bg.png"
const SPLIT_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_letter_delimeter.png"
const OK_TEX: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const OK_P_TEX: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const GOLD_ICON: String = "res://assets/ui/alpha/HVGA/goldicon_small.png"
const DIAMOND_ICON: String = "res://assets/ui/alpha/HVGA/shop_token_icon.png"
# P1-2026-07-10：照源 content.lua:162-171 createCommonAttach 7 种货币图标映射
const CURRENCY_ICONS: Dictionary = {
	"Gold": "res://assets/ui/alpha/HVGA/goldicon_small.png",
	"Diamond": "res://assets/ui/alpha/HVGA/shop_token_icon.png",
	"Exp": "res://assets/ui/alpha/HVGA/task_exp_icon_2.png",
	"CrusadeMoney": "res://assets/ui/alpha/HVGA/money_dragonscale_big.png",
	"PvpMoney": "res://assets/ui/alpha/HVGA/money_arenatoken_big.png",
	"GuildMoney": "res://assets/ui/alpha/HVGA/money_guildtoken_big.png",
	"SkillPoint": "res://assets/ui/alpha/HVGA/herodetail_skill_upgrade_button_1.png",
}
const ITEM_ICON_COLS: int = 4   # 源 createItemAttach :140 4 列网格
const ITEM_ICON_SIZE: float = 65.0  # 源 :137 icon_len=65
# P1（2026-07-16）：UI 文案 cm.get_lstr 化（源 LSTR key，GameData.config 解析，fallback 中文兜底）。
const LSTR_ATTACH_KEY: String = "MAILBOX.ATTACHMENTS_"   # 源 content.lua:239
const ATTACH_FALLBACK: String = "附件"
const LSTR_CLAIM_KEY: String = "MAILBOX.CLAIM"           # 源 content.lua:463
const CLAIM_FALLBACK: String = "领取"
const LSTR_CLOSE_KEY: String = "MAILBOX.CLOSE"           # 源 content.lua:463
const CLOSE_FALLBACK: String = "关闭"
const TITLE_FONT: int = 18              # 源 createTitle:26
const BODY_FONT: int = 16               # 源 createBody:56
# P1-4：照源 content.lua 装饰背景 + 文字颜色（ccc3→from_rgba8 忠实 0-255 色值）
const TITLE_BG_TEX: String = "res://assets/ui/alpha/HVGA/equip_craft_money_bg.png"  # 源 createTitle:13
const ATTACH_BG_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_letter_addon_bg.png"  # 源 createAttach:226
const TITLE_COLOR: Color = Color(172.0 / 255.0, 75.0 / 255.0, 30.0 / 255.0)       # 源 createTitle:32 ccc3
const BODY_COLOR: Color = Color(162.0 / 255.0, 88.0 / 255.0, 41.0 / 255.0)        # 源 createBody:64 / createFrom:106
const ATTACH_TITLE_COLOR: Color = Color(152.0 / 255.0, 98.0 / 255.0, 34.0 / 255.0)  # 源 createAttach:247
const AMOUNT_COLOR: Color = Color(129.0 / 255.0, 61.0 / 255.0, 22.0 / 255.0)      # 源 createCommonAttach:206
const CURRENCY_ICON_H: float = 25.0  # 源 createCommonAttach:188 fix_height=25
const AMOUNT_FONT: int = 18               # 源 createCommonAttach:195 amount size=18
const ATTACH_BG_W: float = 300.0     # 源 createAttach:273 setContentSize width=300

var pd: PlayerData
var _mail_id: int = 0
var _mail: Dictionary
var _on_closed: Callable


# 源 LSTR 走 GameData.config（autoload）；未初始化（headless 测试）fallback 中文兜底。
func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = GameData.config
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


func setup_panel(p_pd: PlayerData, mail_id: int, on_closed: Callable) -> void:
	pd = p_pd
	_mail_id = mail_id
	_on_closed = on_closed
	_mail = pd.mailbox.get_mail(mail_id)
	setup()
	_build_ui()


func _build_ui() -> void:
	var frame_tex: Texture2D = load(FRAME_TEX)
	var frame := TextureRect.new()
	frame.texture = frame_tex
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # [[texture-rect-expand-ignore-size]]
	frame.size = frame_tex.get_size()
	frame.position = Vector2(960.0 * 0.5 - frame.size.x * 0.5, 640.0 * 0.5 - frame.size.y * 0.5)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	_add_content(frame)
	_add_ok_button(frame)


func _add_content(frame: TextureRect) -> void:
	var y: float = 30.0
	# P1-4：title_bg 装饰背景（源 createTitle :9-20 equip_craft_money_bg @165,y width 300）
	var title_bg := TextureRect.new()
	title_bg.texture = load(TITLE_BG_TEX)
	title_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_bg.size = Vector2(ATTACH_BG_W, 28.0)
	title_bg.position = Vector2(frame.size.x * 0.5 - ATTACH_BG_W * 0.5, y - 4.0)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title_bg)
	var title := Label.new()
	title.text = String(_mail.get("name", ""))
	title.position = Vector2(30, y)
	title.size = Vector2(frame.size.x - 60, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font", TITLE_FONT)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title)
	y += 32.0
	var body := Label.new()
	body.text = String(_mail.get("content", ""))
	body.position = Vector2(30, y)
	body.size = Vector2(frame.size.x - 60, 80)
	body.add_theme_font_size_override("font", BODY_FONT)
	body.add_theme_color_override("font_color", BODY_COLOR)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(body)
	y += 88.0
	var from := Label.new()
	# 源 content.lua createFrom:98 text=self.from（无「发件人：」前缀，前缀只在 mailbox.lua 列表 from_title）。
	from.text = String(_mail.get("from", ""))
	from.position = Vector2(30, y)
	from.size = Vector2(frame.size.x - 60, 20)
	from.add_theme_font_size_override("font", BODY_FONT)
	from.add_theme_color_override("font_color", BODY_COLOR)
	from.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(from)
	y += 30.0
	if bool(_mail.get("attached", false)):
		var split := TextureRect.new()
		split.texture = load(SPLIT_TEX)
		split.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		split.size = split.texture.get_size()
		split.position = Vector2(frame.size.x * 0.5 - split.size.x * 0.5, y)
		split.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(split)
		y += 24.0
		_add_attach(frame, y)


# 附件区（照源 createAttach:216-275 + createCommonAttach:162-214 + createItemAttach:135-160）。
# P1-4：attach_bg 装饰背景 + attach_common 数组忠实源数据结构（type 查 7 货币图标）。
func _add_attach(frame: TextureRect, y: float) -> void:
	# attach_bg（源 createAttach :221-234 mailbox_letter_addon_bg @20,y width 300），先 add z 低
	var attach_bg := TextureRect.new()
	attach_bg.texture = load(ATTACH_BG_TEX)
	attach_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	attach_bg.position = Vector2(20.0, y)
	attach_bg.size = Vector2(ATTACH_BG_W, 0.0)   # 高度待设（源 :273 setContentSize(300, bh)）
	attach_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(attach_bg)
	var top_y: float = y
	# attach_title（源 :235-249 "附件" @30,y-15 color ATTACH_TITLE_COLOR）
	var head := Label.new()
	head.text = _lstr(LSTR_ATTACH_KEY, ATTACH_FALLBACK)
	head.position = Vector2(30, y + 2.0)
	head.size = Vector2(100, 20)
	head.add_theme_font_size_override("font", BODY_FONT)
	head.add_theme_color_override("font_color", ATTACH_TITLE_COLOR)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(head)
	var cy: float = y + 30.0   # 源 :252 y=y-30
	# 货币附件（源 createCommonAttach :162-214，遍历 attach_common 按 type 查 CURRENCY_ICONS）
	for entry in _mail.get("attach_common", []):
		var ctype: String = str(entry.get("type", ""))
		var camount: int = int(entry.get("amount", 0))
		if camount <= 0:
			continue
		var icon_path: String = CURRENCY_ICONS.get(ctype, GOLD_ICON)
		cy = _add_currency(frame, cy, icon_path, camount)
	# 装备/物品附件（源 createItemAttach :135-160，4 列网格）
	var items: Array = _mail.get("items", [])
	if not items.is_empty():
		cy = _add_item_attach(frame, cy, items)
	attach_bg.size = Vector2(ATTACH_BG_W, cy - top_y)   # 源 :273 bh=oy-y


# 源 createItemAttach :135-160：4 列装备网格（readequip.createIconWithAmount）。
func _add_item_attach(frame: TextureRect, y: float, items: Array) -> float:
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var item_id: int = int(item.get("id", 0))
		var amount: int = int(item.get("amount", 1))
		if item_id == 0:
			continue
		var col: int = i % ITEM_ICON_COLS
		var row: int = int(i / ITEM_ICON_COLS)
		var icon: Control = ReadequipIcon.create_icon(item_id, amount, pd.cm)
		icon.scale = Vector2(0.85, 0.85)  # 源 :150 createIcon(id, 60) 缩放到 60/72≈0.85
		icon.position = Vector2(34.0 + float(col) * ITEM_ICON_SIZE, y + float(row) * ITEM_ICON_SIZE)
		frame.add_child(icon)
	var rows: int = ceili(float(items.size()) / float(ITEM_ICON_COLS))
	return y + float(rows) * ITEM_ICON_SIZE


func _add_currency(frame: TextureRect, y: float, icon_path: String, amount: int) -> float:
	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(CURRENCY_ICON_H, CURRENCY_ICON_H)   # 源 :188 fix_height=25
	icon.position = Vector2(40, y)   # 源 :186 ccp(40, y)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	var lbl := Label.new()
	lbl.text = "x%d" % amount
	lbl.position = Vector2(40.0 + CURRENCY_ICON_H + 8.0, y)   # 源 right2 icon offset 20
	lbl.size = Vector2(100, CURRENCY_ICON_H)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font", AMOUNT_FONT)   # 源 :195 size=18
	lbl.add_theme_color_override("font_color", AMOUNT_COLOR)   # 源 :206 ccc3(129,61,22)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(lbl)
	return y + 30.0   # 源 :211 y=y-30


func _add_ok_button(frame: TextureRect) -> void:
	var ok := TextureButton.new()
	ok.texture_normal = load(OK_TEX)
	ok.texture_pressed = load(OK_P_TEX)
	ok.ignore_texture_size = true
	ok.custom_minimum_size = Vector2(165, 45)
	ok.size = Vector2(165, 45)
	ok.position = Vector2(frame.size.x * 0.5 - 82, frame.size.y - 60)
	var lbl := Label.new()
	var has_attach: bool = bool(_mail.get("attached", false))
	var is_unread: bool = String(_mail.get("status", "")) == "unread"
	lbl.text = _lstr(LSTR_CLAIM_KEY, CLAIM_FALLBACK) if (is_unread and has_attach) else _lstr(LSTR_CLOSE_KEY, CLOSE_FALLBACK)
	lbl.size = ok.size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ok.add_child(lbl)
	ok.pressed.connect(_on_ok)
	frame.add_child(ok)


# ok（照 doClickRead:483 + doReadMail:494-531）：未读+附件 → claim（+overfull 检查）；未读 → mark_read；已读 → 关闭。
# P1-4：overfull 改弹 MailOverfullPopup（替 Toast 降级，忠实源 overfull.lua 弹窗）。
func _on_ok() -> void:
	var has_attach: bool = bool(_mail.get("attached", false))
	var is_unread: bool = String(_mail.get("status", "")) == "unread"
	if is_unread and has_attach:
		var overfull: Array = _check_overfull()
		if not overfull.is_empty():
			# 源 :525-531 ed.ui.mailoverfull.pop（leftCallback → doRead 领取）
			var popup := MailOverfullPopup.new()
			popup.setup(overfull, pd.cm)
			popup.confirmed.connect(_on_overfull_confirmed)
			container.add_child(popup)
			return
		_claim_and_close()
	elif is_unread:
		pd.mailbox.mark_read(_mail_id)
		_close()


# overfull 检查（源 doReadMail :511-521）：物品 + 当前持有 > 上限 → {id, amount=溢出量 da}。
func _check_overfull() -> Array:
	var overfull: Array = []
	for item in _mail.get("items", []):
		var item_id: int = int(item.get("id", 0))
		var amount: int = int(item.get("amount", 1))
		if item_id == 0:
			continue
		var cur: int = int(pd.items.get(item_id, 0))
		var da: int = cur + amount - PlayerData.MAX_ITEMS_PER_SLOT   # 源 :517 da=ca+amount-max
		if da > 0:
			overfull.append({"id": item_id, "amount": da})
	return overfull


# overfull「强行领取」（源 overfull.lua:10-16 leftCallback → doRead 领取 + destroy）。
func _on_overfull_confirmed() -> void:
	_claim_and_close()


func _claim_and_close() -> void:
	pd.mailbox.claim_attach(_mail_id, pd)
	_close()


func _close() -> void:
	remove_window()
	if _on_closed.is_valid():
		_on_closed.call()
