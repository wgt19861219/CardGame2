extends GutTest
# ConfigManager 单测：真实加载 resources/data/*.json + typed 访问 + 类型规范化 + 缺失处理。

var _cm: ConfigManager

func before_all() -> void:
	_cm = ConfigManager.new()
	_cm.load_all("res://resources/data/")

func test_core_tables_loaded() -> void:
	assert_true(_cm.has_table(&"Unit"), "Unit 表应加载")
	assert_true(_cm.has_table(&"Skill"), "Skill 表应加载")
	assert_true(_cm.has_table(&"Equip"), "Equip 表应加载")
	assert_true(_cm.has_table(&"HeroStars"), "HeroStars 表应加载")

func test_table_count() -> void:
	assert_gt(_cm.get_table_names().size(), 40, "应加载至少 40 张表")

func test_has_entry() -> void:
	assert_true(_cm.has_entry(&"HeroStars", 1), "HeroStars id 1 应存在")
	assert_false(_cm.has_entry(&"HeroStars", 999), "HeroStars id 999 应不存在")

func test_get_int_normalizes_float() -> void:
	# JSON.parse_string 把整数解析成 float；get_int 应规范化回 int
	var stars := _cm.get_int(&"HeroStars", 1, &"Stars")
	assert_eq(typeof(stars), TYPE_INT, "get_int 必须返回 int（治 float→int 坑）")
	assert_eq(stars, 1)

func test_get_int_large_value() -> void:
	assert_eq(_cm.get_int(&"HeroStars", 5, &"Upgrade Price"), 800000)

func test_get_string_unit_art() -> void:
	var art := _cm.get_string(&"Unit", 1, &"Art")
	assert_true(art.contains("card_bg_big_1"), "Unit 1 的 Art 应含资源名")

func test_missing_entry_returns_empty() -> void:
	assert_eq(_cm.get_entry(&"HeroStars", 999), {}, "缺失 id 返回空字典（不崩溃）")
	assert_push_error("配置缺失", "缺失 id 应触发 push_error 且不崩溃")

func test_missing_field_returns_default() -> void:
	assert_eq(_cm.get_int(&"HeroStars", 1, &"NonexistentField"), 0, "缺失字段返回默认 0")
	assert_push_error("字段缺失", "缺失字段应触发 push_error 且返回默认")
