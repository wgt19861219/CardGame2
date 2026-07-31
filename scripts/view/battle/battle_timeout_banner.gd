class_name BattleTimeoutBanner
extends RefCounted

## 超时横幅（View helper）— 从 BattleScene._process 拆出控 ≤400（照 BattleSceneFinalizer 静态拆分范式）。
## 源 battle_scene.lua:1429-1438 addTimeOutUI：time_limit 归零显示 battletext_timeover.png + ScaleTo 弹出，
## 延迟后切结算场景。资源缺失（battletext_timeover.png）时 push_warning 降级，仍走延迟回调保持时序。

const TIMEOVER_TEX_PATH: String = "res://assets/ui/alpha/HVGA/battletext_timeover.png"
const TIMEOVER_DELAY: float = 0.5         # 横幅显示后切结算的延迟（照源 ScaleTo 弹出时长）
const TIMEOVER_POP_DURATION: float = 0.3
const TIMEOVER_POS: Vector2 = Vector2(560.0, 460.0)  # 原 to_godot(480,100)=(480+80,560-100)，HUD 原生坐标


# 超时结束判定：stage 模式 + stage_ended 由 time_limit 归零触发 + last_result==RESULT_TIMEOUT。
# excavate/pvp 不走横幅（直接回主菜单），普通胜利 last_result==RESULT_WIN 不匹配。
static func is_timeout_end(engine: Variant, battle_context: Dictionary) -> bool:
	if engine == null or not bool(engine.stage_ended):
		return false
	if int(engine.last_result) != BattleEngine.RESULT_TIMEOUT:
		return false
	if battle_context.is_empty():
		return false
	return String(battle_context.get("mode", "stage")) == "stage"


# 显示超时横幅：Sprite2D + ScaleTo 弹出 Tween，TIMEOVER_DELAY 后调 on_done 切结算。
# 资源缺失时 push_warning 降级，仍走延迟 on_done 保持时序（finalize 自身会清场景，无需手动 free banner）。
static func show(scene: Node, on_done: Callable) -> void:
	if ResourceLoader.exists(TIMEOVER_TEX_PATH):
		var tex := load(TIMEOVER_TEX_PATH) as Texture2D
		var banner := Sprite2D.new()
		banner.name = "TimeOverBanner"
		banner.texture = tex
		banner.position = TIMEOVER_POS
		banner.scale = Vector2.ZERO
		scene.hud.add_child(banner)
		var t := scene.create_tween()
		t.tween_property(banner, "scale", Vector2.ONE, TIMEOVER_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		push_warning("[BattleTimeoutBanner] 超时横幅资源缺失: " + TIMEOVER_TEX_PATH)
	if scene.is_inside_tree():
		scene.get_tree().create_timer(TIMEOVER_DELAY).timeout.connect(on_done)
	else:
		on_done.call()
