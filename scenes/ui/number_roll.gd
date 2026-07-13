class_name NumberRoll
extends Control

## 数字滚动控件（Step 4.1.5 原子库）：from 插值到 target，用于金币/伤害数字动画。
## 逻辑可测（tick_step）；视觉渲染（Label 更新）在运行时 _process。

const DEFAULT_STEP: int = 1

var current: int = 0
var target: int = 0
var rolling: bool = false

func roll_to(new_target: int) -> void:
	target = new_target
	rolling = true

## 单步推进（测试调用，运行时由 _process 驱动）。
func tick_step() -> void:
	if not rolling:
		return
	if current < target:
		current = min(current + DEFAULT_STEP, target)
	elif current > target:
		current = max(current - DEFAULT_STEP, target)
	if current == target:
		rolling = false

func is_rolling() -> bool:
	return rolling
