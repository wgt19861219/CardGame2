extends Node

## 一次性取证：魂匣表驱动产出端到端（2026-09-16 重建后实测）。
## 打开 tavern → 切 MagicSoul → dump 热点 ids + 抽一次十连 dump loots +
## 交叉验证：整卡=ids[0]（本周英雄）、每位魂石 Fragment 反查英雄 ∈ ids[1..3]（今日热点）。

func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	pd.tutorial_manager.skip_all()
	pd.diamond = 100000
	await get_tree().create_timer(1.0).timeout
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, BattleRng.new(7))
	panel.show_window(get_tree().current_scene)
	panel._select_pool("MagicSoul")
	await get_tree().create_timer(0.3).timeout
	var ids: Array[int] = TavernData.ask_magicsoul(BattleRng.new(7), pd.cm)
	print("QA_FLOW 热点 ids=", ids)
	var r: Dictionary = pd.draw_tavern_full("MagicSoul", true, false, 0, BattleRng.new(5))
	print("QA_FLOW draw ok=", r["ok"], " loots=", r["loots"])
	var week_in: bool = false
	var soul_hit: bool = true
	var frag: Dictionary = pd.cm.get_raw_table("Fragment")
	for loot in r["loots"]:
		var lid: int = int(loot["id"])
		if lid == ids[0]:
			week_in = true
		elif lid >= 100:
			var hero_of: int = 0
			for tid in frag:
				if int(frag[tid].get("Fragment ID", 0)) == lid:
					hero_of = int(tid)
					break
			if not ids.slice(1, 4).has(hero_of):
				soul_hit = false
				print("QA_FLOW 魂石 ", lid, " 反查英雄 ", hero_of, " 不在今日热点 ", ids.slice(1, 4))
	print("QA_FLOW week_hero_in_loots=", week_in, " souls_map_day_hotspot=", soul_hit)
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://qa_shots/")
	img.save_png("user://qa_shots/tavern_magic_flow.png")
	print("QA_FLOW shot ok")
