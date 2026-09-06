class_name SaveManagerSnapshots
extends RefCounted

## 存档管理快照槽 helper（View 层静态工具）— 照源 ui/popwindow/savemanager.lua
## readSaveIndex:8-38 / createSnapshotRow:40-103 / doRestoreSave:262-328 单机版。
## 从 SaveManagerPanel 下沉（面板 400 行门槛）；面板 2026-08-21 修复轮：用户反馈
## 「存档管理功能也没有实现」——三按钮实测正常，缺的是源面板主体快照槽列表。
##
## 机制（照源）：手动保存 = 写主档 + 快照副本（user://save_snap_<time>.json）+
## index 前插（user://save_index.json：[{time,type,level,team}]，截断 MAX_KEEP 删旧文件）；
## 列表显最近 MAX_SHOW 行，点击行 → 二次确认 → 快照全文恢复（复用导入校验链）。
## 受控偏离：源自动存档也写快照（type auto），本项目自动存档 60s 高频不接
## （index 爆炸），仅手动保存产快照；type 字段保留结构兼容未来扩展。

const INDEX_NAME: String = "save_index.json"
const SNAP_NAME_FMT: String = "save_snap_%d.json"
# 快照目录（测试可注入沙箱隔离路径，勿真覆盖用户 index/快照——先例 SaveManagerPanel.save_file_path）。
static var base_dir: String = "user://"

static func _index_path() -> String:
	return base_dir + INDEX_NAME


static func _snap_path(time_unix: int) -> String:
	return base_dir + SNAP_NAME_FMT % time_unix

const MAX_SHOW: int = 3        # 源 maxShow
const MAX_KEEP: int = 5        # index 滚动保留（源未明示，防无限增长）
# 行布局（源 createSnapshotRow：430×72 行 / bg 430×68 cap 同主框 / 队伍 icon 0.33 倍）。
const ROW_SIZE: Vector2 = Vector2(430.0, 72.0)
const BG_SIZE: Vector2 = Vector2(430.0, 68.0)
const ICON_SCALE: float = 0.33
# ReadheroIcon 104×104 缩放后中心对齐用（Node2D position 为左上锚）。
const ICON_HALF: float = 104.0 * 0.33 * 0.5
const MANUAL_TINT: Color = Color(1.0, 240.0 / 255.0, 210.0 / 255.0)   # 源 manual 行染色
const HEADER_COLOR: Color = Color(220.0 / 255.0, 200.0 / 255.0, 160.0 / 255.0)
const LEVEL_COLOR: Color = Color(1.0, 220.0 / 255.0, 100.0 / 255.0)
const EMPTY_COLOR: Color = Color(180.0 / 255.0, 180.0 / 255.0, 180.0 / 255.0)
const FRAME_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
# cap 照主框（源 createSnapshotRow CCRectMake(15,20,45,15) 同 savemanager 主 frame）。
const CAP_L: int = 15
const CAP_T: int = 26
const CAP_R: int = 43
const CAP_B: int = 20


## index 读取（源 readSaveIndex：损坏/缺失返回 []）。
static func read_index() -> Array:
	var text: String = SaveManagerPanel._read_text(_index_path())
	if text.is_empty():
		return []
	var parsed: Variant = str_to_var(text)
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed


## index 原子写（源 writeSaveIndex tmp+rename 模式）。
static func write_index(index: Array) -> void:
	SaveManagerPanel._write_text(_index_path(), var_to_str(index))


## 存快照：主档内容写副本 + index 前插 meta（level/team 从 pd 取）+ 滚动删旧。
## 返回新 index（调用方可直接刷新列表）。
static func save_snapshot(pd: PlayerData, save_content: String) -> Array:
	var time_now: int = int(Time.get_unix_time_from_system())
	var snap_path: String = _snap_path(time_now)
	if SaveManagerPanel._write_text(snap_path, save_content) != OK:
		return read_index()
	var index: Array = read_index()
	index.insert(0, {
		"time": time_now,
		"type": "manual",
		"level": pd.team_level,
		"team": _team_meta(pd),
	})
	while index.size() > MAX_KEEP:
		var dropped: Dictionary = index.pop_back()
		var drop_path: String = _snap_path(int(dropped.get("time", 0)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(drop_path))
	write_index(index)
	return index


## 队伍 meta（源 team {tid, rank, level, stars}；上限 5 照行显示）。
static func _team_meta(pd: PlayerData) -> Array:
	var team: Array = []
	for inst_id: int in pd.team.slice(0, 5):
		var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
		if hero != null:
			team.append({"tid": hero.tid, "rank": hero.rank, "level": hero.level, "stars": hero.stars})
	return team


## 快照行 UI（源 createSnapshotRow 直译：bg + header + Lv + 队伍 icon×5 / 空队伍文案 + 点击恢复）。
## on_restore(snapshot: Dictionary)：行点击回调（面板接确认层）。
static func build_row(snapshot: Dictionary, row_idx: int, frame_res_caps: Array, cm: Variant, on_restore: Callable) -> Control:
	var row := Control.new()
	row.custom_minimum_size = ROW_SIZE
	row.size = ROW_SIZE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# bg（cap 由面板传主框常量数组 [l,t,r,b] 免重复声明）。
	var bg := NinePatchRect.new()
	bg.texture = load(FRAME_RES) as Texture2D
	bg.position = Vector2(0.0, (ROW_SIZE.y - BG_SIZE.y) * 0.5)
	bg.size = BG_SIZE
	bg.patch_margin_left = int(frame_res_caps[0])
	bg.patch_margin_top = int(frame_res_caps[1])
	bg.patch_margin_right = int(frame_res_caps[2])
	bg.patch_margin_bottom = int(frame_res_caps[3])
	bg.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	bg.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	if String(snapshot.get("type", "")) == "manual":
		bg.self_modulate = MANUAL_TINT
	row.add_child(bg)
	# header：#N 手动 MM/DD HH:MM（源 13 号 220,200,160；y 翻转 55→中心 17）。
	# get_datetime_dict_from_unix_time 返回 UTC，源 os.date 本地时区 → 加 bias 偏移
	# （bias 分钟、东八区 +480 → 本地 = unix + bias*60；实测 headless bias=480，
	# 2026-08-21 实机抓出显示差 8h 后修正符号）。
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(
		int(snapshot.get("time", 0)) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	var header := Label.new()
	header.text = "#%d %s  %02d/%02d %02d:%02d" % [row_idx, "手动", dt.get("month", 0), dt.get("day", 0), dt.get("hour", 0), dt.get("minute", 0)]
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", HEADER_COLOR)
	header.position = Vector2(12.0, 8.0)
	header.size = Vector2(BG_SIZE.x - 24.0, 18.0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(header)
	# Lv（源 14 号金；y 翻转 34→中心 38）。
	var level_lbl := Label.new()
	level_lbl.text = "Lv.%d" % int(snapshot.get("level", 1))
	level_lbl.add_theme_font_size_override("font_size", 14)
	level_lbl.add_theme_color_override("font_color", LEVEL_COLOR)
	level_lbl.position = Vector2(12.0, 29.0)
	level_lbl.size = Vector2(70.0, 18.0)
	level_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(level_lbl)
	# 队伍 icon×5（源 90+i*46 中心 y34；Node2D scale 0.33 挂行）。
	var team: Array = snapshot.get("team", [])
	if team.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "无配队"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", EMPTY_COLOR)
		empty_lbl.position = Vector2(90.0, 29.0)
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(empty_lbl)
	else:
		for i: int in range(team.size()):
			var info: Dictionary = team[i]
			var icon := ReadheroIcon.new()
			icon.setup({
				"id": int(info.get("tid", 0)),
				"rank": int(info.get("rank", 1)),
				"stars": int(info.get("stars", 0)),
				"level": int(info.get("level", 1)),
			}, cm)
			icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
			icon.position = Vector2(90.0 + i * 46.0 - SaveManagerSnapshots.ICON_HALF, 38.0 - SaveManagerSnapshots.ICON_HALF)
			row.add_child(icon)
	# 点击热区（源 doMainLayerTouch 坐标命中 → 行 gui_input 等价）。
	var hit := Control.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			on_restore.call(snapshot))
	row.add_child(hit)
	return row



## 快照恢复载荷（源 doRestoreSave 读快照文件；校验复用导入链）。
static func snapshot_payload(snapshot: Dictionary) -> Dictionary:
	var snap_path: String = _snap_path(int(snapshot.get("time", 0)))
	if not FileAccess.file_exists(snap_path):
		return {}
	return SaveManagerPanel.validate_import_text(SaveManagerPanel._read_text(snap_path))
