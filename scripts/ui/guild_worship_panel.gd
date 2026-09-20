class_name GuildWorshipPanel
extends PopWindow

## 膜拜弹窗（View 层）— 照源 guild.lua worshihInfoLayer（:3243 对象/次数/领取）+
## worshihTypeLayer（:3432 三档）+ freeWorship/goldWorship/rmbWorship（:1513-1562）合一。
## 静态树 guild_worship_content.tscn；三档文案 GuildWorship 表驱动（GuildManager.get_worship_options）。
## 单机化：三档奖励挂起（源 _worship 二次领取）+ 领取附公会币（受控偏离产出口径）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/guild_worship_content.tscn")
const OPT_NODES: Array[String] = ["%Opt1", "%Opt2", "%Opt3"]

var _pd: PlayerData
var _mgr: GuildManager
var _cm: ConfigManager
var _member: Dictionary
var _content: Control


func setup_panel(p_pd: PlayerData, p_mgr: GuildManager, member: Dictionary) -> void:
	_pd = p_pd
	_mgr = p_mgr
	_member = member
	_cm = p_pd.cm
	setup()
	hud_identity = ""
	_content = CONTENT_SCENE.instantiate()
	container.add_child(_content)
	(_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	(_node("%ClaimBtn") as BaseButton).pressed.connect(_on_claim)
	for i in OPT_NODES.size():
		(_node(OPT_NODES[i]) as BaseButton).pressed.connect(_on_worship.bind(i + 1))
	_fill()


func _node(path: String) -> Node:
	return _content.get_node(path)


func _fill() -> void:
	(_node("%Title") as Label).text = _cm.get_lstr("GUILDCONFIG.WORSHIP_BIG_SHOT")
	(_node("%TargetLabel") as Label).text = "%s Lv.%d" % [String(_member["name"]), int(_member["level"])]
	var head := TeamHeadIcon.build(_cm, int(_member["avatar"]))
	if head != null:
		var host := _node("%HeadHost") as Control
		for c in host.get_children():
			c.queue_free()
		host.add_child(head)
	_refresh_times()
	_refresh_options()
	_refresh_pending()


func _refresh_times() -> void:
	var info: Dictionary = _mgr.get_worship_times_info(_pd, int(Time.get_unix_time_from_system()))
	(_node("%TimesLabel") as Label).text = "%s%d" % [_cm.get_lstr("GUILDCONFIG.WORSHIP_TIMES_LEFT_TODAY_"), int(info["left"])]


func _refresh_options() -> void:
	var options: Array = _mgr.get_worship_options(_pd)
	for i in options.size():
		if i >= OPT_NODES.size():
			break
		var opt: Dictionary = options[i]
		var btn := _node(OPT_NODES[i]) as Button
		var cost_text: String = _cm.get_lstr("GUILDCONFIG.FREE")
		if bool(opt["consume"]):
			cost_text = "%d%s" % [int(opt["price_amount"]), "金币" if String(opt["price_type"]) == "Gold" else "钻石"]
		btn.text = "%s · 得%d金币 %d体力" % [cost_text, int(opt["gold"]), int(opt["vitality"])]
		btn.disabled = bool(opt["locked"])   # 钻石档 VIP 门槛（源 rmbWorship :1538-1542）


func _refresh_pending() -> void:
	var label := _node("%PendingLabel") as Label
	if not _mgr.has_pending_worship_reward(_pd):
		label.visible = false
		return
	var gold: int = 0
	var vitality: int = 0
	var guildpoint: int = 0
	for p in _pd.guild_data.worship_pending:
		gold += int(p.get("gold", 0))
		vitality += int(p.get("vitality", 0))
		guildpoint += int(p.get("guildpoint", 0))
	label.visible = true
	label.text = "可领:%d金币 %d体力 %d公会币" % [gold, vitality, guildpoint]


func _on_worship(worship_id: int) -> void:
	var r: Dictionary = _mgr.worship(_pd, int(_member["uid"]), worship_id, int(Time.get_unix_time_from_system()))
	if not bool(r["ok"]):
		Toast.show_message(String(r["err"]))
		return
	Toast.show_message(_cm.get_lstr("GUILD.SUCCESSFUL_OPERATION"))
	_refresh_times()
	_refresh_pending()


func _on_claim() -> void:
	var r: Dictionary = _mgr.worship_withdraw(_pd)
	if not bool(r["ok"]):
		Toast.show_message(String(r["err"]))
		return
	var rewards: Dictionary = r["rewards"]
	Toast.show_message("获得金币:%d 体力:%d 公会币:%d" % [int(rewards["gold"]), int(rewards["vitality"]), int(rewards["guildpoint"])])
	_refresh_pending()
