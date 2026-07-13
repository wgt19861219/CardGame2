extends "res://scenes/base_ui.gd"

## 英雄管理场景（View 层）：顶部"英雄"入口 → 弹 HeroPackagePanel（英雄列表）→ 点英雄 →
## HeroDetailPanel（装备槽→EquipCraftPanel / 强化→EquipStrengthenPanel / 技能升级 / 分解）。
## 照源 heropackage（英雄背包面板，listButton 分类 + createHeroList）；本项目单机化场景容器 + PopWindow 弹窗。
## View 纯 UI：场景容器，业务在 HeroPackagePanel/HeroDetailPanel（PopWindow）+ HeroManager（Logic）。

const BACK_BTN_POS: Vector2 = Vector2(20.0, 10.0)
const BACK_BTN_SIZE: Vector2 = Vector2(90.0, 32.0)
const BG_TEXTURE: String = "res://assets/ui/alpha/HVGA/bg.jpg"   # 源 framework.lua:749 全屏背景
# P1-2026-07-10：补全未 preload 的 class_name 类（消除跨脚本强引用）
const HeroPackagePanel = preload("res://scripts/ui/hero_package_panel.gd")


func _ready() -> void:
	_create_bg()   # 全屏 bg.jpg（照 framework.lua:749-751，非 main 场景底层背景）
	_build_back_button()
	_open_hero_package()
	setup(Events.bus)


# 源 framework.lua:749-751 createSprite(bg.jpg) setPosition(400,240) ccScene addChild(bg,-1)。
# 目标 960×640，bg.jpg(512×308) EXPAND_IGNORE_SIZE 拉伸铺满（同 loading 坑，size=get_viewport_rect）。
func _create_bg() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


## 顶部返回按钮（回主界面）。
func _build_back_button() -> void:
	var btn := Button.new()
	btn.position = BACK_BTN_POS
	btn.size = BACK_BTN_SIZE
	btn.text = "← 返回"
	btn.z_index = 10
	btn.pressed.connect(_back_to_main)
	add_child(btn)


func _back_to_main() -> void:
	SceneManager.change_scene("res://scenes/main_menu/main_scene.tscn")


## 弹英雄背包面板（照源 heropackage.create）：列表选英雄 → HeroDetailPanel（装备/强化/技能升级）。
func _open_hero_package() -> void:
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(GameData.player.hero_manager, GameData.config, GameData.player)
	panel.show_window(self)
