extends GutTest
# Phase 6 eatexplist 弹窗测试（2026-07-05 第 27 段）。
# 照源 eatexplist.lua create + doEat。单机化：去 doSendConsume 网络，即时扣物品+加经验。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 找一个 EXPERIENCE_PILL 物品（Category=CONSUMABLES + Consume Type=EXPERIENCE_PILL + Exp>0）。
func _find_exp_pill() -> int:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw:
		var row: Dictionary = raw[tid_str]
		if String(row.get("Category", "")) == "EQUIP.CONSUMABLES" \
				and String(row.get("Consume Type", "")) == "EQUIP.EXPERIENCE_PILL" \
				and int(row.get("Exp", 0)) > 0:
			return int(tid_str)
	return 0


# Levels 表最大 key（末位等级），+1 即超表触发满级判定。
func _levels_max_key() -> int:
	var levels: Dictionary = cm.get_raw_table(&"Levels")
	var max_k: int = 1
	for k in levels:
		max_k = max(max_k, int(k))
	return max_k


func test_setup_builds_frame() -> void:
	var pill_id: int = _find_exp_pill()
	assert_gt(pill_id, 0, "存在 EXPERIENCE_PILL 物品")
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.add_item(pill_id, 1)
	pd.hero_manager.add_hero(1)
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(pill_id, cm, pd)
	panel.show_window(root)
	assert_gt(panel.container.get_child_count(), 0, "frame 已建（container 有子）")
	panel.remove_window()
	root.queue_free()


func test_close_removes_window() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.add_item(_find_exp_pill(), 1)
	pd.hero_manager.add_hero(1)
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(_find_exp_pill(), cm, pd)
	panel.show_window(root)
	panel._on_close_pressed()
	await get_tree().process_frame
	assert_false(is_instance_valid(panel), "close 后 panel 销毁")
	if is_instance_valid(root):
		root.queue_free()


# do_eat_hero 即时扣物品 + 加经验（单机化，无网络延迟）。
func test_do_eat_consumes_item_and_adds_exp() -> void:
	var pill_id: int = _find_exp_pill()
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.add_item(pill_id, 3)
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	var olevel: int = hero.level
	var oexp: int = hero.exp
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(pill_id, cm, pd)
	panel.show_window(root)
	panel.do_eat_hero(inst_id)
	assert_eq(int(pd.items.get(pill_id, 0)), 2, "扣 1 物品")
	var exp_added: bool = hero.level > olevel or hero.exp > oexp
	assert_true(exp_added, "经验增加（升级或当级 exp 增）")
	panel.remove_window()
	root.queue_free()


# 满级英雄（Levels 末位 +1）不喂药（源 isExpMax 拦截）。
func test_do_eat_blocked_when_max_level() -> void:
	var pill_id: int = _find_exp_pill()
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.add_item(pill_id, 3)
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	hero.level = _levels_max_key() + 1   # 超 Levels 表 → _levelup_exp<=0 → 满级
	var oexp: int = hero.exp
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(pill_id, cm, pd)
	panel.show_window(root)
	panel.do_eat_hero(inst_id)
	assert_eq(int(pd.items.get(pill_id, 0)), 3, "满级不扣物品")
	assert_eq(hero.exp, oexp, "满级不加经验")
	panel.remove_window()
	root.queue_free()


# 持有量耗尽（源 useProp amount 上限拦截）。
func test_do_eat_blocked_when_no_item() -> void:
	var pill_id: int = _find_exp_pill()
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)   # 不 add_item，持有量=0
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	var oexp: int = hero.exp
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(pill_id, cm, pd)
	panel.show_window(root)
	panel.do_eat_hero(inst_id)
	assert_eq(int(pd.items.get(pill_id, 0)), 0, "持有量 0")
	assert_eq(hero.exp, oexp, "无物品不加经验")
	panel.remove_window()
	root.queue_free()


# EquipboardPanel consume 右按钮 → 弹 EatexpPanel（第 27 段接 use）。
func test_equipboard_consume_opens_eatexp() -> void:
	var pill_id: int = _find_exp_pill()
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var cell: Dictionary = {"id": pill_id, "makeId": pill_id, "amount": 1, "category": "EQUIP.CONSUMABLES", "type": 1}
	var board := EquipboardPanel.new("equipboard", {})
	board.setup_panel(cell, cm, pd)
	board.show_window(root)
	board._on_right_pressed()   # consume → _open_eatexp
	var has_eatexp: bool = false
	for c in root.get_children():
		if c is EatexpPanel:
			has_eatexp = true
			c.queue_free()
			break
	assert_true(has_eatexp, "EquipboardPanel consume 右按钮弹 EatexpPanel")
	board.remove_window()
	root.queue_free()
