class_name ChapterStarPanel
extends PopWindow

## 章节星数奖励面板（View 层）— 照源 chapter_star_reward handler（local_server.lua:4264-4294）配套 UI。
## 展示某章节 3 tier（30/60/90 星）状态 + 领奖按钮。源章节视图宝箱；本项目独立面板。
## 领奖后 Toast 提示（刷新待优化：关闭重开看新状态）。

const CLOSE_POS: Vector2 = Vector2(880.0, 20.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const TITLE_POS: Vector2 = Vector2(350.0, 20.0)
const TOTAL_POS: Vector2 = Vector2(350.0, 50.0)
const ROW_INFO_POS: Vector2 = Vector2(200.0, 90.0)
const ROW_BTN_POS: Vector2 = Vector2(620.0, 90.0)
const ROW_DY: float = 40.0
const ROW_SIZE: Vector2 = Vector2(400.0, 30.0)
const BTN_SIZE: Vector2 = Vector2(80.0, 30.0)

var _player: PlayerData
var _mgr: StageManager
var _chapter_id: int


func setup_panel(p_player: PlayerData, p_mgr: StageManager, chapter_id: int) -> void:
	_player = p_player
	_mgr = p_mgr
	_chapter_id = chapter_id
	setup()
	_build_ui()


func _build_ui() -> void:
	var close: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_POS)   # 替原文字按钮（X 关闭弹窗）
	close.pressed.connect(remove_window)
	container.add_child(close)
	var title := Label.new()
	title.text = "章节 %d 星数奖励" % _chapter_id
	title.position = TITLE_POS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(title)
	var status: Dictionary = _mgr.get_chapter_star_status(_player, _chapter_id)
	var total_lbl := Label.new()
	total_lbl.text = "总星数：%d" % int(status["total_stars"])
	total_lbl.position = TOTAL_POS
	total_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(total_lbl)
	var y: float = ROW_INFO_POS.y
	for t in status["tiers"]:
		_add_tier_row(t as Dictionary, y)
		y += ROW_DY


func _add_tier_row(td: Dictionary, y: float) -> void:
	var stars: int = int(td["stars"])
	var unlocked: bool = bool(td["unlocked"])
	var claimed: bool = bool(td["claimed"])
	var state: String = "已领" if claimed else ("可领" if unlocked else "未达成")
	var info := Label.new()
	info.text = "Tier%d（%d星）：%s" % [int(td["tier"]), stars, state]
	info.position = Vector2(ROW_INFO_POS.x, y)
	info.size = ROW_SIZE
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(info)
	var btn := Button.new()
	btn.position = Vector2(ROW_BTN_POS.x, y)
	btn.size = BTN_SIZE
	btn.text = "领取"
	btn.disabled = not unlocked or claimed
	btn.pressed.connect(_on_claim.bind(int(td["tier"])))
	container.add_child(btn)


func _on_claim(tier: int) -> void:
	var r: Dictionary = _mgr.claim_chapter_star_reward(_player, _chapter_id, tier)
	Toast.show_message("领取成功" if bool(r["ok"]) else "领取失败")
