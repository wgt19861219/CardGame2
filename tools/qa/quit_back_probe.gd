extends Node

## QA 探针（临时，验证后 uninstall）：模拟 Android 返回键——走真实通知链
## root.propagate_notification(GO_BACK_REQUEST) → HudOverlay._notification 弹确认框。
## 每 8s 补发一次（当前无弹窗时），供"取消后再触发→确认退出"两段验证；游戏退出随进程消亡。


func _ready() -> void:
	await get_tree().create_timer(6.0).timeout
	while true:
		if get_tree().root.find_children("QuitConfirm", "Control", true, false).is_empty():
			print("[QUIT_PROBE] 发送 GO_BACK_REQUEST 通知")
			get_tree().root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		await get_tree().create_timer(8.0).timeout
