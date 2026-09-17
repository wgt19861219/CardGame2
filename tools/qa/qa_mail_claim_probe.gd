extends Node
## qa_mail_claim_probe：邮箱物品点击领取排查探针（2026-09-16）。
## install_override 装载 → 注入 1 封带物品附件测试邮件（money=12345 + item 371×3）
## → 停住等 bridge 用真实鼠标事件复现「开邮箱→点邮件→点领取」全链路。
## 观察点：每步 watch OkBtn pressed 是否触发 / 面板是否关闭 / 货币是否到账。

const QA_MAIL_ID: int = 9901
const QA_MONEY: int = 12345
const QA_ITEM_ID: int = 371
const QA_ITEM_AMOUNT: int = 3

func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var player: PlayerData = GameData.player
	if player == null:
		print("QA FAIL no player")
		return
	var before_money: int = player.hero_manager.gold
	player.mailbox._raw_mails.append({
		"_id": QA_MAIL_ID, "_status": "unread", "_date": "2026-09-16",
		"_content": {"_plain_mail": {"_from": "QA", "_title": "QA领取测试", "_content": "真实点击链路复现用"}},
		"_money": QA_MONEY, "_diamonds": 0, "_skill_point": 0,
		"_items": [{"id": QA_ITEM_ID, "amount": QA_ITEM_AMOUNT}],
	})
	print("QA READY mail injected id=%d money_before=%d mails=%d" % [QA_MAIL_ID, before_money, player.mailbox._raw_mails.size()])
