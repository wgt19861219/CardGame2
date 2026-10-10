class_name BossAura
extends RefCounted

## ch203 Boss 元素光环粒子（2026-10-09 用户需求"冷气/闪电等粒子效果"）：
## CPUParticles2D（compatibility 渲染器无差别）+ 程序生成柔光点贴图，按 Boss Aura 类型
## 配色与运动（mist 水雾上浮 / frost 冷气沉降 / flame 火星窜升 / spark 电光闪烁 /
## blood 血雾升腾——均为垂直主导运动，actor 朝向翻转无视觉差）。
## 挂 battle_actor（is_boss 且 config.boss_aura 非空），数据源 StageDungeon.Boss Aura。

const AURA_TYPES: PackedStringArray = ["mist", "frost", "flame", "spark", "blood"]
const PARTICLE_COUNT: int = 22
const EMISSION_WIDTH: float = 90.0
const EMISSION_HEIGHT: float = 110.0

# 类型参数：主体色/边缘色/初速（logic 单位近似）/重力/尺寸区间/透明度
const _AURA_PARAMS := {
	"mist": {"color": Color(0.55, 0.85, 1.0, 0.34), "velocity": Vector2(0, -26), "gravity": Vector2(0, -6),
		"size": Vector2(7, 13), "spread": 18.0},
	"frost": {"color": Color(0.72, 0.92, 1.0, 0.42), "velocity": Vector2(0, 22), "gravity": Vector2(0, 14),
		"size": Vector2(4, 8), "spread": 14.0},
	"flame": {"color": Color(1.0, 0.62, 0.25, 0.5), "velocity": Vector2(0, -46), "gravity": Vector2(0, -14),
		"size": Vector2(4, 8), "spread": 22.0},
	"spark": {"color": Color(0.95, 0.98, 1.0, 0.6), "velocity": Vector2(0, -12), "gravity": Vector2(0, 0),
		"size": Vector2(3, 6), "spread": 60.0},
	"blood": {"color": Color(0.82, 0.12, 0.16, 0.4), "velocity": Vector2(0, -22), "gravity": Vector2(0, -8),
		"size": Vector2(6, 11), "spread": 16.0},
}


static func make(aura_type: String, body_height: float = 110.0) -> CPUParticles2D:
	var params: Dictionary = _AURA_PARAMS.get(aura_type, {})
	if params.is_empty():
		return null
	var node := CPUParticles2D.new()
	node.name = "BossAura"
	node.texture = _soft_dot_texture()
	node.amount = PARTICLE_COUNT
	node.lifetime = 1.4
	node.preprocess = 1.2   # 开场即满浓度，不从零攒
	node.local_coords = false
	node.position = Vector2(0, -body_height * 0.45)
	node.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	node.emission_rect_extents = Vector2(EMISSION_WIDTH * 0.5, EMISSION_HEIGHT * 0.3)
	node.direction = Vector2(0, -1)
	node.spread = float(params["spread"])
	node.gravity = Vector2(params["gravity"])
	node.initial_velocity_min = maxf(6.0, float(params["velocity"].length()) * 0.6)
	node.initial_velocity_max = float(params["velocity"].length()) * 1.4
	node.scale_amount_min = float(params["size"].x)
	node.scale_amount_max = float(params["size"].y)
	node.color = Color(params["color"])
	node.color_ramp = _fade_ramp(Color(params["color"]))
	if aura_type == "spark":
		# 电光：无重力随机爆闪（高 spread + 短寿命闪烁感）
		node.lifetime = 0.5
		node.amount = PARTICLE_COUNT * 2
	return node


## 32×32 径向柔光点（中心亮→边缘透明；tint 走 material/ramp）。
static func _soft_dot_texture() -> ImageTexture:
	var size: int = 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = size * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x - center + 0.5, y - center + 0.5).length() / center
			var alpha: float = clampf(1.0 - d, 0.0, 1.0)
			alpha = alpha * alpha   # 二次衰减更柔
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


## 淡入淡出 ramp（CPUParticles2D.color_ramp 类型即 Gradient 本体）：
## 头 15% 淡入、尾 40% 淡出。
static func _fade_ramp(base: Color) -> Gradient:
	var grad := Gradient.new()
	grad.set_color(0, Color(base.r, base.g, base.b, 0.0))
	grad.set_color(1, Color(base.r, base.g, base.b, 0.0))
	grad.add_point(0.15, Color(base.r, base.g, base.b, base.a))
	grad.add_point(0.6, Color(base.r, base.g, base.b, base.a))
	return grad
