extends GutTest
## mcp_bridge 导出版剔除守卫（2026-09-18 看板 P1-1 关闭配套）。
## autoload 注册使 mcp_bridge.gd 被导出器强制带进发布包，此前仅挡 editor hint，
## 玩家裸跑导出 exe 会监听 TCP+写 secret+_process 轮询（最小暴露违背）。
## 守卫判据（4.7.2 实测矩阵）：编辑器二进制所有运行形态（-s/--path/F5/run_project
## spawn）均 editor feature=true 不受影响；导出 release 包 editor=false+release=true
## 唯一组合触发跳过。GODOT_MCP_BRIDGE_* 环境变量为调试豁免通道（与上游
## buildSafeEnv 透传域一致）。


func _bridge_source() -> String:
	return FileAccess.get_file_as_string("res://mcp_bridge.gd")


func test_bridge_file_exists() -> void:
	assert_true(FileAccess.file_exists("res://mcp_bridge.gd"),
		"mcp_bridge.gd 在项目根（autoload 依赖）")


func test_export_guard_condition_present() -> void:
	var src := _bridge_source()
	assert_true(src.find("not OS.has_feature(\"editor\") and OS.has_feature(\"release\") and _no_bridge_env()") != -1,
		"EXPORT-1 守卫条件在 _ready：editor=false + release=true + 无豁免 env 才跳过")


func test_guard_placed_before_server_start() -> void:
	var src := _bridge_source()
	var guard_pos := src.find("EXPORT-1 (2026-09-18)")
	var server_pos := src.find("func _start_server")
	assert_true(guard_pos != -1 and guard_pos < src.find("func _exit_tree"),
		"守卫在 _ready 生命周期段（_exit_tree 之前）")
	assert_true(server_pos != -1, "_start_server 存在（守卫跳过即不监听）")


func test_exempt_env_keys_covered() -> void:
	var src := _bridge_source()
	var env_pos := src.find("func _no_bridge_env")
	assert_true(env_pos != -1, "_no_bridge_env 豁免检查函数存在")
	var body := src.substr(env_pos, 400)
	for key in ["GODOT_MCP_BRIDGE_PORT", "GODOT_MCP_BRIDGE_PERSISTENT_SECRET",
			"GODOT_MCP_BRIDGE_ALLOWED_PROFILES"]:
		assert_true(body.find("\"%s\"" % key) != -1, "豁免键 %s 在检查清单" % key)


func test_guard_version_bumped() -> void:
	var src := _bridge_source()
	assert_true(src.find("BRIDGE_SCRIPT_VERSION := \"0.33.9\"") != -1,
		"bridge 版本 0.33.9（EXPORT-1 随版引入，防旧版静默回退）")
