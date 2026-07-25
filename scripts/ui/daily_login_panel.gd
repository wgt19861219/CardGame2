class_name DailyLoginPanel
extends PopWindow

## 每日登录月签到面板（View 层）— 照源 ui/popwindow/dailylogin.lua 翻译。
## 渲染：背景框架 + 累计签到 + 5 列月签到网格（matrix 状态色/图标/已领勾/VIP 角标/Hero 光效）+ close + 奖励说明。
## 交互：点当日格(common)→领奖；点过去/未来格→奖励详情(Toast 降级，源 createRewardDetail :422-460 弹卡)；
## close→关；奖励说明→说明(Toast 降级，源 createExplain :967-1028 弹窗)。
## Logic 走 DailyLoginManager.claim_reward（单机化：领后 status→all/received，源 part/all 双步合并）。
##
## 重构（2026-07-18，hero_detail 范式）：chrome（frame/title_bg/act_bg/close/title/explain/subhead 3 label/
## grid ScrollContainer）静态化进 scenes/ui/daily_login_content.tscn（位置/size 编辑器可视化调）；
## 网格 content + 单格（按当月天数动态变）保留 procedural 挂 %GridScroll（builder.fill_grid）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/daily_login_content.tscn")

# explain Scale9 按钮资源/cap/label 色（源 :821-874 explain + explain_label，.tscn Button 运行时套 StyleBox）。
const EXPLAIN_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_1.png"
const EXPLAIN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_2.png"
const EXPLAIN_CAP: Rect2 = Rect2(20.0, 15.0, 88.0, 19.0)
const EXPLAIN_LABEL_COLOR: Color = Color(225.0 / 255.0, 209.0 / 255.0, 186.0 / 255.0)
const SUBHEAD_GAP: float = 5.0

var _player: PlayerData
var _mgr: DailyLoginManager
var _cm: ConfigManager
var _data_list: Array = []
var _cells: Array = []
var _cell_statuses: Array = []
var _content: Control = null
var _subhead_pre: Label = null
var _subhead_num: Label = null
var _subhead_suf: Label = null


func setup_panel(p_player: PlayerData) -> void:
	_player = p_player
	_mgr = _player.daily_login
	_cm = _player.cm
	setup()
	_build_content()


# 建 UI 内容：chrome 静态节点从 .tscn instantiate（位置/size 可视化）+ fill 动态数据/信号；
# 网格 procedural 挂 %GridScroll（builder.fill_grid）。源 create + createSubhead + createListLayer 组合。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate()
	container.add_child(_content)
	# close（源 :763 close sprite + close_press 子节点 visible 切换）
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	# explain Scale9 按钮（源 :821-874，.tscn 普通 Button → 运行时套 StyleBoxTexture 补九宫格视觉）
	var explain_btn := _content.get_node("%ExplainBtn") as Button
	var explain_text: String = _cm.get_lstr("DAILYLOGIN.AWARDS_DESCRIPTION") if _cm != null else "奖励说明"
	UiScale9Button.apply_with_label(explain_btn, EXPLAIN_RES, EXPLAIN_PRESS_RES, EXPLAIN_CAP, explain_text, EXPLAIN_LABEL_COLOR)
	explain_btn.pressed.connect(_on_explain)
	_subhead_pre = _content.get_node("%SubheadPreLabel") as Label
	_subhead_num = _content.get_node("%SubheadNumLabel") as Label
	_subhead_suf = _content.get_node("%SubheadSufLabel") as Label
	_refresh_view()


# chrome 静态节点不动，只刷新 title/subhead text + 重建网格。
func _refresh_view() -> void:
	_data_list = DailyLoginBuilder.build_reward_data(_cm)
	var now: int = int(Time.get_unix_time_from_system())
	var freq: int = _mgr.get_login_frequency(now)
	var status: String = _mgr.get_reward_status(now)
	var checkin_num: int = freq if status != "common" else freq - 1
	# title LSTR（源 syncDate :893 DAILYLOGIN._D_MONTHLY_ATTENDANCE_AWARDS）
	var title_text: String = _cm.get_lstr("DAILYLOGIN._D_MONTHLY_ATTENDANCE_AWARDS") % _current_month() if _cm != null else "%d月签到奖励" % _current_month()
	(_content.get_node("%TitleLabel") as Label).text = title_text
	# subhead 3 label text + 链式 right2 布局（源 :662/:697/:712 anchor 0,0.5 offset=5）
	_subhead_pre.text = _cm.get_lstr("DAILYLOGIN.THIS_MONTH_HAS_A_TOTAL_ATTENDANCE") if _cm != null else "本月已累计签到"
	_subhead_num.text = str(checkin_num)
	_subhead_suf.text = _cm.get_lstr("DAILYLOGIN.TIMES") if _cm != null else "次"
	_subhead_num.position = _subhead_pre.position + Vector2(_subhead_pre.get_minimum_size().x + SUBHEAD_GAP, 0.0)
	_subhead_suf.position = _subhead_num.position + Vector2(_subhead_num.get_minimum_size().x + SUBHEAD_GAP, 0.0)
	# 网格（builder.fill_grid 清 %GridScroll 子节点并重建 content + cells）
	var grid_scroll := _content.get_node("%GridScroll") as ScrollContainer
	_cell_statuses.clear()
	for i in range(_data_list.size()):
		_cell_statuses.append(_cell_status(i + 1, freq, status))
	var grid: Dictionary = DailyLoginBuilder.fill_grid(grid_scroll, _data_list, _cell_statuses, _cm)
	_cells = grid["cells"]
	for c in _cells:
		(c["button"] as TextureButton).pressed.connect(_on_cell_pressed.bind(int(c["day"])))


func _cell_status(day: int, freq: int, status: String) -> String:
	if day < freq:
		return "past"
	if day == freq:
		return "common" if status == "common" else "past"
	return "future"


func _on_cell_pressed(day: int) -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var st: String = _cell_status(day, _mgr.get_login_frequency(now), _mgr.get_reward_status(now))
	if st == "common":
		_claim(day)
	else:
		_show_detail(day)


func _claim(day: int) -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var r: Dictionary = _mgr.claim_reward(_player, _cm, now)
	if bool(r.get("ok", false)):
		Toast.show_message("领取成功：%s ×%d" % [String(r.get("type", "")), int(r.get("amount", 0))])
		_refresh_view()
	else:
		var fail_text: String = _cm.get_lstr("DAILYLOGIN.FAILED_TO_RECEIVE") if _cm != null else "领取失败"
		Toast.show_message(fail_text)


func _show_detail(day: int) -> void:
	if day < 1 or day > _data_list.size():
		return
	var detail_text: String = _cm.get_lstr("DAILYLOGIN.RECEIVE_THIS_AWARD_AT__D_ATTENDANCE_THIS_MONTH") % day if _cm != null else "第%d天奖励详情" % day
	Toast.show_message(detail_text)


func _on_explain() -> void:
	Toast.show_message("每日5:00重置，过期不可补领。达VIP等级当日可领双倍。")


static func _current_month() -> int:
	return int(Time.get_datetime_dict_from_system().get("month", 1))
