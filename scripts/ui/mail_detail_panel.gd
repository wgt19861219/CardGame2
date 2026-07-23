class_name MailDetailPanel
extends PopWindow

## 邮件详情面板（View 层）— 照源 ui/mail/content.lua create:385 + createContent:277 + doReadMail:494。
## frame（mailbox_letter_bg）+ ok 按钮（领取/关闭）+ title/body/from + splitLine + attach（common 货币）。
## ok 点击：未读+有附件 → claim_attach；未读无附件 → mark_read；已读 → 关闭。单机化裁源 read_mail 联机。
##
## 重构（2026-07-18，hero_detail 范式）：chrome（frame/title_bg/title/body/from/split/ok）静态化进
## scenes/ui/mail_detail_content.tscn（位置/size 编辑器可视化调）；附件区（attach_bg/currency/items）
## 数量随邮件变，保留 procedural 挂 %AttachHost（pos=0,0 保持 frame 局部坐标系不变）。
## 源 cocos(800×480 左下) → Godot(960×640 左上)：纹理显示=纹理/CS（源 hello.lua:311
## setContentScaleFactor(615/480)=1.28125，无 fix 时），frame size/位置已预计算固化进 .tscn。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/mail_detail_content.tscn")
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
const GOLD_ICON: String = "res://assets/ui/alpha/HVGA/goldicon_small.png"
const ITEM_ICON_COLS: int = 4   # 源 createItemAttach :140 4 列网格
const ITEM_ICON_SIZE: float = 65.0  # 源 :137 icon_len=65
# P1（2026-07-16）：UI 文案 cm.get_lstr 化（源 LSTR key，GameData.config 解析，fallback 中文兜底）。
const LSTR_ATTACH_KEY: String = "MAILBOX.ATTACHMENTS_"   # 源 content.lua:239
const ATTACH_FALLBACK: String = "附件"
const LSTR_CLAIM_KEY: String = "MAILBOX.CLAIM"           # 源 content.lua:463
const CLAIM_FALLBACK: String = "领取"
const LSTR_CLOSE_KEY: String = "MAILBOX.CLOSE"           # 源 content.lua:463
const CLOSE_FALLBACK: String = "关闭"
const BODY_FONT: int = 16               # 源 createBody:56 / createFrom:106 / attach head
# P1-4：照源 content.lua 装饰背景 + 文字颜色（ccc3→from_rgba8 忠实 0-255 色值）
const ATTACH_BG_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_letter_addon_bg.png"  # 源 createAttach:226
# title_bg 装饰背景路径（测试引用）；纹理已静态化进 .tscn TitleBg。
const TITLE_BG_TEX: String = "res://assets/ui/alpha/HVGA/equip_craft_money_bg.png"
const ATTACH_TITLE_COLOR: Color = Color(152.0 / 255.0, 98.0 / 255.0, 34.0 / 255.0)  # 源 createAttach:247
const AMOUNT_COLOR: Color = Color(129.0 / 255.0, 61.0 / 255.0, 22.0 / 255.0)      # 源 createCommonAttach:206
const CURRENCY_ICON_H: float = 25.0  # 源 createCommonAttach:188 fix_height=25
const AMOUNT_FONT: int = 18               # 源 createCommonAttach:195 amount size=18
const ATTACH_BG_W: float = 300.0     # 源 createAttach:273 setContentSize width=300
# 附件区起始 y（源 _add_content 计算：from y=150 + 30 + split 后 24 = 204，frame 局部）。
const ATTACH_TOP_Y: float = 204.0

var pd: PlayerData
var _mail_id: int = 0
var _mail: Dictionary
var _on_closed: Callable
var _attach_host: Control = null   # .tscn %AttachHost（附件区动态挂）


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


# 建 UI：chrome 从 .tscn instantiate（位置/size 可视化），fill 动态文本/visible/信号；
# 附件区 procedural 挂 %AttachHost。源 create:385 + createContent:277。
func _build_ui() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	(content.get_node("%Title") as Label).text = str(_mail.get("name", ""))
	(content.get_node("%Body") as Label).text = str(_mail.get("content", ""))
	(content.get_node("%From") as Label).text = str(_mail.get("from", ""))
	var has_attach: bool = bool(_mail.get("attached", false))
	(content.get_node("%SplitLine") as CanvasItem).visible = has_attach
	var ok_btn: TextureButton = content.get_node("%OkBtn") as TextureButton
	ok_btn.pressed.connect(_on_ok)
	var is_unread: bool = str(_mail.get("status", "")) == "unread"
	var ok_text: String = _lstr(LSTR_CLAIM_KEY, CLAIM_FALLBACK) if (is_unread and has_attach) else _lstr(LSTR_CLOSE_KEY, CLOSE_FALLBACK)
	(content.get_node("%OkLabel") as Label).text = ok_text
	_attach_host = content.get_node("%AttachHost") as Control
	if has_attach:
		_add_attach()


# 附件区（照源 createAttach:216-275 + createCommonAttach:162-214 + createItemAttach:135-160）。
# P1-4：attach_bg 装饰背景 + attach_common 数组忠实源数据结构（type 查 7 货币图标）。
# 挂 %AttachHost（pos=0,0 = frame 局部坐标系不变）。
func _add_attach() -> void:
	var y: float = ATTACH_TOP_Y
	# attach_bg（源 createAttach :221-234 mailbox_letter_addon_bg @20,y width 300），先 add z 低
	var attach_bg := TextureRect.new()
	attach_bg.texture = load(ATTACH_BG_TEX)
	attach_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	attach_bg.position = Vector2(20.0, y)
	attach_bg.size = Vector2(ATTACH_BG_W, 0.0)   # 高度待设（源 :273 setContentSize(300, bh)）
	attach_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attach_host.add_child(attach_bg)
	var top_y: float = y
	# attach_title（源 :235-249 "附件" @30,y-15 color ATTACH_TITLE_COLOR）
	var head := Label.new()
	head.text = _lstr(LSTR_ATTACH_KEY, ATTACH_FALLBACK)
	head.position = Vector2(30, y + 2.0)
	head.size = Vector2(100, 20)
	head.add_theme_font_size_override("font", BODY_FONT)
	head.add_theme_color_override("font_color", ATTACH_TITLE_COLOR)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attach_host.add_child(head)
	var cy: float = y + 30.0   # 源 :252 y=y-30
	# 货币附件（源 createCommonAttach :162-214，遍历 attach_common 按 type 查 CURRENCY_ICONS）
	for entry in _mail.get("attach_common", []):
		var ctype: String = str(entry.get("type", ""))
		var camount: int = int(entry.get("amount", 0))
		if camount <= 0:
			continue
		var icon_path: String = CURRENCY_ICONS.get(ctype, GOLD_ICON)
		cy = _add_currency(cy, icon_path, camount)
	# 装备/物品附件（源 createItemAttach :135-160，4 列网格）
	var items: Array = _mail.get("items", [])
	if not items.is_empty():
		cy = _add_item_attach(cy, items)
	attach_bg.size = Vector2(ATTACH_BG_W, cy - top_y)   # 源 :273 bh=oy-y


# 源 createItemAttach :135-160：4 列装备网格（readequip.createIconWithAmount）。
func _add_item_attach(y: float, items: Array) -> float:
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
		_attach_host.add_child(icon)
	var rows: int = ceili(float(items.size()) / float(ITEM_ICON_COLS))
	return y + float(rows) * ITEM_ICON_SIZE


func _add_currency(y: float, icon_path: String, amount: int) -> float:
	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(CURRENCY_ICON_H, CURRENCY_ICON_H)   # 源 :188 fix_height=25
	icon.position = Vector2(40, y)   # 源 :186 ccp(40, y)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attach_host.add_child(icon)
	var lbl := Label.new()
	lbl.text = "x%d" % amount
	lbl.position = Vector2(40.0 + CURRENCY_ICON_H + 8.0, y)   # 源 right2 icon offset 20
	lbl.size = Vector2(100, CURRENCY_ICON_H)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font", AMOUNT_FONT)   # 源 :195 size=18
	lbl.add_theme_color_override("font_color", AMOUNT_COLOR)   # 源 :206 ccc3(129,61,22)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attach_host.add_child(lbl)
	return y + 30.0   # 源 :211 y=y-30


# ok（照 doClickRead:483 + doReadMail:494-531）：未读+附件 → claim（+overfull 检查）；未读无附件 → mark_read+erase；已读 → 关闭。
# P1-4：overfull 改弹 MailOverfullPopup（替 Toast 降级，忠实源 overfull.lua 弹窗）。
# C10/C11（2026-07-23）：未读无附件分支照源 read_mail:2755-2760 补 erase（mark_read 仅改客户端 status，
#   raw 未移除致未读无附件邮件永久留列表）；已读分支补 else: _close()（源 doClickRead:483-491 else destroy）。
func _on_ok() -> void:
	var has_attach: bool = bool(_mail.get("attached", false))
	var is_unread: bool = str(_mail.get("status", "")) == "unread"
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
		# 源 read_mail handler :2755-2760 未读邮件点 ok 后从 mails 移除（不论有无附件）。
		# claim_attach 内已 erase（未读+附件分支），此处未读无附件分支照源补 erase。
		pd.mailbox.mark_read(_mail_id)
		pd.mailbox.erase_mail(_mail_id)
		_close()
	else:
		# C11：源 doClickRead:483-491 else 分支 destroy({skipAnim=true, callback}) 关闭弹窗。
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
