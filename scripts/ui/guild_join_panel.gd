class_name GuildJoinPanel
extends PopWindow

## 公会加入面板（View 层）— 照源 guild.lua joinLayer 三 tab（:414-459 加入/查找/创建）
## + refreshGuildList 行组装（:1609-1650）+ reqGuildById（:600-611）+ 创建校验链（:23）。
## 静态树 guild_join_content.tscn；本文件只做业务、信号 connect、fill。
## 单机化大幅简化：verify 型即入（审批流裁剪）；创建图标 GuildAvatar 前 20 个网格
## （源 289 翻页全量，受控偏离二期再补）；入会成功直开公会主页（源 join_enter 同款）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/guild_join_content.tscn")
const ITEM_SCENE: PackedScene = preload("res://scenes/ui/guild_join_item.tscn")
const ICON_GRID_COUNT: int = 20          # 图标候选数（受控偏离：源 289 全量翻页）
const ICON_SIZE: float = 44.0
const SELECT_FRAME_PATH: String = "res://assets/ui/alpha/HVGA/guild/guild_frame.png"
const SELECT_FRAME_PAD: float = 8.0
const TAB_LIGHT_OVERLAP: float = 5.0

var _pd: PlayerData
var _mgr: GuildManager
var _cm: ConfigManager
var _content: Control
var _tab_views: Dictionary = {}
var _selected_avatar: int = 1
var _select_frames: Dictionary = {}   # avatar_id → 选中框（icon 按钮子节点相对跟随，不依赖布局时序）


func setup_panel(p_pd: PlayerData, p_mgr: GuildManager) -> void:
	_pd = p_pd
	_mgr = p_mgr
	_cm = p_pd.cm
	transparent_shade = true
	setup()
	hud_identity = "guild_join"
	_build_content()


func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate()
	container.add_child(_content)
	(_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	(_node("%Title") as Label).text = _cm.get_lstr("mainres.Guild")
	for pair: Array in [["%TabJoin", "%JoinView"], ["%TabFind", "%FindView"], ["%TabCreate", "%CreateView"]]:
		var btn := _node(String(pair[0])) as BaseButton
		btn.pressed.connect(_on_tab.bind(String(pair[0])))
		_tab_views[String(pair[0])] = _node(String(pair[1]))
	(_node("%SearchBtn") as BaseButton).pressed.connect(_on_search)
	(_node("%CreateBtn") as BaseButton).pressed.connect(_on_create)
	(_node("%NameInput") as LineEdit).text_submitted.connect(func(_t: String) -> void: _on_create())
	_on_tab("%TabJoin")
	_fill_join_rows()
	_fill_icon_grid()


func _node(path: String) -> Node:
	return _content.get_node(path)


# ── tab 切换（光条对齐选中按钮底边）──────────────────────────────────

func _on_tab(tab: String) -> void:
	for key in _tab_views:
		(_tab_views[key] as Control).visible = key == tab
	var light := _node("%TabLight") as TextureRect
	var btn := _node(tab) as Control
	light.position = Vector2(btn.position.x, btn.position.y + btn.size.y - TAB_LIGHT_OVERLAP)


# ── 加入公会 tab：NPC 公会列表 ─────────────────────────────────────

func _fill_join_rows() -> void:
	var rows := _node("%Rows") as VBoxContainer
	for c in rows.get_children():
		c.queue_free()
	var guilds: Array = _mgr.get_guild_list()
	(_node("%EmptyLabel") as Label).visible = guilds.is_empty()
	for g in guilds:
		rows.add_child(_make_guild_row(g))


func _make_guild_row(g: Dictionary) -> Control:
	var row := ITEM_SCENE.instantiate() as Control
	var tex := _avatar_texture(int(g["avatar"]))
	if tex != null:
		(row.get_node("%Icon") as TextureRect).texture = tex
	(row.get_node("%Name") as Label).text = "%s (%d人)" % [String(g["name"]), int(g["member_cnt"])]
	(row.get_node("%Slogan") as Label).text = String(g["slogan"])
	(row.get_node("%LevelLimit") as Label).text = _cm.get_lstr("GUILD.CLAN_LEVEL_NEEDS__D") % int(g["join_limit"])
	var join_type_key: String = "GUILDCONFIG.JOIN_IN_INSTANTLY" if String(g["join_type"]) == GuildManager.JOIN_TYPE_FREE else "GUILDCONFIG.APPLY_TO_JOIN"
	(row.get_node("%JoinType") as Label).text = _cm.get_lstr(join_type_key)
	(row.get_node("%JoinBtn") as BaseButton).pressed.connect(_on_join.bind(int(g["id"])))
	return row


func _on_join(guild_id: int) -> void:
	var r: Dictionary = _mgr.join_guild(_pd, guild_id)
	if not bool(r["ok"]):
		Toast.show_message(String(r["err"]))
		return
	Toast.show_message(_cm.get_lstr("GUILD.SUCCESSFULLY_JOINED_THE_GUILD"))
	remove_window()
	MainSceneEntryRouter.open_guild(get_parent())


# ── 查找公会 tab：ID 精确命中 ───────────────────────────────────────

func _on_search() -> void:
	var host := _node("%ResultHost") as Control
	for c in host.get_children():
		c.queue_free()
	var raw: String = (_node("%IdInput") as LineEdit).text.strip_edges()
	if not raw.is_valid_int():
		Toast.show_message(_cm.get_lstr("GUILD.ENTER_THE_CORRECT_GUILD_ID"))
		return
	var g: Dictionary = _mgr.search_guild(int(raw))
	if g.is_empty():
		Toast.show_message(_cm.get_lstr("GUILD.NO_RESULT"))
		return
	host.add_child(_make_guild_row(g))


# ── 创建公会 tab：名字 + 图标 + 500 钻 ──────────────────────────────

func _fill_icon_grid() -> void:
	var grid := _node("%IconGrid") as GridContainer
	for c in grid.get_children():
		c.queue_free()
	_select_frames.clear()
	var table: Dictionary = _cm.get_raw_table(&"GuildAvatar")
	var made: int = 0
	var avatar_id: int = 1
	while made < ICON_GRID_COUNT and table.has(str(avatar_id)):
		var tex := _avatar_texture(avatar_id)
		if tex != null:
			var btn := TextureButton.new()
			btn.texture_normal = tex
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			btn.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
			# 选中框做按钮子节点（相对定位跟随，不依赖 GridContainer 布局时序）。
			var frame := TextureRect.new()
			frame.texture = load(SELECT_FRAME_PATH)
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.position = Vector2(-SELECT_FRAME_PAD * 0.5, -SELECT_FRAME_PAD * 0.5)
			frame.size = Vector2(ICON_SIZE + SELECT_FRAME_PAD, ICON_SIZE + SELECT_FRAME_PAD)
			frame.visible = false
			btn.add_child(frame)
			_select_frames[avatar_id] = frame
			btn.pressed.connect(_on_icon.bind(avatar_id))
			grid.add_child(btn)
			made += 1
		avatar_id += 1
	_on_icon(_selected_avatar)


func _on_icon(avatar_id: int) -> void:
	_selected_avatar = avatar_id
	for fid in _select_frames:
		(_select_frames[fid] as TextureRect).visible = int(fid) == avatar_id


func _on_create() -> void:
	var name_text: String = (_node("%NameInput") as LineEdit).text.strip_edges()
	var r: Dictionary = _mgr.create_guild(_pd, name_text, _selected_avatar)
	if not bool(r["ok"]):
		Toast.show_message(String(r["err"]))
		return
	Toast.show_message(_cm.get_lstr("GUILD.CREATE_GUILD_SUCCESSFULLY"))
	remove_window()
	MainSceneEntryRouter.open_guild(get_parent())


# ── 公会图标贴图（GuildAvatar.Picture → assets/ui/ITEM；ranklist_rows 范式）──

func _avatar_texture(avatar_id: int) -> Texture2D:
	var pic: String = String(_cm.get_raw_table(&"GuildAvatar").get(str(avatar_id), {}).get("Picture", ""))
	if pic.is_empty():
		return null
	var path: String = "res://assets/ui/" + pic.substr(3)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
