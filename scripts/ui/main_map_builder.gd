class_name MainMapBuilder
extends RefCounted

## 主城地图 4 层容器工厂（View 层）— 照源 ui/main.lua createBottomMap:640 / createMiddleMap:733 /
## createTopMap:788 / createVeryTopMap:759。建 bottom/middle/top/veryTop(+sub) 4 容器 + 各层背景图 +
## cloud 黑云漂移（playBlackCloudAnim:905）+ subContainer 浮动（create:1080）。
## z 顺序：bottom < middle < top < veryTop（源 addChild 顺序）。返回容器引用供 MainParallax + 按钮挂载。

const MAP_W: float = 2400.0
const MAP_H: float = 536.0
const BG_DIR: String = "res://assets/ui/alpha/HVGA/"
const SPINE_DIR: String = "res://assets/spine"
const LOOP_ACTION: String = "Loop"
const FIX_HEIGHT: float = 480.0       # 源 grass config.fix_height（缩放高度到 480）
const CAMPAIGN_X: float = 530.0       # 源 mainres.CampaignX（veryTop bg3 偏移）
const CAMPAIGN_Y: float = -30.0       # 源 mainres.CampaignY（源 y 上）
const FOG_X: float = 600.0            # 源 mainres.mainFogX
const BOTTOM_BLUE: Color = Color(40.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0)   # 源 createBottomMap:685 ccc4(40,100,180)

# 源 mainres.cloud_res:357（pos + move_duration + move_distance；distance ccp(0,y) 源 y 上 → Godot 翻 Y）
const CLOUD4_POS: Vector2 = Vector2(305.0, 370.0)
const CLOUD4_DUR: float = 6.0
const CLOUD4_DIST: Vector2 = Vector2(0.0, 5.0)
const CLOUD5_POS: Vector2 = Vector2(195.0, 385.0)
const CLOUD5_DUR: float = 8.0
const CLOUD5_DIST: Vector2 = Vector2(0.0, 15.0)
const CLOUD6_POS: Vector2 = Vector2(270.0, 420.0)
const CLOUD6_DUR: float = 4.0
const CLOUD6_DIST: Vector2 = Vector2(0.0, -5.0)


## 建 4 容器 + 背景 + 装饰，返 {top, middle, bottom, verytop, sub}。parent = map 区 Control。
func build(parent: Control) -> Dictionary:
	var bottom := _new_container("parallax_bottom")
	var middle := _new_container("parallax_middle")
	var top := _new_container("parallax_top")
	var verytop := _new_container("parallax_verytop")
	var sub := _new_container("parallax_sub")
	parent.add_child(bottom)        # z 最底
	parent.add_child(middle)        # 源 createMiddleMap 空容器（sea 层）
	parent.add_child(top)
	verytop.add_child(sub)
	parent.add_child(verytop)       # z 最顶
	_build_bottom(bottom)
	_build_top(top)
	_build_verytop_sub(sub)
	return {"top": top, "middle": middle, "bottom": bottom, "verytop": verytop, "sub": sub}


func _new_container(node_name: String = "") -> Control:
	var c := Control.new()
	if node_name != "":
		c.name = node_name   # 调试用名（find_nodes 定位 + 验收容器 position）
	c.size = Vector2(MAP_W, MAP_H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 容器不吞事件，穿透到 map 拖拽层
	return c


# 源 createBottomMap:640-705：Spine main_bg_mountain 'BG'（pos animationX=0,Y=0），失败降级蓝底+静态 mountain.jpg。
func _build_bottom(container: Control) -> void:
	var sk := SpineSkeleton.new()
	container.add_child(sk)
	if sk.load_skeleton(SPINE_DIR + "/main_bg_mountain", "main_bg_mountain"):
		sk.play("BG", true)
		sk.position = Vector2(0.0, MAP_H)   # 源 anchor(0,0)+ccp(0,0) → Godot 左下角贴底
		return
	sk.queue_free()
	# 降级（照源 :682-702）：蓝底填充 + 静态 mountain.jpg（scaleY 480）
	var blue := ColorRect.new()
	blue.color = BOTTOM_BLUE
	blue.size = Vector2(2400, FIX_HEIGHT)
	blue.position = _from_bottom(Vector2(-400.0, 0.0), FIX_HEIGHT)
	blue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(blue)
	var tex: Texture2D = load(BG_DIR + "main_bg_mountain.jpg")
	if tex != null:
		_add_sprite(container, BG_DIR + "main_bg_mountain.jpg", Vector2(-200.0, 0.0), Vector2(tex.get_size().x, FIX_HEIGHT))


# 源 createTopMap:788-902：grass_left/right + cloud4/5/6 + left_side/right_side + Fog spine + 黑云漂移。
# 瀑布粒子（ccbi/Particle_Waterfall）无 Godot 等价，stub（源 :883 loadccbi 亦有 nil 降级）。
func _build_top(container: Control) -> void:
	var grass_l_tex: Texture2D = load(BG_DIR + "main_bg_grass_left.png")
	_add_sprite(container, BG_DIR + "main_bg_grass_left.png", Vector2(-212.0, 0.0), Vector2(grass_l_tex.get_size().x, FIX_HEIGHT))
	var grass_r_tex: Texture2D = load(BG_DIR + "main_bg_grass_right.png")
	_add_sprite(container, BG_DIR + "main_bg_grass_right.png", Vector2(716.0, 0.0), Vector2(grass_r_tex.get_size().x, FIX_HEIGHT))
	var c4 := _add_sprite(container, BG_DIR + "main_cloud_4.png", CLOUD4_POS, _tex_size("main_cloud_4.png"))
	var c5 := _add_sprite(container, BG_DIR + "main_cloud_5.png", CLOUD5_POS, _tex_size("main_cloud_5.png"))
	var c6 := _add_sprite(container, BG_DIR + "main_cloud_6.png", CLOUD6_POS, _tex_size("main_cloud_6.png"))
	_add_sprite(container, BG_DIR + "main_left_side.png", Vector2(-212.0, 240.0), _tex_size("main_left_side.png"), true)
	_add_sprite(container, BG_DIR + "main_right_side.png", Vector2(1646.0, 240.0), _tex_size("main_right_side.png"), true)
	if c4 != null:
		_play_black_cloud(c4, CLOUD4_DUR, CLOUD4_DIST)
	if c5 != null:
		_play_black_cloud(c5, CLOUD5_DUR, CLOUD5_DIST)
	if c6 != null:
		_play_black_cloud(c6, CLOUD6_DUR, CLOUD6_DIST)
	_add_fog(container)


# 源 createVeryTopMap:759-785：veryTop 内 subContainer 放 bg3（main_bg_Up.png @ CampaignX,Y）。
func _build_verytop_sub(sub: Control) -> void:
	_add_sprite(sub, BG_DIR + "main_bg_Up.png", Vector2(CAMPAIGN_X, CAMPAIGN_Y), _tex_size("main_bg_Up.png"))
	_float_sub(sub)


# 源 playBlackCloudAnim:905-918：cloud CCMoveBy(dur,dist)+reverse 循环。dist ccp(0,y) 源 y 上 → Godot y 下取反。
func _play_black_cloud(cloud: TextureRect, duration: float, distance: Vector2) -> void:
	var godot_dist := Vector2(distance.x, -distance.y)
	var origin: Vector2 = cloud.position
	var tween := cloud.create_tween()
	tween.set_loops()
	tween.tween_property(cloud, "position", origin + godot_dist, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(cloud, "position", origin, duration).set_trans(Tween.TRANS_SINE)


# 源 create:1080-1085 subContainer 上下 ±10 浮动 4s（CCEaseSineInOut；源 y 上 +10 → Godot y 下 -10）。
func _float_sub(sub: Control) -> void:
	var origin_y: float = sub.position.y
	var tween := sub.create_tween()
	tween.set_loops()
	tween.tween_property(sub, "position:y", origin_y - 10.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sub, "position:y", origin_y + 10.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# 源 createTopMap:891-900 SpineContainer eff_UI_Main_Fog 'Loop'（pos mainFogX=600,Y=0）。加载失败静默跳过。
func _add_fog(container: Control) -> void:
	var sk := SpineSkeleton.new()
	container.add_child(sk)
	if sk.load_skeleton(SPINE_DIR + "/eff_UI_Main_Fog", "eff_UI_Main_Fog"):
		sk.position = Vector2(FOG_X, MAP_H * 0.5)   # Fog 雾气层，纵向居中（视觉调，源 anchor 0,0+ccp(600,0)）
		sk.play(LOOP_ACTION, true)
	else:
		sk.queue_free()


# TextureRect 精灵（EXPAND_IGNORE_SIZE 避纹理撑大 size，[[texture-rect-expand-ignore-size]]）。
# cocos_pos = 源 ccp（左下原点 y 上）；anchor_center=false → anchor(0,0) 左下，true → anchor(0.5,0.5) 中心。
func _add_sprite(container: Control, tex_path: String, cocos_pos: Vector2, tex_size: Vector2, anchor_center: bool = false) -> TextureRect:
	var tex: Texture2D = load(tex_path)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.size = tex_size
	tr.position = _from_bottom(cocos_pos, tex_size.y) if not anchor_center else _from_center(cocos_pos, tex_size)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(tr)
	return tr


# 源 ccp(左下原点 y 上) + anchor(0,0) → Godot 左上角 position（y 翻转：MAP_H - cocos_y - tex_h）。
func _from_bottom(cocos_pos: Vector2, tex_h: float) -> Vector2:
	return Vector2(cocos_pos.x, MAP_H - cocos_pos.y - tex_h)


# 源 ccp + anchor(0.5,0.5) 中心 → Godot 左上角（y 翻转：MAP_H - cocos_y - tex_h/2，x 居中）。
func _from_center(cocos_pos: Vector2, tex_size: Vector2) -> Vector2:
	return Vector2(cocos_pos.x - tex_size.x * 0.5, MAP_H - cocos_pos.y - tex_size.y * 0.5)


func _tex_size(name: String) -> Vector2:
	var tex: Texture2D = load(BG_DIR + name)
	return tex.get_size() if tex != null else Vector2.ZERO
