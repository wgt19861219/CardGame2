extends GutTest
# BaseresData 装备属性显示数据 + ReadequipData.get_att_list 测试（照源 baseres.lua + readequip.lua:48）。
# P1-11 属性四列数据层。

func test_att_name_has_21_keys() -> void:
	assert_eq(BaseresData.ATT_NAME.size(), 21, "att_name 21 属性 key（源 baseres.lua:5-27）")
	assert_true(BaseresData.ATT_NAME.has("AD"), "含 AD 物攻")
	assert_true(BaseresData.ATT_NAME.has("AP"), "含 AP 法强")
	assert_true(BaseresData.ATT_NAME.has("ARM"), "含 ARM 护甲")
	assert_true(BaseresData.ATT_NAME.has("HP"), "含 HP 生命")


func test_get_att_pre_uses_lstr() -> void:
	var cm := ConfigManager.new()
	cm.load_all()
	# AD → BASERES.PHYSICAL_ATTACK_ → LSTR 解析 "物理攻击力"
	assert_eq(BaseresData.get_att_pre("AD", cm), "物理攻击力", "AD 前缀 = 物理攻击力")
	assert_eq(BaseresData.get_att_pre("STR", cm), "力量", "STR 前缀 = 力量")


func test_get_att_suffix_literal() -> void:
	assert_eq(BaseresData.get_att_suffix("CDR"), "%", "CDR 后缀 %")
	assert_eq(BaseresData.get_att_suffix("HEAL"), "%", "HEAL 后缀 %")
	assert_eq(BaseresData.get_att_suffix("ARMP"), "", "ARMP 后缀空")
	assert_eq(BaseresData.get_att_suffix("MRI"), "", "MRI 后缀空")


# 源 readequip.getAttList :48-59：遍历 att_name，Equip 表基础属性 !=0。
func test_get_att_list_keys_subset_of_att_name() -> void:
	var cm := ConfigManager.new()
	cm.load_all()
	for id in [1, 2, 3]:
		var att: Dictionary = ReadequipData.get_att_list(id, cm)
		assert_true(att is Dictionary, "get_att_list 返 Dictionary 不崩（id=%d）" % id)
		for key in att:
			assert_true(BaseresData.ATT_NAME.has(key), "att key %s 应在 ATT_NAME（id=%d）" % [key, id])
			assert_true(float(att[key]) != 0.0, "att 值非 0（id=%d key=%s）" % [id, key])
