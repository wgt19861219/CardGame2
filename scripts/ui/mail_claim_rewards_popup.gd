class_name MailClaimRewardsPopup
extends PopWindow

## 邮件领取奖励展示弹窗（View 层）— 2026-09-16 受控增强（六轮样式统一重构）。
## 源 doReadMail 领取成功 destroy({skipAnim=true}) 无任何展示（源本无领取效果）；
## 用户期望领取反馈 → 领取后弹获得物品清单。六轮起并入 PopWindow 体系（统一遮罩/
## 动态 z 栈/play_scale_in 弹入），chrome 与 SweepRewardPopup 同款（main_vit_tips 框
## + task_title_bg 标题带 + herodetail-detail-close 关闭钮），货币行/物品 icon 渲染
## 同 mail_detail_panel 附件区口径。关闭=CloseBtn / 点 shade。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/mail_claim_rewards_content.tscn")
const CURRENCY_ITEM_SCENE: PackedScene = preload("res://scenes/ui/mail_currency_item.tscn")
const CS: float = 1.28125
const FRAME_TEX_W: float = 94.0
const FRAME_TEX_H: float = 95.0
const ICON_SCALE: float = 60.0 / (FRAME_TEX_W / CS)
# 货币 icon 显示高（同 mail_detail_panel createCommonAttach fix_height=25 口径）
const CURRENCY_ICON_H: float = 25.0
const CURRENCY_ROW_DY: float = 30.0
const ITEM_ICON_COLS: int = 5
const ITEM_ICON_SIZE: float = 75.0
# P1：UI 文案 cm.get_lstr 化（源 ANNOUNCE.GAIN_LOOTS「获得物品」，fallback 中文兜底）。
const LSTR_TITLE_KEY: String = "ANNOUNCE.GAIN_LOOTS"
const TITLE_FALLBACK: String = "获得物品"
const CURRENCY_ICONS: Dictionary = {
	"Gold": "res://assets/ui/alpha/HVGA/goldicon_small.png",
	"Diamond": "res://assets/ui/alpha/HVGA/shop_token_icon.png",
	"Exp": "res://assets/ui/alpha/HVGA/task_exp_icon_2.png",
	"CrusadeMoney": "res://assets/ui/alpha/HVGA/money_dragonscale_big.png",
	"PvpMoney": "res://assets/ui/alpha/HVGA/money_arenatoken_big.png",
	"GuildMoney": "res://assets/ui/alpha/HVGA/money_guildtoken_big.png",
	"SkillPoint": "res://assets/ui/alpha/HVGA/herodetail_skill_upgrade_button_1.png",
}
const GOLD_ICON: String = "res://assets/ui/alpha/HVGA/goldicon_small.png"

var _attach_common: Array = []
var _items: Array = []
var _cm: Variant


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = GameData.config
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# attach_common/items = 领取前邮件 format 快照（claim 会清 raw，快照不受影响）。
# 六轮：改 PopWindow 链——setup_panel（建 shade/container+content）→ 调用方 show_window。
func setup_panel(p_attach_common: Array, p_items: Array, p_cm: Variant) -> void:
	_attach_common = p_attach_common
	_items = p_items
	_cm = p_cm
	setup()
	_build_content()
	register_on_enter(play_scale_in)


func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%TitleLabel") as Label).text = _lstr(LSTR_TITLE_KEY, TITLE_FALLBACK)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	_fill_rewards(content.get_node("%Host") as Control)


# 货币行 + 物品 icon 网格（渲染逻辑同 mail_detail_panel._add_currency_row /
# _add_item_attach；Host 全局 (230,110)-(570,440)，货币行 y-30 逐行居中，
# 物品 5 列 stride 75（照 sweep 网格口径）居中起排）。
func _fill_rewards(host: Control) -> void:
	var cy: float = 10.0
	for entry in _attach_common:
		var ctype: String = str(entry.get("type", ""))
		var camount: int = int(entry.get("amount", 0))
		if camount <= 0:
			continue
		var icon_path: String = CURRENCY_ICONS.get(ctype, GOLD_ICON)
		var row: Control = CURRENCY_ITEM_SCENE.instantiate() as Control
		row.position = Vector2(80.0, cy)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon: TextureRect = row.get_node("%Icon") as TextureRect
		icon.texture = load(icon_path) as Texture2D
		var icon_w: float = CURRENCY_ICON_H
		if icon.texture != null:
			var ts: Vector2 = icon.texture.get_size()
			if ts.y > 0.0:
				icon_w = CURRENCY_ICON_H * ts.x / ts.y
		icon.size = Vector2(icon_w, CURRENCY_ICON_H)
		var lbl: Label = row.get_node("%Amount") as Label
		lbl.text = "x%d" % camount
		lbl.position = Vector2(40.0 + icon_w + 20.0, 0.0)
		host.add_child(row)
		cy += CURRENCY_ROW_DY
	if _items.is_empty():
		return
	var vis_h: float = FRAME_TEX_H / CS * ICON_SCALE   # icon 视觉高（同 detail 口径 60.64）
	var icon_rows: int = ceili(float(_items.size()) / float(ITEM_ICON_COLS))
	var grid_w: float = ITEM_ICON_SIZE * float(mini(_items.size(), ITEM_ICON_COLS))
	var x0: float = (host.size.x - grid_w) * 0.5
	var cy_items: float = cy + 20.0
	for i in range(_items.size()):
		var item: Dictionary = _items[i]
		var item_id: int = int(item.get("id", 0))
		var amount: int = int(item.get("amount", 1))
		if item_id == 0:
			continue
		var col: int = i % ITEM_ICON_COLS
		var row_i: int = int(i / ITEM_ICON_COLS)
		var icon: Control = ReadequipIcon.create_icon(item_id, amount, _cm)
		icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
		icon.position = Vector2(x0 + float(col) * ITEM_ICON_SIZE,
			cy_items + 32.5 + float(row_i) * ITEM_ICON_SIZE - vis_h * 0.5)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(icon)
