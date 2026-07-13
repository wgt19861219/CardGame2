extends GutTest
# Phase 7 StatusBar 测试（2026-07-02）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_setup_and_refresh() -> void:
	var bar := StatusBar.new()
	add_child(bar)
	var pd := PlayerData.new(cm)
	pd.diamond = 999
	pd.vitality = 50
	pd.team_level = 5
	bar.setup(pd)
	# 5 labels（diamond/vitality/team_level/vip + 远征进度）
	assert_eq(bar.get_child_count(), 5, "4 状态 Label + 远征进度")
	var lbl: Label = bar.get_child(0)
	assert_eq(lbl.text, "diamond: 999", "refresh 显 diamond")
	bar.queue_free()
