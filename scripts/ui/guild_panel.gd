class_name GuildPanel
extends PopWindow

## 公会主页（View 层）— 照源 guild.lua mainLayer（:810-）+ memberLayer 成员列表
## （:1578-）+ initMemberList/getMemberDes（:614-675 三排序）骨架。
## 静态树 guild_content.tscn；本文件只做业务、信号 connect、fill。
## 单机化大幅简化：成员管理只读（源踢人/升职/审批裁剪）；佣兵营/团队副本一期裁剪
## （guild_button_* 贴图源库 1x1 占位缺失一并记入）；膜拜=行内按钮（等级门槛显隐）
## 或底部按钮（默认最高级可膜拜对象）；商店=嵌套 ShopPanel(shop7)；解散直接执行
## + Toast（源 confirmDialog 简化，equip_strengthen 先例）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/guild_content.tscn")
const MEMBER_ITEM_SCENE: PackedScene = preload("res://scenes/ui/guild_member_item.tscn")
const SORT_LOGIN: String = "login"
const SORT_ACTIVE: String = "active"
const SORT_INSTANCE: String = "instance"
const DAY_SECONDS: int = 86400
const LOGIN_ONLINE_WINDOW: int = 3600   # 1h 内算今日在线（源 rand(0,3600) 口径）

var _pd: PlayerData
var _mgr: GuildManager
var _cm: ConfigManager
var _content: Control
var _members: Array = []
var _sort_key: String = SORT_LOGIN


func setup_panel(p_pd: PlayerData, p_mgr: GuildManager, rng: BattleRng) -> void:
	_pd = p_pd
	_mgr = p_mgr
	_cm = p_pd.cm
	transparent_shade = true
	setup()
	hud_identity = "guild"
	_content = CONTENT_SCENE.instantiate()
	container.add_child(_content)
	_bind()
	_members = _mgr.get_guild_info(_pd, rng, int(Time.get_unix_time_from_system()))["members"]
	_fill_head()
	_fill_members()


func _bind() -> void:
	(_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	(_node("%LeaveBtn") as BaseButton).pressed.connect(_on_leave)
	(_node("%ShopBtn") as BaseButton).pressed.connect(_on_shop)
	(_node("%WorshipBtn") as BaseButton).pressed.connect(_on_worship_default)
	(_node("%SortLoginBtn") as BaseButton).pressed.connect(_on_sort.bind(SORT_LOGIN))
	(_node("%SortActiveBtn") as BaseButton).pressed.connect(_on_sort.bind(SORT_ACTIVE))
	(_node("%SortInstanceBtn") as BaseButton).pressed.connect(_on_sort.bind(SORT_INSTANCE))


func _node(path: String) -> Node:
	return _content.get_node(path)


# ── 头部 fill ──────────────────────────────────────────────────────

func _fill_head() -> void:
	var gd: GuildData = _pd.guild_data
	var tex := _avatar_texture(gd.guild_avatar)
	if tex != null:
		(_node("%Icon") as TextureRect).texture = tex
	(_node("%GuildName") as Label).text = gd.guild_name
	(_node("%IdLabel") as Label).text = _cm.get_lstr("GUILDCONFIG.GUILD_ID_") + str(gd.guild_id)
	(_node("%SloganLabel") as Label).text = gd.slogan
	(_node("%MemberLabel") as Label).text = "%s%d/%d" % [_cm.get_lstr("GUILDCONFIG.MEMBERS_"),
			_members.size(), GuildManager.MAX_MEMBER_CNT]
	(_node("%VitalityLabel") as Label).text = str(gd.vitality)
	(_node("%Title") as Label).text = _cm.get_lstr("mainres.Guild")
	(_node("%LeaveBtn") as Button).text = _cm.get_lstr("GUILDCONFIG.DISSOLVE_GUILD")
	(_node("%ShopBtn") as Button).text = "公会商店"
	(_node("%WorshipBtn") as Button).text = _cm.get_lstr("GUILDCONFIG.WORSHIP")
	_refresh_worship_tag()


func _refresh_worship_tag() -> void:
	(_node("%WorshipTag") as Label).visible = _mgr.has_pending_worship_reward(_pd)


# ── 成员列表（三排序照源 rankByTime/rankByactive/rankByinstance）────────

func _on_sort(key: String) -> void:
	_sort_key = key
	_fill_members()


func _fill_members() -> void:
	var rows := _node("%Rows") as VBoxContainer
	for c in rows.get_children():
		c.queue_free()
	var sorted: Array = _members.duplicate()
	match _sort_key:
		SORT_ACTIVE:
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["active"]) > int(b["active"]))
		SORT_INSTANCE:
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a["join_instance_time"]) > int(b["join_instance_time"]))
		_:
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["last_login"]) > int(b["last_login"]))
	for m in sorted:
		rows.add_child(_make_member_row(m))


func _make_member_row(m: Dictionary) -> Control:
	var row := MEMBER_ITEM_SCENE.instantiate() as Control
	var head := TeamHeadIcon.build(_cm, int(m["avatar"]))
	if head != null:
		(row.get_node("%HeadHost") as Control).add_child(head)
	(row.get_node("%Name") as Label).text = String(m["name"])
	(row.get_node("%Level") as Label).text = "Lv.%d" % int(m["level"])
	(row.get_node("%Desc") as Label).text = _member_desc(m)
	var job_tag := row.get_node("%JobTag") as Label
	match String(m["job"]):
		GuildManager.JOB_CHAIRMAN:
			job_tag.text = _cm.get_lstr("GUILDCONFIG.HOST")
		GuildManager.JOB_ELDER:
			job_tag.text = _cm.get_lstr("guild.1.10.003")
		_:
			job_tag.visible = false
	# 膜拜按钮显隐照源 guild.lua:257（等级 < 自己+worshipLevelDif 隐藏；玩家自己无按钮）。
	var worship_btn := row.get_node("%WorshipBtn") as BaseButton
	var can_worship: bool = int(m["uid"]) != 1 and _mgr.can_worship_member(m, _pd.team_level)
	worship_btn.visible = can_worship
	if can_worship:
		worship_btn.pressed.connect(_on_member_worship.bind(m))
	return row


## 排序维度描述（源 getMemberDes :623-651 三态；LSTR 值含 <text|> 富文本标签，
## 直显带标签文本 → 单机化改硬编码等义文案，记入验收记录）。
func _member_desc(m: Dictionary) -> String:
	match _sort_key:
		SORT_ACTIVE:
			return "7日贡献:%d活跃" % int(m["active"])
		SORT_INSTANCE:
			return "挑战:%d次" % int(m["join_instance_time"])
		_:
			var now: int = int(Time.get_unix_time_from_system())
			var passed: int = now - int(m["last_login"])
			if passed < LOGIN_ONLINE_WINDOW:
				var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(m["last_login"]))
				return "最后上线: 今日%02d:%02d" % [int(dt["hour"]), int(dt["minute"])]
			var days: int = int(ceil(float(passed) / float(DAY_SECONDS)))
			return "最后上线: %d天前" % days


# ── 底部功能 ───────────────────────────────────────────────────────

func _on_shop() -> void:
	MainSceneEntryRouter.open_shop(get_parent(), MarketConfig.SHOP_GUILD_ID)


func _on_member_worship(member: Dictionary) -> void:
	var panel := GuildWorshipPanel.new("guild_worship", {})
	panel.setup_panel(_pd, _mgr, member)
	panel.show_window(get_parent())
	panel.register_on_exit(_refresh_worship_tag)


func _on_worship_default() -> void:
	# 底部膜拜按钮：默认最高等级可膜拜 NPC（无可膜拜对象提示门槛文案）。
	var target: Dictionary = {}
	for m in _members:
		if int(m["uid"]) != 1 and _mgr.can_worship_member(m, _pd.team_level):
			if target.is_empty() or int(m["level"]) > int(target["level"]):
				target = m
	if target.is_empty():
		Toast.show_message("只能膜拜等级高于自己的成员")
		return
	_on_member_worship(target)


func _on_leave() -> void:
	# 玩家恒 chairman（源 makePlayerMember），离开=解散语义（源 _leave/_dismiss 同为清档）。
	var r: Dictionary = _mgr.leave_guild(_pd)
	if not bool(r["ok"]):
		Toast.show_message(String(r["err"]))
		return
	Toast.show_message(_cm.get_lstr("GUILD.HAS_LEFT_OUT_THE_GUILD"))
	remove_window()


# ── 公会图标贴图（GuildAvatar.Picture → assets/ui/ITEM）──────────────

func _avatar_texture(avatar_id: int) -> Texture2D:
	var pic: String = String(_cm.get_raw_table(&"GuildAvatar").get(str(avatar_id), {}).get("Picture", ""))
	if pic.is_empty():
		return null
	var path: String = "res://assets/ui/" + pic.substr(3)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
