class_name TutorialData
extends RefCounted

## 新手引导步骤数据（Data 层）— 照源 tutorialres.t_keys 首抽(FT)阶段线性链（id 1-16）。
## TutorialManager(_init steps) 接此序列；View 高亮/对话(tutorialmaker/tutorialres)留续。

const DEFAULT_FT_STEPS: Array[StringName] = [
	&"FTintoMain",        # id=1 进主城
	&"FTBronzeOpen",      # id=2 开青铜宝箱（首抽）
	&"FTBronzeOne",       # id=3 选英雄 1
	&"FTBronzeClose",     # id=4 关青铜
	&"FTGoldOpen",        # id=8 开黄金宝箱
	&"FTGoldOne",         # id=9 选英雄 2
	&"FTGoldClose",       # id=10 关黄金
	&"FTbackToMain",      # id=11 回主城
	&"gotoSelectStage",   # id=12 去选关
	&"selectStage",       # id=13 选关卡
	&"gotoPrepare",       # id=14 去备战
	&"selectHero",        # id=15 选英雄
	&"gotoBattle",        # id=16 进战斗
]


static func default_steps() -> Array[StringName]:
	return DEFAULT_FT_STEPS.duplicate()


const STEP_DESCRIPTIONS: Dictionary = {
	&"FTintoMain": "Here you can recruit the most powerful teammates",
	&"FTBronzeOpen": "Free bronze chest, see what's inside",
	&"FTBronzeOne": "",
	&"FTBronzeClose": "With fire woman joined, I mourn for our enemies",
	&"FTGoldOpen": "Try gold treasure chest",
	&"FTGoldOne": "",
	&"FTGoldClose": "You are welcome to join, our strength is more powerful",
	&"FTbackToMain": "",
	&"gotoSelectStage": "Beginning of a great adventure",
	&"selectStage": "Click into the game point",
	&"gotoPrepare": "",
	&"selectHero": "Send heroes to the battlefield",
	&"gotoBattle": "Send heroes to the battlefield",
	&"EEclickHero": "Click to select a hero",
	&"SUopenShortcut": "Come with me",
	&"SUclickHeroPackage": "It is time to teach you to upgrade skills",
	&"SUclickHero": "Select a hero",
	&"SUclickSkillButton": "You can access the skills panel from here",
	&"SUclickLevelup": "Click this button to upgrade skills",
	&"SUcomplete": "Skill points are automatically restored over time, make good use of",
}


# EE step 多 type=tips 无 dialog_text（运行时 context），仅 EEclickHero 有 dialog。
# 触发：玩家首次进装备强化流程（源 ed.tutorial.checkDone 各 UI 查，本项目条件触发 + UI 接 try_complete 待补）。
const EE_STEPS: Array[StringName] = [
	&"EEclickHero",      # 点英雄（hero_package）
	&"EEselectHero",     # 选英雄
	&"EEclickEquip",     # 点装备（hero_detail 装备槽）
	&"EEopenMaterial",   # 开材料（equipstrengthen）
	&"EEclickMaterial",  # 点材料
	&"EEclickEnhance",   # 点强化
]


# 触发：玩家首次进技能升级流程（源 checkDone + 本项目条件触发 + UI 接 try_complete 待补）。
const SU_STEPS: Array[StringName] = [
	&"SUopenShortcut",       # 开 shortcut（技能入口）
	&"SUclickHeroPackage",   # 点英雄包
	&"SUclickHero",          # 点英雄
	&"SUclickSkillButton",   # 点技能按钮（hero_detail 技能槽）
	&"SUclickLevelup",       # 点升级
	&"SUcomplete",           # 完成
]


# 15 功能解锁 step（本项目各功能解锁点条件触发，公告 dialog；数据链备条件触发用）。
const UNLOCK_STEPS: Array[StringName] = [
	&"unlockShop", &"unlockSkillUpgrade", &"unlockEliteMode", &"unlockpvp",
	&"unlockMidas", &"unlockcot", &"unlockEnhance", &"unlockExercise",
	&"unlockCrusade", &"unlockGuild", &"unlockWorldChannel", &"unlockExcavate",
	&"unlockStarShop", &"unlockSpecialShop", &"unlockSoSpecialShop",
]


const UNLOCK_STEP_IDS: Dictionary = {
	&"unlockEliteMode": 50,
	&"unlockShop": 51,
	&"unlockSpecialShop": 52,
	&"unlockSoSpecialShop": 53,
	&"unlockSkillUpgrade": 54,
	&"unlockpvp": 55,
	&"unlockMidas": 56,
	&"unlockcot": 57,
	&"unlockEnhance": 58,
	&"unlockExercise": 59,
	&"unlockCrusade": 87,
	&"unlockGuild": 89,
	&"unlockWorldChannel": 90,
	&"unlockExcavate": 91,
	&"unlockStarShop": 92,
}


## unlock step 名 → 源 tutorialres id（未找到返 0）。
static func get_unlock_step_id(step: StringName) -> int:
	return int(UNLOCK_STEP_IDS.get(step, 0))


# fontColor 全 ccc3(103,47,0)（照源）。坐标（bg_pos/light_pos/label_pos/fca_pos）照源 cocos 布局，
# 本项目 View 用居中弹窗布局重排（坐标转换复杂，照结构不照像素，复刻铁律允许的 Godot 适配）。
# fca_res 源 eff_UI_Main_*（Spine 资源），createExhibitionLayer 调 createFcaNode 不传 aniType →
# View 照源显示 atlas 静态图（createStaticSpriteFromSpineAtlas 最大 region）。Spine 动画的正确用途是
# main_scene aniType=1 按钮（非 unlock 公告，见 main_scene.gd + ui/main.lua:411-417）。
# icon_res 4 个 step 用静态图标 unlock_elitemode/worldchannel（assets 齐）。
const UNLOCK_FONT_COLOR: Color = Color(103.0 / 255.0, 47.0 / 255.0, 0.0)
const _ICON_DIR: String = "res://assets/ui/alpha/HVGA/"
const UNLOCK_STEP_CONFIG: Dictionary = {
	&"unlockShop": {"text": "Unlocked store function", "fca_res": "eff_UI_Main_Shop"},
	&"unlockSkillUpgrade": {"text": "Unlocked skills enhancement", "icon": _ICON_DIR + "unlock_elitemode.png"},
	&"unlockEliteMode": {"text": "Unlocked elite mode", "icon": _ICON_DIR + "unlock_elitemode.png"},
	&"unlockpvp": {"text": "Unlocked arena features", "fca_res": "eff_UI_Main_Pvp"},
	&"unlockMidas": {"text": "Unlocked golden hand function", "icon": _ICON_DIR + "unlock_elitemode.png"},
	&"unlockcot": {"text": "Unlocked caverns of time", "fca_res": "eff_UI_Main_Guard"},
	&"unlockEnhance": {"text": "Unlocked enchanting equipment", "fca_res": "eff_UI_Main_Skill"},
	&"unlockExercise": {"text": "Unlocked heroes trials", "fca_res": "eff_UI_Main_Exercise"},
	&"unlockCrusade": {"text": "Unlocked the burning crusade", "fca_res": "eff_UI_Main_Volcano"},
	&"unlockGuild": {"text": "Unlocked creating and joining the association", "fca_res": "eff_UI_Main_Guild"},
	&"unlockWorldChannel": {"text": "Unlocked world channel", "icon": _ICON_DIR + "unlock_worldchannel.png"},
	&"unlockExcavate": {"text": "Unlocked treasure crypt", "fca_res": "eff_UI_Main_Treasure"},
	&"unlockStarShop": {"text": "Interstellar travel businessman visiting", "fca_res": "eff_UI_Main_Shop_Star"},
	&"unlockSpecialShop": {"text": "Goblin merchant has been found", "fca_res": "eff_UI_Main_Shop2"},
	&"unlockSoSpecialShop": {"text": "Black market businessman has been found", "fca_res": "eff_UI_Main_Shop3"},
}


## unlock step 的公告配置（text/icon/fca_res）。未配置返空字典。
static func get_unlock_config(step: StringName) -> Dictionary:
	return UNLOCK_STEP_CONFIG.get(step, {})


## 步骤说明（源 dialog_text，空字符串表该步无对话）。
static func get_description(step: StringName) -> String:
	return String(STEP_DESCRIPTIONS.get(step, ""))


# circle_center 用本项目 main_scene 实际按钮坐标（game bridge find_ui_elements 查得，源坐标 ccp(630,130) 对应源布局）。
# FT finger step 多数 circle_center 运行时算（指向动态 UI 元素），此处补静态可定位的关键 step。
const STEP_HIGHLIGHTS: Dictionary = {
	&"gotoSelectStage": {  # 指向战役按钮（源 circle_center ccp(630,130)，本项目 @Button@15 center 810,203）
		"type": "finger",
		"circle_center": Vector2(810.0, 203.0),
		"circle_radius": 100.0,
		"circle_res": "res://assets/ui/alpha/HVGA/tutorial_circle_big.png",
	},
	&"selectStage": {  # 指向关卡 1 按钮（源运行时算；本项目 stage_select @Button@47 center 480,245）
		"type": "finger",
		"circle_center": Vector2(480.0, 245.0),
		"circle_radius": 80.0,
		"circle_res": "res://assets/ui/alpha/HVGA/tutorial_circle_big.png",
	},
	# gotoPrepare/selectHero/gotoBattle 属 prepare 备战流程，本项目简化为 stage_select→battle 直连（无 prepare UI），不补 circle
}


## 步骤高亮配置（源 finger type → circle_center/radius；空字典表该步无高亮）。
static func get_highlight(step: StringName) -> Dictionary:
	return STEP_HIGHLIGHTS.get(step, {})
