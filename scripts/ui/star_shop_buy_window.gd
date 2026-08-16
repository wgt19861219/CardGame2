class_name StarShopBuyWindow
extends PopWindow

## 星辰商店购买确认弹窗（View 层）— 照源 popwindow/starshopbuywindow.lua。
## 9 节点照源 uieditor/starshopbuywindow.lua 声明表：frame/line/cancel/ok/title_1/
## icon_container/amount/title_2/name（fix_wh=显示尺寸，position=中心点，frame 局部
## Cocos 左下原点→Godot 容器内 (x,289.84-y) 翻转）。
## 资源缺降级：tips_frame/tips_delimeter/button_1/2.png 源导出物未含 → Frame
## StyleBoxFlat/Line ColorRect/按钮 StarShopBuyBtn 三态（批 2 Task 4）。
## 入场缩放动画照源 :112-119 show frame setScale(0)→CCScaleTo 0.2 EASEBackOut。
## panel 仅填动态 LSTR 文字 + 灵魂石 icon + 连信号。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/star_shop_buy_window_content.tscn")
const SHOW_SEC: float = 0.2
const GOODS_NAME_LSTR: Array[String] = ["PARAMETER.SMALL_PLANET_DEBRIS_BOX", "PARAMETER.MEDIUM_STELLAR_SUITCASE", "PARAMETER.LARGE_INTERSTELLAR_GALLERY"]
# 灵魂石 icon（源 :100-102 createIcon(id,45) anchor(0,0) at(0,0)，项目 72px 基准缩放）
const ICON_SIDE: float = 45.0
const ICON_BASE: float = 72.0
const ICON_HOST_SIDE: float = 42.97

var shop_mgr: ShopManager
var pd: PlayerData
var rng: BattleRng
var slot: int
var owner_panel: StarShopPanel
var _frame: Control


func setup_buy(p_mgr: ShopManager, p_pd: PlayerData, p_rng: BattleRng, p_slot: int, p_owner: StarShopPanel) -> void:
	shop_mgr = p_mgr
	pd = p_pd
	rng = p_rng
	slot = p_slot
	owner_panel = p_owner
	setup()
	_build_ui()


func _build_ui() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	_frame = content.get_node("%Frame") as Control
	var goods: Array = shop_mgr.get_star_goods()
	var g: Dictionary = goods[slot]
	# 5. title_1 "确定兑换？"（源 :107 ARE_YOU_SURE_TO_USE_IT）
	(_frame.get_node("%Title1Label") as Label).text = pd.cm.get_lstr("STARSHOPBUYWINDOW.ARE_YOU_SURE_TO_USE_IT")
	# 7. amount_label "x{amount}"（源 :104 AMOUNT）
	(_frame.get_node("%AmountLabel") as Label).text = "x" + str(int(g["stone_amount"]))
	# 8. title_2 "兑换"（源 :171 EXCHANGE）
	(_frame.get_node("%Title2Label") as Label).text = pd.cm.get_lstr("STARSHOPBUYWINDOW.EXCHANGE")
	# 9. name_label 商品名（源 :105 addition.name = getStarGoodsName）
	(_frame.get_node("%NameLabel") as Label).text = pd.cm.get_lstr(GOODS_NAME_LSTR[int(g["type"])])
	# 6. icon_container 灵魂石 icon（源 :99-103 createIcon(id,45)，Equip 缺条目默认降级框）
	var icon := ReadequipIcon.create_icon(int(g.get("stone_id", 0)), 0, pd.cm)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.scale = Vector2.ONE * (ICON_SIDE / ICON_BASE)
	icon.position = Vector2(0.0, ICON_HOST_SIDE - ICON_SIDE)
	(_frame.get_node("%IconContainer") as Control).add_child(icon)
	# 3. cancel_button（源 DGButton → StarShopBuyBtn 三态，text fill）
	var cancel: Button = _frame.get_node("%CancelBtn") as Button
	cancel.text = pd.cm.get_lstr("CHATCONFIG.CANCEL")
	cancel.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_click_feedback")
		remove_window())
	# 4. ok_button（源 DGButton → StarShopBuyBtn 三态，text fill）
	var ok: Button = _frame.get_node("%OkBtn") as Button
	ok.text = pd.cm.get_lstr("CHATCONFIG.CONFIRM")
	ok.pressed.connect(_on_ok)


func show_window(parent: Node) -> void:
	super.show_window(parent)
	_frame.scale = Vector2.ZERO
	var tw: Tween = create_tween()
	tw.tween_property(_frame, "scale", Vector2.ONE, SHOW_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_ok() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var r: Dictionary = shop_mgr.buy_star(slot, pd, rng, pd.cm)
	remove_window()
	if not bool(r.get("ok", false)):
		if bool(r.get("soldout", false)):
			Toast.show_message("已售罄")
		elif bool(r.get("no_resource", false)):
			Toast.show_message("灵魂石不足")
		else:
			Toast.show_message("兑换失败")
		return
	GameData.mark_save_dirty()   # 星商店购买脏标（扣灵魂石+产出，照源商店脏标模式 local_server:1281，60s/退出刷）
	var loots: Array = r["loots"]
	var box: String = String(r.get("box", ""))
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot(loots, pd.cm, box)   # starshop box 不在 BOX_FCA_MAP → FCA 自动降级
	popup.show_window(owner_panel.get_parent())
	Toast.show_message("兑换成功")
	owner_panel._rebuild()   # 刷新商品售罄 + 灵魂石持有量
