extends GutTest
# MailData 数据层（照源 ui/mailbox.lua formatMailData:11 + orderMailData:290 + doReadMail:184）。
# 邮件列表 + format（plain_mail）+ order（未读优先+id 降序）+ claim（领附件）+ mark_read。


var _md: MailData


func before_each() -> void:
	_md = MailData.new()


func after_each() -> void:
	_md = null


# format：解析 plain_mail（from/name/content）+ status + attached。默认 2 封（照源 generateSystemMails）。
func test_format_plain_mail() -> void:
	var mails: Array = _md.ordered_mails()
	assert_eq(mails.size(), 2, "默认 2 封系统邮件（照源 generateSystemMails）")
	var m0: Dictionary = mails[0]
	assert_true(str(m0["name"]).length() > 0, "name 解析（plain_mail._title）")
	assert_true(str(m0["from"]).length() > 0, "from 解析（plain_mail._from）")
	assert_true(str(m0["content"]).length() > 0, "content 解析（plain_mail._content）")


# order：未读优先 + id 降序（默认 id1/id2 unread → [2,1]）。
func test_order_unread_first_then_id_desc() -> void:
	var mails: Array = _md.ordered_mails()
	assert_eq(str(mails[0]["status"]), "unread", "首封 unread")
	assert_eq(str(mails[1]["status"]), "unread", "次封 unread")
	assert_eq(int(mails[0]["id"]), 2, "unread 内 id 降序（2 > 1）")
	assert_eq(int(mails[1]["id"]), 1, "unread id 1")


# claim：领附件 → player 加资源 + raw 标 read + 附件清空（照 doReadMail:184）。
# 源 local_server.lua:2689-2705 id=1 欢迎 _money=5000 _diamonds=200
func test_claim_attach() -> void:
	var mp := _MockPlayer.new()
	var gold_before: int = mp.hero_manager.gold
	_md.claim_attach(1, mp)   # mail 1: money 5000, diamond 200（照源 :2689-2705）
	assert_eq(mp.hero_manager.gold, gold_before + 5000, "领后金币 +5000（照源）")
	assert_eq(mp.diamond, 200, "领后钻石 +200（照源）")
	# 源 read_mail:2755-2760 领取后从 localdata.mails 移除该 raw → ordered_mails 不再含 id=1
	var ids: Array = []
	for m in _md.ordered_mails():
		ids.append(int(m["id"]))
	assert_false(ids.has(1), "领后邮件从列表移除（照源 read_mail:2755-2760）")
	assert_eq(_md.get_mail(1), {}, "get_mail 返空（raw 已移除）")


# 源 local_server.lua:2707-2723 id=2 道具礼包 _money=10000 + item 371×10
func test_claim_newbie_item_pack() -> void:
	var mp := _MockPlayer.new()
	_md.claim_attach(2, mp)   # mail 2: money 10000 + item 371×10（照源 :2707-2723）
	assert_eq(mp.hero_manager.gold, 10000, "道具礼包金币 +10000（照源）")
	assert_eq(int(mp.items.get(371, 0)), 10, "道具礼包 item 371×10（照源）")


# mark_read：无附件未读邮件 → status=read（照 refreshMailAt:370）。
func test_mark_read() -> void:
	_md.mark_read(2)
	var m: Dictionary = _md.get_mail(2)
	assert_eq(str(m["status"]), "read", "mark_read 后 status=read")


# C10（2026-07-23）：erase_mail 从 _raw_mails 移除邮件（照源 local_server.lua:2755-2760
# read_mail handler：未读邮件点 ok 后服务端无条件从 localdata.mails 移除该 id）。
# mark_read 仅改 status 不移除 raw，claim_attach 内部已 erase，本方法补未读无附件路径的 erase。
func test_erase_mail() -> void:
	assert_eq(_md.ordered_mails().size(), 2, "初始 2 封")
	_md.erase_mail(1)
	var ids: Array = []
	for m in _md.ordered_mails():
		ids.append(int(m["id"]))
	assert_false(ids.has(1), "erase_mail 后 id=1 从列表移除")
	assert_eq(_md.get_mail(1), {}, "get_mail 返空（raw 已移除）")
	assert_eq(ids.has(2), true, "其他邮件保留")


# erase_mail 对不存在 id 安全（照源 handler 循环无匹配不报错）。
func test_erase_mail_nonexistent_safe() -> void:
	_md.erase_mail(999)   # 不存在
	assert_eq(_md.ordered_mails().size(), 2, "不存在 id 不影响列表")


# claim 已领取邮件（附件已清）→ 不重复发资源。
func test_claim_no_duplicate() -> void:
	var mp := _MockPlayer.new()
	_md.claim_attach(1, mp)
	var gold_after_first: int = mp.hero_manager.gold
	_md.claim_attach(1, mp)   # 再领（附件已清）
	assert_eq(mp.hero_manager.gold, gold_after_first, "二次领不重复发金币")


# P1-4：attach_common 数组（照源 content.lua:253-268 createAttach 拆 common=[{type,amount}]）。
func test_format_attach_common() -> void:
	var m1: Dictionary = _md.get_mail(1)   # welcome：_money 5000 + _diamonds 200
	var ac1: Array = m1.get("attach_common", [])
	assert_eq(ac1.size(), 2, "mail 1 attach_common 2 项（Gold+Diamond）")
	assert_eq(str(ac1[0].get("type", "")), "Gold", "首项 type=Gold")
	assert_eq(int(ac1[0].get("amount", 0)), 5000, "Gold amount 5000")
	assert_eq(str(ac1[1].get("type", "")), "Diamond", "次项 type=Diamond")
	assert_eq(int(ac1[1].get("amount", 0)), 200, "Diamond amount 200")
	var m2: Dictionary = _md.get_mail(2)   # newbie：_money 10000（item 走 items 不入 attach_common）
	var ac2: Array = m2.get("attach_common", [])
	assert_eq(ac2.size(), 1, "mail 2 attach_common 1 项（Gold）")


# Mock player（duck-type MailData.claim_attach 用：hero_manager.add_money/add_diamond/add_skill_point/add_item）。
class _MockPlayer:
	var hero_manager: _MockHeroMgr
	var diamond: int = 0
	var _skill_point: int = 0
	var items: Dictionary = {}

	func _init() -> void:
		hero_manager = _MockHeroMgr.new()

	func add_diamond(amount: int) -> void:
		diamond += amount

	func add_item(item_id: int, count: int = 1) -> void:
		items[item_id] = int(items.get(item_id, 0)) + count

	func add_skill_point(amount: int = 1) -> void:
		_skill_point += amount


class _MockHeroMgr:
	var gold: int = 0

	func add_money(amount: int) -> void:
		gold += amount
