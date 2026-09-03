class_name ShortcutRouter
extends RefCounted

## Shortcut 按钮路由器（View 层 helper）— 照源 framework.lua:570-657 getSCButtonTouchHandler。
##
## 源 shortcut 5 按钮（heroPackage/package/fragment/task/todoList）的路由统一逻辑。
## 从 main_scene._on_shortcut_open 提取，供所有 FrameworkHud 接入的场景共用（去重）。
##
## 嵌套规则（用户确认）：panel 内点 shortcut 开新 panel，新 panel 挂到当前 panel 的 parent
## （即与当前 panel 同级叠在它上面，模拟源 pushScene 栈语义）。

const MainSceneEntryRouter = preload("res://scripts/ui/main_scene_entry_router.gd")


## 统一 shortcut 按钮路由。
## parent: 新 panel 的挂载父节点（当前 panel/scene 的 parent）
## key: heroPackage/package/fragment/task/todoList
static func route(parent: Node, key: String) -> void:
	match key:
		"package":
			MainSceneEntryRouter.open_package(parent, "package")
		"fragment":
			MainSceneEntryRouter.open_package(parent, "fragment")
		"heroPackage":
			MainSceneEntryRouter.open_hero(parent)
		"task":
			MainSceneEntryRouter.open_task(parent, "task")
		"todoList":
			# 源 framework.lua:649-653 doClickDailyjob → dailyTask 独立弹窗（:34 addChild
			# z=101）。2026-08-22 曾合并进 TaskPanel 双区（受控偏离），2026-09-03 三轮
			# 用户指示拆回两独立弹窗：本按钮开 dailyTask 模式（标题"日常活动"+仅每日列表）。
			MainSceneEntryRouter.open_task(parent, "dailyTask")
		_:
			pass
