class_name NumberNode
extends RefCounted

## 逐字符数字贴图节点 — 源 tools.lua getNumberNode 等价（2026-08-27 批 A G1b 像素级对齐）。
## 源机制：UI/alpha/HVGA/digits/<folder>/<char>.png 白底黑描边字符图（"," → comma、
## "/" → slash、":" → colon，负号用 "-" 贴图），每字符左排 padding=-3 点；
## folder 缺省 white（statusbar 资源条实际观感，A/B 样张对照定案）；体力超上限
## 用 main_blue（statusbar.lua:1121 条件 folder）。mrv_scale=1 原尺寸显示，
## 数字字符贴图均无 TextureConfig 条目 → 显示尺寸=纹理像素÷CS。
## 右缘锚定（framework.lua updateMRV left2Point）：容器垂直中心 = 条内 (48-25)=23、
## 右缘 x=rightPoint.x（gold 135 / rmb 130 / maxVit 107，money_bg 局部系直译）。

const CONTENT_SCALE: float = 1.28125
const DIGITS_DIR: String = "res://assets/ui/alpha/HVGA/digits/"
const PADDING: float = -3.0
# 特殊字符映射（tools.lua:402-406 ct 表）。
const CHAR_ALIAS: Dictionary = {",": "comma", "/": "slash", ":": "colon"}


## 千分位格式化（源 tools.lua formatNumWithComma：自右每三位插逗号）。
static func format_comma(value: int) -> String:
	var s := str(value)
	var tail := ""
	while s.length() > 3:
		tail = "," + s.substr(s.length() - 3, 3) + tail
		s = s.substr(0, s.length() - 3)
	return s + tail


## 构建字符组容器（右缘对齐配合 place_right 用）。
static func build(text: String, folder: String = "white") -> Control:
	return _rebuild(Control.new(), text, folder)


## 数值变化重建子节点（源 refreshNumberNode 的 remove+rebuild 等价）。
static func refresh(host: Control, text: String, folder: String = "white") -> void:
	if host == null:
		return
	for c in host.get_children():
		host.remove_child(c)
		c.free()
	_rebuild(host, text, folder)


## 把容器右缘钉在 right_x（调用方条局部系）、垂直中心 center_y。
static func place_right(host: Control, right_x: float, center_y: float) -> void:
	host.position = Vector2(right_x - host.size.x, center_y - host.size.y * 0.5)


static func _rebuild(host: Control, text: String, folder: String) -> Control:
	var dir: String = DIGITS_DIR + folder + "/"
	var cursor_x: float = 0.0
	var max_h: float = 0.0
	for i in range(text.length()):
		var ch := text[i]
		var fname: String = CHAR_ALIAS.get(ch, ch)
		var path: String = dir + fname + ".png"
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var size: Vector2 = tex.get_size() / CONTENT_SCALE
		max_h = maxf(max_h, size.y)   # 源先并高再定位：setPosition(ccp(nw, h/2))
		var tr := TextureRect.new()
		tr.name = "ch%d" % i
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = size
		tr.custom_minimum_size = size
		tr.position = Vector2(cursor_x, max_h * 0.5 - size.y * 0.5)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(tr)
		cursor_x += size.x + PADDING
		max_h = maxf(max_h, size.y)
	# 源 node contentSize = 累计 w-h；末字符 -padding 归零尾隙（全缺资源防负宽）。
	var total_w: float = maxf(cursor_x - PADDING if text.length() > 0 else 0.0, 0.0)
	host.size = Vector2(total_w, max_h)
	host.custom_minimum_size = host.size
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return host
