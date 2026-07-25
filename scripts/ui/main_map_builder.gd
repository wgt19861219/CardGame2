class_name MainMapBuilder
extends RefCounted

## 主城地图 4 层容器工厂（View 层）— 照源 ui/main.lua createBottomMap:640 / createMiddleMap:733 /
## createTopMap:788 / createVeryTopMap:759。建 bottom/middle/top/veryTop(+sub) 4 容器 + 各层背景图 +
## cloud 黑云漂移（playBlackCloudAnim:905）+ subContainer 浮动（create:1080）。
## z 顺序：bottom < middle < top < veryTop（源 addChild 顺序）。返回容器引用供 MainParallax + 按钮挂载。

const MAP_W: float = 2400.0
const MAP_H: float = 640.0   # grass/mountain/cloud/side 整体下移（_from_bottom 640 基准，grass 放屏底 160~640）
const BG_DIR: String = "res://assets/ui/alpha/HVGA/"
const CONTENT_SCALE: float = 1.28125
const SPINE_DIR: String = "res://assets/spine"
const LOOP_ACTION: String = "Loop"
const FIX_HEIGHT: float = 480.0
const CAMPAIGN_X: float = 530.0
const CAMPAIGN_Y: float = -30.0
const FOG_X: float = 600.0
const BOTTOM_BLUE: Color = Color(40.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0)
const MOUNTAIN_TOP_GAP: float = 52.0   # mountain Spine position=MAP_H 时顶部空隙：root bone 不在包围盒左下角（源 Cocos anchor(0,0) 自动补偿，Godot position=root 需 MAP_H-此值 让包围盒顶部对齐 y=0 填满容器）

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
	parent.add_child(middle)
	parent.add_child(top)
	verytop.add_child(sub)
	parent.add_child(verytop)       # z 最顶
	_build_bottom(bottom)
	var map_width: float = _build_top(top)
	_build_verytop_sub(sub)
	return {"top": top, "middle": middle, "bottom": bottom, "verytop": verytop, "sub": sub, "map_width": map_width}


func _new_container(node_name: String = "") -> Control:
	var c := Control.new()
	if node_name != "":
		c.name = node_name   # 调试用名（find_nodes 定位 + 验收容器 position）
	c.size = Vector2(MAP_W, MAP_H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 容器不吞事件，穿透到 map 拖拽层
	return c


# 去 Spine 云海（Godot 渲染顶部黑覆盖 jpg 蓝天，致 statusbar 透明区露黑边）；jpg 满铺避拼接/黑边。
func _build_bottom(container: Control) -> void:
	var blue := ColorRect.new()
	blue.color = BOTTOM_BLUE
	blue.size = Vector2(MAP_W, MAP_H)
	blue.position = Vector2(-200.0, 0.0)
	blue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(blue)
	var tex: Texture2D = load(BG_DIR + "main_bg_mountain.jpg")
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = Vector2(MAP_W, MAP_H)
		tr.position = Vector2(-400.0, 0.0)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(tr)


# 瀑布粒子（ccbi/Particle_Waterfall）无 Godot 等价，stub（源 :883 loadccbi 亦有 nil 降级）。
# 返回 grass_left+right 显示总宽（源 create:1065 mapWidth，供 MainParallax 算 map_min_x）。
func _build_top(container: Control) -> float:
	var grass_l_tex: Texture2D = load(BG_DIR + "main_bg_grass_left.png")
	var grass_l_w: float = grass_l_tex.get_size().x * FIX_HEIGHT / grass_l_tex.get_size().y if grass_l_tex != null else 0.0
	var map_width: float = grass_l_w
	_add_sprite(container, BG_DIR + "main_bg_grass_left.png", Vector2(-212.0, 0.0), Vector2(grass_l_w, FIX_HEIGHT))
	var grass_r_tex: Texture2D = load(BG_DIR + "main_bg_grass_right.png")
	var grass_r_w: float = grass_r_tex.get_size().x * FIX_HEIGHT / grass_r_tex.get_size().y if grass_r_tex != null else 0.0
	map_width += grass_r_w
	_add_sprite(container, BG_DIR + "main_bg_grass_right.png", Vector2(716.0, 0.0), Vector2(grass_r_w, FIX_HEIGHT))
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
	return map_width


func _build_verytop_sub(sub: Control) -> void:
	_add_sprite(sub, BG_DIR + "main_bg_Up.png", Vector2(CAMPAIGN_X, CAMPAIGN_Y), _tex_size("main_bg_Up.png"))
	_float_sub(sub)


func _play_black_cloud(cloud: TextureRect, duration: float, distance: Vector2) -> void:
	var godot_dist := Vector2(distance.x, -distance.y)
	var origin: Vector2 = cloud.position
	var tween := cloud.create_tween()
	tween.set_loops()
	tween.tween_property(cloud, "position", origin + godot_dist, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(cloud, "position", origin, duration).set_trans(Tween.TRANS_SINE)


func _float_sub(sub: Control) -> void:
	var origin_y: float = sub.position.y
	var tween := sub.create_tween()
	tween.set_loops()
	tween.tween_property(sub, "position:y", origin_y - 10.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sub, "position:y", origin_y + 10.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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


func _from_bottom(cocos_pos: Vector2, tex_h: float) -> Vector2:
	return Vector2(cocos_pos.x, MAP_H - cocos_pos.y - tex_h)


func _from_center(cocos_pos: Vector2, tex_size: Vector2) -> Vector2:
	return Vector2(cocos_pos.x - tex_size.x * 0.5, MAP_H - cocos_pos.y - tex_size.y * 0.5)


func _tex_size(name: String) -> Vector2:
	var res: String = BG_DIR + name
	# cloud4/5/6 + left/right_side + bg3 源 config={} 无 fix → 显示=纹理/CS（grass fix_height 另走 :87 不经此函数）
	if not ResourceLoader.exists(res):
		return Vector2.ZERO
	return TexDisplaySize.display_size(res)
