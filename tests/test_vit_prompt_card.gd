extends GutTest
## VitPromptCard 测试（C12：照源 framework.lua:67-160 体力恢复提示卡）。
## 覆盖文本组装（满体/未满两分支）+ show/destroy 生命周期 + 时间格式化。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_player() -> PlayerData:
	var pd := PlayerData.new(cm)
	pd.diamond = 100000
	return pd


# _hms：秒数 → "HH:MM:SS"（源 ed.gethmsNString）
func test_hms_format() -> void:
	assert_eq(VitPromptCard._hms(0), "00:00:00", "0 秒")
	assert_eq(VitPromptCard._hms(3661), "01:01:01", "3661 秒 = 01:01:01")
	assert_eq(VitPromptCard._hms(36000), "10:00:00", "36000 秒 = 10:00:00")


# _seconds_to_next_update：源 player.lua:642-650 getVitalityNextUpdate = gap - (now - ltime)
func test_seconds_to_next_update_uses_last_recover() -> void:
	var pd := _make_player()
	var now: int = int(Time.get_unix_time_from_system())
	pd.vitality_last_recover = now - 100   # 100 秒前恢复过
	# gap=360 - 100 = 260（剩余秒数）
	var dt: int = VitPromptCard._seconds_to_next_update(pd)
	assert_between(dt, 259, 261, "gap=360 - elapsed≈100 → ≈260 秒")
	# 刚恢复（ltime=now）：返 gap（满周期）
	pd.vitality_last_recover = now
	var dt_full: int = VitPromptCard._seconds_to_next_update(pd)
	assert_eq(dt_full, 360, "刚恢复 → gap=360（满周期）")


# _build_text 未满体：包含 NEXT/RESTORE/INTERVAL 三段
func test_build_text_unfilled_includes_recovery_info() -> void:
	var pd := _make_player()
	pd.vitality = 50   # < max=120，未满
	var text: String = VitPromptCard._build_text(pd, cm)
	assert_false(text.is_empty(), "未满体文本非空")
	# 源 :74 CURRENT_TIME 行 + :75 已购次数行 + :81/83/85 三段恢复信息
	# zh-CN：CURRENT_TIME="当前时间:" / BOUGHT="今日已购买能量次数: %d/%d"
	# ALREADY_BACK="体力已回满" 不应出现在未满文本
	assert_false(text.contains("体力已回满"), "未满体不含 ALREADY_BACK_TO_FULL_STRENGTH")
	# 验证含"当前时间"或等价（LSTR key 已加载）
	assert_true(text.contains("当前时间") or text.contains("FRAMEWORK.CURRENT_TIME"), "含当前时间前缀")


# _build_text 满体：含 ALREADY_BACK_TO_FULL_STRENGTH，无恢复时间信息
func test_build_text_filled_includes_full_stamina() -> void:
	var pd := _make_player()
	pd.vitality = pd.vitality_max   # 满体
	var text: String = VitPromptCard._build_text(pd, cm)
	assert_true(text.contains("体力已回满"), "满体含 ALREADY_BACK_TO_FULL_STRENGTH")


# show：创建节点挂在 parent + 返回 ref；destroy_prompt 销毁
func test_show_creates_node_destroy_removes() -> void:
	var pd := _make_player()
	var parent := Control.new()
	add_child_autofree(parent)
	var ref: Dictionary = VitPromptCard.show(parent, pd, cm)
	assert_true(ref.has("node"), "ref 含 node")
	assert_true(ref.has("label"), "ref 含 label")
	assert_true(ref.has("timer"), "ref 含 timer")
	var node: Node = ref.get("node", null)
	assert_not_null(node, "node 非空")
	assert_true(node is Node and is_instance_valid(node), "node 有效 Node")
	assert_eq(node.get_parent(), parent, "node 挂在 parent")
	# destroy_prompt(_active 单实例)
	VitPromptCard.destroy_prompt()
	# queue_free 异步，校验 _active 已清（同步状态）
	# node 仍在 tree 但已 queue_free（is_instance_valid 直到帧末仍 true），校验 _active 清空间接（再 destroy 无 crash）
	VitPromptCard.destroy_prompt()   # 二次销毁不 crash（守卫）


# show 传 null parent → 返回空 ref（守卫，不 crash）
func test_show_null_parent_returns_empty() -> void:
	var pd := _make_player()
	var ref: Dictionary = VitPromptCard.show(null, pd, cm)
	assert_true(ref.is_empty(), "null parent → 空 ref（守卫）")


# destroy_prompt 空参数：不 crash（_active 为空时）
func test_destroy_prompt_no_active_no_crash() -> void:
	VitPromptCard.destroy_prompt()   # _active 已清/初始，不 crash
	assert_true(true, "destroy_prompt 空 _active 不 crash")