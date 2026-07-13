class_name StarShopBuyWindow
extends PopWindow

## 星际商店购买确认弹窗（View 层）— 照源 popwindow/starshopbuywindow.lua。
## 9 节点照源 starshopbuywindow editorui：frame/line/cancel/ok/title_1/icon_container/amount/title_2/name。
## 资源缺降级：tips_frame/tips_delimeter/button_1/2 png 缺（cocos Studio 导出物未含），框/线跳过、按钮文字。
## 入场缩放动画照源 :112-119 show frame setScale(0)→CCScaleTo 0.2 EASEBackOut。

const FRAME_POS: Vector2 = Vector2(246.0, 180.0)
const FRAME_SIZE: Vector2 = Vector2(466.0, 290.0)
# 源 starshopbuywindow 节点坐标（cocos anchor→Godot 左上，frame 466×290）
const LINE_POS: Vector2 = Vector2(28.0, 184.0)         # line a0.5 (230,102) 405×8
const LINE_SIZE: Vector2 = Vector2(405.0, 8.0)
const CANCEL_BTN_POS: Vector2 = Vector2(81.0, 196.0)   # cancel_button a0.5 (141,67)
const OK_BTN_POS: Vector2 = Vector2(248.0, 199.0)      # ok_button a0.5 (308,64)
const BTN_SIZE: Vector2 = Vector2(120.0, 54.0)
const TITLE_1_POS: Vector2 = Vector2(190.0, 130.0)     # title_1 a0.5 (240,140)
const TITLE_1_SIZE: Vector2 = Vector2(100.0, 22.0)
const ICON_CONTAINER_POS: Vector2 = Vector2(180.0, 92.0)  # icon_container a0,0 (180,155)
const ICON_CONTAINER_SIZE: Vector2 = Vector2(43.0, 43.0)
const AMOUNT_POS: Vector2 = Vector2(240.0, 90.0)       # amount_label a0,0.5 (240,180)
const TITLE_2_POS: Vector2 = Vector2(120.0, 200.0)     # title_2 a0.5 (140,220)
const TITLE_2_SIZE: Vector2 = Vector2(40.0, 22.0)
const NAME_LABEL_POS: Vector2 = Vector2(186.0, 90.0)   # name_label a0,0.5 (186,220)
const TITLE_COLOR: Color = Color(129.0 / 255.0, 204.0 / 255.0, 255.0 / 255.0)
const VALUE_COLOR: Color = Color(131.0 / 255.0, 240.0 / 255.0, 255.0 / 255.0)
const LABEL_FONT_SIZE: int = 20
const SHOW_SEC: float = 0.2   # 源 :116 CCScaleTo 0.2
const UI_DIR: String = "res://assets/ui/alpha/HVGA/"
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


func _build_ui() -> void:
	_frame = Control.new()
	_frame.position = FRAME_POS
	_frame.size = FRAME_SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP   # 框区域吞外击（源 out_frame clickHandler destroy）
	container.add_child(_frame)
	# 1. frame 图（tips_frame 缺 → ResourceLoader 守卫跳过，容器仍在）
	_add_texture(_frame, UI_DIR + "shop_star_tips_frame.png", Vector2.ZERO, FRAME_SIZE)
	# 2. line 分隔线（tips_delimeter 缺 → 跳过）
	_add_texture(_frame, UI_DIR + "shop_star_tips_delimeter.png", LINE_POS, LINE_SIZE)
	var goods: Array = shop_mgr.get_star_goods()
	var g: Dictionary = goods[slot]
	# 5. title_1 "确定兑换？"（源 :107 ARE_YOU_SURE_TO_USE_IT）
	var title_1 := Label.new()
	title_1.text = pd.cm.get_lstr("STARSHOPBUYWINDOW.ARE_YOU_SURE_TO_USE_IT")
	title_1.position = TITLE_1_POS
	title_1.size = TITLE_1_SIZE
	title_1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_1.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	title_1.modulate = TITLE_COLOR
	_frame.add_child(title_1)
	# 6. icon_container（源 :99-103 createIcon(payid,45)；Equip 无灵魂石 8/9/10 → 留空容器降级）
	var icon_container := Control.new()
	icon_container.position = ICON_CONTAINER_POS
	icon_container.size = ICON_CONTAINER_SIZE
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(icon_container)
	# 7. amount_label "x{amount}"（源 :104 AMOUNT）
	var amount_label := Label.new()
	amount_label.text = "x" + str(int(g["stone_amount"]))
	amount_label.position = AMOUNT_POS
	amount_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	amount_label.modulate = VALUE_COLOR
	_frame.add_child(amount_label)
	# 8. title_2 "兑换"（源 :171 EXCHANGE）
	var title_2 := Label.new()
	title_2.text = pd.cm.get_lstr("STARSHOPBUYWINDOW.EXCHANGE")
	title_2.position = TITLE_2_POS
	title_2.size = TITLE_2_SIZE
	title_2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_2.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	title_2.modulate = TITLE_COLOR
	_frame.add_child(title_2)
	# 9. name_label 商品名（源 :105 addition.name = getStarGoodsName）
	var name_label := Label.new()
	name_label.text = pd.cm.get_lstr(GOODS_NAME_LSTR[int(g["type"])])
	name_label.position = NAME_LABEL_POS
	name_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	name_label.modulate = VALUE_COLOR
	_frame.add_child(name_label)
	# 3. cancel_button（源 DGButton，button png 缺 → 文字 Button）
	var cancel := Button.new()
	cancel.text = pd.cm.get_lstr("CHATCONFIG.CANCEL")
	cancel.position = CANCEL_BTN_POS
	cancel.size = BTN_SIZE
	cancel.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_click_feedback")
		remove_window())
	_frame.add_child(cancel)
	# 4. ok_button（源 DGButton，button png 缺 → 文字 Button）
	var ok := Button.new()
	ok.text = pd.cm.get_lstr("CHATCONFIG.CONFIRM")
	ok.position = OK_BTN_POS
	ok.size = BTN_SIZE
	ok.pressed.connect(_on_ok)
	_frame.add_child(ok)


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
	var loots: Array = r["loots"]
	var box: String = String(r.get("box", ""))
	var popup := PopTavernLoot.new("poptavernloot", {})
	popup.setup_loot(loots, pd.cm, box)   # starshop box 不在 BOX_FCA_MAP → FCA 自动降级
	popup.show_window(owner_panel.get_parent())
	Toast.show_message("兑换成功")
	owner_panel._rebuild()   # 刷新商品售罄 + 灵魂石持有量


func _add_texture(parent: Control, path: String, pos: Vector2, sz: Vector2) -> void:
	if not ResourceLoader.exists(path):
		return
	var tr := TextureRect.new()
	tr.position = pos
	tr.size = sz
	tr.texture = load(path)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parent.add_child(tr)
