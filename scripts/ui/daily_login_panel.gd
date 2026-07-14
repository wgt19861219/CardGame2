class_name DailyLoginPanel
extends PopWindow

## 每日登录月签到面板（View 层）— 照源 ui/popwindow/dailylogin.lua 翻译。
## 渲染：背景框架 + 累计签到 + 5 列月签到网格（matrix 状态色/图标/已领勾/VIP 角标/Hero 光效）+ close + 奖励说明。
## 交互：点当日格(common)→领奖；点过去/未来格→奖励详情(Toast 降级，源 createRewardDetail :422-460 弹卡)；
## close→关；奖励说明→说明(Toast 降级，源 createExplain :967-1028 弹窗)。
## Logic 走 DailyLoginManager.claim_reward（单机化：领后 status→all/received，源 part/all 双步合并）。
## View 工厂 DailyLoginBuilder；本主类 ≤400 行铁律。

var _player: PlayerData
var _mgr: DailyLoginManager
var _cm: ConfigManager
var _data_list: Array = []
var _cells: Array = []
var _cell_statuses: Array = []
var _subhead_num: Label = null


func setup_panel(p_player: PlayerData) -> void:
	_player = p_player
	_mgr = _player.daily_login
	_cm = _player.cm
	setup()
	_refresh_view()


# 源 create + syncDate + createList + createSubhead 组合（刷新即重建网格，源 createRewardItem 重建单格）。
func _refresh_view() -> void:
	for c in container.get_children():
		c.queue_free()
	_cells.clear()
	_cell_statuses.clear()
	_data_list = DailyLoginBuilder.build_reward_data(_cm)
	var now: int = int(Time.get_unix_time_from_system())
	var freq: int = _mgr.get_login_frequency(now)
	var status: String = _mgr.get_reward_status(now)
	var checkin_num: int = freq if status != "common" else freq - 1   # 源 getCheckinNumber :137-146
	var chrome: Dictionary = DailyLoginBuilder.create_chrome(container, "%d月签到奖励" % _current_month(), checkin_num)
	(chrome["close"] as TextureButton).pressed.connect(remove_window)
	(chrome["explain"] as Button).pressed.connect(_on_explain)
	_subhead_num = chrome["subhead_num"]
	for i in range(_data_list.size()):
		_cell_statuses.append(_cell_status(i + 1, freq, status))
	var grid: Dictionary = DailyLoginBuilder.create_grid(container, _data_list, _cell_statuses, _cm)
	_cells = grid["cells"]
	for c in _cells:
		(c["button"] as TextureButton).pressed.connect(_on_cell_pressed.bind(int(c["day"])))


# 源 getRewardStatus :119-136（单机：vip 态省略，received→past）。
func _cell_status(day: int, freq: int, status: String) -> String:
	if day < freq:
		return "past"
	if day == freq:
		return "common" if status == "common" else "past"
	return "future"


# 源 doClickIn :603-623（past/future→详情；common→领奖）。
func _on_cell_pressed(day: int) -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var st: String = _cell_status(day, _mgr.get_login_frequency(now), _mgr.get_reward_status(now))
	if st == "common":
		_claim(day)
	else:
		_show_detail(day)


# 源 askCommonReward + doDailyReward + askRewardReply（单机：mgr.claim_reward 一步发奖）。
func _claim(day: int) -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var r: Dictionary = _mgr.claim_reward(_player, _cm, now)
	if bool(r.get("ok", false)):
		Toast.show_message("领取成功：%s ×%d" % [String(r.get("type", "")), int(r.get("amount", 0))])
		_refresh_view()
	else:
		Toast.show_message("今日已领取或无奖励数据")


# 源 createRewardDetail :422-460（弹详情卡）→ 降级 Toast（单机化，readequip.getDetailCard 依赖重）。
func _show_detail(day: int) -> void:
	if day < 1 or day > _data_list.size():
		return
	var d: Dictionary = _data_list[day - 1]
	Toast.show_message("第%d天奖励：%s ID%d ×%d" % [day, String(d.get("type", "")), int(d.get("id", 0)), int(d.get("amount", 0))])


# 源 createExplain :967-1028（continuechargedialog 弹窗）→ 降级 Toast。
func _on_explain() -> void:
	Toast.show_message("每日5:00重置，过期不可补领。达VIP等级当日可领双倍。")


static func _current_month() -> int:
	return int(Time.get_datetime_dict_from_system().get("month", 1))
