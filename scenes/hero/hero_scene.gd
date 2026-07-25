extends "res://scenes/base_ui.gd"

## 英雄管理场景（View 层）：顶部货币条（金币/钻石/体力）+ bg.jpg +
## HeroPackagePanel（英雄列表）→ 点英雄 → HeroDetailPanel（装备/强化/技能升级）。
## createHead/createTitleButton 只 main（hero 无头像/加号按钮），createBack 非 main（back 按钮在 HeroPackagePanel）。
## View 纯 UI：场景容器，业务在 HeroPackagePanel/HeroDetailPanel（PopWindow）+ HeroManager（Logic）。

const BG_TEXTURE: String = "res://assets/ui/alpha/HVGA/bg.jpg"
# 货币条位置统一引用 MainStatusBar.BAR_POS_X/BAR_Y（与主界面 main 一致，通用设置）。
# P1-2026-07-10：补全未 preload 的 class_name 类（消除跨脚本强引用）
const HeroPackagePanel = preload("res://scripts/ui/hero_package_panel.gd")
const MainStatusBar = preload("res://scripts/ui/main_status_bar.gd")

var _status_refs: Dictionary = {}   # MainStatusBar 货币条 label 引用（_refresh_status 更新）


func _ready() -> void:
	_create_bg()   # 全屏 bg.jpg（照 framework.lua:749-751，非 main 场景底层背景）
	_build_status_bar()
	_open_hero_package()
	_refresh_status()
	setup(Events.bus)


# 目标 960×640，bg.jpg(512×308) EXPAND_IGNORE_SIZE 拉伸铺满（同 loading 坑，size=get_viewport_rect）。
func _create_bg() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -1
	add_child(bg)


# 顶部货币条（金币/钻石/体力）— 照源 framework.createTitle common（所有场景建）。
# hero 无头像（createHead 只 main），只建 3 货币条（MainStatusBar.build_bars_only）。
func _build_status_bar() -> void:
	_status_refs = MainStatusBar.build_bars_only(self, MainStatusBar.BAR_POS_X, MainStatusBar.BAR_Y, _on_vitality_plus)


## 从 GameData 刷新货币条（委托 MainStatusBar.refresh）。
func _refresh_status() -> void:
	var p: PlayerData = GameData.player
	MainStatusBar.refresh(_status_refs, p.team_level, p.hero_manager.gold, p.diamond, p.vitality, p.vitality_max, p.player_name, p.vip_level, p.avatar)


## 体力加号（照源 statusbar vitality_add_icon→buyVitality；单机化直接买 + Toast，同 main_scene）。
func _on_vitality_plus() -> void:
	var p: PlayerData = GameData.player
	if not p.can_buy_vitality():
		Toast.show_message("今日购买体力次数已达上限")
		return
	if p.buy_vitality():
		Toast.show_message("购买体力 +120")
		_refresh_status()
	else:
		Toast.show_message("钻石不足")


## 弹英雄背包面板（照源 heropackage.create）：列表选英雄 → HeroDetailPanel（装备/强化/技能升级）。
func _open_hero_package() -> void:
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(GameData.player.hero_manager, GameData.config, GameData.player)
	panel.show_window(self)


## 设置货币条可见性。hero_detail 是 PopWindow（shade 半透 0.588）盖不住本场景顶部货币栏，
## 货币栏会从 shade 半透露出（变暗叠在 detail tab view 上）视觉遮挡。照源 hero_detail 独立场景
## （mainLayer z=120 + 不透明 bg）盖底层；本项目简化为 PopWindow，须 hero_package 点英雄时手动隐藏（同 container）。
func set_bars_visible(v: bool) -> void:
	for key in ["gold", "diamond", "vitality"]:
		if _status_refs.has(key):
			var lbl: Label = _status_refs[key] as Label
			if lbl != null and lbl.get_parent() != null:
				(lbl.get_parent() as CanvasItem).visible = v
