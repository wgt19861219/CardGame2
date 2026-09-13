class_name ChainActor
extends Node2D

## 链式闪电 actor（View 包装）— 照源 chain.lua:90-157 ChainEffect 翻译。
## 连线节点：每帧放 source→target 中点，按向量旋转，X 缩放=距离/100（拉伸贴图覆盖全程）。
## 协议同 BattleActor/ProjectileActor：update_view(dt) + model(BattleChain).terminated → actor_list 销毁。
##
## 旋转（照源 :140）：-deg(atan2(dy,dx))（Godot 用弧度，省去 math.deg）。
## 拉伸（照源 :141）：content.scaleX = dist/100（贴图原宽 100px 基准拉伸到实际距离）。
## 高度（照源 :131）：endPos 取 target 高度 48*unitScale；startPos 取 launchPoint 高度（首跳）或 12（后续）。

const BattleViewCoords = preload("res://scripts/ui/battle_view_coords.gd")
const BattleEffect = preload("res://scripts/view/battle/battle_effect.gd")

const CHAIN_CONTENT_BASE_W: float = 100.0  # 源 setScaleX(dist/100) 基准：贴图按 100px 宽拉伸
const CHAIN_TARGET_HEIGHT: float = 48.0    # 源 :131 endPos height = 48 * unitScale * sy（简化取 48）
const CHAIN_SOURCE_HEIGHT: float = 12.0    # 源 :112 后续跳 source height=12

var model: Variant = null  # BattleChain（Logic 层）
var _content: Variant = null  # BattleEffect（持 FCA 连线动画节点）
var _start_pos: Vector2 = Vector2.ZERO  # 视图坐标起点（首跳 launchPoint，后续旧 target 位）
var _base_scale: Vector2 = Vector2.ONE  # FCA root 基准缩放（_create_sprites 设 0.09），拉伸乘法保留


func setup(chain: Variant) -> void:
	model = chain
	var info: Dictionary = chain.skill.info
	var eff_name: String = String(info.get("Chain Effect", ""))
	if eff_name != "":
		_content = BattleEffect.create(eff_name)
	if _content != null:
		# 照源 ChainEffectCreate（chain.lua:104 setExternalPositioning(true)）：丢弃 cha 仿射，
		# 散件纹理原尺寸居中，节点位置/旋转/拉伸由本 actor 控制（唯一该模式的消费方）。
		_content.set_external_positioning()
		_content.play("Loop", true)
		var content_node: Node2D = _content.get_node()
		add_child(content_node)
		_base_scale = content_node.scale   # 记录 (0.09,0.09) 基准——拉伸须乘法保留
	# startPos 照源 :108-112：首跳用 launchPoint，后续跳用 source.position（height=12）。
	# 这里取当前 source（首跳 source=caster，后续 source=上一 target）。
	_init_start_pos()
	update_view(0.0)


func _init_start_pos() -> void:
	var src: Variant = model.source
	if src == null:
		return
	# 首跳（jumps_remaining 刚减 1）照源用 launchPoint；后续跳用 source.position + height 12。
	# 简化：统一用 source.position + CHAIN_SOURCE_HEIGHT（首跳误差极小，launchPoint.x≈caster.x）。
	_start_pos = BattleViewCoords.to_view_position(float(src.position.x), float(src.position.y), CHAIN_SOURCE_HEIGHT)


func update_view(_dt: float) -> void:
	if model == null or _content == null:
		return
	var tgt: Variant = model.target
	if tgt == null:
		return
	# endPos 照源 :131（简化高度，不含 unitScale 细节）。
	var end_pos: Vector2 = BattleViewCoords.to_view_position(float(tgt.position.x), float(tgt.position.y), CHAIN_TARGET_HEIGHT)
	# source 可能随跳跃变化，每帧刷新起点（照源 update 实时跟 source）。
	_init_start_pos()
	var dx: float = end_pos.x - _start_pos.x
	var dy: float = end_pos.y - _start_pos.y
	var dist: float = maxf(sqrt(dx * dx + dy * dy), 1.0)
	# node 放中点（照源 :138）。
	position = Vector2((_start_pos.x + end_pos.x) * 0.5, (_start_pos.y + end_pos.y) * 0.5)
	# 旋转（照源 :139，弧度版；源 -deg(atan2) = 弧度 -atan2）。
	rotation = -atan2(dy, dx)
	# X 拉伸覆盖全程（照源 :141 setScaleX(dist/100)）；Y 固定 3（照源 :142 setScaleY(3)）。
	# ⚠️ 乘法保留 _base_scale（FCA root 的 0.09，与散件 transform 的 1/0.09 因子配对抵消）——
	# 覆盖式赋值会冲掉基准致净放大 1/0.09≈11×（宙斯连锁闪电横铺全屏"技能动画错乱"根因，
	# 2026-09-06；同款 bug 2026-08-01 dbdd6ee 在 play_effect_on_scene 已修乘法，此处漏改）。
	var content_node: Node2D = _content.get_node()
	content_node.scale = Vector2(
		_base_scale.x * dist / CHAIN_CONTENT_BASE_W,
		_base_scale.y * 3.0
	)
	z_index = -int(tgt.position.y)


# freeze/unfreeze 变色（battle_entity.gd emit_tint 波及 projectile_list 内的 chain）。
# 源 chain.lua 无 tint，但本项目 engine.freeze() 遍历链同样 emit TINT——_dispatch 无本方法
# 会以 ProjectileActor 同款方式炸 Nonexistent function 'tint'（2026-09-05 投射物残留回归
# 同根因）。受控补齐：clamp modulate（同 ProjectileActor.tint / UnitSprite.tint 口径）。
func tint(r: float, g: float, b: float) -> void:
	modulate = Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0))
