class_name GapLoopAnimator
extends Node

## 按钮/装饰 gap/loop 间隙动画（View 层 Step 13.3/13.4）— 照源 ui/main.lua:446-471 createMainFca registerUpdateHandler。
## 有 gap_min/gap_max 或 loop_gap 的节点间歇性播 Start 动画（吸引注意），Start 单次播完 → action_finished → 回 Loop。
## 覆盖：按钮 Spine（shop/sshop/ssshop/mailbox/starshop）+ 装饰 FCA（lightning，mainres:56-65）。
## _anim 鸭子类型：SpineSkeleton/FcaAnimation 共有 play(action,loop)/action_finished signal，play 内部 action 不存在安全返。

const LOOP_ACTION: String = "Loop"
const START_ACTION: String = "Start"

var _anim: Variant = null   # SpineSkeleton/FcaAnimation（鸭子 API）
var _gap_min: float = 0.0
var _gap_max: float = 0.0
var _loop_gap: float = 0.0
var _loop_times_min: int = 0
var _loop_times_max: int = 0
var _timer: float = NAN   # 倒计时（NAN 待首次 reset）


## 配置（照源 createMainFca:446-450 读 v.gap_min/gap_max/loop_gap/loop_times_min/max）。
func setup(anim: Variant, gap_min: float, gap_max: float, loop_gap: float, loop_times_min: int, loop_times_max: int) -> void:
	_anim = anim
	_gap_min = gap_min
	_gap_max = gap_max
	_loop_gap = loop_gap
	_loop_times_min = loop_times_min
	_loop_times_max = loop_times_max
	if _anim != null and not _anim.action_finished.is_connected(_on_action_finished):
		_anim.action_finished.connect(_on_action_finished)


func _process(delta: float) -> void:
	if _anim == null or not is_instance_valid(_anim):
		set_process(false)
		return
	if is_nan(_timer):
		_reset_gap()
	_timer -= delta
	if _timer <= 0.0:
		_anim.play(START_ACTION, false)
		_reset_gap()


# Start 单次播完 → 回 Loop 循环。
func _on_action_finished(action: String) -> void:
	if action == START_ACTION and _anim != null and is_instance_valid(_anim):
		_anim.play(LOOP_ACTION, true)


func _reset_gap() -> void:
	var gg: float = _gap_max - _gap_min
	var gt: int = randi_range(0, int(gg)) if gg > 0.0 else 0
	var lt: int = randi_range(_loop_times_min, _loop_times_max) if _loop_times_max > 0 else 0
	_timer = gg * float(gt) + _gap_min + _loop_gap * float(lt)
