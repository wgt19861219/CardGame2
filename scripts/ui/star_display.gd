class_name StarDisplay
extends Control

## 星级显示（Step 4.1.5 原子库）：stars(0-5) 计算 + 显示数据。
## 逻辑可测（显示星星数）；视觉（星形 Sprite）在 .tscn 运行时。

const MAX_STARS: int = 5

var stars: int = 0

func set_stars(count: int) -> void:
	stars = clampi(count, 0, MAX_STARS)

func filled_count() -> int:
	return stars

func empty_count() -> int:
	return MAX_STARS - stars
