class_name StageDetailBuilder
extends RefCounted

## 关卡详情 View 构造器（View helper）— 照源 stagedetail.lua create:1536-1934 翻译。
## 重构（2026-07-17）：base 层静态节点位置/size 固化进 stage_detail_content.tscn（编辑器可视化调）。
## 本类只 fill 动态数据（texture/text/visible）+ 建动态内容（敌人阵容/奖励/星，挂 %EnemyHost/%RewardHost/%StarHost）。
## 坐标：源 cocos（800×480，y 向上，原点左下）→ Godot（960×640，y 向下）。
## 面板 800×480 居中 offset(80,80)：Godot = (cocos_x + 80, 560 - cocos_y)。

const OFFSET_X: float = 80.0
const BASE_Y: float = 560.0

const C_TITLE: Color = Color(250.0 / 255.0, 205.0 / 255.0, 16.0 / 255.0)     # :1644 toccc3(16436496)
const C_WHITE: Color = Color(1.0, 1.0, 1.0)                                  # :1659 toccc3(16777215)
const C_SECTION: Color = Color(241.0 / 255.0, 193.0 / 255.0, 113.0 / 255.0)  # toccc3(15843697)
const C_NUM: Color = Color(245.0 / 255.0, 225.0 / 255.0, 190.0 / 255.0)      # toccc3(16114110)
const C_DISABLE: Color = Color(1.0, 102.0 / 255.0, 49.0 / 255.0)             # toccc3(16737841)
const C_RESET: Color = Color(1.0, 206.0 / 255.0, 31.0 / 255.0)               # :1816 ccc3(255,206,31)

const UI_DIR: String = "res://assets/ui/alpha/HVGA/"
const BOSS_TAG_RES: String = UI_DIR + "stagedetail_boss_tag.png"

const ENEMY_CONTAINER: float = 104.0  # ReadheroIcon.CONTAINER_SIZE.x
const ENEMY_LEN_NORMAL: float = 70.0  # 源 createEnemy:1172 普通敌人边长（cocos px）
const ENEMY_LEN_BOSS: float = 80.0    # 源 createEnemy:1169 boss 边长
const ENEMY_BOSS_OX: float = 5.0      # 源 createEnemy:1172 boss 额外偏移
const REWARD_ICON_SCALE: float = 0.7  # 奖励图标缩放（72→~50，对齐源 cocos 80 间距视觉）

# title_bg 在 .tscn 取 normal 基线 size（504×12），fill 时按 stage_type 重设 size + position（源 Scale9 中心定位）。
const TITLE_BG_COCOS: Vector2 = Vector2(400.0, 355.0)


static func get_res_info(stage_type: String) -> Dictionary:
	match stage_type:
		"normal":
			return _pack(UI_DIR + "stage-map-frame.png", UI_DIR + "Normal_title_bg.png", Vector2(504.0, 12.0), 55, Vector2(698.0, 80.0), Vector2(400.0, 205.0))
		"elite", "dungeon":
			return _pack(UI_DIR + "stage-map-elite-frame.png", UI_DIR + "Elite_title_bg.png", Vector2(404.0, 12.0), 50, Vector2(678.0, 80.0), Vector2(400.0, 207.0))
		"raid":
			return _pack(UI_DIR + "stage_map_guild_frame.png", UI_DIR + "guild_title_bg.png", Vector2(404.0, 12.0), 50, Vector2(678.0, 80.0), Vector2(400.0, 207.0))
	return _pack(UI_DIR + "stage-map-frame.png", UI_DIR + "Normal_title_bg.png", Vector2(504.0, 12.0), 55, Vector2(698.0, 80.0), Vector2(400.0, 205.0))


static func _pack(frame: String, title_bg: String, bg_size: Vector2, star_gap: int, go_btn: Vector2, frame_pos: Vector2) -> Dictionary:
	return {"frame": frame, "title_bg": title_bg, "title_bg_size": bg_size, "star_gap": star_gap, "go_btn_pos": go_btn, "frame_pos": frame_pos}


static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


# cm: ConfigManager，用于 LSTR 化硬编码中文（源 stagedetail.lua :1686/:1730/:1807/:1834/:1848）。
# 返 ui 引用 dict（panel 后处理显隐/色用，同旧 build 返回兼容）。
static func setup_content(content: Control, info: Dictionary, res_info: Dictionary, cm: Variant) -> Dictionary:
	var left: int = int(info.get("count_limit", 0)) - int(info.get("count", 0))
	# texture + size/pos fill。源 stagedetail.lua:1586-1606 frame2=detail_bg_2.png（实心背景图）+ frame3=frameRes
	# （stage-map-frame.png 空心边框=背景框），两帧同中心 framePosNormal=ccp(400,205)→godot(480,355)、
	# 同尺寸 display_size 936×507、完全重合（背景图铺满框）。对齐关卡选择 FrameLayer scale 0.9（用户偏好
	# "frame 太大贴屏边"缩放），故详情两帧一起按 0.9 等比缩、同中心重合（"以关卡选择为准"+"框里背景图铺满"）。
	# .tscn 里 Frame2/Frame3 是过时占位 offset，运行时用 offset 重定（size/position 在 layout_mode 3 不覆盖 tscn offset）。
	const SELECT_FRAME_SCALE: float = 0.9
	var frame3: TextureRect = content.get_node("%Frame3") as TextureRect
	var frame_res: String = String(res_info.get("frame", ""))
	_set_texture(frame3, frame_res)
	var frame_size: Vector2 = TexDisplaySize.display_size(frame_res)
	var frame_pos: Vector2 = Vector2(res_info.get("frame_pos", Vector2(400.0, 205.0)))
	var frame_center: Vector2 = to_godot(frame_pos.x, frame_pos.y)
	var scaled_size: Vector2 = frame_size * SELECT_FRAME_SCALE
	frame3.offset_left = frame_center.x - scaled_size.x * 0.5
	frame3.offset_right = frame_center.x + scaled_size.x * 0.5
	frame3.offset_top = frame_center.y - scaled_size.y * 0.5
	frame3.offset_bottom = frame_center.y + scaled_size.y * 0.5
	# Frame2（背景图 detail_bg_2.png）与 Frame3 同尺寸同中心重合（源 frame2 同 framePosNormal，铺满框）。
	var frame2: TextureRect = content.get_node("%Frame2") as TextureRect
	frame2.offset_left = frame_center.x - scaled_size.x * 0.5
	frame2.offset_right = frame_center.x + scaled_size.x * 0.5
	frame2.offset_top = frame_center.y - scaled_size.y * 0.5
	frame2.offset_bottom = frame_center.y + scaled_size.y * 0.5
	var title_bg: TextureRect = content.get_node("%TitleBg") as TextureRect
	# texture 已烘 .tscn（detail_title_bg.png 各 stage_type 共用），仅运行时按 stage_type 重设 size/position。
	var bg_size: Vector2 = Vector2(res_info.get("title_bg_size", Vector2(504.0, 12.0)))
	title_bg.size = bg_size
	title_bg.position = to_godot(TITLE_BG_COCOS.x, TITLE_BG_COCOS.y) - bg_size * 0.5
	# text fill
	var ui: Dictionary = {
		"frame2": content.get_node("%Frame2"),
		"frame3": content.get_node("%Frame3"),
		"title_bg": title_bg,
		"detail": content.get_node("%Detail"),
		"power_title": content.get_node("%PowerTitle"),
		"power_number": content.get_node("%PowerNumber"),
		"power_icon": content.get_node("%PowerIcon"),
		"count_title": content.get_node("%CountTitle"),
		"count_number": content.get_node("%CountNumber"),
		"total_number": content.get_node("%TotalNumber"),
		"reset": content.get_node("%Reset"),
		"reset_label": content.get_node("%ResetLabel"),
		"enemy_bg": content.get_node("%EnemyBg"),
		"enemy_title": content.get_node("%EnemyTitle"),
		"award_title": content.get_node("%AwardTitle"),
		"go_button": content.get_node("%GoButton"),
		"go_button_shade": content.get_node("%GoButtonShade"),
		"star_box": content.get_node("%StarHBox"),
		"enemy_box": content.get_node("%EnemyHBox"),
		"reward_box": content.get_node("%RewardHBox"),
	}
	var detail_lbl: Label = ui["detail"] as Label
	detail_lbl.text = String(info.get("detail", ""))
	detail_lbl.visible = bool(info.get("is_key_stage", false)) or String(info.get("detail", "")) != ""
	(ui["power_number"] as Label).text = str(info.get("power", 0))
	(ui["total_number"] as Label).text = "/ " + str(info.get("count_limit", "??"))
	(ui["count_number"] as Label).text = str(left)
	var lstr_power: String = String(cm.get_lstr("STAGEDETAIL.PHYSICAL_EXERTION")) if cm != null else ""
	var lstr_left: String = String(cm.get_lstr("EXERCISE.REMAINING_TIMES_FOR_TODAY_")) if cm != null else ""
	var lstr_buy: String = String(cm.get_lstr("EQUIPINFO.PURCHASE")) if cm != null else ""
	var lstr_enemy: String = String(cm.get_lstr("STAGEDETAIL.ENEMY_LINEUP")) if cm != null else ""
	var lstr_award: String = String(cm.get_lstr("STAGEDETAIL.MAY_BE_OBTAINED")) if cm != null else ""
	(ui["power_title"] as Label).text = lstr_power
	(ui["count_title"] as Label).text = lstr_left + str(left)
	(ui["reset_label"] as Label).text = lstr_buy
	(ui["enemy_title"] as Label).text = lstr_enemy
	(ui["award_title"] as Label).text = lstr_award
	return ui


static func _set_texture(rect: TextureRect, res_path: String) -> void:
	if rect == null or res_path.is_empty():
		return
	if not ResourceLoader.exists(res_path):
		return
	rect.texture = load(res_path) as Texture2D


# 敌方阵容：照源 createEnemy:1142-1192 翻译，容器化（ReadheroIcon 是 Node2D 不能直接进 HBox，
# 套 Control wrapper + custom_minimum_size，范式同 excavate_team_panel._add_hero_icon）。
# boss/普通尺寸差异通过 wrapper size + icon scale 处理，坐标交由 %EnemyHBox 自动排版。
static func create_enemy(parent: Node, enemies: Array, cm: Variant) -> void:
	# boss 排在小怪后面（用户偏好：详情阵容 boss 在末尾，区别于战斗站位 Boss Position）。
	var ordered: Array = []
	var bosses: Array = []
	for e in enemies:
		if bool(e.get("is_boss", false)):
			bosses.append(e)
		else:
			ordered.append(e)
	ordered.append_array(bosses)
	for e in ordered:
		var tid: int = int(e.get("tid", 0))
		if tid == 0:
			continue
		var is_boss: bool = bool(e.get("is_boss", false))
		var icon := ReadheroIcon.new()
		var rank: int = mini(ExcavateData.hero_level_to_rank(int(e.get("level", 1))), 8)
		icon.setup({"id": tid, "rank": rank, "stars": int(e.get("stars", 0))}, cm)
		var length: float = ENEMY_LEN_BOSS if is_boss else ENEMY_LEN_NORMAL
		var s: float = length / ENEMY_CONTAINER
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(ENEMY_CONTAINER * s + (ENEMY_BOSS_OX if is_boss else 0.0), ENEMY_CONTAINER * s)
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.scale = Vector2(s, s)
		icon.position = Vector2(ENEMY_BOSS_OX if is_boss else 0.0, 0.0)
		wrapper.add_child(icon)
		parent.add_child(wrapper)
		if icon.ori_icon is Sprite2D:
			(icon.ori_icon as Sprite2D).flip_h = true
		if is_boss:
			_add_boss_tag(icon)


static func _add_boss_tag(icon: ReadheroIcon) -> void:
	var host: Node = icon.icon if icon.icon != null else icon
	if ResourceLoader.exists(BOSS_TAG_RES):
		var tag := Sprite2D.new()
		tag.texture = load(BOSS_TAG_RES) as Texture2D
		tag.centered = false
		tag.position = Vector2(52.0, 20.0)
		tag.z_index = 10
		host.add_child(tag)
	else:
		var lbl := Label.new()
		lbl.text = "BOSS"
		lbl.position = Vector2(20.0, 0.0)
		lbl.add_theme_color_override("font_color", Color.RED)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.z_index = 10
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(lbl)


# 奖励：照源 createReward:1193-1211 翻译，容器化（ReadequipIcon 返回 Control 直接进 %RewardHBox）。
static func create_reward(parent: Node, drops: Array, cm: Variant) -> void:
	for d in drops:
		var item_id: int = int(d.get("item_id", 0))
		if item_id == 0:
			continue
		var icon: Control = ReadequipIcon.create_icon(item_id, 1, cm)
		icon.scale = Vector2(REWARD_ICON_SCALE, REWARD_ICON_SCALE)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		parent.add_child(icon)


# 星级：照源 createStars:1212-1261，星星已静态化进 .tscn（%StarHBox 下 Star1/2/3 TextureRect）。
# 本方法按 star_count 切换 3 个 TextureRect 的 texture（detail_star / detail_star_grey）。
static func apply_stars(star_box: Node, star_count: int) -> void:
	for i in range(3):
		var star: TextureRect = (star_box.get_child(i)) as TextureRect
		if star == null:
			continue
		var res_path: String = (UI_DIR + "detail_star.png") if i < star_count else (UI_DIR + "detail_star_grey.png")
		if ResourceLoader.exists(res_path):
			star.texture = load(res_path) as Texture2D
