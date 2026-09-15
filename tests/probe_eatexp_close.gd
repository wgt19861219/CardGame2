extends Node
## 探针：eatexp 关闭按钮真实输入验证（2026-09-15 树序根修后）。
## 挂面板 → bridge real_event 点击 CloseBtn → watch 打印面板存活态（valid=false=已关闭）。

const PILL_CATEGORY: String = "EQUIP.CONSUMABLES"
const PILL_TYPE: String = "EQUIP.EXPERIENCE_PILL"
const WATCH_ROUNDS: int = 30


func _find_exp_pill(cm: ConfigManager) -> int:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw:
		var row: Dictionary = raw[tid_str]
		if String(row.get("Category", "")) == PILL_CATEGORY \
				and String(row.get("Consume Type", "")) == PILL_TYPE \
				and int(row.get("Exp", 0)) > 0:
			return int(tid_str)
	return 0


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var cm := ConfigManager.new()
	cm.load_all()
	var pill_id: int = _find_exp_pill(cm)
	var pd := PlayerData.new(cm)
	pd.add_item(pill_id, 5)
	pd.hero_manager.add_hero(1)
	var panel := EatexpPanel.new("eatexp", {})
	panel.setup_panel(pill_id, cm, pd)
	panel.show_window(get_tree().root)
	await get_tree().create_timer(0.3).timeout
	var close: TextureButton = panel._content.get_node("%CloseBtn") as TextureButton
	print("[probe] panel=", str(panel.get_path()), " close=", str(close.get_path()),
		" rect=", close.get_global_rect(), " filter=", close.mouse_filter,
		" conns=", close.get_signal_connection_list("pressed").size())
	for i in range(WATCH_ROUNDS):
		await get_tree().create_timer(1.0).timeout
		var alive: bool = is_instance_valid(panel) and not panel.is_queued_for_deletion()
		print("[probe] t=", i + 1, " alive=", alive)
		if not alive:
			print("[probe] PANEL CLOSED —— 真实输入点击关闭成功")
			return
