extends GutTest
# 打击音映射（设计文档 2.1）：eff_impact_X.cha / eff_point_X.cha → sound/sound_X.mp3。
# 源走 Puppet 时间轴 PlaySound（数据缺失），Godot 用 Impact/Point Effect 字段重建（受控偏离三-1）。
# 拼写差异：特效表 lightning / 音效文件 lightening（唯一别名）。

const RendererScript = preload("res://scripts/view/battle/battle_event_renderer.gd")


func test_effect_to_sfx_rel_basic_impact() -> void:
	assert_eq(RendererScript.effect_to_sfx_rel("eff_impact_burn.cha"),
		"sound/sound_eff_impact_burn.mp3", "burn 基础映射")


func test_effect_to_sfx_rel_lightning_alias() -> void:
	assert_eq(RendererScript.effect_to_sfx_rel("eff_impact_lightning.cha"),
		"sound/sound_eff_impact_lightening.mp3", "lightning→lightening 唯一拼写别名")


func test_effect_to_sfx_rel_point_series() -> void:
	assert_eq(RendererScript.effect_to_sfx_rel("eff_point_EM_atk4.cha"),
		"sound/sound_eff_point_EM_atk4.mp3", "point 系列（二审 M-A：PLAY_EFFECT 通道）")


func test_effect_to_sfx_rel_empty() -> void:
	assert_eq(RendererScript.effect_to_sfx_rel(""), "", "空特效名返回空")


func test_mapped_sfx_files_exist() -> void:
	# 有音效文件的代表集（17 个 sound_eff_* 实测存在；断言映射产物落盘有效）
	var samples: Array[String] = [
		"eff_impact_burn.cha", "eff_impact_slash.cha", "eff_impact_crush.cha",
		"eff_impact_lightning.cha", "eff_impact_CM_atk.cha", "eff_impact_Zeus_ult.cha",
		"eff_point_EM_atk4.cha",
	]
	for fx in samples:
		var rel: String = RendererScript.effect_to_sfx_rel(fx)
		assert_true(ResourceLoader.exists("res://assets/" + rel),
			"映射产物文件存在: %s → %s" % [fx, rel])


func test_renderer_wires_both_branches() -> void:
	# 守卫断言（项目 grep 断言先例）：两分支都接线（二审 M-A：point 走 PLAY_EFFECT）。
	# case 体缩进为 3 tab（与文件现状一致，勿用 2 tab 匹配）。
	var src := FileAccess.get_file_as_string("res://scripts/view/battle/battle_event_renderer.gd")
	assert_true(src.contains("_play_effect_sound(e.text)"), "renderer 分支调用打击音")
	assert_eq(src.count("\t\t\t_play_effect_sound(e.text)"), 2, "ADD_EFFECT 与 PLAY_EFFECT 双分支都接")
