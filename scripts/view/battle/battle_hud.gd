class_name BattleHud
extends Control

## 战斗 HUD 容器（View 层）— 统一编排战斗界面元素，脱离 to_godot 坐标转换层。
## 照 hero_detail 范式：本 .tscn 固化分区容器（TopBar/BottomLeft/BottomRight/CenterRight），
## battle_scene 各 _create_* 把 HUD 元素挂进对应 Host，位置由本场景锚点/容器编排。
##
## 分区职责：
## - TopBar：大血条 / 金·掉落·波次标记 / 返回键（顶部带，y≈120）
## - BottomLeft (HBoxContainer)：英雄头像面板集群（自动横向排列，修历史重叠 bug）
## - BottomRight (VBoxContainer)：倍速 / 自动 / 计时器
## - CenterRight：下一波键
##
## 注意：仅服务 HUD 固定界面（A 类坐标）。战斗世界对象（actor/特效/飘字/掉落）
## 仍走 BattleViewCoords.to_view_position（B 类，含离地高度正交投影），不经本容器。


var bottom_left: HBoxContainer = null
var bottom_right: VBoxContainer = null
var center_right: Control = null
var top_bar: Control = null


func _ready() -> void:
	bottom_left = get_node("%BottomLeft") as HBoxContainer
	bottom_right = get_node("%BottomRight") as VBoxContainer
	center_right = get_node("%CenterRight") as Control
	top_bar = get_node("%TopBar") as Control


## 英雄头像面板加入左下集群（HBoxContainer 自动横向排列，杜绝历史重叠）。
func add_hero_panel(panel: Control) -> void:
	if bottom_left == null:
		return
	bottom_left.add_child(panel)


## 顶部带 HUD 元素挂载（大血条/标记/返回键）。
func add_to_top_bar(node: Control) -> void:
	if top_bar == null:
		return
	top_bar.add_child(node)


## 右下角按钮/计时器挂载（倍速/自动）。
func add_to_bottom_right(node: Control) -> void:
	if bottom_right == null:
		return
	bottom_right.add_child(node)


## 中右区域挂载（下一波键）。
func add_to_center_right(node: Control) -> void:
	if center_right == null:
		return
	center_right.add_child(node)
