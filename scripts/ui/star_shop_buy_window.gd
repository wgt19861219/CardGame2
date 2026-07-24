class_name StarShopBuyWindow
extends PopWindow

## 星际商店购买确认弹窗（View 层）— 照源 popwindow/starshopbuywindow.lua。
## 9 节点照源 starshopbuywindow editorui：frame/line/cancel/ok/title_1/icon_container/amount/title_2/name。
## 资源缺降级：tips_frame/tips_delimeter/button_1/2 png 缺（cocos Studio 导出物未含），框/线跳过、按钮文字。
## 入场缩放动画照源 :112-119 show frame setScale(0)→CCScaleTo 0.2 EASEBackOut。
##
## 重构（2026-07-18，hero_detail 范式）：frame/title_1/icon_container/amount/title_2/name/cancel/ok
## 静态化进 scenes/ui/star_shop_buy_window_content.tscn（位置/size 编辑器可视化调）。
## 原 procedural 9 节点位置/size/颜色/字号固化为 .tscn；panel 仅填动态 LSTR 文字 + 连信号。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/star_shop_buy_window_content.tscn")
const SHOW_SEC: float = 0.2   # 源 :116 CCScaleTo 0.2
# 源 getStarGoodsName → parameter.lua:36-38 LSTR key（type 0/1/2 → stone_green/blue/purple）
const GOODS_NAME_LSTR: Array[String] = ["PARAMETER.SMALL_PLANET_DEBRIS_BOX", "PARAMETER.MEDIUM_STELLAR_SUITCASE", "PARAMETER.LARGE_INTERSTELLAR_GALLERY"]

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


# 源 starshopbuywindow.lua:99-110 节点装配：chrome 从 .tscn instantiate（位置/size 固化），fill 动态文字 + 连信号。
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
	# 3. cancel_button（源 DGButton，button png 缺 → 文字 Button）
	var cancel: Button = _frame.get_node("%CancelBtn") as Button
	cancel.text = pd.cm.get_lstr("CHATCONFIG.CANCEL")
	cancel.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_click_feedback")
		remove_window())
	# 4. ok_button（源 DGButton，button png 缺 → 文字 Button）
	var ok: Button = _frame.get_node("%OkBtn") as Button
	ok.text = pd.cm.get_lstr("CHATCONFIG.CONFIRM")
	ok.pressed.connect(_on_ok)


# 源 :112-119 show frame setScale(0)→CCScaleTo 0.2 EASEBackOut
func show_window(parent: Node) -> void:
	super.show_window(parent)
	_frame.scale = Vector2.ZERO
	var tw: Tween = create_tween()
	tw.tween_property(_frame, "scale", Vector2.ONE, SHOW_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# 源 starshopbuywindow.lua:39-78 确认购买流程。
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
