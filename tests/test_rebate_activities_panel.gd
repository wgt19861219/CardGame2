extends GutTest
# 活动详情面板测试 — 照源 ui/rebateActivities.lua createPrizeIndex 三态（未达标/可领/已领）
# + 领取链路（claim 入账 + 行状态翻转）+ 两件套范式守卫。
# 2026-10-13 玩法活动临时下线：公告形态断言走当前 JSON（announce 无档位/长期有效）；
# 档位三态用注入表（管线保留，恢复活动只需换回 JSON 数据）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


## 注入玩法活动表（照源数值；档位三态/领取链路不依赖当前公告 JSON）。
func _cm_with_activities() -> ConfigManager:
	var c := ConfigManager.new()
	c.load_all()
	c._tables[&"ActivitiesConfig"] = {
		"diamond_consume": {
			"type": "diamond_consume", "title": "钻石消费返利", "desc": "d", "rules": "r",
			"rewards": [
				{"job": "act_dia_200", "threshold": 200, "reward": {"type": "money", "id": 0, "amount": 50000}},
				{"job": "act_dia_1000", "threshold": 1000, "reward": {"type": "item", "id": 14002, "amount": 2}},
			],
		},
		"combo_br_tavern": {
			"type": "tavern_ten", "title": "青铜十连优惠", "desc": "d", "rules": "r",
			"rewards": [
				{"job": "act_combo_br_tavern", "threshold": 1, "reward": {"type": "money", "id": 0, "amount": 10000}},
			],
		},
	}
	return c


func _make_player(p_cm: ConfigManager) -> PlayerData:
	var pd := PlayerData.new(p_cm)
	pd.apply_default_data()
	return pd


func _make_panel(pd: PlayerData, act_key: String) -> RebateActivitiesPanel:
	var root := Node.new()
	add_child(root)
	var now: int = int(Time.get_unix_time_from_system())
	var acts: Array = pd.activity.get_activities(now, pd.cm)
	var target: Dictionary = {}
	for a in acts:
		if String(a.get("key", "")) == act_key:
			target = a
	var panel := RebateActivitiesPanel.new("rebate_activities", {})
	panel.setup_panel(pd, target)
	panel.show_window(root)
	return panel


# ── 公告形态（当前 JSON）──

func test_announce_panel_chrome() -> void:
	var pd := _make_player(cm)
	var panel := _make_panel(pd, "announcement")
	assert_eq(String((panel._content.get_node("%TitleLabel") as Label).text), "公告", "标题=公告")
	assert_eq(String((panel._content.get_node("%TimeValueLabel") as Label).text), "长期有效", "公告无档期显示长期有效")
	assert_false((panel._content.get_node("%HasDoneLabel") as Label).visible, "公告隐藏已累计进度")
	var host := panel._content.get_node("%PrizeHost") as VBoxContainer
	assert_eq(host.get_children().size(), 0, "公告无档位行（纯展示）")
	panel.remove_window()
	panel.get_parent().queue_free()


# ── 档位三态 + 领取链路（注入表）──

func test_tier_states_and_claim() -> void:
	var cm2 := _cm_with_activities()
	var pd := _make_player(cm2)
	var now: int = int(Time.get_unix_time_from_system())
	pd.activity.on_diamond_spent(600, now)   # 200 档达标
	var panel := _make_panel(pd, "diamond_consume")
	var host := panel._content.get_node("%PrizeHost") as VBoxContainer
	assert_eq(host.get_children().size(), 2, "2 档位行")
	var row0 := host.get_child(0)
	assert_true(String((row0.get_node("%Bg") as TextureRect).texture.resource_path).ends_with("activity_list_bg_2.png"), "200 档达标行底图 bg_2")
	assert_false((row0.get_node("%MaskReceived") as TextureRect).visible, "未领无遮罩")
	var row1 := host.get_child(1)
	assert_true(String((row1.get_node("%Bg") as TextureRect).texture.resource_path).ends_with("activity_list_bg_1.png"), "1000 档未达标行底图 bg_1")
	var gold_before: int = pd.hero_manager.gold
	panel._on_claim_pressed_index(0)
	assert_eq(pd.hero_manager.gold, gold_before + 50000, "领取 200 档入账金币 50000")
	assert_true((host.get_child(0).get_node("%MaskReceived") as TextureRect).visible, "领取后行翻已领遮罩")
	# 已领再点 → 拒绝（gold 不再变化）
	var gold_after_claim: int = pd.hero_manager.gold
	panel._on_claim_pressed_index(0)
	assert_eq(pd.hero_manager.gold, gold_after_claim, "重复领取不再入账")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_tavern_activity_cond_text() -> void:
	var cm2 := _cm_with_activities()
	var pd := _make_player(cm2)
	var now: int = int(Time.get_unix_time_from_system())
	pd.activity.on_tavern_draw("Bronze", true, now)   # 十连 1 次 → combo 档达标
	var panel := _make_panel(pd, "combo_br_tavern")
	var host := panel._content.get_node("%PrizeHost") as VBoxContainer
	var row0 := host.get_child(0)
	assert_eq(String((row0.get_node("%CondValLabel") as Label).text), "1 次十连", "tavern 档门槛文案")
	assert_true(String((panel._content.get_node("%HasDoneLabel") as Label).text).contains("已十连 1 次"), "十连进度文案")
	panel.remove_window()
	panel.get_parent().queue_free()


# ── 两件套 tscn 守卫 ──

func test_item_scene_row_chrome() -> void:
	var inst := (preload("res://scenes/ui/rebate_activities_item.tscn") as PackedScene).instantiate() as Control
	add_child(inst)
	assert_almost_eq(inst.custom_minimum_size.x, 524.0, 0.5, "档位行宽 524（源底图 534.63×0.98）")
	assert_almost_eq(inst.custom_minimum_size.y, 96.0, 0.5, "档位行高 96")
	for n in ["%Bg", "%MaskReceived", "%CondPreLabel", "%CondValLabel", "%IconHost1", "%ClaimHost"]:
		assert_ne(inst.get_node(n), null, "%s 存在" % n)
	inst.queue_free()


func test_rules_scene_chrome() -> void:
	var inst := (preload("res://scenes/ui/rebate_rules_content.tscn") as PackedScene).instantiate() as Control
	add_child(inst)
	assert_ne(inst.get_node("%CloseBtn"), null, "规则弹窗关闭按钮存在")
	assert_ne(inst.get_node("%RulesTextLabel"), null, "规则文本唯一名存在")
	inst.queue_free()
