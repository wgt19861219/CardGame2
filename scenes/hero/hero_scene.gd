extends Control

## 英雄管理场景（View 层）：顶部货币条（金币/钻石/体力）+ bg.jpg +
## HeroPackagePanel（英雄列表）→ 点英雄 → HeroDetailPanel（装备/强化/技能升级）。
## createHead/createTitleButton 只 main（hero 无头像/加号按钮），createBack 非 main（back 按钮在 HeroPackagePanel）。
## View 纯 UI：场景容器，业务在 HeroPackagePanel/HeroDetailPanel（PopWindow）+ HeroManager（Logic）。

const BG_TEXTURE: String = "res://assets/ui/alpha/HVGA/bg.jpg"
# P1-2026-07-10：补全未 preload 的 class_name 类（消除跨脚本强引用）
const HeroPackagePanel = preload("res://scripts/ui/hero_package_panel.gd")


func _ready() -> void:
	_create_bg()   # 全屏 bg.jpg（照 framework.lua:749-751，非 main 场景底层背景）
	# HudOverlay 切 identity=heropackage（hero 无头像，仅 3 货币条；shortcut 默认展开）。
	HudOverlay.apply_identity("heropackage")
	_open_hero_package()
	HudOverlay.refresh()


# 目标 800×480，bg.jpg(512×308) EXPAND_IGNORE_SIZE 拉伸铺满（同 loading 坑，size=get_viewport_rect）。
func _create_bg() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -1
	add_child(bg)


## 弹英雄背包面板（照源 heropackage.create）：列表选英雄 → HeroDetailPanel（装备/强化/技能升级）。
func _open_hero_package() -> void:
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(GameData.player.hero_manager, GameData.config, GameData.player)
	panel.show_window(self)


## 设置货币条可见性。hero_detail 是 PopWindow（shade 半透 0.588）盖不住本场景顶部货币栏，
## 货币栏会从 shade 半透露出（变暗叠在 detail tab view 上）视觉遮挡。照源 hero_detail 独立场景
## （mainLayer z=120 + 不透明 bg）盖底层；本项目简化为 PopWindow，须 hero_package 点英雄时手动隐藏。
## HudOverlay 模式下直接切其 StatusBar visible。
func set_bars_visible(v: bool) -> void:
	HudOverlay.set_status_visible(v)
