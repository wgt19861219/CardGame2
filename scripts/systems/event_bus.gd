class_name EventBus
extends RefCounted

## 全局事件总线（RefCounted，Logic 层可 headless 单测，零 Node 依赖）。
## View 层通过 autoload Events.bus 订阅；Logic 层通过依赖注入获得实例。

signal data_changed(scope: StringName)
signal tutorial_step(step: StringName)    # Phase 8 EE/unlock/SU UI 动作 → tutorial_try_complete
signal tutorial_switch(steps: Array)      # Phase 8 条件触发切阶段（FT→EE→SU→unlock）
signal feature_unlocked(step: StringName) # unlock 公告：玩家升级达条件解锁功能 → View 弹公告

## 触发数据变更信号。scope 标识变更域（如 &"hero"、&"wallet"），View 据此选择性刷新。
func emit_data_changed(scope: StringName) -> void:
	data_changed.emit(scope)


## Phase 8 EE/unlock/SU UI 动作触发（main_scene 接 → tutorial_try_complete 推进 + 刷新 GuideView）。
func emit_tutorial_step(step: StringName) -> void:
	tutorial_step.emit(step)


## Phase 8 条件触发切阶段（main_scene 接 → tutorial_switch_phase 切步骤链 + 刷新 GuideView）。
func emit_tutorial_switch(steps: Array) -> void:
	tutorial_switch.emit(steps)


## unlock 公告触发（PlayerData.check_unlocks 升级达条件 → main_scene 接弹公告 View）。
func emit_feature_unlocked(step: StringName) -> void:
	feature_unlocked.emit(step)
