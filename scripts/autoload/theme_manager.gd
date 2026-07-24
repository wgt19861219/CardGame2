extends Node
## 全局 Theme 单例（autoload 名 ThemeManager 即全局，仿 events.gd/audio_player.gd 不用 class_name）：
## 加载 default_theme.tres，提供 get_theme() 给 View 层控件引用。
## 受控偏离：源无集中 UI 主题系统（ccc3 散落 150 文件），本项目新建。
## 渐进策略：当前只归纳 Label font_size/color/outline + 容器 separation + Button 空 stylebox 骨架；
## Button 纹理(59 处散落)留 Task 4 试点 + 后续批次逐步归纳。

const DEFAULT_THEME_RES: String = "res://resources/themes/default_theme.tres"

var _theme: Theme = null


func _ready() -> void:
	_theme = load(DEFAULT_THEME_RES) as Theme
	if _theme == null:
		push_error("ThemeManager: default_theme.tres 加载失败")
		return
	# 挂到根 Viewport，所有 Control 自动继承
	get_tree().root.set_theme(_theme)


## 返回全局 Theme（autoload 就绪后非空）。
func get_theme() -> Theme:
	return _theme
