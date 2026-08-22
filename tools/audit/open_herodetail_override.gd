extends Node

## 调试 override：运行时直开英雄详情面板（viewport 溢出专项认证截图用，无文件写入）。
## 队伍第一个英雄，挂当前场景。若已有面板先移除。

func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	var scene := get_tree().current_scene
	if scene == null:
		return
	for c in scene.get_children():
		if c.name == "DebugHeroDetail":
			c.queue_free()
	var pd: Variant = GameData.player
	var hero: Variant = pd.hero_manager.get_hero(pd.team[0]) if pd.team.size() > 0 else null
	if hero == null:
		print("[OVR] no hero in team")
		return
	var panel := HeroDetailPanel.new("herodetail", {})
	panel.name = "DebugHeroDetail"
	panel.setup_panel(hero, pd.cm, pd.hero_manager, pd)
	scene.add_child(panel)
	print("[OVR] hero_detail opened for ", hero)
