extends Node
## qa_summon_visual：召唤动画链实机视觉取证（2026-09-09）。
## 零污染：内存 HeroManager 造 tid=41（不进 GameData、不 mark_dirty），
## 独立弹两环（HeroAwakePanel 卡展示 + GetNewHeroPopup 新英雄展示）供 bridge 截图。
## 流程：卡显示后停 8s（拍第一窗）→ 模拟点击 → getNewHero 停住（拍第二窗）。

func _ready() -> void:
	await get_tree().create_timer(1.5).timeout   # 等 GameData/主场景就绪
	var cm: ConfigManager = GameData.player.cm
	var mgr := HeroManager.new(cm)
	var inst_id: int = mgr.add_hero(41)
	var hero: HeroInstance = mgr.get_hero(inst_id)
	var card := HeroAwakePanel.new("popherocard", {})
	card.setup_awake(hero, cm)
	card.show_window(get_tree().root)
	print("QA_SUMMON card_shown tid=41")
	await get_tree().create_timer(25.0).timeout   # 拍照窗口①（bg fade 0.4+light+卡 fade+FCA；25s 防启动延迟错过）
	card._on_click_layer()
	print("QA_SUMMON card_clicked")
	var popup := GetNewHeroPopup.new("getnewhero", {})
	popup.setup_popup(41, cm)
	popup.show_window(get_tree().root)
	print("QA_SUMMON newhero_shown")
	# 停住供拍照窗口②（light 旋转中/立绘展示）
