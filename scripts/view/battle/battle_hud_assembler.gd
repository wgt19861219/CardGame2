class_name BattleHudAssembler
extends RefCounted

## 战斗 HUD 装配（View helper）— 从 BattleScene 拆出控 ≤400（照 BattleResourceAssembler 静态拆分范式）。
## 承接 BattleScene 的纯 UI 节点装配（speed/return/timer/next/auto 按钮 + 大血条 + heroes_panel）。
## static 方法第一参 scene，装配后节点存 scene 对应变量，信号连回 scene 的 _on_* 回调。
## 含业务/流程逻辑的 _on_* 回调保留在 BattleScene（速度切换/pause 状态机/next 波次推进）。


const BattleSpeedButton = preload("res://scripts/view/battle/battle_speed_button.gd")
const BattleTimer = preload("res://scripts/view/battle/battle_timer.gd")
const BattleNextButton = preload("res://scripts/view/battle/battle_next_button.gd")
const BattleAutoButton = preload("res://scripts/view/battle/battle_auto_button.gd")
const BattleHeroPanel = preload("res://scripts/view/battle/battle_hero_panel.gd")
const RETURN_BTN_TEX: String = "res://assets/ui/alpha/HVGA/pausebtn.png"
const HERO_PANEL_MIN_SIZE: Vector2 = Vector2(120.0, 126.0)  # 卡逻辑区（源 width=120/height≈144 取桶+条包络 126；HBox 中心距 120=源排布公式）


# 倍速按钮装配（源 :1235-1250）。setup 内读持久化档（源 :14 CCUserDefault），读出回写
# scene.speed_state（源是静态类变量天然共享，本项目 scene 实例变量须显式同步，engine 倍速才生效）。
static func create_speed_button(scene) -> void:
	if scene.speed_btn != null:
		scene.speed_btn.queue_free()
	var btn := BattleSpeedButton.new()
	btn.setup(scene.speed_state)
	scene.set_speed_state(btn.get_state())
	btn.speed_changed.connect(scene._on_speed_changed)
	scene.hud.add_to_bottom_right(btn)
	scene.speed_btn = btn


# 返回（暂停）按钮装配（源 pausebtn @757,440 中心，createButtonWithMask÷CS 显示 54.6×53.9）。
# TextureButton 贴图 + RETURN_BTN_POS + ÷CS scale + pressed 连 _on_return_pressed。
const RETURN_BTN_SCALE: Vector2 = Vector2(0.7805, 0.7805)   # 1/1.28125（源 createSprite÷CS）
static func create_return_button(scene) -> void:
	if scene.return_btn != null:
		scene.return_btn.queue_free()
	var btn := TextureButton.new()
	btn.texture_normal = load(RETURN_BTN_TEX) as Texture2D
	btn.position = scene.RETURN_BTN_POS
	btn.scale = RETURN_BTN_SCALE
	btn.pressed.connect(scene._on_return_pressed)
	scene.hud.add_to_top_bar(btn)
	scene.return_btn = btn


# 计时器装配（源 :1341-1387）。挂 hud，update 由 scene._update_timer 每帧驱动。
static func create_timer(scene) -> void:
	if scene.timer != null:
		scene.timer.queue_free()
	var t := BattleTimer.new()
	t.setup()
	scene.hud.add_to_top_bar(t)
	scene.timer = t


# 下一波按钮装配（源 :1198-1206）。pressed 连 _on_next_pressed（含 engine.battle_supply + walk + 波次推进）。
static func create_next_button(scene) -> void:
	if scene.next_btn != null:
		scene.next_btn.queue_free()
	var btn := BattleNextButton.new()
	btn.setup()
	btn.pressed.connect(scene._on_next_pressed)
	scene.hud.add_to_center_right(btn)
	scene.next_btn = btn


# 自动战斗按钮装配（源 :1207-1257）。toggled 连 _on_auto_toggled。
# 2026-10-08 受控增强（用户需求）：初始态读偏好档（user://battle.cfg auto_combat，跨战斗记忆，
# 照 create_speed_button 读档回写范式）——源每场重置 off。同日用户指示取消源 :1208-1231 的
# 通关门槛（pve stars>=3 才显示）：全模式恒显示恒读档，大招自动释放不再受通关进度限制（受控
# 偏离源行为）。源 replay 隐藏/attack 真人锁/teach(autoBattle) 教学无本项目对应入口（单机化裁剪）。
static func create_auto_button(scene) -> void:
	if scene.auto_btn != null:
		scene.auto_btn.queue_free()
	var btn := BattleAutoButton.new()
	var initial_on: bool = btn.read_persisted_on(false)
	btn.setup(initial_on, true)
	scene.auto_combat = btn.is_on()   # 读出档同步引擎（不触发 _on_auto_toggled 音效）
	btn.toggled.connect(scene._on_auto_toggled)
	scene.hud.add_to_bottom_right(btn)
	scene.auto_btn = btn


# heroes_panel 容器复用 hud.bottom_left（HBoxContainer 横向排列，修历史重叠）。
# 波次重置只清子节点 + _hero_panels，不重建容器（hud 常驻）。
static func create_heroes_panel(scene) -> void:
	scene._hero_panels.clear()
	if scene.hud != null and scene.hud.bottom_left != null:
		for child in scene.hud.bottom_left.get_children():
			child.queue_free()
	scene.heroes_panel = scene.hud.bottom_left if scene.hud != null else null


# 单英雄头像面板加入左下集群（HBox 自动横向排列，杜绝历史重叠）。
# 排列方向照源 addHeroPanel :521-529：x=width*(N/2-idx+3)+10，先加入（idx 小）x 大
# 排最右、后加入往左——即前排英雄（unit_list 靠前）显示在最右。HBox 默认 add_child
# 先加在左恰与源相反（2026-10-08 用户实测反馈反了），故每块新面板插到最左（move_child 0）。
static func add_hero_panel(scene, unit: Variant) -> void:
	if scene.heroes_panel == null:
		return
	var panel := BattleHeroPanel.new()
	panel.setup(unit, scene.cm, scene)
	panel.custom_minimum_size = HERO_PANEL_MIN_SIZE
	scene.heroes_panel.add_child(panel)
	scene.heroes_panel.move_child(panel, 0)
	scene.ui_list.append(panel)
	scene._hero_panels[unit] = panel
