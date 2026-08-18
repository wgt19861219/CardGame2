class_name DailyLoginPanel
extends PopWindow

## 每日登录月签到面板（View 层）— 照源 ui/popwindow/dailylogin.lua 翻译。
## 批 2 两件套改造（2026-08-16）：静态 chrome + 网格底板常驻 scenes/ui/daily_login_content.tscn；
## 签到格 daily_login_cell.tscn 模板 fill（board 三态贴图/checked 勾/VIP 角标/Hero 光效/数量），
## 原 builder 层已退役（其 capInsets 互换错误与静态建节点随删除消亡）。
## 交互：点当日格(common)→领奖；点过去/未来格→奖励详情(Toast 降级，源 :422-460 弹卡)；
## close→关；奖励说明→说明(Toast 降级，源 :967-1028 弹窗)。
## Logic 走 DailyLoginManager.claim_reward（单机化：领后 status→received，源 part/all 双步合并）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/daily_login_content.tscn")
const CELL_SCENE: PackedScene = preload("res://scenes/ui/daily_login_cell.tscn")

# 网格布局（源 createList :380-420：wlen=103 hlen=101 wa=5 pad 12/14；
# 首格中心 board 局部 (58,56)——源 ox,oy=198,316 相对 board 顶左 (140,372)）
const COLS: int = 5
const CELL_OX: float = 58.0
const CELL_OY: float = 56.0
const CELL_DX: float = 103.0
const CELL_DY: float = 101.0
const GRID_PAD_X: float = 12.0
const GRID_PAD_Y: float = 14.0
# 显示尺寸换算 CS（纹理像素 ÷ 1.28125；dailylogin 系纹理 TextureConfig 无条目 → ÷CS）
const CONTENT_SCALE: float = 1.28125
# 单格局部锚点（源 :331/:352/:366 Cocos 左下原点 → y 按 board 显示高 101.5 翻转）
const ICON_CENTER_LOCAL: Vector2 = Vector2(51.0, 49.5)
# ReadequipIcon frame 纹理像素尺寸（Sprite2D 原尺寸渲染口径，hero_detail 装备槽同款；
# 源 :317-334 createIcon(id) 无 length → 显示原点尺寸 = 94×95÷CS = 73.37×74.13 →
# scale=1/CS 补偿 + 中心定位，task-11 修：旧版未补偿致 icon 偏大溢出 board/盖 VIP 角标）
const FRAME_TEX_SIZE: Vector2 = Vector2(94.0, 95.0)
const AMOUNT_RIGHT_LOCAL: Vector2 = Vector2(92.0, 79.5)
const VIP_TAG_LOCAL: Vector2 = Vector2(24.0, 21.5)
# 光效旋转（源 :313-315 CCRotateBy 5s/360 循环）
const LIGHT_SPIN_SEC: float = 5.0
# subhead 链式布局与弹跳（源 createSubhead :662-712 offset=5 / refreshSubhead :721-732）
const SUBHEAD_GAP: float = 5.0
const SUBHEAD_BOUNCE_PEAK: Vector2 = Vector2(1.5, 1.5)
const SUBHEAD_BOUNCE_SEC: float = 0.2
# 查表兜底年份（当年月缺表时回落，源 getMonthDayAmount :96-108）
const FALLBACK_YEAR: int = 2018
# board 三态贴图（源 :245-253：当日 common=yellow、past/future=matrix；
# purple 为源 VIP 双倍态，单机化裁剪——VIP 角标保留装饰）
const MATRIX_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_matrix.png"
const MATRIX_YELLOW_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_matrix_yellow.png"
# 静态类型奖励 icon（源 getRewardData :148-152 icon_res 表；PlayerEXP 条目资产未随迁 → 降级）
const ICON_DIAMOND_RES: String = "res://assets/ui/alpha/HVGA/task_rmb_icon.png"
const ICON_GOLD_RES: String = "res://assets/ui/alpha/HVGA/task_gold_icon.png"
const STATIC_ICON_MAP: Dictionary = {"Diamond": ICON_DIAMOND_RES, "Gold": ICON_GOLD_RES}

var _player: PlayerData
var _mgr: DailyLoginManager
var _cm: ConfigManager
var _data_list: Array = []
var _cells: Array = []
var _cell_statuses: Array = []
var _content: Control = null
var _grid_content: Control = null
var _reward_bg: NinePatchRect = null
var _subhead_pre: Label = null
var _subhead_num: Label = null
var _subhead_suf: Label = null
var _subhead_bounce_tween: Tween = null   # refreshSubhead 弹跳 tween（kill 复用）


func setup_panel(p_player: PlayerData) -> void:
	_player = p_player
	_mgr = _player.daily_login
	_cm = _player.cm
	setup()
	hud_identity = "dailylogin"   # 2026-08-18 修复轮二 R2：主城直开——切子场景 StatusBar（无头像，excavate 判例），用户反馈主头像透到二级界面
	_build_content()


# 建 UI 内容：静态 chrome 从 .tscn instantiate + fill 动态数据/信号；
# 网格 cell 模板 fill 挂 %GridContent。源 create + createSubhead + createListLayer + createList 组合。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	# close（源 :763 close sprite + close_press 子节点 visible 切换）
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	# explain 按钮（源 :821-874 Scale9 explain/explain_press → theme DailyLoginExplainBtn
	# 三态接管，fill 只填 LSTR 文案）
	var explain_btn := _content.get_node("%ExplainBtn") as Button
	(explain_btn.get_node("%ExplainLabel") as Label).text = \
		_cm.get_lstr("DAILYLOGIN.AWARDS_DESCRIPTION") if _cm != null else "奖励说明"
	explain_btn.pressed.connect(_on_explain)
	_subhead_pre = _content.get_node("%SubheadPreLabel") as Label
	_subhead_num = _content.get_node("%SubheadNumLabel") as Label
	_subhead_suf = _content.get_node("%SubheadSufLabel") as Label
	_grid_content = _content.get_node("%GridContent") as Control
	_reward_bg = _grid_content.get_node("%RewardBg") as NinePatchRect
	_refresh_view()


# chrome 静态节点不动，只刷新 title/subhead text + 重建网格。
# bounce=true（领奖后）→ subhead_num 弹跳（源 refreshSubhead:721-732）；false（初建）不跳。
func _refresh_view(bounce: bool = false) -> void:
	_data_list = build_reward_data(_cm)
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
	if bounce:
		_play_subhead_bounce()
	# 网格状态（源 getRewardStatus :119-136 逐日 past/common/future）
	_cell_statuses.clear()
	for i in range(_data_list.size()):
		_cell_statuses.append(_cell_status(i + 1, freq, status))
	_fill_grid()


# 网格 fill（源 createList :380-420 + createRewardItem :222-378）：
# 清旧 cell（保留 RewardBg 底板）→ 设 content/bg 尺寸（ha 行数随当月天数变）→ 逐日实例化 cell 模板。
func _fill_grid() -> void:
	for c in _grid_content.get_children():
		if c != _reward_bg:
			c.queue_free()
	var da: int = _data_list.size()
	var ha: int = maxi(1, int(ceil(float(da) / float(COLS))))
	var grid_size := Vector2(CELL_DX * float(COLS) + GRID_PAD_X, CELL_DY * float(ha) + GRID_PAD_Y)
	_grid_content.custom_minimum_size = grid_size
	_grid_content.size = grid_size
	_reward_bg.custom_minimum_size = grid_size
	_reward_bg.size = grid_size
	_cells.clear()
	for i in range(da):
		var st: String = String(_cell_statuses[i]) if i < _cell_statuses.size() else "future"
		var cell := CELL_SCENE.instantiate() as TextureButton
		cell.name = "Cell%d" % (i + 1)
		var col: int = i % COLS
		var row: int = int(i / COLS)
		cell.position = Vector2(CELL_OX + CELL_DX * float(col), CELL_OY + CELL_DY * float(row)) - cell.size * 0.5
		cell.texture_normal = load(MATRIX_YELLOW_RES if st == "common" else MATRIX_RES) as Texture2D
		_grid_content.add_child(cell)
		_fill_cell(cell, _data_list[i], st)
		cell.pressed.connect(_on_cell_pressed.bind(i + 1))
		_cells.append(cell)


# 单格 fill：数量/VIP 角标/Hero 光效（源 createRewardItem :222-378）。
# checked 勾排模板最后绘制（源 z=10 置顶）；三态贴图在 _fill_grid 已切。
func _fill_cell(cell: TextureButton, data: Dictionary, status: String) -> void:
	var amount_lbl := cell.get_node("%AmountLabel") as Label
	amount_lbl.text = "x%d" % int(data.get("amount", 1))
	amount_lbl.size = amount_lbl.get_minimum_size()
	amount_lbl.position = AMOUNT_RIGHT_LOCAL - Vector2(amount_lbl.size.x, amount_lbl.size.y * 0.5)
	var vip: int = int(data.get("vip", 0))
	(cell.get_node("%VipBg") as TextureRect).visible = vip > 0
	var vip_num := cell.get_node("%VipNum") as Label
	vip_num.visible = vip > 0
	if vip > 0:
		vip_num.text = "VIP%d" % vip
		vip_num.size = vip_num.get_minimum_size()
		vip_num.pivot_offset = vip_num.size * 0.5
		vip_num.position = VIP_TAG_LOCAL - vip_num.size * 0.5
	var light := cell.get_node("%Light") as TextureRect
	var want_light: bool = String(data.get("type", "")) == "Hero" and (status == "future" or status == "common")
	light.visible = want_light
	if want_light:
		var tw := light.create_tween().set_loops()
		tw.tween_property(light, "rotation", TAU, LIGHT_SPIN_SEC).as_relative()
	(cell.get_node("%CheckedIcon") as TextureRect).visible = (status == "past")
	_fill_icon(cell.get_node("%IconHost") as TextureRect, data)


# 奖励 icon fill（源 :317-334 icon 中心 board 局部 (51,52)）：
# Item/Hero → ReadequipIcon 动态节点；Diamond/Gold → host 直接填纹理（÷CS 显示尺寸）；
# PlayerEXP 源 icon_res 表条目 task_exp_icon.png 资产未随迁 → 降级 EXP Label。
func _fill_icon(host: TextureRect, data: Dictionary) -> void:
	for c in host.get_children():
		c.queue_free()
	host.texture = null
	var type: String = String(data.get("type", ""))
	var id: int = int(data.get("id", 0))
	if type == "Item" or type == "Hero":
		if id > 0:
			var icon := ReadequipIcon.create_icon(id, 0, _cm)
			if icon != null:
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				host.add_child(icon)
				# 源显示原点尺寸（无 length）→ scale=1/CS 使视觉=73.37×74.13；
				# 中心 (51,52) y-up → godot (51,49.5)，左上 = 中心 - 半视觉盒
				icon.scale = Vector2.ONE / CONTENT_SCALE
				icon.position = ICON_CENTER_LOCAL - FRAME_TEX_SIZE / CONTENT_SCALE * 0.5
		return
	var res_path: String = String(STATIC_ICON_MAP.get(type, ""))
	if res_path.is_empty():
		var lbl := Label.new()
		lbl.text = "EXP"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(lbl)
		lbl.position = ICON_CENTER_LOCAL - lbl.get_minimum_size() * 0.5
		return
	var tex := load(res_path) as Texture2D
	if tex == null:
		return
	host.texture = tex
	var sz: Vector2 = tex.get_size() / CONTENT_SCALE
	host.size = sz
	host.position = ICON_CENTER_LOCAL - sz * 0.5


# 源 dailylogin.lua:721-732 refreshSubhead：number setScale(0.2,1.5) SineOut → setScale(0.2,1) SineIn。
# anchor(0.5,0.5) → pivot 居中，弹跳绕中心。
func _play_subhead_bounce() -> void:
	if not is_instance_valid(_subhead_num):
		return
	# pivot 居中（Label 默认 pivot 0,0；设为 minimum_size/2 让 scale 绕中心）。
	_subhead_num.pivot_offset = _subhead_num.size * 0.5
	if _subhead_bounce_tween != null and _subhead_bounce_tween.is_valid():
		_subhead_bounce_tween.kill()
	_subhead_bounce_tween = create_tween()
	_subhead_bounce_tween.tween_property(_subhead_num, "scale", SUBHEAD_BOUNCE_PEAK, SUBHEAD_BOUNCE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_subhead_bounce_tween.tween_property(_subhead_num, "scale", Vector2.ONE, SUBHEAD_BOUNCE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


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
		_refresh_view(true)   # 领奖后 refreshSubhead 弹跳（源 :721-732）
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


# ── 数据查表（源 getRewardData :147-181 / getMonthDayAmount :96-108，原 builder 吸收）──

static func build_reward_data(cm: Variant) -> Array:
	var table: Dictionary = cm.get_raw_table(&"DailyLoginReward")
	var now_dict: Dictionary = Time.get_datetime_dict_from_system()
	var year: int = int(now_dict.get("year", FALLBACK_YEAR))
	var month: int = int(now_dict.get("month", 1))
	var month_data: Dictionary = {}
	for try_year in [year, FALLBACK_YEAR]:
		var md: Dictionary = table.get(str(try_year), {}).get(str(month), {})
		if not md.is_empty():
			month_data = md
			break
	if month_data.is_empty():
		return []
	var da: int = month_day_amount(month_data)
	var out: Array = []
	for i in range(1, da + 1):
		var row: Dictionary = month_data.get(str(i), {})
		if row.is_empty():
			break
		out.append({
			"type": String(row.get("Reward Type", "")),
			"id": int(row.get("Reward ID", 0)),
			"amount": int(row.get("Reward Amount", 0)),
			"vip": int(row.get("Double Reward VIP Level", 0)),
			"day": i,
		})
	return out


static func month_day_amount(month_data: Dictionary) -> int:
	var i: int = 1
	while month_data.has(str(i)) and not String(month_data[str(i)].get("Reward Type", "")).is_empty():
		i += 1
	return i - 1


static func _current_month() -> int:
	return int(Time.get_datetime_dict_from_system().get("month", 1))
