class_name ExcavateBattlePlayerRowBuilder
extends RefCounted

## 挖矿战报玩家行动态构建（两件套范式，excavate 批 Task 5，2026-08-17）：
## 静态结构在 excavate_battle_player_item.tscn 模板（照源 uieditor/
## itemexcavatebattleplayer.lua 216 行直译），本类只实例化行 + 填动态数据 +
## 胜/败 tag 互斥（源 excavatebattlereport.lua getInitHandler:113-125）+
## 英雄 ReadheroIcon（源 :127-146 j=1..5 有 hero 才填，length=槽宽 46.88）。
## 单机受控降级（报告记录）：icon_container/level_container 照源建位但不填
## （源 getTeamHead/getLevelIcon 头像/等级徽章基础设施缺失，与 ranklist_panel
## 同源残留）；hp/mp 血条不画（单机 _dyna 恒空无战斗结束血量）；名字单机映射
## （敌方=矿点守军名/我方=玩家名，源 playerData._name 无对应数据）。

const ITEM_SCENE: PackedScene = preload("res://scenes/ui/excavate_battle_player_item.tscn")
# 源 hicon readhero.createIcon length=槽宽 46.88 → ReadheroIcon 104 容器缩放填槽
const HICON_SLOT: float = 46.88
const HICON_SCALE: float = HICON_SLOT / ReadheroIcon.CONTAINER_SIZE.x
# 源 j=1..5 固定 5 槽（超出不显示）
const HERO_SLOTS: int = 5


## 单侧 fill：实例化玩家行挂 host + tag 互斥 + 名字 + 英雄 icon（返行实例）。
static func fill_side(host: Control, team_data: Dictionary, display_name: String,
		side_won: bool, p_cm: Variant) -> Control:
	var row: Control = ITEM_SCENE.instantiate() as Control
	host.add_child(row)
	(row.get_node("%TagWin") as CanvasItem).visible = side_won
	(row.get_node("%TagLose") as CanvasItem).visible = not side_won
	(row.get_node("%NameLabel") as Label).text = display_name
	_fill_hero_icons(row, team_data.get("_hero", []), p_cm)
	return row


## 英雄 icon 1..5 槽（源 :127-146 heroData[j] 有才 createIcon 塞槽，空槽留空）。
static func _fill_hero_icons(row: Control, heroes: Array, p_cm: Variant) -> void:
	var count: int = mini(heroes.size(), HERO_SLOTS)
	for i: int in range(count):
		var hero: Dictionary = heroes[i]
		var base: Dictionary = hero.get("_base", {})   # _base 照源（history 记录 {"_base":{...}}）
		var slot: Control = row.get_node("Hicon%d" % (i + 1)) as Control
		var icon := ReadheroIcon.new()
		icon.setup({
			"id": int(base.get("_tid", 0)),
			"rank": int(base.get("_rank", 1)),
			"stars": int(base.get("_stars", 0)),
			"level": int(base.get("_level", 0)),
		}, p_cm)
		icon.scale = Vector2(HICON_SCALE, HICON_SCALE)
		slot.add_child(icon)
