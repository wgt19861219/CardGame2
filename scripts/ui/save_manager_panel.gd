class_name SaveManagerPanel
extends PopWindow

## 存档管理弹窗（View 层）— 照源 ui/popwindow/savemanager.lua（693 行）单机最小版。
## 修复轮 A（2026-08-18）：用户实跑反馈 configure"存档管理"只弹 Toast 暂缓 → 本面板补全。
## 多档位轮（2026-09-17，Godot 原生阶段受控增强，源单账号无对应物）：frame 280→380 扩高，
## 顶部档位条（SaveManagerSlotBar：三档胶囊 auto/save_1/save_2，空档即新建入口，
## 切换/新建走确认层 + GameData.switch_slot + 回主菜单）；主档路径随活跃槽。
##
## 功能（照源 doManualSave/doExportSave/doImportSave）：
##   手动保存 = GameData.save()（原子写活跃槽）+ 快照副本；
##   导出 = 刷盘后存档文本 → 剪贴板 + user://save_export.txt 双写（换机迁移桌面最实用）；
##   导入 = 剪贴板 → 导出文件回退 → str_to_var 校验 → 二次确认（ConfirmDialog 状态机）
##         → 备份 .bak_pre_import → GameData.apply_imported_save 落地 → 回主场景。
## 快照语义（多档位轮不变）：快照为跨档共享的进度副本，恢复=覆盖当前活跃档（同导入）。
##
## 受控裁剪/偏离：
##   - 快照槽列表 2026-08-21 修复轮已恢复（源 readSaveIndex/createSnapshotRow/doRestoreSave）；
##   - 源 Android 多路径导出（/sdcard/Download 等）→ Godot 桌面 user:// + 剪贴板；
##   - 源 UserDefault 内置导出副本（cardgame_save_export）→ 剪贴板等价；
##   - 源 _export_time 注入省略（var_to_str 格式存档带运行时时间戳无校验价值）。
##
## 两件套豁免：内容少（frame/title/close/3 按钮）procedural 挂 container，无独立 tscn
## （修复轮 A 授权；后续若加快照 UI 再 tscn 化）。坐标照源直译 to_godot(x,y)=(x,480-y)。
## 快捷栏红点同款判读：源 herosplit_tag（main_deal_tag）在源 savemanager/heropackage 均
## 恒隐藏死代码，本面板不设 tag。

const FRAME_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/common/common_tips_button_close_1.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/common/common_tips_button_close_2.png"
const CONTENT_SCALE: float = 1.28125   # 纹理像素 ÷CS = Godot 显示尺寸（无 TextureConfig 条目）

# frame：源 Scale9Sprite cap(15,20,45,15) 467×280 anchor(0.5,1)@(400,380)（贴图 103×61，
# 纹理px L15/T26/R43/B20；patch 须 ÷CS 取整 → L12/T20/R34/B16，同 configure Frame）。
# 多档位轮（2026-09-17）：280→380 扩高纳档位条（受控增强，源单账号无此区）。
const FRAME_RECT: Rect2 = Rect2(246.5, 100.0, 467.0, 380.0)
const FRAME_CAP_LEFT: int = 12
const FRAME_CAP_TOP: int = 20
const FRAME_CAP_RIGHT: int = 34
const FRAME_CAP_BOTTOM: int = 16
# title：源 (400,390) 中心锚 size22 金(255,220,100) 黑阴影(0,2) → 跟 frame 顶沿上移。
const TITLE_CENTER: Vector2 = Vector2(480.0, 90.0)
const TITLE_FONT_SIZE: int = 22
const TITLE_COLOR: Color = Color(255.0 / 255.0, 220.0 / 255.0, 100.0 / 255.0)
const TITLE_SHADOW_OFFSET: Vector2 = Vector2(0.0, 2.0)
# close：源 common_tips_button_close (624,390) 中心，65×66px ÷CS。
const CLOSE_CENTER: Vector2 = Vector2(704.0, 90.0)
const CLOSE_SIZE: Vector2 = Vector2(50.73, 51.52)
# 3 按钮：源 sell_number_button cap(15,22,15,25) scaleSize(120,40) 中心 (270/400/530,120)。
# 九宫格样式走 theme ConfigureActionBtn variation（同图同 cap 复用 SB_pkg_hb_n/p）。
# Godot NinePatch 垂直 patch 20+22=42 会把高 40 钳到 42（源 Cocos 允许挤压，2px 受控偏离）。
const BTN_SIZE: Vector2 = Vector2(120.0, 42.0)
const BTN_CENTERS: Array[Vector2] = [
	Vector2(350.0, 440.0), Vector2(480.0, 440.0), Vector2(610.0, 440.0),
]
const BTN_LABELS: Array[String] = ["手动保存", "导出存档", "导入存档"]
const BTN_LABEL_FONT_SIZE: int = 18
# 按钮内独立 Label（configure 范式：Button.text 受 stylebox content_margin 干扰不用）。
const BTN_LABEL_COLOR: Color = Color(235.0 / 255.0, 223.0 / 255.0, 207.0 / 255.0)

# 导入确认层（源 doImportSave 走 showConfirmDialog 恢复确认同款交互；本面板内嵌层）。
# 文案动态化（多档位轮）：导入/切换档/新建档三种确认共用此层。
const CONFIRM_LAYER_COLOR: Color = Color(0.0, 0.0, 0.0, 150.0 / 255.0)
const CONFIRM_FRAME_RECT: Rect2 = Rect2(300.0, 250.0, 360.0, 140.0)
const CONFIRM_MSG: String = "导入将覆盖当前进度，确定继续？"
const CONFIRM_SWITCH_FMT: String = "切换到%s？当前进度已自动保存。"
const CONFIRM_NEW_FMT: String = "在%s新建存档？将开始新游戏，当前进度已自动保存。"
const CONFIRM_MSG_RECT: Rect2 = Rect2(320.0, 268.0, 320.0, 60.0)
const CONFIRM_CANCEL_RECT: Rect2 = Rect2(330.0, 336.0, 130.0, 42.0)
const CONFIRM_OK_RECT: Rect2 = Rect2(500.0, 336.0, 130.0, 42.0)
const CONFIRM_CANCEL_TEXT: String = "取消"
const CONFIRM_OK_TEXT: String = "确定"

# 存档/导出路径（export 为测试可注入隔离路径，勿真覆盖用户档）。
# 多档位轮：主档路径改随活跃槽（save_file_path 硬编码 auto 会读错档）。
var export_file_path: String = "user://save_export.txt"


## 当前活跃档落盘路径（GameData.save_dir + 活跃槽；测试注入沙箱目录自动跟随）。
func _active_save_path() -> String:
	return "%ssave_%s.json" % [GameData.save_dir, GameData.active_slot]
# 源 :181 saved #saved > 10 才视为有效内容（剪贴板空串/残留短文本过滤）。
const MIN_IMPORT_LEN: int = 10

var _confirm: ConfirmDialog = null
var _confirm_layer: Control = null
var _confirm_msg_label: Label = null
var _pending_import: Dictionary = {}
var _pending_slot_action: Dictionary = {}   # {kind:"switch"|"new", slot} 待确认档位操作
var _title_label: Label = null
var _slot_bar_host: Control = null


func setup_panel() -> void:
	setup()
	register_on_enter(play_scale_in)   # 源 show() EaseBackOut 0.2 弹入
	_build_content()


# 入口（configure_panel._on_save_manager 调）。
static func open(parent: Control) -> void:
	var panel := SaveManagerPanel.new("savemanager", {})
	panel.setup_panel()
	panel.show_window(parent)


func _build_content() -> void:
	_add_frame()
	_add_title()
	_add_close_btn()
	_build_slot_bar()   # 多档位轮：档位条（三档胶囊，空档即新建入口）
	_build_snapshot_list()   # 2026-08-21 修复轮：源面板主体快照槽列表（此前裁剪致「没实现」体感）
	for i in range(BTN_CENTERS.size()):
		_add_action_btn(i)
	_add_confirm_layer()


# 档位条（SaveManagerSlotBar helper 构建；点击非当前档 → _on_slot_picked 确认分流）。
func _build_slot_bar() -> void:
	if _slot_bar_host != null:
		_slot_bar_host.queue_free()
	_slot_bar_host = SaveManagerSlotBar.build(GameData.slot_metas(), _on_slot_picked)
	container.add_child(_slot_bar_host)


# 档位点击分流：空档 → 新建确认；有档 → 切换确认（当前档 helper 已拦，此处防御）。
func _on_slot_picked(slot: String, exists: bool) -> void:
	if exists and slot == GameData.active_slot:
		return
	var display: String = SaveManagerSlotBar.slot_display(slot)
	if exists:
		_pending_slot_action = {"kind": "switch", "slot": slot}
		_set_confirm_msg(CONFIRM_SWITCH_FMT % display)
	else:
		_pending_slot_action = {"kind": "new", "slot": slot}
		_set_confirm_msg(CONFIRM_NEW_FMT % display)
	_confirm_layer.visible = true
	_confirm.open(_on_confirmed)


# 档位操作落地（确认后）：switch_slot 覆盖两分支——空档切换即在该档开新号并落盘。
func _apply_slot_action() -> void:
	_confirm_layer.visible = false
	var slot := String(_pending_slot_action.get("slot", ""))
	_pending_slot_action = {}
	var err: int = GameData.switch_slot(slot)
	if err != OK:
		_show_toast("档位操作失败（错误码 %d），进度未变更" % err)
		return
	remove_window()
	SceneManager.change_scene("res://scenes/main_menu/main_scene.tscn")   # 换档回主菜单重载 UI（同导入）


func _set_confirm_msg(text: String) -> void:
	if _confirm_msg_label != null:
		_confirm_msg_label.text = text


# 快照槽列表（源 createWindow :560-586：最近 3 行 / 空列表占位文案）。
# 行区屏幕坐标：源行 yPos 360/288/216（cocos 430×72）→ 本版 y 195/265/335。
# 2026-09-17 实测修正：初版 240/312/384 致第 3 行 bg 底(452)越过按钮顶沿(419)
# 遮挡 ~35px（bridge 截图 VisualCoding 像素复核抓出）；上收整段为档位条下方。
const SNAP_ROW_POS: Array[Vector2] = [
	Vector2(265.0, 195.0), Vector2(265.0, 265.0), Vector2(265.0, 335.0),
]
const SNAP_EMPTY_CENTER: Vector2 = Vector2(480.0, 290.0)   # 源 (400,280) 暂无存档记录
const SNAP_EMPTY_TEXT: String = "暂无存档记录"
var _snap_host: Control = null

func _build_snapshot_list() -> void:
	if _snap_host != null:
		_snap_host.queue_free()
	_snap_host = Control.new()
	_snap_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var index: Array = SaveManagerSnapshots.read_index()
	var shown: int = min(index.size(), SaveManagerSnapshots.MAX_SHOW)
	if shown == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = SNAP_EMPTY_TEXT
		empty_lbl.add_theme_font_size_override("font_size", BTN_LABEL_FONT_SIZE)
		empty_lbl.add_theme_color_override("font_color", SaveManagerSnapshots.EMPTY_COLOR)
		empty_lbl.position = SNAP_EMPTY_CENTER - Vector2(60.0, 10.0)
		empty_lbl.size = Vector2(120.0, 20.0)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_snap_host.add_child(empty_lbl)
	else:
		var caps: Array = [FRAME_CAP_LEFT, FRAME_CAP_TOP, FRAME_CAP_RIGHT, FRAME_CAP_BOTTOM]
		for i: int in range(shown):
			var row: Control = SaveManagerSnapshots.build_row(index[i], i + 1, caps, GameData.config,
				func(snapshot: Dictionary) -> void: _on_snapshot_clicked(snapshot))
			row.position = SNAP_ROW_POS[i]
			_snap_host.add_child(row)
	container.add_child(_snap_host)


# 行点击 → 恢复确认（复用导入确认层；源 doRestoreSave 前有恢复确认交互）。
func _on_snapshot_clicked(snapshot: Dictionary) -> void:
	var payload: Dictionary = SaveManagerSnapshots.snapshot_payload(snapshot)
	if payload.is_empty():
		_show_toast("快照文件缺失或格式无效")
		return
	_pending_import = payload
	_set_confirm_msg(CONFIRM_MSG)
	_confirm_layer.visible = true
	_confirm.open(_on_confirmed)


func _add_frame() -> void:
	var frame := NinePatchRect.new()
	frame.texture = load(FRAME_RES) as Texture2D
	frame.position = FRAME_RECT.position
	frame.size = FRAME_RECT.size
	frame.patch_margin_left = FRAME_CAP_LEFT
	frame.patch_margin_top = FRAME_CAP_TOP
	frame.patch_margin_right = FRAME_CAP_RIGHT
	frame.patch_margin_bottom = FRAME_CAP_BOTTOM
	# 拉伸模式用默认 STRETCH（2026-09-18 三轮：TILE_FIT 平铺有 tile 边界采样接缝；
	# 中间区纯色，平铺与拉伸观感一致，STRETCH 无缝且对齐源 Scale9Sprite 默认）。
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)


func _add_title() -> void:
	_title_label = Label.new()
	_title_label.text = "存档管理"
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_title_label.add_theme_constant_override("shadow_offset_x", int(TITLE_SHADOW_OFFSET.x))
	_title_label.add_theme_constant_override("shadow_offset_y", int(TITLE_SHADOW_OFFSET.y))
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_title_label)
	_center_label(_title_label, TITLE_CENTER)


func _add_close_btn() -> void:
	var btn := TextureButton.new()
	btn.texture_normal = load(CLOSE_RES) as Texture2D
	btn.texture_pressed = load(CLOSE_PRESS_RES) as Texture2D
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.position = CLOSE_CENTER - CLOSE_SIZE * 0.5
	btn.size = CLOSE_SIZE
	btn.pressed.connect(remove_window)
	container.add_child(btn)


func _add_action_btn(i: int) -> void:
	var btn := Button.new()
	btn.theme_type_variation = &"ConfigureActionBtn"
	btn.position = BTN_CENTERS[i] - BTN_SIZE * 0.5
	btn.size = BTN_SIZE
	btn.pressed.connect([_on_save_clicked, _on_export_clicked, _on_import_clicked][i])
	container.add_child(btn)
	var lbl := Label.new()
	lbl.text = BTN_LABELS[i]
	lbl.add_theme_font_size_override("font_size", BTN_LABEL_FONT_SIZE)
	lbl.add_theme_color_override("font_color", BTN_LABEL_COLOR)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)


# 导入二次确认层：ConfirmDialog 状态机（scripts/ui/confirm_dialog.gd）+ procedural 视觉。
func _add_confirm_layer() -> void:
	_confirm = ConfirmDialog.new()
	_confirm_layer = Control.new()
	_confirm_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_layer.visible = false
	var shade := ColorRect.new()
	shade.color = CONFIRM_LAYER_COLOR
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP   # 模态拦截（源 confirmDialog 层 touchEnabled）
	_confirm_layer.add_child(shade)
	var frame := NinePatchRect.new()
	frame.texture = load(FRAME_RES) as Texture2D
	frame.position = CONFIRM_FRAME_RECT.position
	frame.size = CONFIRM_FRAME_RECT.size
	frame.patch_margin_left = FRAME_CAP_LEFT
	frame.patch_margin_top = FRAME_CAP_TOP
	frame.patch_margin_right = FRAME_CAP_RIGHT
	frame.patch_margin_bottom = FRAME_CAP_BOTTOM
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_layer.add_child(frame)
	var msg := Label.new()
	msg.text = CONFIRM_MSG
	msg.add_theme_font_size_override("font_size", BTN_LABEL_FONT_SIZE)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.position = CONFIRM_MSG_RECT.position
	msg.size = CONFIRM_MSG_RECT.size
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_layer.add_child(msg)
	_confirm_msg_label = msg
	_add_confirm_btn(CONFIRM_CANCEL_RECT, CONFIRM_CANCEL_TEXT, _on_confirm_cancel)
	_add_confirm_btn(CONFIRM_OK_RECT, CONFIRM_OK_TEXT, _on_confirm_ok)
	container.add_child(_confirm_layer)


func _add_confirm_btn(rect: Rect2, text: String, handler: Callable) -> void:
	var btn := Button.new()
	btn.theme_type_variation = &"DialogConfirmBtn"
	btn.position = rect.position
	btn.size = rect.size
	btn.text = text
	btn.pressed.connect(handler)
	_confirm_layer.add_child(btn)


func _center_label(lbl: Label, center: Vector2) -> void:
	var sz: Vector2 = lbl.get_minimum_size()
	lbl.position = center - sz * 0.5


# ── 手动保存（源 doManualSave :106-123 + 快照生产：源 _nextSaveType="manual"
## 使 saveGame 落盘时写快照；本项目等价=save() 后由面板写快照副本 + index 前插）──
func _on_save_clicked() -> void:
	var err: int = GameData.save()
	if err == OK:
		var content: String = _read_text(_active_save_path())
		if not content.is_empty():
			SaveManagerSnapshots.save_snapshot(GameData.player, content)
			_build_snapshot_list()   # 源保存成功 destroy+重开面板刷新列表 → 本地重建等价
		_show_toast("手动保存成功")
	else:
		_show_toast("保存失败（错误码 %d）" % err)


# ── 导出（源 doExportSave :125-172）──
func _on_export_clicked() -> void:
	GameData.save()   # 源 :127 先 saveGame 刷盘再读文件
	if not FileAccess.file_exists(_active_save_path()):
		_show_toast("未找到存档文件")
		return
	var content: String = _read_text(_active_save_path())
	if content.is_empty():
		_show_toast("存档文件为空")
		return
	DisplayServer.clipboard_set(content)   # 源 UserDefault 内置副本 → 桌面剪贴板（headless no-op）
	var err: int = _write_text(export_file_path, content)
	if err != OK:
		_show_toast("导出失败（错误码 %d）" % err)
		return
	_show_toast("存档已复制到剪贴板，文件：" + ProjectSettings.globalize_path(export_file_path))


# ── 导入（源 doImportSave :174-260）──
func _on_import_clicked() -> void:
	var content: String = _read_import_content()
	if content.length() <= MIN_IMPORT_LEN:
		_show_toast("未找到导出的存档（先在旧设备导出，剪贴板或 user://save_export.txt）")
		return
	var data: Dictionary = validate_import_text(content)
	if data.is_empty():
		_show_toast("存档文件格式无效")
		return
	_pending_import = data
	_set_confirm_msg(CONFIRM_MSG)
	_confirm_layer.visible = true
	_confirm.open(_on_confirmed)   # 状态机登记回调；取消走 _on_confirm_cancel


func _on_confirm_cancel() -> void:
	_confirm.cancel()
	_pending_import = {}
	_pending_slot_action = {}
	if _confirm_layer != null:
		_confirm_layer.visible = false


# 确定按钮 handler：只驱动状态机，动作一律由 _on_confirmed 唯一执行。
# 2026-09-17 双执行根修：旧版在此还手动调 _apply_*——而 confirm() 的状态机回调正是
# open() 登记的函数，若登记的是本 handler 则重入：内层先跑真动作（pending 消费），
# 外层再跑一遍拿到空 slot → switch_slot 返 ERR_INVALID_PARAMETER(31)=用户实测
# 「新建存档错误码31」；既有导入链同病（第二次 apply 空字典重建默认号）一并根修。
func _on_confirm_ok() -> void:
	_confirm.confirm()


# 状态机回调（_confirm.open 登记，confirm() 恰好触发一次）：确认动作唯一执行点。
func _on_confirmed() -> void:
	if not _pending_slot_action.is_empty():
		_apply_slot_action()
		return
	if _pending_import.is_empty():
		_confirm_layer.visible = false
		return
	_apply_import()


func _apply_import() -> void:
	_confirm_layer.visible = false
	var data: Dictionary = _pending_import
	_pending_import = {}
	_backup_current_save()   # 源 :217-225 写 .bak_pre_import
	var err: int = GameData.apply_imported_save(data)
	if err != OK:
		_show_toast("导入失败（错误码 %d），进度未变更" % err)
		return
	remove_window()
	SceneManager.change_scene("res://scenes/main_menu/main_scene.tscn")   # 源 :254 popScene2


# 源导入顺序 :180-202：剪贴板（UserDefault 副本等价）优先，空则导出文件回退。
func _read_import_content() -> String:
	var clip: String = DisplayServer.clipboard_get()
	if clip.length() > MIN_IMPORT_LEN:
		return clip
	if FileAccess.file_exists(export_file_path):
		var from_file: String = _read_text(export_file_path)
		if from_file.length() > MIN_IMPORT_LEN:
			return from_file
	return ""


# 存档文本校验（源 :207-214 json.decode + _userid/_heroes 完整性 → 本项目 str_to_var
# + hero_manager 键）。str_to_var 仅解析数据字面量不执行代码；非法/不完整返回空字典。
static func validate_import_text(text: String) -> Dictionary:
	var parsed: Variant = str_to_var(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	if not data.has("hero_manager"):
		return {}
	return data


# 覆盖前备份当前存档（源 :216-225 cardgame_save.json.bak_pre_import → save_auto.json.bak_pre_import）。
func _backup_current_save() -> void:
	var active_path: String = _active_save_path()
	if not FileAccess.file_exists(active_path):
		return
	var content: String = _read_text(active_path)
	if content.is_empty():
		return
	_write_text(active_path + ".bak_pre_import", content)


static func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


static func _write_text(path: String, content: String) -> int:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(content)
	f.close()
	return OK
