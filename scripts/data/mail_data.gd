class_name MailData
extends RefCounted

## 信箱数据层（Data 层）— 照源 ui/mailbox.lua formatMailData:11 + orderMailData:290 + doReadMail:184。
## 单机化：源联机 getMailData（ed.send get_maillist）+ read_mail → 本地程序生成系统邮件 + 直接 claim。
## 邮件 raw dict：{_id, _status, _date, _content={_plain_mail={_from,_title,_content}}, _money, _diamonds, _skill_point, _items=[{id,amount}]}。
## _format_mail 配置邮件（mailutil.getMailText mid）单机裁剪（仅 _plain_mail 纯文本）。

const ICON_UNREAD: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_maillist_letter_icon.png"
const ICON_READ: String = "res://assets/ui/alpha/HVGA/mailbox/mailbox_maillist_letter_open_icon.png"
const ICON_BG_DEFAULT: String = "res://assets/ui/alpha/HVGA/task_icon_bg.png"
# 单机初始邮件配置（照源 local_server.lua:2683-2726 generateSystemMails；id + 奖励数值提常量避魔法数字）
const MAIL_ID_WELCOME: int = 1
const MAIL_ID_NEWBIE: int = 2
const WELCOME_MONEY: int = 5000
const WELCOME_DIAMOND: int = 200
const NEWBIE_MONEY: int = 10000
const NEWBIE_ITEM_ID: int = 371
const NEWBIE_ITEM_AMOUNT: int = 10

var _raw_mails: Array = []   # raw mail dicts


func _init() -> void:
	_raw_mails = _default_mails()


# 单机初始系统邮件（照源 local_server.lua:2689-2723 generateSystemMails 2 封：欢迎/道具礼包）。
func _default_mails() -> Array:
	return [
		{_id = MAIL_ID_WELCOME, _status = "unread", _date = "2026-07-07",
			_content = {_plain_mail = {_from = "系统", _title = "欢迎来到卡牌大乱斗", _content = "勇敢的冒险者，欢迎降临！附赠初始资源，开启你的征程。"}},
			_money = WELCOME_MONEY, _diamonds = WELCOME_DIAMOND, _skill_point = 0, _items = []},
		{_id = MAIL_ID_NEWBIE, _status = "unread", _date = "2026-07-07",
			_content = {_plain_mail = {_from = "运营团队", _title = "道具礼包", _content = "为您准备了道具礼包，请查收！"}},
			_money = NEWBIE_MONEY, _diamonds = 0, _skill_point = 0,
			_items = [{"id": NEWBIE_ITEM_ID, "amount": NEWBIE_ITEM_AMOUNT}]},
	]


# 格式化 raw → 显示 dict（照 formatMailData:11-105）。返 null 表示过期（单机无过期，总返 dict）。
func format_mail(raw: Dictionary) -> Dictionary:
	var id: int = int(raw["_id"])
	var status_str: String = str(raw.get("_status", "unread"))
	var status: String = "read"
	if status_str == "unread" or status_str == "0":
		status = "unread"
	var money: int = int(raw.get("_money", 0))
	var diamond: int = int(raw.get("_diamonds", 0))
	var skill_point: int = int(raw.get("_skill_point", 0))
	var items: Array = raw.get("_items", [])
	var attached: bool = (money + diamond + skill_point) > 0 or items.size() > 0
	# P1-4：照源 content.lua:253-268 createAttach 拆 common/items。源 attach=[{type,amount}]，
	# type ∈ 7 货币名（createCommonAttach :162-171）+ Item。单机 raw 只 _money/_diamonds/_skill_point
	# → Gold/Diamond/SkillPoint 三种；View createCommonAttach 忠实支持全 7 种（存档/扩展邮件带其他货币可显示）。
	var attach_common: Array = []
	if money > 0:
		attach_common.append({"type": "Gold", "amount": money})
	if diamond > 0:
		attach_common.append({"type": "Diamond", "amount": diamond})
	if skill_point > 0:
		attach_common.append({"type": "SkillPoint", "amount": skill_point})
	var iconres: String = ICON_UNREAD if status == "unread" else ICON_READ
	var from: String = ""
	var mail_name: String = ""
	var content: String = ""
	var c: Dictionary = raw.get("_content", {})
	if c.has("_plain_mail"):
		var pm: Dictionary = c["_plain_mail"]
		from = String(pm.get("_from", ""))
		mail_name = String(pm.get("_title", ""))
		content = String(pm.get("_content", ""))
	var iconid: int = 0
	if items.size() > 0:
		iconid = int(items[0].get("id", 0))
	return {
		"id": id,
		"attached": attached,
		"status": status,
		"date": String(raw.get("_date", "")),
		"from": from,
		"name": mail_name,
		"content": content,
		"money": money,
		"diamond": diamond,
		"skill_point": skill_point,
		"items": items,
		"attach_common": attach_common,
		"iconres": iconres,
		"iconid": iconid,
		"iconbg": ICON_BG_DEFAULT,
	}


# 排序列表（照 orderMailData:290-321）：未读优先 + id 降序。返 format 后的 Array。
func ordered_mails() -> Array:
	var list: Array = []
	for raw in _raw_mails:
		list.append(format_mail(raw))
	list.sort_custom(_compare_mail)
	return list


func _compare_mail(a: Dictionary, b: Dictionary) -> bool:
	var a_unread: bool = a["status"] == "unread"
	var b_unread: bool = b["status"] == "unread"
	if a_unread and not b_unread:
		return true
	if not a_unread and b_unread:
		return false
	return int(a["id"]) > int(b["id"])


# 领附件（照 doReadMail:184-249 + mail/content.lua doReadMail:494）。发到 player + 清附件 + 标记已读。
func claim_attach(mail_id: int, player: Variant) -> void:
	var raw: Dictionary = _find_raw(mail_id)
	if raw.is_empty():
		return
	var money: int = int(raw.get("_money", 0))
	var diamond: int = int(raw.get("_diamonds", 0))
	var skill_point: int = int(raw.get("_skill_point", 0))
	if money > 0 and player != null:
		player.hero_manager.add_money(money)
	if diamond > 0 and player != null:
		player.add_diamond(diamond)
	if skill_point > 0 and player != null:
		SkillPointManager.add(player, skill_point)
	if player != null:
		for item in raw.get("_items", []):
			player.add_item(int(item["id"]), int(item["amount"]))
	raw["_money"] = 0
	raw["_diamonds"] = 0
	raw["_skill_point"] = 0
	raw["_items"] = []
	raw["_status"] = "read"
	# 客户端 _mail_list 仅返剩余）。单机照此从 _raw_mails 移除（raw 是列表内同一引用，erase 安全）。
	_raw_mails.erase(raw)


# 标记已读（无附件邮件点开 → read，照 refreshMailAt:370 data.status="read"）。
func mark_read(mail_id: int) -> void:
	var raw: Dictionary = _find_raw(mail_id)
	if not raw.is_empty():
		raw["_status"] = "read"


# 从列表移除邮件（照源 local_server.lua:2755-2760 read_mail handler：未读邮件点 ok 后，
# 服务端无条件从 localdata.mails 移除该 id；已读点 ok 不移除——源 doClickRead:483 else 分支仅 destroy）。
# 单机：未读无附件分支与未读有附件分支（claim_attach 已 erase）对齐，均从 _raw_mails 移除。
func erase_mail(mail_id: int) -> void:
	var raw: Dictionary = _find_raw(mail_id)
	if not raw.is_empty():
		_raw_mails.erase(raw)


# 取单封 format（点击列表项时）。
func get_mail(mail_id: int) -> Dictionary:
	var raw: Dictionary = _find_raw(mail_id)
	if raw.is_empty():
		return {}
	return format_mail(raw)


func _find_raw(mail_id: int) -> Dictionary:
	for raw in _raw_mails:
		if int(raw["_id"]) == mail_id:
			return raw
	return {}


## 存档序列化（照 crusade_manager 范式）。
func to_dict() -> Dictionary:
	return {"raw_mails": _raw_mails.duplicate(true)}


static func from_dict(data: Dictionary) -> MailData:
	var md := MailData.new()
	md._raw_mails = data.get("raw_mails", md._raw_mails)
	return md
