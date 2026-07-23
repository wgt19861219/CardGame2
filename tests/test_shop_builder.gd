extends GutTest

## ShopBuilder 测试（C7 2026-07-23）— 照源 shop.lua:468-486 saleIcon + tagIcon。
## 源 createCommon item：sale==1 → saleIcon at ccp(75,50)；tagRes 非空 → tagIcon at ccp(55,55)。
## 修复前 ShopBuilder._create_item 只加 noneTag；照源补 saleIcon（shop_sale_6.png）+ tagIcon。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 构造商品 dict + _create_item（static private 可直调，GDScript 无强私有）
func _make_item(g: Dictionary) -> Control:
	var config: Dictionary = MarketConfig.get_type_config(1)
	return ShopBuilder._create_item(g, Vector2.ZERO, config, cm)


# C7 资源缺 Label 降级（shop_sale_6.png / shop_new.png / shop_hot.png 源+本项目均缺）
# 双路径断言：查 TextureRect by suffix 或 Label by text。
func _has_marker(node: Node, tex_suffix: String, label_text: String) -> bool:
	if node is TextureRect and node.texture != null:
		if tex_suffix != "" and node.texture.resource_path.findn(tex_suffix) >= 0:
			return true
	if node is Label and label_text != "" and String(node.text) == label_text:
		return true
	for c in node.get_children():
		if _has_marker(c, tex_suffix, label_text):
			return true
	return false


# C7：is_sale==1 → saleIcon（资源缺 → "SALE" Label 降级；源 marketconfig.lua:4 scaleIcon）
func test_sale_icon_assembled_when_is_sale() -> void:
	var item: Control = _make_item({
		"id": 371, "type": "gold", "price": 100, "amount": 1, "is_sale": 1,
	})
	assert_true(_has_marker(item, "shop_sale_6", "SALE"), "is_sale=1 装配 saleIcon 或 SALE Label（源 :468-477）")
	item.free()


# C7：is_sale=0/缺 → 不装配 saleIcon
func test_no_sale_icon_when_not_sale() -> void:
	var item: Control = _make_item({
		"id": 371, "type": "gold", "price": 100, "amount": 1, "is_sale": 0,
	})
	assert_false(_has_marker(item, "shop_sale_6", "SALE"), "is_sale=0 不装配 saleIcon")
	item.free()


# C7：tag=hot → tagIcon（资源缺 → "NEW" Label 降级；源 getHotTagRes hot→shop_new.png）
func test_tag_icon_hot() -> void:
	var item: Control = _make_item({
		"id": 371, "type": "gold", "price": 100, "amount": 1, "tag": "hot",
	})
	assert_true(_has_marker(item, "shop_new.png", "NEW"), "tag=hot 装配 shop_new 或 NEW Label（源 :479-487）")
	item.free()


# C7：tag=old → tagIcon（资源缺 → "HOT" Label 降级；源 getHotTagRes old→shop_hot.png）
func test_tag_icon_old() -> void:
	var item: Control = _make_item({
		"id": 371, "type": "gold", "price": 100, "amount": 1, "tag": "old",
	})
	assert_true(_has_marker(item, "shop_hot.png", "HOT"), "tag=old 装配 shop_hot 或 HOT Label（源 :479-487）")
	item.free()


# C7：tag 缺/无效 → 不装配 tagIcon
func test_no_tag_icon_when_invalid_tag() -> void:
	var item: Control = _make_item({
		"id": 371, "type": "gold", "price": 100, "amount": 1, "tag": "invalid",
	})
	assert_false(_has_marker(item, "shop_new.png", "NEW"), "无效 tag 不装配 hot 标")
	assert_false(_has_marker(item, "shop_hot.png", "HOT"), "无效 tag 不装配 old 标")
	item.free()


# C7：sale + tag 同时存在 → 两图标都装配（源顺序 saleIcon→tagIcon）
func test_both_sale_and_tag_icons() -> void:
	var item: Control = _make_item({
		"id": 371, "type": "gold", "price": 100, "amount": 1, "is_sale": 1, "tag": "hot",
	})
	assert_true(_has_marker(item, "shop_sale_6", "SALE"), "sale=1 + tag=hot 同时装配 saleIcon")
	assert_true(_has_marker(item, "shop_new.png", "NEW"), "sale=1 + tag=hot 同时装配 tagIcon")
	item.free()


# _get_tag_icon 直接测（源 marketconfig.lua:288-293 getHotTagRes 映射）
func test_get_tag_icon_mapping() -> void:
	assert_eq(ShopBuilder._get_tag_icon("hot"), "shop_new.png", "hot→shop_new.png")
	assert_eq(ShopBuilder._get_tag_icon("old"), "shop_hot.png", "old→shop_hot.png")
	assert_eq(ShopBuilder._get_tag_icon(""), "", "空 tag 返空")
	assert_eq(ShopBuilder._get_tag_icon("invalid"), "", "无效 tag 返空")
