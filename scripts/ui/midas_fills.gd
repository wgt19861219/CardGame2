class_name MidasFills
extends RefCounted

## MidasPanel 纯数据填充（两件套范式，批 2 Task 6 2026-08-16）。
## midas_renderer.gd（2026-07-25 拆的静态建节点 helper）改写：静态结构归 tscn
## （历史行模板 midas_history_item.tscn / 确认弹窗 midas_confirm_content.tscn），
## 本类只做 fill（instantiate 行模板 + 填文本/visible 切换 + 滚动到底），
## 坐标全预计算进 tscn（坐标换算工具消亡）。
## 唯一节点构造：ratio 图缺降级 Label/TextureRect（assets midas/ 仅数字图的现实路径）。

const HISTORY_ROW_SCENE: PackedScene = preload("res://scenes/ui/midas_history_item.tscn")

# ratio 标记（源 :434-458 ratio_config 4 档 + :532-544 ratio_res 图；图缺 Label 降级）。
# ratio 值域 1/2/3/4 → 倍率 1/2/3/10（源 ratio_config[ratio].ratio）。
const HISTORY_RATIO_RES: Dictionary = {
	2: "res://assets/ui/alpha/HVGA/midas/midas_crip2.png",
	3: "res://assets/ui/alpha/HVGA/midas/midas_crip3.png",
	4: "res://assets/ui/alpha/HVGA/midas/midas_crip10.png",
}
const RATIO_TEXT: Dictionary = {1: "", 2: " ×2!", 3: " ×3!", 4: " ×10!!"}
const RATIO_COLOR: Dictionary = {
	1: Color.WHITE, 2: Color(1.0, 0.4, 0.7), 3: Color(1.0, 0.4, 0.7), 4: Color(1.0, 0.36, 0.27),
}
# 源 midas.lua:494 fix_height = ed.DGLen(30)（readnode.lua:8 DGLen = len/1.28）= 23.4375 点。
# 旧值 30.0 漏除 DGLen 系数，比例图标高偏大 28%（2026-08-22 溢出修复清查修正）。
const RATIO_ICON_H: float = 30.0 / 1.28
const LSTR_USE := "MIDAS.USE"
const LSTR_GET := "ADDEQUIP.GET"
# 确认弹窗 3 行 LSTR（源 createMultiWindow :563/:584/:598/:631）。
const LSTR_MULTI := "midas.1.10.1.002"
const LSTR_TIMES_SUFFIX := "midas.1.10.1.003"
const LSTR_COST_TITLE := "midas.1.10.1.004"
const LSTR_GAIN_TITLE := "midas.1.10.1.005"


# 历史区全量重建（源 refreshHistory :668-708 push 逐条 + move2end）：
# 清 VBox → 逐行 instantiate 模板 fill → 滚到底（最新行可见，源 :705）。
static func fill_history_rows(scroll: ScrollContainer, host: VBoxContainer, history: Array, lstr_resolver: Callable) -> void:
	for c in host.get_children():
		c.queue_free()
	for h in history:
		fill_history_row(host, h, lstr_resolver)
	if scroll != null and not history.is_empty():
		_scroll_to_end(scroll)


# 单行 fill：行模板 6 节点文本 + ratio 标记（源 initHistoryItemHandler :425-545）。
static func fill_history_row(host: VBoxContainer, h: Dictionary, lstr_resolver: Callable) -> void:
	var row: Control = HISTORY_ROW_SCENE.instantiate() as Control
	var bar: HBoxContainer = row.get_node("Bar") as HBoxContainer
	(bar.get_node("UseLabel") as Label).text = String(lstr_resolver.call(LSTR_USE))
	(bar.get_node("CostLabel") as Label).text = str(int(h.get("cost", 0)))
	(bar.get_node("GetLabel") as Label).text = String(lstr_resolver.call(LSTR_GET))
	(bar.get_node("AcquireLabel") as Label).text = str(int(h.get("acquire", 0)))
	var ratio: int = int(h.get("ratio", 1))
	if ratio >= 2:
		fill_ratio(row.get_node("RatioHost") as Control, ratio)
	host.add_child(row)


# ratio 标记（源 :532-544：ratio_res 图 fix_height 30 行内 anchor(0,0.5)；
# 图缺（assets 实况）→ 降级 Label ×N! 色照 ratio_config）。
static func fill_ratio(host: Control, ratio: int) -> void:
	var res_path: String = String(HISTORY_RATIO_RES.get(ratio, ""))
	if res_path != "" and ResourceLoader.exists(res_path):
		var tex: Texture2D = load(res_path) as Texture2D
		if tex != null:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.size = Vector2(tex.get_width() * RATIO_ICON_H / maxf(tex.get_height(), 1.0), RATIO_ICON_H)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			host.add_child(icon)
			return
	var rtext: String = String(RATIO_TEXT.get(ratio, ""))
	if rtext == "":
		return
	var lbl := Label.new()
	lbl.text = rtext
	lbl.modulate = RATIO_COLOR.get(ratio, Color.WHITE)
	lbl.theme_type_variation = &"MidasHistoryLabel"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(lbl)


# 滚到底（源 :705 scrollView:move2end(0.4)）：布局帧末置底（VBox 增行后
# max_value 在布局 pass 更新，deferred 回调时已是新值）。
static func _scroll_to_end(scroll: ScrollContainer) -> void:
	(func() -> void:
		if is_instance_valid(scroll):
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)).call_deferred()


# 确认弹窗 3 行文本 fill（源 createMultiWindow :556-657 ChaosNode：
# 连兑次数行/总花费行/总获得行）。
static func fill_confirm_texts(content: Control, times: int, total_cost: int, total_acquire: int, lstr_resolver: Callable) -> void:
	var rows: VBoxContainer = content.get_node("%Frame/%Rows") as VBoxContainer
	var row_times: HBoxContainer = rows.get_node("RowTimes") as HBoxContainer
	(row_times.get_node("TimesTextLabel") as Label).text = String(lstr_resolver.call(LSTR_MULTI))
	(row_times.get_node("TimesCountLabel") as Label).text = str(times)
	(row_times.get_node("TimesTailLabel") as Label).text = String(lstr_resolver.call(LSTR_TIMES_SUFFIX))
	var row_cost: HBoxContainer = rows.get_node("RowCost") as HBoxContainer
	(row_cost.get_node("CostTitleLabel") as Label).text = String(lstr_resolver.call(LSTR_COST_TITLE))
	(row_cost.get_node("CostLabel") as Label).text = "x" + str(total_cost)
	var row_gain: HBoxContainer = rows.get_node("RowGain") as HBoxContainer
	(row_gain.get_node("GainTitleLabel") as Label).text = String(lstr_resolver.call(LSTR_GAIN_TITLE))
	(row_gain.get_node("GainLabel") as Label).text = "x" + str(total_acquire)
