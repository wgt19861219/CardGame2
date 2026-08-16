class_name MidasConfirm
extends PopWindow

## 连兑确认弹窗（View 层）— 照源 midas.lua createMultiWindow :550-666
## ed.popConfirmDialog + uieditor/confirmdialog.lua 声明表（批 2 Task 6 独立 PopWindow 化）。
## 结构静态归 midas_confirm_content.tscn（frame/delimeter/3 行/双按钮），本类只 fill
## 动态文本（连兑次数/总花费/总获得 LSTR）+ 连接确认/取消按钮。
## 帧缩放入场照源 popwindow show（PopWindow 基类 scale_in）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/midas_confirm_content.tscn")

var _frame: Control = null
var _ok_handler: Callable = Callable()


# panel 传入：连兑次数 + 预算总额 + LSTR 解析器 + 确认回调（源 rightHandler :662-664）。
func setup_confirm(times: int, total_cost: int, total_acquire: int, lstr_resolver: Callable, ok_handler: Callable) -> void:
	_ok_handler = ok_handler
	setup()
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	_frame = content.get_node("%Frame") as Control
	MidasFills.fill_confirm_texts(content, times, total_cost, total_acquire, lstr_resolver)
	(_frame.get_node("%OkBtn") as Button).text = String(lstr_resolver.call(&"CHATCONFIG.CONFIRM"))
	(_frame.get_node("%CancelBtn") as Button).text = String(lstr_resolver.call(&"CHATCONFIG.CANCEL"))
	(_frame.get_node("%OkBtn") as Button).pressed.connect(_on_ok)
	(_frame.get_node("%CancelBtn") as Button).pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_click_feedback")
		remove_window())


func _on_ok() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	remove_window()
	if _ok_handler.is_valid():
		_ok_handler.call()
