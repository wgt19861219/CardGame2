class_name BattleCameraShake
extends RefCounted

## 战斗场景相机震动（View helper）— 从 BattleScene 拆出控 ≤400。
## static 方法第一参 scene，照 equip_strengthen_anim.gd 静态拆分范式。
## 主类 start/stop_camera_shake_animation_x/y 转发本类（公开 API，被 BattleActor 调用）。


# shakeNum 次交替 ±max_height，shake_time 总时长（每次 interval = shake_time/shakeNum），末尾还原。
static func shake_y(scene, max_height: float, shake_time: float, shake_num: int) -> void:
	if scene._camera == null:
		return
	if scene._shake_tween_y != null:
		scene._shake_tween_y.kill()
	var interval: float = shake_time / float(maxi(shake_num, 1))
	scene._shake_tween_y = scene.create_tween().set_loops(shake_num)
	for i in range(shake_num):
		var off: float = max_height if i % 2 == 0 else -max_height
		scene._shake_tween_y.tween_property(scene._camera, "offset:y", off, interval)
	scene._shake_tween_y.tween_property(scene._camera, "offset:y", 0.0, interval)


static func stop_y(scene) -> void:
	if scene._shake_tween_y != null:
		scene._shake_tween_y.kill()
		scene._shake_tween_y = null
	if scene._camera != null:
		scene._camera.offset.y = 0.0


static func shake_x(scene, max_height: float, shake_time: float, shake_num: int) -> void:
	if scene._camera == null:
		return
	if scene._shake_tween_x != null:
		scene._shake_tween_x.kill()
	var interval: float = shake_time / float(maxi(shake_num, 1))
	scene._shake_tween_x = scene.create_tween().set_loops(shake_num)
	for i in range(shake_num):
		var off: float = max_height if i % 2 == 0 else -max_height
		scene._shake_tween_x.tween_property(scene._camera, "offset:x", off, interval)
	scene._shake_tween_x.tween_property(scene._camera, "offset:x", 0.0, interval)


static func stop_x(scene) -> void:
	if scene._shake_tween_x != null:
		scene._shake_tween_x.kill()
		scene._shake_tween_x = null
	if scene._camera != null:
		scene._camera.offset.x = 0.0


# 场景销毁时调用（_exit_tree）：仅 kill 残留 tween，不复位 camera offset（场景即将 free）。
static func kill_all(scene) -> void:
	if scene._shake_tween_x != null:
		scene._shake_tween_x.kill()
		scene._shake_tween_x = null
	if scene._shake_tween_y != null:
		scene._shake_tween_y.kill()
		scene._shake_tween_y = null
