class_name NameInputPanel
extends PopWindow

## 命名面板（View 层）— 照源 ui/popwindow/bename.lua。
## frame main_vit_tips 弹窗 + title + name_bg activate_input 输入框 + roll 骰子随机名
## + ok/cancel sell_number_button。roll 随机名照源 affixcount 词库
## （bename.lua:9-16 rollName，affixcount.lua 5356 英文名 → AffixCount.json）。
##
## 两件套改造（批 4 Task 2，2026-08-17）：完整静态树进 scenes/ui/name_input_content.tscn
## （子节点挂 Frame 局部坐标，源 readnode root=frame :294，y' = 180-y 翻译）；
## panel 只做 fill（Title/Button 文案走 LSTR、空名 roll 照源 createEdit :39-47）+
## 信号 connect + 确认校验（照源 doSetName :383-409）。ok/cancel 九宫格三态
## 静态化进 theme NameInputButton（复用 SB_pkg_hb_n/p 同图同 cap），
## UiScale9Button 运行时套样式退役。
## 受控裁剪（单机化 2026-07-18 既有决策延续）：GameCenter 昵称回填、dirtyword
## 词库校验、pay 型 100 钻石改名确认与网络回复（set_name 协议）不适用；
## 点 frame 外=取消走 PopWindow shade（源 registerTouchHandler :116-118 等价）；
## 改名成功照源直接关窗无成功 toast。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/name_input_content.tscn")
# roll 随机名照源 affixcount 词库（bename.lua:9-16 rollName，affixcount.lua 5356 英文名）。
const AFFIXCOUNT_PATH: String = "res://resources/data/AffixCount.json"
# 源 :395-398 名字长度上限（gsub UTF-8 首字节计数 = 字符数 > 13 拒绝）。
const NAME_MAX_LENGTH: int = 13

var _pd: PlayerData
var _content: Control
var _input: LineEdit
var _affixcount: Array = []


func setup_panel(p_pd: PlayerData) -> void:
	_pd = p_pd
	setup()
	register_on_enter(play_scale_in)
	_build_content()


# content 静态树 instantiate + fill 文案/初始名 + 信号绑定
# （源 show() EaseBackOut 0.2 弹入 → PopWindow.play_scale_in 基类等价）。
func _build_content() -> void:
	_load_affixcount()
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	(_content.get_node("%Title") as Label).text = GameData.config.get_lstr("BENAME.A_NAME_FOR_YOUR_TEAM_")
	(_content.get_node("%OkBtn") as Button).text = GameData.config.get_lstr("CHATCONFIG.CONFIRM")
	(_content.get_node("%CancelBtn") as Button).text = GameData.config.get_lstr("CHATCONFIG.CANCEL")
	_input = _content.get_node("%Input") as LineEdit
	_input.text = _pd.player_name
	# 源 createEdit :39-47：无名（GameCenter 昵称单机化不存在 → 等价空名分支）
	# 且非 pvp 时 roll 随机名。
	if _input.text.is_empty():
		_on_roll()
	(_content.get_node("%RollBtn") as BaseButton).pressed.connect(_on_roll)
	(_content.get_node("%CancelBtn") as BaseButton).pressed.connect(remove_window)
	(_content.get_node("%OkBtn") as BaseButton).pressed.connect(_on_confirm)


func _load_affixcount() -> void:
	var f := FileAccess.open(AFFIXCOUNT_PATH, FileAccess.READ)
	if f == null:
		return
	_affixcount = JSON.parse_string(f.get_as_text())
	f.close()


func _on_roll() -> void:
	if _affixcount.is_empty():
		return
	_input.text = String(_affixcount[randi_range(0, _affixcount.size() - 1)])


# 确认校验照源 doSetName :383-409：空名 toast 拒绝 → 超长 toast 拒绝 →
# set_player_name + mark dirty + 关窗（源成功 destroy 无成功提示）。
func _on_confirm() -> void:
	var new_name: String = _input.text.strip_edges()
	if new_name == "":
		_show_toast(GameData.config.get_lstr("BENAME.PLEASE_ENTER_A_NAME"))
		return
	if new_name.length() > NAME_MAX_LENGTH:
		_show_toast(GameData.config.get_lstr("BENAME.NAME_CAN_NOT_EXCEED_SEVEN_WORDS"))
		return
	_pd.set_player_name(new_name)
	GameData.mark_save_dirty()
	HudOverlay.refresh()   # 2026-08-21：改名回传主界面 HUD 昵称（同换头像回传链）
	remove_window()
