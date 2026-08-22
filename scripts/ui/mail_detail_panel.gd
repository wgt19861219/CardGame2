class_name MailDetailPanel
extends PopWindow

## 邮件详情面板（View 层）— 照源 ui/mail/content.lua create:385 + createContent:277 + doReadMail:494。
## frame（mailbox_letter_bg）+ ok 按钮（领取/关闭）+ title/body/from + splitLine + attach（common 货币）。
## ok 点击：未读+有附件 → claim_attach；未读无附件 → mark_read；已读 → 关闭。单机化裁源 read_mail 联机。
##
## 批 2 两件套改造（2026-08-16，star_shop 范式）：chrome（frame/title_bg/title/body/from/
## split/ok/attach_bg/attach_title）静态化进 scenes/ui/mail_detail_content.tscn——title_bg/
## attach_bg 源 Scale9Sprite → NinePatchRect（cap 纹理像素直译），ok 按钮 TextureButton 整拉
## → Button theme variation（SB_pkg_hb 同图同 cap 复用，文字 Button.text 承载）。
## 货币附件行走 mail_currency_item.tscn 行模板；物品 icon 保留 ReadequipIcon 动态挂
## %AttachHost（pos=0,0 保持 frame 局部坐标系）。源 cocos(800×480 左下)→Godot(800×480 左上)，
## 显示尺寸=纹理px/CS(1.28125)。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/mail_detail_content.tscn")
const CURRENCY_ITEM_SCENE: PackedScene = preload("res://scenes/ui/mail_currency_item.tscn")
# 显示尺寸换算 CS（源 setContentScaleFactor(615/480)）
const CS: float = 1.28125
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
const ITEM_ICON_COLS: int = 4
const ITEM_ICON_SIZE: float = 65.0
# 物品附件 icon 缩放（源 content.lua:141 createIconWithAmount(id, 60, amount) → 显示 60 点）：
# 9bc640e 起 create_icon 内部 _load_sprite 统一 ÷CS（frame 显示 94/CS），分母 = 94/CS
# （旧 60/94 系原像素口径，统一后双重 ÷CS 实显 46.8，2026-08-22 修，mail_overfull 同款）。
const FRAME_TEX_W: float = 94.0
const FRAME_TEX_H: float = 95.0
const ICON_SCALE: float = 60.0 / (FRAME_TEX_W / CS)
# P1（2026-07-16）：UI 文案 cm.get_lstr 化（源 LSTR key，GameData.config 解析，fallback 中文兜底）。
const LSTR_ATTACH_KEY: String = "MAILBOX.ATTACHMENTS_"
const ATTACH_FALLBACK: String = "附件"
const LSTR_CLAIM_KEY: String = "MAILBOX.CLAIM"
const CLAIM_FALLBACK: String = "领取"
const LSTR_CLOSE_KEY: String = "MAILBOX.CLOSE"
const CLOSE_FALLBACK: String = "关闭"
# title_bg 装饰背景路径（测试引用）；纹理已静态化进 .tscn TitleBg。
const TITLE_BG_TEX: String = "res://assets/ui/alpha/HVGA/equip_craft_money_bg.png"
const ATTACH_BG_TEX: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_letter_addon_bg.png"
# 货币 icon 显示高（源 createCommonAttach config fix_height=25，readnode 等比缩放）
const CURRENCY_ICON_H: float = 25.0
const ATTACH_BG_W: float = 300.0
# 附件区起始 y（源 _add_content 计算：from y=150 + 30 + split 后 24 = 204，frame 局部
# y-up；M2 修正：照 tscn 公式 (x, 422.24-y) 翻转 → 422.24-204=218.24，货币行/物品行
# y 均由此派生自动联动 +14.24）。
const ATTACH_TOP_Y: float = 218.24
# 货币行间距（源 :211 逐行 y-30）与行首偏移（源 createAttach y-30 后起排）
const CURRENCY_ROW_DY: float = 30.0

var pd: PlayerData
var _mail_id: int = 0
var _mail: Dictionary
var _on_closed: Callable
var _attach_host: Control = null   # .tscn %AttachHost（附件区动态挂）


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


# 建 UI：chrome 从 .tscn instantiate，fill 动态文本/visible/信号；附件区挂 %AttachHost。
# 源 create:385 + createContent:277。
func _build_ui() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	(content.get_node("%Title") as Label).text = str(_mail.get("name", ""))
	(content.get_node("%Body") as Label).text = str(_mail.get("content", ""))
	(content.get_node("%From") as Label).text = str(_mail.get("from", ""))
	var has_attach: bool = bool(_mail.get("attached", false))
	(content.get_node("%SplitLine") as CanvasItem).visible = has_attach
	var ok_btn: Button = content.get_node("%OkBtn") as Button
	ok_btn.pressed.connect(_on_ok)
	var is_unread: bool = str(_mail.get("status", "")) == "unread"
	var ok_text: String = _lstr(LSTR_CLAIM_KEY, CLAIM_FALLBACK) if (is_unread and has_attach) else _lstr(LSTR_CLOSE_KEY, CLOSE_FALLBACK)
	ok_btn.text = ok_text
	_attach_host = content.get_node("%AttachHost") as Control
	if has_attach:
		_add_attach()


# 附件区（照源 createAttach:216-275 + createCommonAttach:162-214 + createItemAttach:135-160）。
# attach_bg/attach_title 静态化进 .tscn（visible fill 显示）；货币行走行模板；
# 物品 icon 动态挂。挂 %AttachHost（pos=0,0 = frame 局部坐标系不变）。
func _add_attach() -> void:
	var attach_bg: NinePatchRect = _attach_host.get_node("%AttachBg") as NinePatchRect
	attach_bg.visible = true
	var head: Label = _attach_host.get_node("%AttachTitle") as Label
	head.visible = true
	head.text = _lstr(LSTR_ATTACH_KEY, ATTACH_FALLBACK)
	var top_y: float = ATTACH_TOP_Y
	var cy: float = ATTACH_TOP_Y + CURRENCY_ROW_DY
	# 货币附件（源 createCommonAttach :162-214，遍历 attach_common 按 type 查 CURRENCY_ICONS）
	for entry in _mail.get("attach_common", []):
		var ctype: String = str(entry.get("type", ""))
		var camount: int = int(entry.get("amount", 0))
		if camount <= 0:
			continue
		var icon_path: String = CURRENCY_ICONS.get(ctype, GOLD_ICON)
		_add_currency_row(cy, icon_path, camount)
		cy += CURRENCY_ROW_DY
	# 装备/物品附件（源 createItemAttach :135-160，4 列网格）
	var items: Array = _mail.get("items", [])
	if not items.is_empty():
		cy = _add_item_attach(cy, items)
	attach_bg.size = Vector2(ATTACH_BG_W, cy - top_y)


# 货币附件行（mail_currency_item.tscn 模板 fill：icon 等比高 25 + x{amount}）。
func _add_currency_row(y: float, icon_path: String, amount: int) -> void:
	var row: Control = CURRENCY_ITEM_SCENE.instantiate() as Control
	row.position = Vector2(0.0, y)
	var icon: TextureRect = row.get_node("%Icon") as TextureRect
	icon.texture = load(icon_path) as Texture2D
	var icon_w: float = CURRENCY_ICON_H
	if icon.texture != null:
		var ts: Vector2 = icon.texture.get_size()
		if ts.y > 0.0:
			icon_w = CURRENCY_ICON_H * ts.x / ts.y
	icon.size = Vector2(icon_w, CURRENCY_ICON_H)
	var lbl: Label = row.get_node("%Amount") as Label
	lbl.text = "x%d" % amount
	lbl.position = Vector2(40.0 + icon_w + 20.0, 0.0)
	_attach_host.add_child(row)


func _add_item_attach(y: float, items: Array) -> float:
	var vis_h: float = FRAME_TEX_H / CS * ICON_SCALE   # icon 视觉高（95/CS 显示 ×scale = 60.64）
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var item_id: int = int(item.get("id", 0))
		var amount: int = int(item.get("amount", 1))
		if item_id == 0:
			continue
		var col: int = i % ITEM_ICON_COLS
		var row_i: int = int(i / ITEM_ICON_COLS)
		var icon: Control = ReadequipIcon.create_icon(item_id, amount, pd.cm)
		icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
		# 源 :137-143 getpos：icon 中心 (34+65col+32.5, y-65row-32.5) frame 局部 y-up →
		# godot 中心 (66.5+65col, y+32.5+65row)；视觉盒左上 = 中心 - (30, vis_h/2)
		icon.position = Vector2(36.5 + float(col) * ITEM_ICON_SIZE,
			y + 32.5 + float(row_i) * ITEM_ICON_SIZE - vis_h * 0.5)
		_attach_host.add_child(icon)
	var rows: int = ceili(float(items.size()) / float(ITEM_ICON_COLS))
	return y + float(rows) * ITEM_ICON_SIZE


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
			var popup := MailOverfullPopup.new()
			popup.setup(overfull, pd.cm)
			popup.confirmed.connect(_on_overfull_confirmed)
			container.add_child(popup)
			return
		_claim_and_close()
	elif is_unread:
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
		var da: int = cur + amount - PlayerData.MAX_ITEMS_PER_SLOT
		if da > 0:
			overfull.append({"id": item_id, "amount": da})
	return overfull


# overfull「强行领取」（源 overfull.lua:10-16 leftCallback → doRead 领取 + destroy）。
func _on_overfull_confirmed() -> void:
	_claim_and_close()


func _claim_and_close() -> void:
	pd.mailbox.claim_attach(_mail_id, pd)
	GameData.mark_save_dirty()
	_close()


func _close() -> void:
	remove_window()
	if _on_closed.is_valid():
		_on_closed.call()
