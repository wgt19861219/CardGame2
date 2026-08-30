class_name LevelIcon
extends RefCounted

## 等级徽章 — 源 resource_manager.lua getLevelIcon(:1070-1096)：silver 底图（vip 用 gold）
## + 20 号 ccc3(255,255,228) 等级字。底图 46x39px ÷CS = 35.90x30.44pt；字中心 y+1（cocos）
## → Godot y-1。走查批 C（2026-08-27）ranklist 行/浮窗启用，替代名字合并 "LvN" 降级。

const CONTENT_SCALE: float = 1.28125
const FRAME_SILVER: String = "res://assets/ui/alpha/HVGA/pvp/main_head_level_bg_silver.png"
const FRAME_GOLD: String = "res://assets/ui/alpha/HVGA/pvp/main_head_level_bg_gold.png"
const VAR_LABEL: String = "RanklistLevelLabel20"
const LABEL_DY: float = -1.0


## 建等级徽章（level>=1；vip=true 用金底）。组合以 host 原点为中心（frame/lbl 各带
## -fsz/2 偏移），调用方 position=中心锚点（源中心锚定位语义）。
static func build(level: int, vip: bool = false) -> Control:
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = load(FRAME_GOLD if vip else FRAME_SILVER)
	var frame := TextureRect.new()
	frame.texture = tex
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var fsz: Vector2 = tex.get_size() / CONTENT_SCALE
	frame.size = fsz
	frame.position = -fsz * 0.5
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(frame)
	var lbl := Label.new()
	lbl.text = str(maxi(1, level))
	lbl.theme_type_variation = VAR_LABEL
	lbl.size = fsz
	lbl.position = -fsz * 0.5 + Vector2(0.0, LABEL_DY)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(lbl)
	return host
