class_name BattleBigHpBar
extends Control

## Boss 多血段大血条（View 层）— 照源 hp_bar.lua BigHpBar(:137-339)。
## hpLayer 段（red/purple/blue 循环），跨段切换：损血进下段 isMinBlood（fore→0 后换段重置）、
## 回血升上段 isMaxBlood。fore/mid 平滑同 HpBar。挂 ui_layer 固定位置（Boss 屏幕顶）。
## guild 资源（guildraid_hpbar_boss_* / boss_frame）全就位。
##
## 重构（2026-07-18，hero_detail 范式）：6 个 Sprite2D（background/midlayer/foreground/
## decration/boss_icon_frame/boss_icon）+ 3 个静态贴图（bg/transition/boss_frame）+ centered
## 固化进 scenes/battle/battle_big_hp_bar_content.tscn；动态贴图（foreground/decration 段色 /
## boss_icon）+ position（依赖 texture size）+ scale.x（血量百分比）保留 _setup/_layout 计算。

const CONTENT_SCENE: PackedScene = preload("res://scenes/battle/battle_big_hp_bar_content.tscn")
const GUILD_DIR: String = "res://assets/ui/alpha/HVGA/guild/"
const EPSILON: float = 0.001
const INC_SPEED: float = 0.3       # 源 :291
const BG_SCALE_FACTOR: float = 0.9  # 源 :311 hpBarLength*0.9/bgWidth
const ICON_FRAME_GAP: float = 10.0  # 源 :333 -10

var _unit: Variant = null
var _length: float = 0.0
var _background: Sprite2D = null
var _midlayer: Sprite2D = null
var _foreground: Sprite2D = null
var _decration: Sprite2D = null     # 源 :287 decration（下一段提示色块）
var _boss_icon_frame: Sprite2D = null
var _boss_icon: Sprite2D = null
var _blood_bar_info: Array = []     # 源 :301 [{name, slice}, ...]（slice=1/count）
var _blood_index: int = 1           # 1-based（源 for i=1..）
var _blood_percent: float = 1.0
var _percent: float = 1.0
var _fore_length: float = 1.0
var _mid_length: float = 1.0
var _is_min_blood: bool = false     # 源 :296 段降（损血进下段）
var _is_max_blood: bool = false
var terminated: bool = false


# 源 BigHpBar.create（:279-338）
static func create(unit: Variant, length: float) -> BattleBigHpBar:
	var bar := BattleBigHpBar.new()
	bar._setup(unit, length)
	return bar


func _setup(unit: Variant, length: float) -> void:
	_unit = unit
	_length = length
	# Phase A 静态化：6 个 Sprite2D + centered + bg/transition/boss_frame 贴图固化进 .tscn
	# （content 挂 self — Control 组件坑 7）；position 0,0、动态贴图、scale 由 _layout/resetForeground 设。
	var content := CONTENT_SCENE.instantiate()
	add_child(content)
	_background = content.get_node("%Background") as Sprite2D
	_midlayer = content.get_node("%Midlayer") as Sprite2D
	_decration = content.get_node("%Decration") as Sprite2D       # 贴图 resetForeground 动态设
	_foreground = content.get_node("%Foreground") as Sprite2D     # 贴图 resetForeground 动态设
	_boss_icon_frame = content.get_node("%BossIconFrame") as Sprite2D
	_boss_icon = content.get_node("%BossIcon") as Sprite2D
	var icon_tex: Texture2D = _load_unit_icon(String(unit.boss_icon_name))
	if icon_tex:
		_boss_icon.texture = icon_tex
	_blood_bar_info = _get_blood_bar_rcs_and_percent(int(unit.hp_layer))
	_reset_blood_state()   # 源 :302 设 foreground/decration 贴图 + bloodIndex
	_percent = _blood_percent   # 源 :303-305
	_fore_length = _percent
	_mid_length = _percent
	_layout()


# 源 update（:139-208）：跨段切换 + fore/mid 平滑。
func update(dt: float) -> void:
	var r: Dictionary = _get_blood_bar_index_and_percent()
	var real_blood_percent: float = float(r["real"])
	var blood_index: int = int(r["blood_index"])
	var blood_percent: float = float(r["blood_percent"])
	if real_blood_percent <= 0.0:   # 源 :142-145 单位死→移除
		terminated = true
		queue_free()
		return
	if bool(r["ok"]):   # 源 :147-160
		_blood_percent = blood_percent
		_percent = blood_percent
		if _blood_index != blood_index:
			if blood_index > _blood_index:
				_is_min_blood = true   # 段降
				_percent = 0.0
			else:
				_is_max_blood = true   # 段升
				_percent = 1.0
	# 源 :167-186 fore/mid 平滑（同 HpBar）
	if _fore_length < _percent - EPSILON:
		_fore_length += INC_SPEED * dt
		if _percent < _fore_length:
			_fore_length = _percent
		_foreground.scale.x = _fore_length
	elif _fore_length > _percent + EPSILON:
		_fore_length = _percent
		_foreground.scale.x = _percent
	if _mid_length < _fore_length - EPSILON:
		_mid_length = _fore_length
		_midlayer.scale.x = _fore_length
	elif _mid_length > _fore_length:
		_mid_length -= INC_SPEED * dt
		_midlayer.scale.x = _mid_length
	# 源 :187-207 跨段切换收尾
	if _percent == 0.0 and _is_min_blood:
		if _fore_length >= _mid_length:
			_reset_blood_state()
			_percent = _blood_percent
			_foreground.scale.x = _percent
			_midlayer.scale.x = 1.0
			_fore_length = _percent
			_mid_length = 1.0
			_blood_index = blood_index
			_is_min_blood = false
	elif _percent == 1.0 and _is_max_blood and _fore_length >= _percent - EPSILON:
		_reset_blood_state()
		_percent = _blood_percent
		_midlayer.scale.x = 0.0
		_foreground.scale.x = 0.0
		_fore_length = 0.0
		_mid_length = 0.0
		_blood_index = blood_index
		_is_max_blood = false


# 源 getBloodBarRcsAndPercent（:209-228）：按段数生成 red/purple/blue 循环（i 从 count 递减）。
func _get_blood_bar_rcs_and_percent(count: int) -> Array:
	var ret: Array = []
	var slice: float = 1.0 / float(count) if count > 0 else 1.0
	var i: int = count
	while i >= 1:
		var idx: int = i % 3   # 源 math.mod(i,3)
		var nm: String = ""
		if idx == 1:
			nm = "guildraid_hpbar_boss_red.png"
		elif idx == 2:
			nm = "guildraid_hpbar_boss_purple.png"
		else:   # idx == 0
			nm = "guildraid_hpbar_boss_blue.png"
		ret.append({"name": nm, "slice": slice})
		i -= 1
	return ret


# 源 getBloodBarIndexAndPercent（:229-248）：算当前段 + 段内剩余 percent + 真实血比例。
func _get_blood_bar_index_and_percent() -> Dictionary:
	var real_blood_percent: float = float(_unit.hp) / float(_unit.attribs.get("HP", 1))
	var total_percent: float = 1.0 - real_blood_percent   # 已损血比例
	var blood_index: int = 0
	var blood_percent: float = 0.0
	var acc: float = 0.0
	for i in range(_blood_bar_info.size()):
		acc += float(_blood_bar_info[i]["slice"])
		if total_percent <= acc:
			blood_index = i + 1   # 1-based
			blood_percent = (acc - total_percent) / float(_blood_bar_info[i]["slice"])
			break
	return {"ok": true, "blood_index": blood_index, "blood_percent": blood_percent, "real": real_blood_percent}


# 源 resetForegroundAndDecration（:250-265）：换 foreground 贴图为当前段色，decration 为下一段色。
func _reset_foreground_and_decration() -> void:
	var fg_name: String = String(_blood_bar_info[_blood_index - 1]["name"])
	if _blood_index < _blood_bar_info.size():
		var dec_name: String = String(_blood_bar_info[_blood_index]["name"])   # 下一段
		_decration.visible = true
		_set_sprite_texture(_decration, dec_name)
	else:
		_decration.visible = false   # 末段无下一段提示
	_set_sprite_texture(_foreground, fg_name)


# 源 resetBloodState（:266-273）
func _reset_blood_state() -> void:
	var r: Dictionary = _get_blood_bar_index_and_percent()
	_blood_index = int(r["blood_index"])
	if _blood_index < 1:   # hp 满时 acc 累加未触发（total_percent=0 ≤ 第 1 段 acc）
		_blood_index = 1
	_blood_percent = float(r["blood_percent"])
	_reset_foreground_and_decration()


# 源 create 布局段（:306-336）：anchor/position/scale 翻译（Cocos anchor→Godot centered=false 左上角）。
# Phase A：节点层级 + centered + 静态贴图固化进 .tscn，此函数只设动态 position/scale
# （依赖 texture size + length + percent）。background position=(0,0) 已在 .tscn。
func _layout() -> void:
	var icon_frame_size: Vector2 = _tex_size(_boss_icon_frame)
	var bg_size: Vector2 = _tex_size(_background)
	var mid_size: Vector2 = _tex_size(_midlayer)
	var fg_size: Vector2 = _tex_size(_foreground)
	var hp_bar_length: float = _length - icon_frame_size.x   # 源 :310
	var bg_scale: float = minf(hp_bar_length * BG_SCALE_FACTOR / bg_size.x, 1.0) if bg_size.x > 0.0 else 1.0
	var offset_x: float = bg_size.x - (bg_size.x - mid_size.x) / 2.0   # 源 :312
	var offset_y: float = bg_size.y / 2.0   # 源 :313
	var offset_x_left: float = (bg_size.x - mid_size.x) / 2.0   # 源 :314
	var offset_y_down: float = (bg_size.y - mid_size.y) / 2.0   # 源 :315
	# background scale 动态（centered=true position=(0,0) 已在 .tscn）
	_background.scale = Vector2(bg_scale, 1.0)
	# decration：anchor(1,0.5) pos(offset_x,offset_y) → 左上 = pos-(w,h/2)
	_decration.position = Vector2(offset_x - _tex_size(_decration).x, offset_y - _tex_size(_decration).y / 2.0)
	# midlayer：anchor(0,0) pos(offset_x_left,offset_y_down)
	_midlayer.position = Vector2(offset_x_left, offset_y_down)
	# foreground：同 midlayer
	_foreground.position = Vector2(offset_x_left, offset_y_down)
	_midlayer.scale.x = _percent
	_foreground.scale.x = _percent
	# bossIconFrame：anchor(0,0.5) pos(fg_w*bg_scale/2-10, 0) → 左上 = pos-(0,h/2)
	_boss_icon_frame.position = Vector2(fg_size.x * bg_scale / 2.0 - ICON_FRAME_GAP, -icon_frame_size.y / 2.0)
	# bossIcon：anchor(0.5,0.5) pos(frame_w/2,frame_h/2) → centered=true
	_boss_icon.position = Vector2(icon_frame_size.x / 2.0, icon_frame_size.y / 2.0)


func _tex_size(sprite: Sprite2D) -> Vector2:
	if sprite and sprite.texture:
		return sprite.texture.get_size()
	return Vector2.ZERO


func _set_sprite_texture(sprite: Sprite2D, res: String) -> void:
	var path: String = GUILD_DIR + res
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		sprite.texture = tex


# unit.bossIconName = info["Boss Portrait"]，"UI/..." 前缀路径。
func _load_unit_icon(res_path: String) -> Texture2D:
	if res_path.is_empty():
		return null
	var p: String = "res://assets/ui/" + res_path.trim_prefix("UI/")
	if not ResourceLoader.exists(p):
		return null
	return load(p) as Texture2D
