extends GutTest
# Phase 6 ReadequipIcon 魂石标签 + 可合成角标测试（2026-07-05 第 28 段）。
# 照源 readequip.lua createHeroStone :571-602 + createIconWithTag :841-876。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 找一个 Fragment 表条目（tid → {Fragment ID, Fragment Count}）。
func _find_fragment_entry() -> Dictionary:
	var frag: Dictionary = cm.get_raw_table(&"Fragment")
	for tid_str in frag:
		var row: Dictionary = frag[tid_str]
		var fid: int = int(row.get("Fragment ID", 0))
		var need: int = int(row.get("Fragment Count", 0))
		if fid > 0 and need > 0:
			return {"tid": int(tid_str), "frag_id": fid, "need": need}
	return {}


func _has_child_with_texture(node: Control, tex_name: String) -> bool:
	for c in node.get_children():
		if c is Sprite2D:
			var tex: Texture2D = (c as Sprite2D).texture
			if tex != null and tex.resource_path.find(tex_name) >= 0:
				return true
	return false


func test_create_hero_stone_icon_builds() -> void:
	var entry: Dictionary = _find_fragment_entry()
	assert_gt(int(entry.get("frag_id", 0)), 0, "存在 Fragment 表条目")
	var icon: Control = ReadequipIcon.create_hero_stone_icon(int(entry["frag_id"]), 5, cm)
	assert_gt(icon.get_child_count(), 0, "魂石图标含子件")
	assert_true(_has_child_with_texture(icon, "equip_soulstone_tag"), "含 equip_soulstone_tag 魂石标签")


func test_create_icon_with_tag_tick_when_composable() -> void:
	var entry: Dictionary = _find_fragment_entry()
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_fragment(int(entry["frag_id"]), int(entry["need"]))   # 持有=need → 可合成
	var icon: Control = ReadequipIcon.create_icon_with_tag(int(entry["tid"]), int(entry["need"]), cm, pd)
	assert_true(_has_child_with_texture(icon, "fragment_tick"), "持有>=need 且未拥有英雄 → 含 fragment_tick")


func test_create_icon_with_tag_no_tick_when_owned_hero() -> void:
	var entry: Dictionary = _find_fragment_entry()
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_fragment(int(entry["frag_id"]), int(entry["need"]))
	pd.hero_manager.add_hero(int(entry["tid"]))   # 已拥有英雄 → is_fragment_composable false
	var icon: Control = ReadequipIcon.create_icon_with_tag(int(entry["tid"]), int(entry["need"]), cm, pd)
	assert_false(_has_child_with_texture(icon, "fragment_tick"), "已拥有英雄不加 tick")


func test_create_icon_with_tag_no_tick_when_insufficient() -> void:
	var entry: Dictionary = _find_fragment_entry()
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_fragment(int(entry["frag_id"]), 1)   # 持有<need → 不可合成
	var icon: Control = ReadequipIcon.create_icon_with_tag(int(entry["tid"]), 1, cm, pd)
	assert_false(_has_child_with_texture(icon, "fragment_tick"), "持有不足不加 tick")
