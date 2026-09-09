extends RefCounted

## 关卡选择动态层构造器（stage_select_panel 的 fills helper，批3 Task 5 两件套，2026-08-16）。
## 由 stage_select_builder.gd（317 行）退役归并：静态底板（bg/mode toggle/箭头/close/挂载层）
## 在 stage_select_content.tscn；本类只建数据驱动动态行与 crossfade 动画节点：
##   - map layer（章节 bg/route/stage 圆点/stars/pointer/key mask，随章节与进度重建）
##   - frame/title_bg/title label（mode/章节切换 crossfade 依赖节点重建，照源
##     createFrame:944/createTitle:885 的重建+fade 模式，静态单节点换纹理无法表达交叉淡化）
##   - chapter dots（数量 1-13 随进度）
## 贴图口径（批3 Task 4/5 定稿）：显示 = 像素÷CS×条目CS（Prescaled=true 才施加）——
## stageselect_map_bg 系条目 Prescaled=true CS=2 → 468×254px → 730.54×396.49；
## stage-map-frame 条目 Prescaled=false 不施加 → 936×507px → 730.34×395.61；其余无条目只 ÷CS。
## 坐标系：源 cocos(800×480 左下原点) → Godot 800×480 左上原点 = (cx, 480-cy)。

const StageSelectMapClass = preload("res://scripts/systems/stage_select_map.gd")
const TexSize = preload("res://scripts/ui/tex_display_size.gd")

const CONTENT_SCALE: float = 1.28125

const FRAME_NORMAL: String = "res://assets/ui/alpha/HVGA/stage-map-frame.png"
const FRAME_ELITE: String = "res://assets/ui/alpha/HVGA/stage-map-elite-frame.png"
const FRAME_GUILD: String = "res://assets/ui/alpha/HVGA/stage_map_guild_frame.png"
const TITLE_BG_NORMAL: String = "res://assets/ui/alpha/HVGA/Normal_title_bg.png"
const TITLE_BG_ELITE: String = "res://assets/ui/alpha/HVGA/Elite_title_bg.png"
const TITLE_BG_GUILD: String = "res://assets/ui/alpha/HVGA/guild_title_bg.png"
const MODE_TOGGLE_NS: String = "res://assets/ui/alpha/HVGA/elitetoggle-ns.png"
const MODE_TOGGLE_S: String = "res://assets/ui/alpha/HVGA/elitetoggle-s.png"
const DOT_NORMAL: String = "res://assets/ui/alpha/HVGA/stageselect_chapter_dot.png"
const DOT_CURRENT: String = "res://assets/ui/alpha/HVGA/stageselect_chapter_cursor.png"
const POINTER: String = "res://assets/ui/alpha/HVGA/stagepointer.png"
const STAR_BG: String = "res://assets/ui/alpha/HVGA/stageselect_star_bg.png"
const STAR: String = "res://assets/ui/alpha/HVGA/stageselect_star.png"

# 源 clipStencil 712×372 @ cocos(44,20)（stageselect.lua:1610-1612）→ godot rect(44,88)。
# 2026-07-20 clip 903×471 系偏大口径（base×cs 漏÷CS）补偿，随口径修正一并撤销。
const CLIP_RECT: Rect2 = Rect2(44.0, 88.0, 712.0, 372.0)
const CLIP_OFFSET: Vector2 = Vector2(44.0, 88.0)
# title（源 createTitleBg:939 titleBg ccp(397,393)、createTitleText:874 label 同位）
# → godot 中心 (397,87)；2026-07-20 上移 117 系偏大 frame 补偿（frame top 101.5），
# 修正后源 frame top 157.2 偏好跨边框稍下，恢复源位。
const TITLE_CENTER: Vector2 = Vector2(397.0, 87.0)
# 星级布局（源 createStage spos :1242-1255，相对 star_bg 中心，cocos 中心锚 y 上正）
const STAR_POS_SN: Array = [
	[Vector2(37.0, 15.0)],
	[Vector2(26.0, 18.0), Vector2(48.0, 18.0)],
	[Vector2(17.0, 18.0), Vector2(37.0, 15.0), Vector2(57.0, 18.0)],
]
# star_bg 位置（2026-09-01 三轮定谳）：源直译=icon 左下角 (82, 上38) 即叠底座下缘
# （胶囊中心=圆窗中心正下方 ~36、水平居中）。三轮史：一轮底部口径（源直译）→二轮
# 用户口误指认「顶部」改 STAR_BG_TOP_Y=30 →三轮用户出示原版 MuMu 真值截图澄清
# 「应该在底部」+原版实测胶囊中心偏圆窗 (+0.8,+37.2) 与一轮版 (+0.4,+35.75) 吻合
# →回滚一轮公式。原版星体 15.7 逻辑=贴图金核 ~20px÷CS（阈值量的是可见内容不含
# 透明边），尺寸口径两边一致无真差异。
# dots（源 stageselectres.lua:1493-1495 + getDotPos:76-86：中心 x=400 / gap_x 20 / normal y 40 / elite y 45 → godot 440/435）
const DOT_CENTER_X: float = 400.0
const DOT_GAP_X: float = 20.0
const DOT_NORMAL_Y: float = 440.0
const DOT_ELITE_Y: float = 435.0
# stage 按钮命中层边长 = 源 KEY/NOT_KEY_STAGE_RADIUS=45（stageselect.lua:15-16）×2。
# 源 doStageTouch :126-131 isPointInCircle(t.pos, 45, x,y) 圆形命中与贴图大小无关；
# 方形近似圆（四角偏差 45×(√2-1)≈18.6px，轴向等价）。Godot 直译 TextureButton
# rect=贴图显示尺寸后小圆盘（passed 态 37×41px→显示 ~29×32）命中区过小 + 城堡
# （209×189px→显示 163×148）rect 含透明边吞相邻据点点击（用户 2026-09-07 报
# 「两个城堡之间的小据点非常难点击选中」），故命中层（本按钮）与贴图显示层
# （子 TextureRect 照旧尺寸居中，不裁剪不吞点击）分离（2026-09-07 根修）。
const STAGE_HIT_SIZE: float = 90.0

# panel/builder 共享 meta key（panel 切换动画识别 frame/title/pointer/mask 节点用）。
const META_FRAME: StringName = &"ss_frame"
const META_TITLE: StringName = &"ss_title"
const META_POINTER: StringName = &"ss_pointer"
const META_MASK: StringName = &"ss_mask"   # 钥匙关 current/passed 闪烁遮罩（源 :1229-1238 FadeTo 循环）
# 源 createStage :1331-1351 forGetWay 引导素材（呼吸圈+手指；动画归 panel _guide_*）。
const GUIDE_CIRCLE_RES: String = "res://assets/ui/alpha/HVGA/tutorial_circle.png"
const GUIDE_FINGER_RES: String = "res://assets/ui/alpha/HVGA/tutorial_finger.png"
const META_GUIDE_CIRCLE: StringName = &"ss_guide_circle"
const META_GUIDE_FINGER: StringName = &"ss_guide_finger"


static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx, 480.0 - cy)   # Cocos 800×480 左下原点 → Godot 800×480 左上原点


## 显示尺寸（批3定稿通用公式）：像素÷CS×条目CS（content_scale_of 已封装
## "Prescaled=true 且 CS≠0 才施加"）。map_bg 系 Prescaled=true CS=2 与 frame 系
## Prescaled=false 在此公式下自动分轨。2026-08-21 Task5 修正后 TexDisplaySize.display_size
## 与本公式等价；本地保留因缺资源语义不同（本处返 ZERO，helper 返 45×45 fallback）。
static func display_size(res: String) -> Vector2:
	if res.is_empty() or not ResourceLoader.exists(res):
		return Vector2.ZERO
	var tex: Texture2D = load(res) as Texture2D
	if tex == null:
		return Vector2.ZERO
	return tex.get_size() / CONTENT_SCALE * TexSize.content_scale_of(res)


## fill .tscn %ModeNormalBtn/EliteBtn/GuildBtn 纹理（selected=elitetoggle-s 否则 ns）+ Label
## LSTR 文本（源 doModeButtonTouch :347-362 press 切换 + updateModeButtonState :292-318）。
## 位置/size/stretch_mode 已固化 .tscn，此处只切纹理 + 填文本（TextureButton normal 双态
## 简化，源 Sprite+press 切 visible 等价）。fontinfo "ui_normal_button" size=18。
static func fill_mode_toggle(buttons: Dictionary, current_mode: String, cm: Variant) -> void:
	var lstr_keys: Dictionary = {
		"normal": "STAGESELECT.NORMAL",
		"elite": "EQUIPCRAFT.ELITE",
		"guild": "STAGESELECT.RAID",
	}
	for mode in buttons:
		var btn: TextureButton = buttons[mode]
		var selected: bool = mode == current_mode
		var res_path: String = MODE_TOGGLE_S if selected else MODE_TOGGLE_NS
		if ResourceLoader.exists(res_path):
			btn.texture_normal = load(res_path) as Texture2D
		var lbl: Label = null
		for child in btn.get_children():
			if child is Label:
				lbl = child
				break
		if lbl != null:
			var key: String = String(lstr_keys[mode])
			lbl.text = String(cm.get_lstr(key)) if cm != null else key


## 建 map layer（源 createMap:1359 + createStage:1212）：裁剪层 + 章节 bg/route +
## stage 圆点按钮（含 stars/key mask/pointer）。返回 {node, stage_buttons(sid->TextureButton)}。
## 子坐标减 CLIP_OFFSET 进 layer 局部空间；mask 与 btn 平级且先声明（源 :1229-1241
## mask 先 add、icon 后 add 盖 mask，闪烁光圈露边）。
static func create_map_layer(container: Control, chapter: int, mode: String, cm: Variant, star_of: Callable) -> Dictionary:
	var layer := Control.new()
	layer.name = "MapLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.clip_contents = true
	layer.position = CLIP_RECT.position
	layer.size = CLIP_RECT.size
	container.add_child(layer)
	var ch: Dictionary = StageSelectMapClass.get_chapter(chapter)
	_make_centered_child(layer, StageSelectMapClass.get_bg_res(chapter), ch.get("bg", {}).get("pos", [400, 212]))
	_make_centered_child(layer, StageSelectMapClass.get_route_res(chapter), ch.get("route", {}).get("pos", [400, 212]))
	var tag: int = StageSelectMapClass.get_tag(chapter)
	var buttons: Dictionary = {}
	for s in StageSelectMapClass.get_stages(chapter):
		var info: Dictionary = s
		var dec: Dictionary = StageSelectMapClass.decide_stage_icon(info, tag, mode, cm, star_of)
		var icon_res: String = String(dec["icon"])
		if icon_res.is_empty() or not ResourceLoader.exists(icon_res):
			continue
		var pos: Array = info.get("pos", [0, 0])
		var center: Vector2 = to_godot(float(pos[0]), float(pos[1])) - CLIP_OFFSET
		var dec_type := String(dec["type"])
		if dec_type != "locked":
			_add_key_mask(layer, String(dec.get("mask", "")), center)
		var btn := TextureButton.new()
		# 命中层（无纹理的 TextureButton 仍是有效 BaseButton，rect 即命中区）；
		# 贴图改子 TextureRect 绘制——视觉尺寸/位置照旧，不随命中层缩放（见
		# STAGE_HIT_SIZE 注释，源圆形命中 r45 直译）。
		btn.size = Vector2(STAGE_HIT_SIZE, STAGE_HIT_SIZE)
		btn.position = center - btn.size * 0.5
		# 2026-09-09 统一分发：按钮不再各自接收输入（树序 rect 命中在密集据点下互吞，
		# 数据序靠后 add 恒上层 + disabled 也吞输入，见 _add_hit_catcher 注释）。
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = load(icon_res) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = display_size(icon_res)
		icon.position = (btn.size - icon.size) * 0.5
		# pivot 居中：panel 按下 0.95 缩放反馈以关卡中心为基准（源 setScale 语义）
		icon.pivot_offset = icon.size * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
		btn.set_meta(&"stage_info", info)
		if dec_type == "locked":
			btn.disabled = true
		else:
			_add_stars(icon, info, mode, star_of)
		layer.add_child(btn)
		if dec_type == "current":
			_add_pointer(layer, info, CLIP_OFFSET)
		if dec_type != "locked":
			var sid: int = _current_sid(info, mode)
			if sid > 0:
				buttons[sid] = btn
	var catcher := _add_hit_catcher(layer)
	return {"node": layer, "stage_buttons": buttons, "hit_catcher": catcher}


## 输入捕获层（2026-09-09 统一分发）：覆盖整个裁剪区的透明 STOP Control，挂在按钮
## 之后（最上层），gui_input 由 panel 连接分发——在全部 stage 按钮中取"距点击最近中心
## （<r45）"者触发。替代按钮各自树序 rect 命中的根因：据点最小间距 41px < 命中层 90，
## 相邻按钮命中层互叠，数据序靠后 add 恒在上层优先命中，实测章 1 dot5 可见圆盘右 1/3
## 的点击被 dot6 吞且点中隔壁关无感知；disabled（locked）按钮同样吞输入。源
## doStageTouch :126-131 是 r45 圆形命中 + locked/passed 普通关不进命中循环，无此问题。
static func _add_hit_catcher(layer: Control) -> Control:
	var catcher := Control.new()
	catcher.name = "StageHitCatcher"
	catcher.set_meta(&"ss_hit_catcher", true)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.size = layer.size
	layer.add_child(catcher)
	return catcher


## 章节 bg/route（源 createMap :1386-1393 createSprite pos 直译，中心锚）。
static func _make_centered_child(parent: Node, res: String, cocos_pos: Variant) -> void:
	if res.is_empty() or not ResourceLoader.exists(res):
		return
	var tex: Texture2D = load(res) as Texture2D
	if tex == null:
		return
	var node := TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.size = display_size(res)
	var p: Array = cocos_pos if cocos_pos is Array else [400, 212]
	node.position = to_godot(float(p[0]), float(p[1])) - node.size * 0.5 - CLIP_OFFSET
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)


## 星级（源 createStage :1256-1274）：star:setPosition(spos) 挂 starBg 下——cocos 子节点
## position 原点=父 contentSize 左下角（与父锚点无关）→ godot star 中心=bg 左上角
## +(spos.x, bg.h-spos.y)，星组弧形嵌满胶囊（±20.7 对称、中星正中）。starBg 挂 icon 的
## 源位 (82,上38)=叠底座下缘（左下角口径），2026-08-31 二轮用户观感裁决「应该在顶部」
## 受控偏离为顶部 30（见 STAR_BG_TOP_Y 注释；水平由源 82≈半宽改精确半宽居中）。
## host = 贴图显示层（TextureRect，size=贴图显示尺寸；2026-09-07 命中根修后星级挂
## 贴图层下而非命中按钮，父 contentSize 口径与源 icon 一致）。
static func _add_stars(host: Control, info: Dictionary, mode: String, star_of: Callable) -> void:
	if mode == "guild":
		return
	var id: int = int(info.get("eid", 0)) if mode == "elite" else int(info.get("id", 0))
	if id <= 0 or not info.has("eid"):
		return
	var sn: int = int(star_of.call(id))
	if sn <= 0 or sn > 3:
		return
	var bg := TextureRect.new()
	bg.texture = load(STAR_BG) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = display_size(STAR_BG)
	# 三轮回滚一轮底部口径（原版真值证实，见 STAR_BG 定谳注释）
	bg.position = Vector2(82.0, host.size.y - 38.0) - bg.size * 0.5
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bg)
	var spos: Array = STAR_POS_SN[sn - 1]
	for i in range(sn):
		var star := TextureRect.new()
		star.texture = load(STAR) as Texture2D
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.size = display_size(STAR)
		star.position = Vector2((spos[i] as Vector2).x, bg.size.y - (spos[i] as Vector2).y) - star.size * 0.5
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(star)


## 当前关指针（源 :1298-1311 currentTag）：key 关 cpos=(x, y+60)、非 key 关 (x-1, y+30)。
## set_meta(META_POINTER) 供 panel _bob_all_pointers 启动上下浮动 tween。
static func _add_pointer(layer: Control, info: Dictionary, offset: Vector2 = Vector2.ZERO) -> void:
	if not ResourceLoader.exists(POINTER):
		return
	var pos: Array = info.get("pos", [0, 0])
	var is_key: bool = info.has("eid")
	var cx: float = float(pos[0]) - (0.0 if is_key else 1.0)
	var cy: float = float(pos[1]) + (60.0 if is_key else 30.0)
	var p := TextureRect.new()
	p.texture = load(POINTER) as Texture2D
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.size = display_size(POINTER)
	p.position = to_godot(cx, cy) - p.size * 0.5 - offset
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_meta(META_POINTER, true)
	layer.add_child(p)


## 钥匙关 current/passed mask（源 :1229-1238）：与 icon 平级同位、先声明（icon 盖 mask），
## set_meta(META_MASK) 供 panel _blink_all_masks 启动 alpha 循环闪烁。
static func _add_key_mask(layer: Control, mask_res: String, center_local: Vector2) -> void:
	if mask_res.is_empty() or not ResourceLoader.exists(mask_res):
		return
	var mask := TextureRect.new()
	mask.texture = load(mask_res) as Texture2D
	mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mask.size = display_size(mask_res)
	mask.position = center_local - mask.size * 0.5
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.set_meta(META_MASK, true)
	layer.add_child(mask)


static func _current_sid(info: Dictionary, mode: String) -> int:
	if mode == "elite":
		return int(info.get("eid", 0))
	if mode == "guild":
		return int(info.get("guildInstanceId", 0))
	return int(info.get("id", 0))


## frame + title_bg（源 createFrame:944 + createTitleBg:926）：mode 切换 crossfade 由
## panel 重建驱动。set_meta(META_FRAME) 供 panel 章节 op 识别跳过（源 createFrame 仅
## create/mode 调，:325/:1618）。z 序：titleBg z=21 压 modeContainer z=20（源 :941），
## ModeLayer 声明在 FrameLayer 后 → z_index 200 absolute 提到 mode 之上。
static func create_frame(container: Control, mode: String) -> void:
	# 源 stageselect.lua:967-969 frame ccp(400,207)/normal ccp(400,205) → godot (400,275/273)。
	# 2026-08-22 巡检订正：旧 (480,355/353) 是 960×640 旧口径残留（viewport 迁移漏网——本页
	# 不在 6 页对照内），frame 显示 730.34×395.61 右溢屏 45px/下溢屏 73px。
	var frame_y: float = 275.0 if mode == "normal" else 273.0
	var frame: CanvasItem = _make_centered_at(container, _frame_res(mode), Vector2(400.0, frame_y))
	if frame != null:
		frame.set_meta(META_FRAME, true)
	var title_bg: CanvasItem = _make_centered_at(container, _title_bg_res(mode), TITLE_CENTER)
	if title_bg != null:
		title_bg.set_meta(META_FRAME, true)
		# relative z=21/22：面板内盖过 mode 层(z=20)（tscn 声明序 map1<frame5<mode20），
		# effective=面板基准+21 恒低于上层弹窗（动态 z 栈基准差 100，2026-09-03 方案 B）。
		# 原 z=200/201+relative=false 系绝对全局层，会穿透 stage_detail 等子弹窗
		#（battle_prepare 曾以 z=210 压它，见 battle_prepare_panel.gd:97 注释）。
		title_bg.z_index = 21
		title_bg.z_as_relative = true


## 章节标题 Label（源 createTitleText:861：Pre Chapter Name + Chapter Name，色
## ccc3(250,205,16) size18 走 StageTitleLabel variation；章节切换 crossfade 由 panel
## 重建驱动，set_meta(META_TITLE) 供识别）。
static func create_title(container: Control, chapter: int, cm: Variant) -> void:
	var chapter_table: Dictionary = cm.get_raw_table(&"Chapter")
	var ch_row: Dictionary = chapter_table.get(str(chapter), {})
	var pre: String = _lstr(cm, String(ch_row.get("Pre Chapter Name", "")))
	var name: String = _lstr(cm, String(ch_row.get("Chapter Name", "")))
	var lbl := Label.new()
	lbl.text = pre + "   " + name if not name.is_empty() else ("第 " + str(chapter) + " 章")
	lbl.theme_type_variation = &"StageTitleLabel"
	lbl.position = TITLE_CENTER - Vector2(120.0, 12.0)
	lbl.size = Vector2(240.0, 24.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# relative z=22（title_bg 21 之上，mode 层 20 之下界），见 create_map_layer 标题注释（方案 B）。
	lbl.z_index = 22
	lbl.z_as_relative = true
	lbl.set_meta(META_TITLE, true)
	container.add_child(lbl)


## Chapter/Stage Name 存 LSTR key，get_lstr 本地化。
static func _lstr(cm: Variant, key: String) -> String:
	if cm == null or key.is_empty():
		return key
	return String(cm.get_lstr(key))


static func _frame_res(mode: String) -> String:
	return FRAME_ELITE if mode == "elite" else (FRAME_GUILD if mode == "guild" else FRAME_NORMAL)


static func _title_bg_res(mode: String) -> String:
	return TITLE_BG_ELITE if mode == "elite" else (TITLE_BG_GUILD if mode == "guild" else TITLE_BG_NORMAL)


static func _make_centered_at(parent: Node, res: String, godot_center: Vector2) -> CanvasItem:
	if res.is_empty() or not ResourceLoader.exists(res):
		return null
	var tex: Texture2D = load(res) as Texture2D
	if tex == null:
		return null
	var node := TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.size = display_size(res)
	node.position = godot_center - node.size * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


## chapter dots（源 createDot:676 + getDotPos:76）：数量 1..max_chapter 动态，位置
## x = 480 + gap*(i-center)、y normal 520/elite 515（guild 由 panel 隐藏容器，源 :698-702）。
static func create_chapter_dots(container: Control, max_chapter: int, current: int, mode: String) -> void:
	var y: float = DOT_ELITE_Y if mode == "elite" else DOT_NORMAL_Y
	var center: float = (float(max_chapter) + 1.0) * 0.5
	for i in range(1, max_chapter + 1):
		var res: String = DOT_CURRENT if i == current else DOT_NORMAL
		if not ResourceLoader.exists(res):
			continue
		var dot := TextureRect.new()
		dot.texture = load(res) as Texture2D
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.size = display_size(res)
		dot.position = Vector2(DOT_CENTER_X + DOT_GAP_X * (float(i) - center), y) - dot.size * 0.5
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(dot)


## 获取途径引导节点（源 createStage :1331-1351 forGetWay）：目标关按钮层叠 tutorial_circle
## （中心锚呼吸圈，pivot 居中供 panel 缩放动画）+ tutorial_finger（源 anchor(0,1)=左上角
## @ccp(x-4,y+4) 中心上方 4 → Godot 左上锚 (x-4,y-4)）。动画归 panel（_guide_circle_breath/
## _guide_finger_slide）。mouse_filter=IGNORE（装饰节点红线）。
static func attach_get_way_guide(layer: Control, btn: TextureButton) -> void:
	var center: Vector2 = btn.position + btn.size * 0.5
	var circle := TextureRect.new()
	circle.texture = load(GUIDE_CIRCLE_RES) as Texture2D
	circle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var csize: Vector2 = display_size(GUIDE_CIRCLE_RES)
	circle.size = csize
	circle.position = center - csize * 0.5
	circle.pivot_offset = csize * 0.5
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.set_meta(META_GUIDE_CIRCLE, true)
	layer.add_child(circle)
	var finger := TextureRect.new()
	finger.texture = load(GUIDE_FINGER_RES) as Texture2D
	finger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	finger.size = display_size(GUIDE_FINGER_RES)
	finger.position = Vector2(center.x - 4.0, center.y - 4.0)
	finger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finger.set_meta(META_GUIDE_FINGER, true)
	layer.add_child(finger)
