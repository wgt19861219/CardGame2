class_name MailManager
extends RefCounted

## 邮件（Step 3.7）：邮件列表 + 领取附件（过期清理/已领删除）。

var mails: Array[Dictionary] = []  # {id, title, reward, claimed}

func add_mail(mail_id: int, title: String, reward: Dictionary) -> void:
	mails.append({"id": mail_id, "title": title, "reward": reward, "claimed": false})

## 领取邮件附件：返回 reward，标记已领；重复/不存在返回空。
func claim(mail_id: int) -> Dictionary:
	for m in mails:
		if int(m["id"]) == mail_id and not bool(m["claimed"]):
			m["claimed"] = true
			return Dictionary(m["reward"])
	return {}

func unclaimed_count() -> int:
	var n: int = 0
	for m in mails:
		if not bool(m["claimed"]):
			n += 1
	return n

## 清理已领取邮件。
func purge_claimed() -> void:
	var kept: Array[Dictionary] = []
	for m in mails:
		if not bool(m["claimed"]):
			kept.append(m)
	mails = kept
