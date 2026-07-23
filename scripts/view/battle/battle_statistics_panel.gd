class_name BattleStatisticsPanel
extends Control

## 战斗伤害统计弹窗（View 层）— 照源 ui/battleStatistics.lua 翻译。
## 源 battleStatist.create(engineList) 装配：setImx 算 maxdmg → showPlayBar（条形图 scale 动画）
##   + setCount（numberJump 数字跳动 scheduler）+ getIcon（英雄头像）。
## 本实现：弹窗（全屏黑半透 + hurtBg 面板）+ 英雄行（头像+数字+条）+ Tween 动画。
## 单机化：pvp changeTitle 裁剪（源 :149-152，单机无 pvp）；cExit + 点遮罩关闭。
##
## 数据：unit_snapshot（finalizer 从 engine.unit_list 快照，含 tid/camp/dmg_statistics/rank/stars/level）。
## 坐标：源 hurtBg 800×480 Cocos，子节点 ccp(cx,cy) 相对 hurtBg 左下 → Godot 局部 (cx, 360-cy)。
## 资源降级：hp_black_small/stagedone_statistics_friend/enemy 缺图时 ColorRect 降级（不阻塞装配）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/battle/battle_statistics_content.tscn")
const ALPHA_HVGA_DIR: String = "res://assets/ui/alpha/HVGA/"
const COMMON_DIR: String = "res://assets/ui/alpha/HVGA/common/"
const BAR_BG_TEX: String = "hp_black_small.png"
const BAR_FRIEND_TEX: String = "stagedone_statistics_friend.png"
const BAR_ENEMY_TEX: String = "stagedone_statistics_enemy.png"
# 源 getIcon length=45（readhero.getIcon 缩放参数）→ ReadheroIcon container 104×104，scale=45/104。
const ICON_SCALE: float = 45.0 / 104.0
const HURT_BG_H: float = 360.0   # 源 hurtBg scaleSize height（局部 y 翻转基准）
# 源 showPlayBar/setCount：每方最多 5 行，行间距 50（y=260/210/160/110/60）。
const ROWS_Y: Array[float] = [260.0, 210.0, 160.0, 110.0, 60.0]
const COUNT_Y_OFFSET: float = 20.0   # 源 mCount ccp(x, sprite_y+20)（260→280）
const BAR_Y_OFFSET: float = -10.0    # 源 mBar ccp(x, sprite_y-10)（260→250）
# 我方列 x（源 mSprite=40, mCount=138, mBar=136）
const M_SPRITE_X: float = 40.0
const M_COUNT_X: float = 138.0
const M_BAR_X: float = 136.0
const M_BAR_W: float = 137.0   # 源 ui1 scaleSize width
# 敌方列 x（源 eSprite=380, eCount=282, eBar=284）
const E_SPRITE_X: float = 380.0
const E_COUNT_X: float = 282.0
const E_BAR_X: float = 284.0
const E_BAR_W: float = 136.0   # 源 eui1 scaleSize width
const BAR_H: float = 15.0      # 源 ui/eui scaleSize height
const LABEL_W: float = 60.0
const LABEL_H: float = 16.0
# 源 upBar final scale.x = 0.5 * len（len=dmg/maxdmg）。简化为 size 对齐底条后 ratio 直接用（详见验收点）。
const BAR_SCALE_Y: float = 0.5   # 源 setScaleY(0.5) 固定
const MAX_BAR_TIME: float = BattleStatisticsCalc.MAX_BAR_TIME   # 源 getBarTime 第三参 0.8

signal closed

var _content: Control = null
var _hurt_bg: Control = null


# 装配入口（照源 battleStatist.create）。unit_snapshot: Array of Dictionary（finalizer 快照）。
func setup(unit_snapshot: Array, cm: ConfigManager) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # 模态拦截（源 touchInfo bSwallowsTouches）
	var max_dmg: float = BattleStatisticsCalc.calc_max_dmg(unit_snapshot)
	if max_dmg <= 0.0:
		max_dmg = 1.0   # 防空除（全 0 伤害时避免 NaN）
	_build_static(cm)
	var camps: Dictionary = BattleStatisticsCalc.split_by_camp(unit_snapshot)
	_fill_rows(camps["player"], camps["enemy"], max_dmg, cm)


# 静态框架：instantiate .tscn + 接 cExit/遮罩关闭 + 填标题（cm.get_lstr 多语言）。
func _build_static(cm: ConfigManager) -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	add_child(_content)
	_hurt_bg = _content.get_node("%HurtBg") as Control
	(_content.get_node("%CExit") as TextureButton).pressed.connect(close)
	(_content.get_node("%Shelter") as ColorRect).gui_input.connect(_on_shelter_input)
	if cm != null:
		(_content.get_node("%TitleOur") as Label).text = str(cm.get_lstr("BATTLESTATISTICSCONFIG.OUR_PART"))
		(_content.get_node("%TitleEnemy") as Label).text = str(cm.get_lstr("BATTLESTATISTICSCONFIG.ENEMYS_PART"))
		(_content.get_node("%TitleOurDmg") as Label).text = str(cm.get_lstr("BATTLESTATISTICSCONFIG.OUTPUT_INJURY"))
		(_content.get_node("%TitleEnemyDmg") as Label).text = str(cm.get_lstr("BATTLESTATISTICSCONFIG.OUTPUT_INJURY"))


# 填英雄行（照源 showPlayBar + setCount）。player/enemy: Array of unit Dictionary。
func _fill_rows(player: Array, enemy: Array, max_dmg: float, cm: ConfigManager) -> void:
	for i in player.size():
		_create_row(true, i, player[i], max_dmg, cm)
	for i in enemy.size():
		_create_row(false, i, enemy[i], max_dmg, cm)


# 创建单行（照源 showPlayBar + getIcon + upBar + setCount numberJump）。
func _create_row(is_player: bool, idx: int, unit: Dictionary, max_dmg: float, cm: ConfigManager) -> void:
	var sprite_x: float = M_SPRITE_X if is_player else E_SPRITE_X
	var count_x: float = M_COUNT_X if is_player else E_COUNT_X
	var bar_x: float = M_BAR_X if is_player else E_BAR_X
	var bar_w: float = M_BAR_W if is_player else E_BAR_W
	var row_y: float = ROWS_Y[idx]
	# getIcon：英雄头像（源 readhero.getIcon length=45）
	var icon := ReadheroIcon.new()
	icon.setup({
		"id": int(unit.get("tid", 0)),
		"rank": int(unit.get("rank", 1)),
		"stars": int(unit.get("stars", 0)),
		"level": int(unit.get("level", 1)),
	}, cm)
	icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
	icon.position = _local(sprite_x, row_y)
	icon.modulate.a = 0.0
	_hurt_bg.add_child(icon)
	# mCount Label（源 anchor 0.5,1 底部中心）
	var dmg: float = float(unit.get("dmg_statistics", 0.0))
	var speed_time: float = BattleStatisticsCalc.get_bar_time(dmg, max_dmg, MAX_BAR_TIME)
	var count := Label.new()
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.size = Vector2(LABEL_W, LABEL_H)
	count.position = _local(count_x, row_y + COUNT_Y_OFFSET) - Vector2(LABEL_W * 0.5, LABEL_H)
	count.text = "0"
	_hurt_bg.add_child(count)
	# upBar：底条 + 填充条（源 ui1 hp_black_small + mBar stagedone_statistics_friend/enemy）
	var bar_bg := _make_bar_bg(bar_x, row_y, bar_w)
	_hurt_bg.add_child(bar_bg)
	var bar_fill := _make_bar_fill(is_player, bar_bg, bar_w)
	_hurt_bg.add_child(bar_fill)
	# 动画：icon fade + bar scale + number jump（照源 showPlayBar + setCount）
	_play_icon_fade(icon)
	_up_bar(bar_fill, is_player, dmg / max_dmg, BattleStatisticsCalc.get_bar_time(dmg, max_dmg, MAX_BAR_TIME))
	_number_jump(count, dmg, speed_time)


# 源 hurtBg 局部坐标转换：ccp(cx,cy) 相对 hurtBg 左下 → Godot 局部 (cx, HURT_BG_H - cy)。
func _local(cx: float, cy: float) -> Vector2:
	return Vector2(cx, HURT_BG_H - cy)


# 底条（源 ui1/eui1 hp_black_small scaleSize w×15）。缺图 ColorRect 降级。
func _make_bar_bg(cx: float, cy: float, w: float) -> Control:
	var node: Control = null
	var tex: Texture2D = _load(ALPHA_HVGA_DIR + BAR_BG_TEX)
	if tex != null:
		var npr := NinePatchRect.new()
		npr.texture = tex
		npr.patch_margin_left = 12
		npr.patch_margin_top = 4
		npr.patch_margin_right = 65
		npr.patch_margin_bottom = 3
		node = npr
	else:
		var cr := ColorRect.new()
		cr.color = Color(0.1, 0.1, 0.1, 0.8)
		node = cr
	node.size = Vector2(w, BAR_H)
	node.position = _local(cx, cy) - Vector2(w * 0.5, BAR_H * 0.5)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


# 填充条（源 mBar stagedone_statistics_friend / eBar stagedone_statistics_enemy）。
# 我方从左生长（pivot 左中心），敌方从右生长（pivot 右中心）。缺图 ColorRect 降级（我方蓝/敌方红）。
func _make_bar_fill(is_player: bool, bar_bg: Control, w: float) -> Control:
	var tex: Texture2D = _load(ALPHA_HVGA_DIR + (BAR_FRIEND_TEX if is_player else BAR_ENEMY_TEX))
	var node: Control = null
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node = tr
	else:
		var cr := ColorRect.new()
		cr.color = Color(0.2, 0.5, 0.9, 1.0) if is_player else Color(0.9, 0.3, 0.2, 1.0)
		node = cr
	node.size = Vector2(w, BAR_H)
	node.position = bar_bg.position   # 与底条同位（pivot 控制生长方向）
	node.pivot_offset = Vector2(0.0 if is_player else w, BAR_H * 0.5)
	node.scale = Vector2(0.0, BAR_SCALE_Y)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


# 源 upBar(:96-108)：setScaleX(0) setScaleY(0.5) → CCScaleTo(barTime, 0.5*len, 0.5)。
# 本实现 size 对齐底条，scale.x 0→ratio（ratio=dmg/maxdmg，源 0.5*len 简化，详见验收点）。
func _up_bar(bar_fill: Control, is_player: bool, ratio: float, duration: float) -> void:
	var target_x: float = clampf(ratio, 0.0, 1.0)
	if duration <= 0.0:
		bar_fill.scale.x = target_x
		return
	var t := create_tween()
	t.tween_property(bar_fill, "scale:x", target_x, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)


# 源 numberJump(:42-76)：scheduler 每帧 count+=dt，ce=min(floor(speed*count),dmg)，setString(comma(floor(ce)))。
# 本实现 Tween method 0→dmg（duration=speed_time，speed=dmg/speed_time 照源），每帧 floor+千分位。
func _number_jump(label: Label, dmg: float, speed_time: float) -> void:
	if dmg <= 0.0:
		label.text = BattleStatisticsCalc.format_comma(0)
		return
	var duration: float = maxf(speed_time, 0.001)   # 防 0 时长
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: label.text = BattleStatisticsCalc.format_comma(int(v)), 0.0, dmg, duration)


func _play_icon_fade(icon: Node2D) -> void:
	var t := create_tween()
	t.tween_property(icon, "modulate:a", 1.0, 0.2)


# 源 release/exit：点遮罩或 cExit 关闭（源 battleStatist.exit removeChild + release）。
func _on_shelter_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()


func close() -> void:
	closed.emit()
	queue_free()


func _load(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
