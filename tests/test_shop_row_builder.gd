extends GutTest

## ShopRowBuilder 测试（两件套范式 2026-08-14）— 商品行模板装配 + 徽标/售罄切换。
## 替代 test_shop_builder.gd（ShopBuilder 退役）。源 shop.lua:363-382 getItemPos + createCommon item。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_item(g: Dictionary) -> Control:
	var config: Dictionary = MarketConfig.get_type_config(1)
	return ShopRowBuilder._create_item(g, Vector2.ZERO, config, cm)


func test_template_static_structure() -> void:
	var item: Control = _make_item({"id": 371, "type": "gold", "price": 100, "amount": 1})
	assert_almost_eq(item.size.x, 204.0, 0.5, "行宽 204（shop_product_bg 261/CS）")
	assert_almost_eq(item.size.y, 146.0, 0.5, "行高 146（187/CS）")
	assert_almost_eq(item.pivot_offset.x, item.size.x * 0.5, 0.5, "pivot x 居中（源 shop.lua:198 setScale 0.95 绕中心）")
	assert_almost_eq(item.pivot_offset.y, item.size.y * 0.5, 0.5, "pivot y 居中")
	var bg: TextureRect = item.get_node("%ProductBg") as TextureRect
	assert_true(bg.texture != null, "ProductBg 底图烘在模板（shop_product_bg.png）")
	item.free()


func test_product_bg_per_type_override() -> void:
	var config: Dictionary = MarketConfig.get_type_config(2)
	var item: Control = ShopRowBuilder._create_item({"id": 371, "type": "gold", "price": 1, "amount": 1}, Vector2.ZERO, config, cm)
	var bg: TextureRect = item.get_node("%ProductBg") as TextureRect
	assert_true(bg.texture.resource_path.find("shop_product_bg_2") != -1, "type=2 行底图切 shop_product_bg_2.png（market_config.gd:41）")
	item.free()


func test_item_texts_filled() -> void:
	var item: Control = _make_item({"id": 371, "type": "gold", "price": 100, "amount": 1})
	assert_eq((item.get_node("%PriceLabel") as Label).text, "100", "价格 fill")
	assert_true((item.get_node("%IconHost") as Control).get_child_count() >= 1, "装备图标挂 IconHost")
	# Task 5 二轮：源 createNode 锚点 (0.5,0.5) 中心语义，元素中心 = ccp 源坐标（四锚同点+对称 offsets）。
	add_child(item)
	var price: Label = item.get_node("%PriceLabel") as Label
	assert_almost_eq(price.global_position.x + price.size.x * 0.5, item.global_position.x + 110.0, 1.5, "PriceLabel 中心 x=110（源 costLabel ccp(110,25)→Godot 121）")
	assert_almost_eq(price.global_position.y + price.size.y * 0.5, item.global_position.y + 121.0, 1.5, "PriceLabel 中心 y=121")
	var icon: Control = (item.get_node("%IconHost") as Control).get_child(0) as Control
	assert_almost_eq(icon.global_position.x + icon.size.x * 0.5, item.global_position.x + 100.0, 1.5, "icon 中心 x=100（源 icon ccp(100,75)）")
	assert_almost_eq(icon.global_position.y + icon.size.y * 0.5, item.global_position.y + 71.0, 1.5, "icon 中心 y=71")
	item.free()


# Task 5 三轮：NameLabel/PriceLabel 走 theme variation（源 size 20、name 色 ccc3(69,59,56)、price 白字黑影）。
func test_item_label_variations() -> void:
	var item: Control = _make_item({"id": 371, "type": "gold", "price": 100, "amount": 1})
	assert_eq(String((item.get_node("%NameLabel") as Label).theme_type_variation), "ShopItemNameLabel", "NameLabel 走 ShopItemNameLabel variation")
	assert_eq(String((item.get_node("%PriceLabel") as Label).theme_type_variation), "ShopItemPriceLabel", "PriceLabel 走 ShopItemPriceLabel variation")
	item.free()


func test_sale_badge_visible_when_is_sale() -> void:
	var item: Control = _make_item({"id": 371, "type": "gold", "price": 100, "amount": 1, "is_sale": 1})
	var badge: Label = item.get_node("%SaleBadge") as Label
	assert_true(badge.visible, "is_sale=1 → SALE 徽标显示（源 :468-477）")
	assert_eq(badge.text, "SALE", "SALE 文案")
	item.free()


func test_sale_badge_hidden_when_not_sale() -> void:
	var item: Control = _make_item({"id": 371, "type": "gold", "price": 100, "amount": 1, "is_sale": 0})
	assert_false((item.get_node("%SaleBadge") as Label).visible, "is_sale=0 → 徽标隐藏")
	item.free()


func test_tag_badge_hot_and_old() -> void:
	var hot: Control = _make_item({"id": 371, "type": "gold", "price": 100, "amount": 1, "tag": "hot"})
	assert_eq((hot.get_node("%TagBadge") as Label).text, "NEW", "tag=hot → NEW（shop_new.png 缺 Label 降级）")
	var old: Control = _make_item({"id": 371, "type": "gold", "price": 100, "amount": 1, "tag": "old"})
	assert_eq((old.get_node("%TagBadge") as Label).text, "HOT", "tag=old → HOT（shop_hot.png 缺 Label 降级）")
	hot.free()
	old.free()


func test_tag_badge_hidden_when_invalid_tag() -> void:
	var item: Control = _make_item({"id": 371, "type": "gold", "price": 100, "amount": 1, "tag": "invalid"})
	assert_false((item.get_node("%TagBadge") as Label).visible, "无效 tag → 徽标隐藏")
	item.free()


func test_both_sale_and_tag() -> void:
	var item: Control = _make_item({"id": 371, "type": "gold", "price": 100, "amount": 1, "is_sale": 1, "tag": "hot"})
	assert_true((item.get_node("%SaleBadge") as Label).visible, "sale+tag 同时显示 saleIcon")
	assert_true((item.get_node("%TagBadge") as Label).visible, "sale+tag 同时显示 tagIcon")
	item.free()


func test_soldout_label_and_opacity() -> void:
	var item: Control = _make_item({"id": 371, "type": "gold", "price": 100, "amount": 0})
	assert_true((item.get_node("%SoldoutLabel") as Label).visible, "amount=0 → 售罄显示")
	assert_almost_eq(item.modulate.a, 120.0 / 255.0, 0.01, "售罄行整体半透明（源 shop.lua refreshGoods setOpacity(120)）")
	# 源 :108-125 售罄隐藏 icon/coinIcon/costLabel（name 不隐藏）。
	assert_false((item.get_node("%IconHost") as Control).visible, "售罄隐藏 icon")
	assert_false((item.get_node("%CoinHost") as Control).visible, "售罄隐藏 coinIcon")
	assert_false((item.get_node("%PriceLabel") as Label).visible, "售罄隐藏 costLabel")
	item.free()


func test_tag_fallback_mapping() -> void:
	assert_eq(ShopRowBuilder.TAG_FALLBACK["hot"]["text"], "NEW", "hot→NEW（源 getHotTagRes hot→shop_new.png）")
	assert_eq(ShopRowBuilder.TAG_FALLBACK["old"]["text"], "HOT", "old→HOT（源 getHotTagRes old→shop_hot.png）")


func test_goods_two_rows_layout() -> void:
	var layer := Control.new()
	add_child(layer)
	var goods: Array = [
		{"id": 371, "type": "gold", "price": 1, "amount": 1},
		{"id": 371, "type": "gold", "price": 1, "amount": 1},
		{"id": 371, "type": "gold", "price": 1, "amount": 1},
		{"id": 371, "type": "gold", "price": 1, "amount": 1},
	]
	var items: Array = ShopRowBuilder.build_goods(layer, goods, MarketConfig.get_type_config(1), cm)
	assert_eq(items.size(), 4, "4 商品 4 行")
	assert_almost_eq((items[0] as Control).position.x, 18.0, 0.5, "item0 top-left x=18（to_godot(185,256) 265-102-145 裁剪层原点）")
	assert_almost_eq((items[0] as Control).position.y, 31.0, 0.5, "item0 top-left y=31（304-73-200）")
	assert_almost_eq((items[1] as Control).position.x - (items[0] as Control).position.x, 205.0, 0.5, "上排相邻列 dx=205（源 getItemPos）")
	assert_almost_eq((items[2] as Control).position.y - (items[0] as Control).position.y, 150.0, 0.5, "上排比下排高 dy=150（Godot y-down 上排 y 小，简报原断言符号反）")
	assert_eq(int((items[0] as Control).get_meta(&"shop_slot", -1)), 0, "shop_slot meta 标记（panel 连信号用）")
	layer.free()
