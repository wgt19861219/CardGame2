class_name TeamHeadIcon
extends RefCounted

## 盾形头像组件 — 源 resource_manager.lua getHeadIcon(:1022-1041) + getTeamHead(:1043-1068)
## + createClippingNode(:676-694) 三段链路等价。
## 源链路：头像 ClippingNode（main_head_mask 圆形裁剪，stencil setScale 贴合头像再 -10pt）
## 整体缩放为 70pt 宽（length 默认）；容器仅定位用——head 中心偏 (-3,+2 cocos)、
## 金框（:1058 恒 gold）中心偏 (+13,-1 cocos)，均为 pt 值与头像缩放无关。
## Godot：portrait_mask shader 在头像 UV 上采样 mask（源 stencil 贴合缩放等价，Coco.jpg
## 100x100 与 mask 100x100 同尺寸下逐像素一致）；cocos y-up → Godot y 翻转：
## head (-3,-2)、frame (+13,+1)。走查批 C（2026-08-27）ranklist 行/浮窗启用，替代
## Avatar.Picture 方图直显降级。

const CONTENT_SCALE: float = 1.28125
const FRAME_RES: String = "res://assets/ui/alpha/HVGA/main_head_frame_gold.png"
const MASK_RES: String = "res://assets/ui/alpha/HVGA/main_head_mask.png"
const PORTRAIT_SHADER: Shader = preload("res://shaders/portrait_mask.gdshader")
const HEAD_LENGTH: float = 70.0
const HEAD_CENTER_OFFSET: Vector2 = Vector2(-3.0, -2.0)
const FRAME_CENTER_OFFSET: Vector2 = Vector2(13.0, 1.0)


## 建头像+金框组合（host 尺寸未定，调用方按中心锚定位 host.position）。
## avatar_id 查 Avatar 表 Picture；缺图/缺表时返空 host（调用方降级自行处理）。
static func build(cm: ConfigManager, avatar_id: int) -> Control:
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic: String = String(cm.get_raw_table(&"Avatar").get(str(avatar_id), {}).get("Picture", ""))
	if pic.is_empty():
		return host
	var head_path: String = "res://assets/ui/" + pic.substr(3)
	if not ResourceLoader.exists(head_path):
		return host
	var tex: Texture2D = load(head_path)
	var base: Vector2 = tex.get_size() / CONTENT_SCALE
	var show_scale: float = HEAD_LENGTH / base.x if base.x > 0.0 else 1.0
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var sz: Vector2 = base * show_scale
	icon.size = sz
	icon.position = HEAD_CENTER_OFFSET - sz * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PORTRAIT_SHADER
	mat.set_shader_parameter("mask_tex", load(MASK_RES))
	icon.material = mat
	host.add_child(icon)
	var frame_tex: Texture2D = load(FRAME_RES)
	var frame := TextureRect.new()
	frame.texture = frame_tex
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var fsz: Vector2 = frame_tex.get_size() / CONTENT_SCALE
	frame.size = fsz
	frame.position = FRAME_CENTER_OFFSET - fsz * 0.5
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(frame)
	return host
