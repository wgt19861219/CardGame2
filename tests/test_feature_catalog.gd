extends GutTest
# FeatureCatalog 单测：功能清单完整性 + 域查询 + handler 覆盖。

func test_domains_present() -> void:
	var catalog := FeatureCatalog.new()
	var domains := catalog.get_domains()
	assert_true(domains.has("battle"), "应含战斗域")
	assert_true(domains.has("hero"), "应含英雄域")
	assert_true(domains.has("equip"), "应含装备域")
	assert_true(domains.has("gacha"), "应含抽卡域")

func test_handler_count_matches_sum() -> void:
	var catalog := FeatureCatalog.new()
	var total: int = 0
	for domain in catalog.get_domains():
		total += catalog.get_handlers(domain).size()
	assert_eq(catalog.handler_count(), total, "handler 总数应等于各域之和")

func test_battle_handlers_include_core() -> void:
	var catalog := FeatureCatalog.new()
	var battle := catalog.get_handlers("battle")
	assert_true(battle.has("enter_stage"), "战斗域含进入关卡")
	assert_true(battle.has("tbc"), "战斗域含远征")
	assert_true(battle.has("ladder"), "战斗域含竞技场")
	assert_true(battle.has("excavate"), "战斗域含挖矿")

func test_unknown_domain_returns_empty() -> void:
	var catalog := FeatureCatalog.new()
	assert_eq(catalog.get_handlers("nonexistent").size(), 0, "未知域返回空")

func test_singleplayer_skips_multiplayer() -> void:
	# 单机版跳过的域不应出现在 DOMAINS
	var catalog := FeatureCatalog.new()
	var domains := catalog.get_domains()
	assert_false(domains.has("social"), "单机版跳过社交域")
	assert_false(domains.has("payment"), "单机版跳过付费域")

func test_has_handler_lookup() -> void:
	var catalog := FeatureCatalog.new()
	assert_true(catalog.has_handler("login"), "含 login")
	assert_true(catalog.has_handler("tavern_draw"), "含抽卡")
	assert_false(catalog.has_handler("chat"), "单机版不含聊天")


# P2-GUT-3：handler→manager dispatch 对照（IMPLEMENTATIONS 映射完整性 + 一致性）。
# catalog 是 handler→"Class.method" 声明基准（防只登记不实现潜伏）；现有测试只测数据登记，补 dispatch 声明对照。
func test_every_domain_handler_has_implementation() -> void:
	var catalog := FeatureCatalog.new()
	var missing: Array = []
	for handler in catalog.get_all_handlers():
		if not catalog.IMPLEMENTATIONS.has(handler):
			missing.append(handler)
	assert_eq(missing, [], "每个 DOMAINS handler 应在 IMPLEMENTATIONS 有映射（防只登记不实现）")


func test_implementations_only_known_handlers() -> void:
	var catalog := FeatureCatalog.new()
	var known: Array = catalog.get_all_handlers()
	var ghosts: Array = []
	for handler in catalog.IMPLEMENTATIONS.keys():
		if not known.has(handler):
			ghosts.append(handler)
	assert_eq(ghosts, [], "IMPLEMENTATIONS 不应有 DOMAINS 之外的幽灵 handler（防过期条目）")


func test_skipped_not_in_implementations() -> void:
	var catalog := FeatureCatalog.new()
	var leaked: Array = []
	for handler in catalog.SKIPPED_HANDLERS:
		if catalog.IMPLEMENTATIONS.has(handler):
			leaked.append(handler)
	assert_eq(leaked, [], "SKIPPED handler 不应在 IMPLEMENTATIONS（裁剪的不应有实现声明）")


func test_renamed_consistent_with_implementations() -> void:
	# RENAMED 源 handler 应在 DOMAINS；IMPLEMENTATIONS 的 method 部分应与 RENAMED 目标一致
	var catalog := FeatureCatalog.new()
	var all_handlers: Array = catalog.get_all_handlers()
	for src in catalog.RENAMED:
		assert_true(all_handlers.has(src), "RENAMED 源 %s 应在 DOMAINS" % src)
		var target_method: String = catalog.RENAMED[src]
		var impl: String = catalog.IMPLEMENTATIONS.get(src, "")
		var parts := impl.split(".")
		var method: String = ""
		if parts.size() >= 2:
			method = parts[-1]
		assert_eq(method, target_method, "RENAMED 目标 %s 应与 IMPLEMENTATIONS method 一致（%s）" % [target_method, src])
