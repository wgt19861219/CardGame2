class_name ProjectileActor
extends Node2D

## 投射物 actor（View 包装）— 照源 projectile.lua:223-321 ProjectileActor 翻译。
## Node2D 容器 + FCA 动画（或降级占位）+ 位置/旋转/朝向同步。
## 协议同 BattleActor：update_view(dt) + model(BattleProjectile).terminated → 由 scene actor_list 统一推进/销毁。
##
## 旋转（照源 :299-300）：-atan2(zSpeed + v.y*DEEP_PROJECTION_Y, v.x + v.y*DEEP_PROJECTION_X)。
## 本项目正交投影 DEEP_PROJECTION_X=0 / DEEP_PROJECTION_Y=1，简化为 -atan2(zSpeed + v.y, v.x)（弧度）。
## 朝向（照源 :301）：scale.y = v.x > 0 ? 1 : -1（朝右不翻转，朝左沿 Y 轴翻转贴图）。

const BattleViewCoords = preload("res://scripts/view/battle/battle_view_coords.gd")
const BattleEffect = preload("res://scripts/view/battle/battle_effect.gd")

var model: Variant = null  # BattleProjectile（Logic 层投射物）
var _fca_effect: Variant = null  # BattleEffect（持 FCA 动画节点；投射物飞行时常驻循环播放）


func setup(proj: Variant) -> void:
	model = proj
	var info: Dictionary = proj.skill.info
	var art: String = String(info.get("Tile Art", ""))
	if art == "":
		update_view(0.0)
		return
	if art.ends_with(".png"):
		# .png 投射物（箭矢/子弹）：数据表值 "projectile/xxx.png"，映射 res://assets/projectile/xxx.png。
		# 照源 projectile.lua:245 createSprite(art)，原尺寸无缩放。
		var png_path := "res://assets/" + art
		if ResourceLoader.exists(png_path):
			var sprite := Sprite2D.new()
			sprite.texture = load(png_path)
			add_child(sprite)
		# 资源缺失则空节点降级（照源 stub 兜底）
	elif art.ends_with(".cha"):
		# .cha 投射物（FCA 动画）：BattleEffect.create 剥后缀 + 查 effect/ 子目录（路径回退已修）。
		_fca_effect = BattleEffect.create(art)
		if _fca_effect != null:
			_fca_effect.play("Loop", true)  # 飞行期间循环播放（源 setStartAction/setLoopAction("Loop")，无 Loop 资源兜底首个）
			var n: Node2D = _fca_effect.get_node()
			add_child(n)
			# 大位移资源内容居中（2026-08-19）：幽灵船等 .cha 投射物帧 tx/ty ±5000 原始，
			# 内容中心偏节点原点缩后 500px+（投射物锚点在船外）→ 直接飞出屏幕"看不到"。
			# 把内容中心平移回投射物锚点（小位移资源近似无操作）。
			if n.has_method("center_content"):
				n.call("center_content")
	update_view(0.0)


func update_view(_dt: float) -> void:
	if model == null:
		return
	# 位置：逻辑坐标 + 离地高度 → 视图坐标（照源 :296 toViewPosition）。
	position = BattleViewCoords.to_view_position(float(model.position.x), float(model.position.y), float(model.height))
	# ZOrder：按 y 排序（照源 :298 setZOrder(-position[2])），与单位 actor 一致。
	z_index = -int(model.position.y)
	# 旋转：按速度向量倾斜（照源 :299-300，弧度版）。
	var vx: float = float(model.velocity.x)
	var vy: float = float(model.velocity.y)
	var zsp: float = float(model.z_speed)
	if vx != 0.0 or zsp != 0.0 or vy != 0.0:
		rotation = -atan2(zsp + vy, vx)
	# 朝向：朝右不翻，朝左沿 Y 翻转（照源 :301 setScaleY）。
	scale.y = 1.0 if vx >= 0.0 else -1.0


# 源 projectile.lua:313-320 tint（puppet 有 tint 走 puppet，否则 tintSprite(node)）。
# freeze/unfreeze（battle_entity.gd emit_tint）会波及飞行中投射物（engine.freeze 遍历
# projectile_list）；曾漏译本方法致 TINT 事件分发炸 Nonexistent function 'tint' → step 从
# render 行中断（ProjectileSync.sync/_advance_actor_list 当帧全跳）+ 编辑器 Debugger Break
# 挂死游戏——2026-09-05 用户"投射物切波后还在"回归根因（probe 实锤）。统一 clamp 设
# modulate（覆盖 .png sprite 与 FCA 两态；UNFREEZE_TINT=2.5 clamp 到 1.0=WHITE 复白）。
func tint(r: float, g: float, b: float) -> void:
	modulate = Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0))
