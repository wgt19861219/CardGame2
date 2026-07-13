extends GutTest
# SpineSkeletonData 解析测试（Spine 2.1.07 .json）。资源 eff_UI_Main_Shop。

const SPINE_JSON_PATH: String = "res://assets/spine/eff_UI_Main_Shop/eff_UI_Main_Shop.json"


func test_load_json_structure() -> void:
	var d := SpineSkeletonData.new()
	assert_true(d.load_json(SPINE_JSON_PATH), "load .json 成功")
	assert_eq(d.bones.size(), 6, "6 骨骼（root + bone + bone2-5）")
	assert_eq(d.slots.size(), 6, "6 slot")
	assert_true(d.has_action("Loop"), "Loop 动作")
	assert_true(d.has_action("Start"), "Start 动作")


func test_bone_hierarchy_and_setup() -> void:
	var d := SpineSkeletonData.new()
	d.load_json(SPINE_JSON_PATH)
	assert_eq(String(d.bones["root"]["parent"]), "", "root 无 parent")
	assert_eq(String(d.bones["bone"]["parent"]), "root", "bone 父 root")
	assert_eq(String(d.bones["bone2"]["parent"]), "root", "bone2 父 root")
	# root setup scale 0.8（json scaleX/Y 0.8）
	assert_eq(float(d.bones["root"]["scaleX"]), 0.8, "root scaleX 0.8")
	assert_eq(float(d.bones["root"]["scaleY"]), 0.8, "root scaleY 0.8")
	# bone2 setup rotation -90.45（json）
	assert_eq(float(d.bones["bone2"]["rotation"]), -90.45, "bone2 rotation -90.45")


func test_slot_attachment() -> void:
	var d := SpineSkeletonData.new()
	d.load_json(SPINE_JSON_PATH)
	var first_slot: Dictionary = d.slots[0]
	assert_eq(String(first_slot["name"]), "eff_UI_Main_Shop_1", "slot 0 名 _Shop_1")
	assert_eq(String(first_slot["bone"]), "bone2", "slot 0 绑 bone2")
	var att: Dictionary = d.get_attachment("eff_UI_Main_Shop", "eff_UI_Main_Shop")
	assert_eq(float(att.get("width", 0.0)), 188.0, "shop attachment width 188")


func test_color_hex_parse() -> void:
	assert_almost_eq(SpineSkeletonData.parse_color_hex("ffffff32").a, 50.0 / 255.0, 0.001, "alpha 0x32=50/255")
	assert_eq(SpineSkeletonData.parse_color_hex("ff0000ff").r, 1.0, "r 0xff=1.0")
	assert_eq(SpineSkeletonData.parse_color_hex("00ff00ff").g, 1.0, "g 0xff=1.0")
