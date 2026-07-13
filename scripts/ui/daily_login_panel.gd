class_name DailyLoginPanel
extends PopWindow

## 连续登录奖励面板（View 层）— 照源 ask_daily_login reply 渲染。
## 显示当前连续天数 + 今日奖励 + 领取按钮。Logic 走 DailyLoginManager.claim_reward。

const TITLE_POS: Vector2 = Vector2(350.0, 30.0)
const INFO_POS: Vector2 = Vector2(150.0, 100.0)
const BTN_POS: Vector2 = Vector2(350.0, 300.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const CLOSE_POS: Vector2 = Vector2(820.0, 20.0)

var _mgr: DailyLoginManager
var _player: PlayerData


func setup_panel(p_player: PlayerData) -> void:
	_player = p_player
	_mgr = _player.daily_login
	setup()
	_refresh_view()


func _refresh_view() -> void:
	for c in container.get_children():
		c.queue_free()
	var close: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_POS)
	close.pressed.connect(remove_window)
	container.add_child(close)
	var title := Label.new()
	title.text = "每日登录奖励"
	title.position = TITLE_POS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(title)
	var now: int = int(Time.get_unix_time_from_system())
	var freq: int = _mgr.get_login_frequency(now)
	var reward_status: String = _mgr.get_reward_status(now)
	var info := Label.new()
	var status_text: String = "今日可领" if reward_status == "common" else "今日已领"
	info.text = "连续登录 %d 天\n状态：%s" % [freq, status_text]
	info.position = INFO_POS
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(info)
	# 领取按钮
	if reward_status == "common":
		var btn := Button.new()
		btn.text = "领取奖励"
		btn.position = BTN_POS
		btn.pressed.connect(_on_claim)
		container.add_child(btn)


func _on_claim() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var r: Dictionary = _mgr.claim_reward(_player, _player.cm, now)
	if bool(r.get("ok", false)):
		Toast.show_message("领取成功：%s ×%d" % [String(r.get("type", "")), int(r.get("amount", 0))])
		_refresh_view()
	else:
		Toast.show_message("今日已领取或无奖励数据")
