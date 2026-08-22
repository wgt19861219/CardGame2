class_name DungeonDegreePopup
extends PopWindow

## 副本难度选择弹窗 — 照源 ui/dungeon_map.lua:256-438 showDegreePopup + :446-520
## popupTouchHandler（brief 源对照表"dungeon.lua 367 行"系误配：该文件为副本入口
## 列表弹窗，非本弹窗；原头注所指 dungeon_map 为真源，2026-08-16 批 3 Task 2 核实）。
## 2026-08-16 两件套改造：Frame/Title/CloseBtn 静态进 content tscn；难度格（数量随
## difficulties ≤4）走 dungeon_degree_item.tscn 行模板 + fill。原 7 处动态构造全数消亡
## （VBox/HBox 容器壳系迁移发明删除，按钮/icon/vit 行静态结构入模板）。
## 受控偏离：title_bg（源 :305-313 act_popup_bg visible=false 死资产，无运行时切换，裁）；
## 遮罩与弹出动画收敛 PopWindow 基类（shade 150/255 + play_scale_in EaseBackOut 0.2s，
## 源 :263/:425-429 等价）；灰态 modulate=0.4+disabled 等价源 setSpriteGray+isUnlock 判定。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/dungeon_degree_popup_content.tscn")
const ITEM_SCENE: PackedScene = preload("res://scenes/ui/dungeon_degree_item.tscn")

# 格定位（源 :330-332 ox=97 oy=140 dx=170；格宽 172.49 = act_select_bg 221px/CS）：
# 格左 = 97-172.49/2；格顶 = 300-140-152.20/2（frame 局部 y'=300-y 点空间直译）。
const CELL_X0: float = 10.76
const CELL_DX: float = 170.0
const CELL_TOP: float = 83.90
const BTN_DISPLAY_SIZE := Vector2(172.49, 152.20)
# 源 setSpriteGray 等价（resource_manager.lua:871-877 ccc3(100,100,100)+opacity 180；
# 2026-08-22 巡检订正：旧 (0.4,0.4,0.4) 缺 alpha 分量）。
const GRAY_MODULATE := Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0)
const ICON_DIR: String = "res://assets/ui/alpha/HVGA/act/act_icon_difficulty_"
const CONTENT_SCALE: float = 1.28125

var boss_idx: int = 0
var _content: Control = null              # content tscn 根（%Frame/%TitleLabel/%DegreeHost/%CloseBtn 持有者）
var _degree_host: Control = null          # %DegreeHost（难度格宿主，Frame 全域）

signal degree_selected(p_boss_idx: int, diff_data: Dictionary)
signal close_requested


func setup_popup(p_boss_idx: int, p_boss_name: String, p_difficulties: Array, p_player_level: int) -> void:
	boss_idx = p_boss_idx
	setup()
	register_on_enter(play_scale_in)
	_build_content(p_boss_name)
	_fill_degree_items(p_difficulties, p_player_level)


# content 静态树 instantiate + fill title（无 fallback，源 :318 text = boss.name or ""）+ connect close。
func _build_content(p_boss_name: String) -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	(_content.get_node("%TitleLabel") as Label).text = p_boss_name
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close)
	_degree_host = _content.get_node("%DegreeHost") as Control


# 难度格 fill（源 :334-417 循环 ipairs(boss.difficulties)：实例化行模板 + 定位 + 数据）。
func _fill_degree_items(p_difficulties: Array, p_player_level: int) -> void:
	for di in range(p_difficulties.size()):
		var diff: Dictionary = p_difficulties[di]
		var item: Control = ITEM_SCENE.instantiate() as Control
		item.position = Vector2(CELL_X0 + CELL_DX * di, CELL_TOP)
		_degree_host.add_child(item)
		_fill_item(item, diff, p_player_level)


func _fill_item(p_item: Control, p_diff: Dictionary, p_player_level: int) -> void:
	var btn: TextureButton = p_item.get_node("%DiffBtn") as TextureButton
	var icon: TextureRect = p_item.get_node("%DiffIcon") as TextureRect
	var tex: Texture2D = _load_tex(ICON_DIR + str(int(p_diff["diff"])) + ".png")
	if tex != null:
		# 源 :358-366 button_icon mediate 居中不缩放；尺寸 = 贴图像素/CS（diff1-3 128.78 / diff4 135.80）
		icon.texture = tex
		var icon_size: Vector2 = tex.get_size() / CONTENT_SCALE
		icon.size = icon_size
		icon.position = (BTN_DISPLAY_SIZE - icon_size) * 0.5
	(p_item.get_node("%VitNum") as Label).text = str(int(p_diff["vit"]))
	var unlocked: bool = int(p_diff["unlock_level"]) <= p_player_level
	btn.modulate = GRAY_MODULATE if not unlocked else Color(1, 1, 1)
	btn.disabled = not unlocked
	btn.pressed.connect(Callable(self, "_on_degree_pressed").bind(p_diff))


func _on_degree_pressed(p_diff: Dictionary) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	emit_signal("degree_selected", boss_idx, p_diff)
	_on_close()


func _on_close() -> void:
	emit_signal("close_requested")
	remove_window()


static func _load_tex(p_path: String) -> Texture2D:
	return (load(p_path) as Texture2D) if ResourceLoader.exists(p_path) else null
