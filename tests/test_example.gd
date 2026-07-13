extends GutTest
# GUT 冒烟测试：验证 headless CI 流程（先 import 再 gut_cmdln）跑通。
# P2-GUT-2：从纯 assert_true(true) 占位升级为真实链路冒烟（验证 ConfigManager 可加载，
# 覆盖 GUT 框架 + autoload class_name 解析 + JSON 加载完整 CI 链路）。

func test_gut_assertion_basics() -> void:
	# GUT 核心断言能力（保留冒烟，验证框架本身工作）
	assert_true(true, "true 必须成立")
	assert_eq(1 + 1, 2, "1 + 1 应等于 2")

func test_ci_smoke_config_manager_loads() -> void:
	# 真实 CI 链路冒烟：ConfigManager 加载 + class_name 解析 + JSON 读取
	# （证明 headless --import 注册了 class_name，GUT 能访问 autoload 类）
	var cm := ConfigManager.new()
	cm.load_all()
	assert_gt(cm.get_raw_table("Stage").size(), 0, "ConfigManager 应加载 Stage 表（CI 链路完整）")
	assert_gt(cm.get_raw_table("Unit").size(), 0, "ConfigManager 应加载 Unit 表")
