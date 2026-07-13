extends GutTest
# BattleRng 单测：确定性（同 seed 同序列）+ 禁全局随机的可注入性。

func test_same_seed_same_sequence() -> void:
	# 确定性契约核心：同 seed 两次产生相同随机序列
	var rng_a := BattleRng.new(42)
	var rng_b := BattleRng.new(42)
	var seq_a: Array[float] = []
	var seq_b: Array[float] = []
	for i in range(10):
		seq_a.append(rng_a.randf())
		seq_b.append(rng_b.randf())
	assert_eq(seq_a, seq_b, "同 seed 必须产生相同 randf 序列")

func test_different_seed_different_sequence() -> void:
	var rng_a := BattleRng.new(42)
	var rng_b := BattleRng.new(7)
	assert_ne(rng_a.randf(), rng_b.randf(), "不同 seed 应产生不同值")

func test_randi_range_in_bounds() -> void:
	var rng := BattleRng.new(42)
	for i in range(20):
		var value := rng.randi_range(3, 8)
		assert_between(value, 3, 8, "randi_range 必须在闭区间内")

func test_seed_queryable() -> void:
	var rng := BattleRng.new(12345)
	assert_eq(rng.get_seed(), 12345, "seed 应可查（快照/回放）")
