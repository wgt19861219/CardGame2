class_name BattleAutoButton
extends Control

## 自动战斗按钮 — 照源 battle_scene.lua:1207-1257（auto_btn @734,60 CCMenuItemToggle
## autocombat_on/off 两态）+ autoCombatHandler :1016-1029 翻译（Phase 4）。
## TextureButton 贴图两态切换（代码直建，照 create_return_button 先例）。
## 2026-09-06 升级：源图 Content/res/UI/alpha/HVGA/autocombat_on/off.png 补齐入库，
## 撤 2026-07-21 文本降级（当时误判资源硬缺）；位置修正中心→左上角换算（对齐倍速按钮）。

const TEXTURE_ON: String = "res://assets/ui/alpha/HVGA/autocombat_on.png"
const TEXTURE_OFF: String = "res://assets/ui/alpha/HVGA/autocombat_off.png"
# 显示尺寸 = 纹理像素 ÷ CS（2026-09-06 三轮订正：源 hello.lua:311 Director 全局
# setContentScaleFactor(615/480)=1.28125，引擎 Texture2D::getContentSize 返回点尺寸，
# CCMenuItemImage 内部 Sprite 一样÷CS——08-28"MenuItemImage 不÷CS"判例据此推翻）。
const CONTENT_SCALE: float = 1.28125
# 源 :1254 auto_btn:setPosition(ccp(734,60)) 是 MenuItem 锚点中心；显示 82.73×46.83 点。
# Godot position=左上角 → 中心 to_godot(734,60)=(734,420) − 显示半尺寸。
const GODOT_POS: Vector2 = Vector2(692.63, 396.59)  # (734,420) − (106/CS/2, 60/CS/2)

signal toggled(on: bool)

var _on: bool = false
var _button: TextureButton = null


func setup(initial_on: bool = false, visible_default: bool = true) -> void:
	_on = initial_on
	position = GODOT_POS
	_button = TextureButton.new()
	_button.scale = Vector2.ONE / CONTENT_SCALE   # 显示=纹理像素÷CS（照 battle 域 hp_bar 等同款范式）
	add_child(_button)
	_apply_texture()
	_button.pressed.connect(_on_pressed)
	visible = visible_default


func _apply_texture() -> void:
	if _button != null:
		_button.texture_normal = _load_texture(_on)


# 源 CCMenuItemToggle 两态：setSelectedIndex(auto and 1 or 0) — on 态显 autocombat_on，off 显 off。
func _load_texture(on: bool) -> Texture2D:
	var path: String = TEXTURE_ON if on else TEXTURE_OFF
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _on_pressed() -> void:
	_on = not _on
	_apply_texture()
	toggled.emit(_on)


func set_on(on: bool) -> void:
	_on = on
	_apply_texture()


func is_on() -> bool:
	return _on


func show_button() -> void:
	visible = true


func hide_button() -> void:
	visible = false
