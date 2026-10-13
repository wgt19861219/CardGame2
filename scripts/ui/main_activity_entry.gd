class_name MainActivityEntry
extends Control

## 主城运营活动入口（View 层）— 源 statusbar.lua:497-539 createTitleButton activity Sprite
## （uires.lua:58 activity_pos = ori_pos + d_pos×1 = 签到右侧 110px → Godot (330,88)，
## 贴图 main_icon_op_act_1/2）+ activitiesList.lua:149-160 红点（judgeAllowData）。
## 按钮创建/红点判定/面板关闭重算收口一处——从 main_scene 拆独立组件守其 ≤400 行守卫
## （2026-10-13 活动系统迁移）。

const BTN_RES: String = "res://assets/ui/alpha/HVGA/main_icon_op_act_1.png"
const BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/main_icon_op_act_2.png"
const BTN_CENTER: Vector2 = Vector2(330.0, 88.0)
const TAG_RES: String = "res://assets/ui/alpha/HVGA/main_deal_tag.png"
# 红点骑缝偏移（按钮右上角；shortcut tag 同视觉位）
const TAG_OFFSET: Vector2 = Vector2(108.0, -6.0)
# 散图显示=纹理÷CS（main_icon_op_act 无 TextureConfig 条目，同签到按钮口径）
const CONTENT_SCALE: float = 1.28125

var _tag: TextureRect = null


## 挂到主城场景并建按钮（main_scene._build_hud 单行调用）。
static func create(parent: Node) -> MainActivityEntry:
	var entry := MainActivityEntry.new()
	parent.add_child(entry)
	entry._build()
	return entry


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btn := UiButton.make(BTN_RES, BTN_PRESS_RES, BTN_CENTER)
	var size: Vector2 = (load(BTN_RES) as Texture2D).get_size() / CONTENT_SCALE
	btn.size = size
	btn.position = BTN_CENTER - size / 2.0
	btn.pressed.connect(_on_pressed)
	add_child(btn)
	_tag = TextureRect.new()
	_tag.texture = load(TAG_RES) as Texture2D
	var tag_size: Vector2 = (_tag.texture as Texture2D).get_size() / CONTENT_SCALE
	_tag.size = tag_size
	_tag.position = TAG_OFFSET
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.visible = _red_dot()
	btn.add_child(_tag)


# 入口点击（源 showActivity framework.lua:349-357 → activitiesList）。
# 面板 tree_exited 时重算红点（源 Activities.exit → judgeAllowData 重算同语义）。
func _on_pressed() -> void:
	var panel := MainSceneEntryRouter.open_activities(get_parent())
	if panel != null:
		panel.tree_exited.connect(_refresh_tag)


func _red_dot() -> bool:
	var p: PlayerData = GameData.player
	return p != null and p.activity.has_red_dot(
		int(Time.get_unix_time_from_system()), p.cm)


func _refresh_tag() -> void:
	if _tag != null:
		_tag.visible = _red_dot()
