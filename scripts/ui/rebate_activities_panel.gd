class_name RebateActivitiesPanel
extends PopWindow

## 运营活动详情面板（View 层）— 照源 ui/rebateActivities.lua + rebateActivitiesConfig.lua UIRes 翻译。
## 两件套（2026-10-13）：静态 chrome scenes/ui/rebate_activities_content.tscn；
## 档位行 rebate_activities_item.tscn 模板 fill 三态（源 createPrizeIndex :123-172：
## 未领达标 bg_2+领取按钮 / 未领未达标 bg_1 / 已领 bg_1+mask+绿勾）。
## 领取走 ActivityManager.claim（源 completeTask→job_rewards act_ 分支；入账+已领标记在 manager）。
## 规则弹窗 rebate_rules_content.tscn 挂本 panel container 顶层（源 showRoles z=700）。
## 2026-10-13 用户拍板：玩法活动临时下线，ActivitiesConfig 只留一条 announce 纯展示公告
## （无档位/无领取/无红点）；面板与管线全保留，恢复活动只需换回 JSON 数据。
## 受控裁剪（2026-10-13）：「立即购买游戏币」充值按钮（源 :434-448 addRecharge，单机无充值，
## 源仅 rmb_recharge 活动显示而本项目无该类型）；按住奖励格弹道具详情卡（源 suspensionLayer）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/rebate_activities_content.tscn")
const ITEM_SCENE: PackedScene = preload("res://scenes/ui/rebate_activities_item.tscn")
const RULES_SCENE: PackedScene = preload("res://scenes/ui/rebate_rules_content.tscn")

const CONTENT_SCALE: float = 1.28125   # 散图显示口径（task_gold/rmb 无 TextureConfig 条目）
const PRIZE_ICON_SCALE: float = 0.8    # 源 createPrize plistIcon setScale(0.8)
const BG_READY_RES: String = "res://assets/ui/alpha/HVGA/activity/activity_list_bg_2.png"
const BG_NORMAL_RES: String = "res://assets/ui/alpha/HVGA/activity/activity_list_bg_1.png"
const CLAIM_BTN_RES: String = "res://assets/ui/alpha/HVGA/task_get_reward_button.png"
const CLAIMED_ICON_RES: String = "res://assets/ui/alpha/HVGA/dailylogin/dailylogin_checked_green.png"
const ICON_DIAMOND_RES: String = "res://assets/ui/alpha/HVGA/task_rmb_icon.png"
const ICON_GOLD_RES: String = "res://assets/ui/alpha/HVGA/task_gold_icon.png"

const TYPE_DIAMOND: String = "diamond_consume"
const TYPE_TAVERN_ONCE: String = "tavern_once"
const TYPE_TAVERN_TEN: String = "tavern_ten"

var _player: PlayerData
var _cm: ConfigManager
var _act: Dictionary = {}
var _content: Control = null
var _prize_host: VBoxContainer = null


func setup_panel(p_player: PlayerData, p_act: Dictionary) -> void:
	_player = p_player
	_act = p_act
	_cm = _player.cm
	setup()
	_build_content()


func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	(_content.get_node("%RulesBtn") as BaseButton).pressed.connect(_on_rules_pressed)
	_prize_host = _content.get_node("%PrizeHost") as VBoxContainer
	_refresh_view()


func _refresh_view() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var acts: Array = _player.activity.get_activities(now, _cm)
	_act = _find_act(acts, String(_act.get("key", "")))
	(_content.get_node("%TitleLabel") as Label).text = String(_act.get("title", ""))
	var is_announce: bool = String(_act.get("type", "")) == "announce"
	var time_lbl := _content.get_node("%TimeValueLabel") as Label
	if is_announce:
		time_lbl.text = "长期有效"   # 纯展示公告无档期（2026-10-13 玩法活动临时下线改公告）
	else:
		time_lbl.text = "%s ~ %s" % [
			_format_time(int(_act.get("start", 0))), _format_time(int(_act.get("end", 0)))]
	(_content.get_node("%DescValueLabel") as Label).text = String(_act.get("desc", ""))
	var hasdone := _content.get_node("%HasDoneLabel") as Label
	hasdone.visible = not is_announce
	if not is_announce:
		hasdone.text = _hasdone_text()
	_fill_rows()


static func _find_act(acts: Array, key: String) -> Dictionary:
	for a in acts:
		if String(a.get("key", "")) == key:
			return a
	return {}


func _hasdone_text() -> String:
	var progress: int = int(_act.get("progress", 0))
	match String(_act.get("type", "")):
		TYPE_TAVERN_ONCE:
			return "本周已单抽 %d 次" % progress
		TYPE_TAVERN_TEN:
			return "本周已十连 %d 次" % progress
	return "已累计消费 %d 钻石" % progress


# 档位行 fill（源 init :25-39 + createPrizeIndex：清旧行 → 逐档实例化模板填三态）。
func _fill_rows() -> void:
	for c in _prize_host.get_children():
		_prize_host.remove_child(c)
		c.queue_free()
	var tiers: Array = _act.get("tiers", [])
	for i in range(tiers.size()):
		var tier: Dictionary = tiers[i]
		var row := ITEM_SCENE.instantiate() as Control
		row.name = "TierRow%d" % i
		_prize_host.add_child(row)
		_fill_row(row, tier, i)
		row.gui_input.connect(_on_row_gui_input.bind(i))


func _fill_row(row: Control, tier: Dictionary, index: int) -> void:
	var claimed: bool = bool(tier.get("claimed", false))
	var ready: bool = bool(tier.get("ready", false))
	var bg := row.get_node("%Bg") as TextureRect
	bg.texture = load(BG_READY_RES if (ready and not claimed) else BG_NORMAL_RES) as Texture2D
	(row.get_node("%MaskReceived") as TextureRect).visible = claimed
	(row.get_node("%CondPreLabel") as Label).text = _cond_pre_text()
	var val_lbl := row.get_node("%CondValLabel") as Label
	val_lbl.text = _cond_val_text(int(tier.get("threshold", 0)))
	val_lbl.position = (row.get_node("%CondPreLabel") as Label).position \
			+ Vector2((row.get_node("%CondPreLabel") as Label).get_minimum_size().x, 0.0)
	_fill_claim(row.get_node("%ClaimHost") as Control, claimed, ready, index)
	var reward: Dictionary = tier.get("reward", {})
	_fill_prize_slot(row, 1, reward)
	(row.get_node("%IconHost2") as Control).visible = false
	(row.get_node("%IconHost3") as Control).visible = false


func _cond_pre_text() -> String:
	match String(_act.get("type", "")):
		TYPE_TAVERN_ONCE:
			return "本周完成"
		TYPE_TAVERN_TEN:
			return "本周完成"
	return "累计消费"


func _cond_val_text(threshold: int) -> String:
	match String(_act.get("type", "")):
		TYPE_TAVERN_ONCE:
			return "1 次单抽"
		TYPE_TAVERN_TEN:
			return "1 次十连"
	return "%d 钻石" % threshold


# 领取区 fill（源 getRes：可领 task_get_reward_button / 已领绿勾；未达标无图标）。
func _fill_claim(host: Control, claimed: bool, ready: bool, index: int) -> void:
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()
	if claimed:
		var icon := TextureRect.new()
		var tex := load(CLAIMED_ICON_RES) as Texture2D
		icon.texture = tex
		var sz: Vector2 = tex.get_size() / CONTENT_SCALE * 0.66
		icon.size = sz
		icon.position = (host.size - sz) * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(icon)
	elif ready:
		var btn := TextureButton.new()
		btn.texture_normal = load(CLAIM_BTN_RES) as Texture2D
		var bsz: Vector2 = (load(CLAIM_BTN_RES) as Texture2D).get_size() / CONTENT_SCALE * 0.9
		btn.size = bsz
		btn.position = (host.size - bsz) * 0.5
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_claim_pressed_index.bind(index))
		host.add_child(btn)


# 奖励格 fill（源 createPrize :40-93：货币/物品图标 + x数量 + 名字）。
# 格子子节点用普通路径取（IconHost1/2/3 三组同名子节点不可都开唯一名，AGENTS 规范）。
func _fill_prize_slot(row: Control, slot: int, reward: Dictionary) -> void:
	var host := row.get_node("IconHost%d" % slot) as Control
	var tex_host := host.get_node("IconTextureHost") as TextureRect
	tex_host.texture = null
	var rtype: String = String(reward.get("type", ""))
	var rid: int = int(reward.get("id", 0))
	var name_text: String = ""
	var icon_scale: float = PRIZE_ICON_SCALE
	if rtype == "item" and rid > 0:
		var icon := ReadequipIcon.create_icon(rid, 0, _cm)
		if icon != null:
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex_host.add_child(icon)
			icon.position = Vector2.ZERO
		name_text = _equip_name(rid)
	elif rtype == "rmb":
		tex_host.texture = load(ICON_DIAMOND_RES) as Texture2D
		tex_host.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_host.stretch_mode = TextureRect.STRETCH_SCALE
		name_text = _lstr("RECHARGE.DIAMOND", "钻石")
	else:
		tex_host.texture = load(ICON_GOLD_RES) as Texture2D
		tex_host.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_host.stretch_mode = TextureRect.STRETCH_SCALE
		icon_scale = PRIZE_ICON_SCALE * 0.8   # 金币图标较大再收一档（视觉对齐源 0.8 档）
		name_text = _lstr("TASK.GOLD", "金币")
	if tex_host.texture != null:
		var base: Vector2 = tex_host.texture.get_size() / CONTENT_SCALE
		var sz: Vector2 = base * icon_scale
		tex_host.size = sz
		tex_host.position = Vector2((host.size.x - sz.x) * 0.5, 2.0)
	(host.get_node("AmountLabel") as Label).text = "x%d" % int(reward.get("amount", 0))
	(host.get_node("NameLabel") as Label).text = name_text


func _equip_name(item_id: int) -> String:
	var equip: Dictionary = _cm.get_raw_table(&"Equip").get(str(item_id), {})
	return String(equip.get("Name", str(item_id)))


func _lstr(key: String, fallback: String) -> String:
	if _cm == null:
		return fallback
	var s: String = _cm.get_lstr(key)
	return s if s != key else fallback


# 行点击（源 onListClick :328-350 由行背景触发）：可领→领取；已领→提示；未达标→进度提示
# （源未达标无响应，此处加 Toast 为体验微调）。
func _on_row_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_on_claim_pressed_index(index)


func _on_claim_pressed_index(index: int) -> void:
	var tiers: Array = _act.get("tiers", [])
	if index < 0 or index >= tiers.size():
		return
	var tier: Dictionary = tiers[index]
	var job: String = String(tier.get("job", ""))
	var now: int = int(Time.get_unix_time_from_system())
	var r: Dictionary = _player.activity.claim(_player, _cm, job, now)
	if bool(r.get("ok", false)):
		var reward: Dictionary = r.get("reward", {})
		Toast.show_message("领取成功：%s x%d" % [_reward_name(reward), int(reward.get("amount", 0))])
		GameData.mark_save_dirty()
		_refresh_view()
	elif String(r.get("reason", "")) == "claimed":
		Toast.show_message("该档奖励已领取")
	else:
		Toast.show_message("进度未达标，继续努力吧")


func _reward_name(reward: Dictionary) -> String:
	var rtype: String = String(reward.get("type", ""))
	if rtype == "item":
		return _equip_name(int(reward.get("id", 0)))
	if rtype == "rmb":
		return _lstr("RECHARGE.DIAMOND", "钻石")
	return _lstr("TASK.GOLD", "金币")


# 规则弹窗（源 showRoles :210-219，rolUIRes z=700 盖本面板）。
func _on_rules_pressed() -> void:
	var popup := RULES_SCENE.instantiate() as Control
	container.add_child(popup)
	(popup.get_node("%CloseBtn") as BaseButton).pressed.connect(popup.queue_free)
	(popup.get_node("%RulesTextLabel") as Label).text = String(_act.get("rules", ""))


# 时间格式化（源 os.date "%m-%d %H:%M" 本地时区；_local_date 同口径 +bias 拆解）。
static func _format_time(ts: int) -> String:
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(ts + off_min * 60)
	return "%02d-%02d %02d:%02d" % [int(d.get("month", 1)), int(d.get("day", 1)),
			int(d.get("hour", 0)), int(d.get("minute", 0))]
