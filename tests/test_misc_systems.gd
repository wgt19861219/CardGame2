extends GutTest
# Step 3.7 任务/炼金/邮件/图鉴/商店单测。

# ---- 邮件 ----
func test_mail_claim() -> void:
	var m := MailManager.new()
	m.add_mail(1, "test", {"gold": 100})
	assert_eq(m.unclaimed_count(), 1)
	var reward := m.claim(1)
	assert_eq(int(reward["gold"]), 100)
	assert_eq(m.unclaimed_count(), 0)
	assert_eq(m.claim(1).size(), 0, "重复领取返回空")

func test_mail_purge() -> void:
	var m := MailManager.new()
	m.add_mail(1, "a", {})
	m.add_mail(2, "b", {})
	m.claim(1)
	m.purge_claimed()
	assert_eq(m.mails.size(), 1, "清理已领，剩 1")

# ---- 炼金（照源 local_server.lua:1849-1898 midas）----
func test_midas_exchange() -> void:
	# 批量 times 次，成本 GradientPrice 梯度 + 产出 Midas Money × Yield；钻石够 → 成功
	var cm := ConfigManager.new()
	cm.load_all()
	var m := MidasManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.diamond = 100000
	pd.team_level = 1
	var r: Dictionary = m.exchange(pd, 1)
	assert_true(bool(r["ok"]), "钻石够 → 兑换成功")
	assert_gte((r["acquired"] as Array).size(), 1, "产出列表非空")
	assert_eq(pd.diamond, 100000 - int(r["cost"]), "扣 totalCost 钻石（GradientPrice[1].Midas）")


func test_midas_insufficient_diamond() -> void:
	# 源 :1887 playerRmb < totalCost → 空 acquire
	var cm := ConfigManager.new()
	cm.load_all()
	var m := MidasManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.diamond = 0   # 不足
	var r: Dictionary = m.exchange(pd, 1)
	assert_false(bool(r["ok"]), "钻石不足 → ok:false")
	assert_eq((r["acquired"] as Array).size(), 0, "空 acquire（源 :1888）")

# ---- 任务 ----
func test_task_claim_requires_complete() -> void:
	var t := TaskManager.new()
	assert_false(t.claim(1), "未完成不可领")
	t.complete(1)
	assert_true(t.claim(1))
	assert_false(t.claim(1), "重复不可领")

# ---- 图鉴 ----
func test_handbook_record() -> void:
	var h := HandbookManager.new()
	h.record_hero(1)
	h.record_hero(1)  # 重复不增
	h.record_hero(2)
	assert_eq(h.hero_count(), 2)
	assert_true(h.has_hero(1))
