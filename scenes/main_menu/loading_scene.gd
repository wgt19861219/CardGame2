extends Control

## 加载场景（View 层 Step 4.2）：启动入口过渡 + 启动公告。
## 单机版资源随 PCK 加载，进度条走满后不直接切主城——弹启动公告窗（数据 =
## ActivitiesConfig announcement，与主城活动入口公告同源），玩家点「进入游戏」再切
## （源 loading.lua 的 Godot 适配 + 启动公告受控增强，2026-10-13 用户指示）。
## 节点动态建（避 MCP add_node 的 parent path bug）。

const PROGRESS_SPEED: float = 1.0   # 进度增速（约 1s 满）
const PERCENT_FULL: float = 100.0
const PROGRESS_DONE: float = 1.0
const MAIN_SCENE: String = "res://scenes/main_menu/main_scene.tscn"
# 背景（2026-10-13 换正确 loading 背景图：原 HVGA bg.jpg 512×308 拉伸 800×480 模糊无焦点；
# icecrown 1456×794 缩小显示零损失，KEEP_ASPECT_COVERED 裁两侧保比例铺满）。
const BG_TEXTURE: String = "res://assets/ui/lich/bg_icecrown.png"
const CS: float = 1.28125   # hello.lua:311 ContentScaleFactor（贴图显示尺寸=px÷CS）

# 进度条照源复刻（源 loading.lua:33-43：herodetail-xp-bg 槽 setScaleX(1.5)/setScaleY(0.5)
# 中心 Cocos(400,100)；fill herodetail-xp 裁 CCRectMake(19,10,200,8) setScaleX(progress)）。
# 309×37px ÷CS = 241.2×28.87 点 ×源 scale(1.5,0.5) = 361.8×14.4 点；Cocos y=100 → Godot y=380。
const BAR_BG_RES: String = "res://assets/ui/alpha/HVGA/herodetail-xp-bg.png"
const BAR_FILL_RES: String = "res://assets/ui/alpha/HVGA/herodetail-xp.png"
const BAR_SRC_REGION: Rect2 = Rect2(19.0, 10.0, 200.0, 8.0)   # 源 CCRectMake(19,10,200,8) 槽区
const BAR_SIZE: Vector2 = Vector2(361.8, 14.4)
const BAR_CENTER: Vector2 = Vector2(400.0, 380.0)
# fill 对齐槽区（槽区纹理坐标 19/10 起 → 条内等比例点坐标；满宽 200px 槽 → 200/309×361.8）。
const FILL_OFFSET: Vector2 = Vector2(22.2, 3.9)
const FILL_FULL_W: float = 234.2
const FILL_H: float = 3.1
# 百分比文字（源无百分比，迁移期既有增强保留；挪回屏内——旧 (430,555)/(330,580) 超出 800×480）。
const LABEL_CENTER_Y: float = 347.0
const LABEL_RECT: Vector2 = Vector2(400.0, 26.0)

# 启动公告窗（hero_evolve_announce 同款 main_vit_tips Scale9 底板口径）。
# 正文上下滚动（2026-10-13 用户指示）：ScrollContainer 裁切（clip_contents）+
# 禁横向滚动；「进入游戏」按钮放弹窗外面下方（2026-10-13 用户修正，不压弹窗底板）。
const ANNOUNCE_TABLE: StringName = &"ActivitiesConfig"
const ANNOUNCE_KEY: String = "announcement"
const ANNOUNCE_BG_RES: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const ANNOUNCE_PATCH: Rect2 = Rect2(10.0, 25.0, 58.0, 26.0)   # cap(10,10,58,26) 同 avatar 换算
const ANNOUNCE_SIZE: Vector2 = Vector2(410.0, 290.0)
const ANNOUNCE_TOPLEFT: Vector2 = Vector2(195.0, 65.0)
const SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 150.0 / 255.0)   # 项目弹窗统一遮罩深度
const TITLE_COLOR: Color = Color(241.0 / 255.0, 193.0 / 255.0, 113.0 / 255.0)   # 源 ccc3(241,193,113)
const TITLE_FONT: int = 22
const TITLE_TOP: float = 90.0
const BODY_TOP: float = 128.0
const BODY_BOTTOM: float = 340.0
const BODY_W: float = 340.0
const ENTER_BTN_W: float = 120.0
const ENTER_BTN_H: float = 49.0
const ENTER_BTN_TOP: float = 372.0   # 弹窗底(355)之下、屏幕底(480)之上，居 x=400
const DEFAULT_TITLE: String = "公告"
const DEFAULT_DESC: String = "欢迎体验！更多精彩活动敬请期待。"
const DEFAULT_RULES: String = "游戏当前为单机体验版，更多玩法与活动持续开放中，敬请期待。"

var _bg: TextureRect
var _bar_bg: TextureRect
var _bar_fill: TextureRect
var _label: Label
var _announce_root: Control
var _progress: float = 0.0

func _ready() -> void:
	_build_ui()

## 动态建背景 + 进度条 + 百分比（不依赖 .tscn 子节点，治 MCP parent path bug）。
func _build_ui() -> void:
	_bg = TextureRect.new()
	_bg.texture = load(BG_TEXTURE) as Texture2D
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# 显式全屏 size（不靠 anchors）：loading_scene 根 Control 未设全屏锚点，子节点 anchors 算出
	# size=0；直接取 viewport size 铺满（照源 loading.lua:29 bg 铺满屏）。COVERED 裁两侧保比例。
	_bg.position = Vector2.ZERO
	_bg.size = get_viewport_rect().size
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_bar_bg = _make_bar_rect(BAR_BG_RES)
	_bar_bg.position = BAR_CENTER - BAR_SIZE * 0.5
	_bar_bg.size = BAR_SIZE
	add_child(_bar_bg)
	_bar_fill = _make_bar_rect(BAR_FILL_RES)
	# fill 包 AtlasTexture 走 region 裁剪（TextureRect 无裁剪属性，volume_bar 同范式；
	# 显式 position/size 防锚定被 region 变更通知链重置——实机判例）。
	var atlas := AtlasTexture.new()
	atlas.atlas = load(BAR_FILL_RES) as Texture2D
	atlas.region = Rect2(Vector2.ZERO, Vector2.ZERO)
	_bar_fill.texture = atlas
	_bar_fill.position = _bar_bg.position + FILL_OFFSET
	add_child(_bar_fill)
	_label = Label.new()
	_label.text = "0%"
	_label.theme_type_variation = &"DialogMsgLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(BAR_CENTER.x - LABEL_RECT.x * 0.5, LABEL_CENTER_Y - LABEL_RECT.y * 0.5)
	_label.size = LABEL_RECT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func _make_bar_rect(res: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(res) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _process(delta: float) -> void:
	_progress = minf(_progress + delta * PROGRESS_SPEED, PROGRESS_DONE)
	_refresh_bar()
	if _progress >= PROGRESS_DONE:
		set_process(false)
		_show_announcement()

## 裁剪式填充（volume_bar 范式）：region 显示源纹理槽区左段 progress 比例，
## fill.size 宽同步 ×比例——裁剪区与显示区恒等比，图案不拉伸变形。
func _refresh_bar() -> void:
	_label.text = "%d%%" % int(_progress * PERCENT_FULL)
	if _bar_fill == null or not (_bar_fill.texture is AtlasTexture):
		return
	var atlas: AtlasTexture = _bar_fill.texture
	atlas.region = Rect2(BAR_SRC_REGION.position,
			Vector2(BAR_SRC_REGION.size.x * _progress, BAR_SRC_REGION.size.y))
	_bar_fill.size = Vector2(FILL_FULL_W * _progress, FILL_H)

## 进度满弹启动公告窗：shade + main_vit_tips Scale9 底板 + 标题/正文 + 进入按钮。
## 数据取 ActivitiesConfig announcement（主城活动公告同源）；表缺失/空条目走默认文案。
func _show_announcement() -> void:
	var data: Dictionary = _announce_data()
	var title_text: String = String(data.get("title", DEFAULT_TITLE))
	if title_text == "":
		title_text = DEFAULT_TITLE
	var body_text: String = "%s\n\n%s" % [
		String(data.get("desc", DEFAULT_DESC)), String(data.get("rules", DEFAULT_RULES))]
	_announce_root = Control.new()
	_announce_root.name = "AnnounceRoot"
	_announce_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_announce_root)
	var shade := ColorRect.new()
	shade.color = SHADE_COLOR
	shade.position = Vector2.ZERO
	shade.size = get_viewport_rect().size
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_announce_root.add_child(shade)
	var frame := NinePatchRect.new()
	frame.name = "Frame"
	frame.texture = load(ANNOUNCE_BG_RES) as Texture2D
	frame.patch_margin_left = int(ANNOUNCE_PATCH.position.x)
	frame.patch_margin_top = int(ANNOUNCE_PATCH.position.y)
	frame.patch_margin_right = int(ANNOUNCE_PATCH.size.x)
	frame.patch_margin_bottom = int(ANNOUNCE_PATCH.size.y)
	frame.position = ANNOUNCE_TOPLEFT
	frame.size = ANNOUNCE_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announce_root.add_child(frame)
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = title_text
	title.add_theme_font_size_override("font_size", TITLE_FONT)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(ANNOUNCE_TOPLEFT.x, TITLE_TOP)
	title.size = Vector2(ANNOUNCE_SIZE.x, TITLE_FONT + 4.0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announce_root.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "BodyScroll"
	scroll.position = Vector2(BAR_CENTER.x - BODY_W * 0.5, BODY_TOP)
	scroll.size = Vector2(BODY_W, BODY_BOTTOM - BODY_TOP)
	scroll.clip_contents = true   # 用户指示注意裁切：正文溢出可视区即裁掉，不出底板
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED   # 只上下滚动
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_announce_root.add_child(scroll)
	var body := Label.new()
	body.name = "BodyLabel"
	body.text = body_text
	body.theme_type_variation = &"DialogMsgLabel"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.custom_minimum_size = Vector2(BODY_W, 0.0)   # 撑宽约束 autowrap；高度随内容
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(body)
	var enter := Button.new()
	enter.name = "EnterBtn"
	enter.text = "进入游戏"
	enter.theme_type_variation = &"DialogConfirmBtn"
	enter.position = Vector2(BAR_CENTER.x - ENTER_BTN_W * 0.5, ENTER_BTN_TOP)
	enter.size = Vector2(ENTER_BTN_W, ENTER_BTN_H)
	enter.pressed.connect(_on_enter_pressed)
	_announce_root.add_child(enter)

## 公告数据（loading 阶段 GameData.config 已就绪：autoload _ready 同步 load_all 先于场景）。
func _announce_data() -> Dictionary:
	if GameData.config == null:
		return {}
	return GameData.config.get_raw_table(ANNOUNCE_TABLE).get(ANNOUNCE_KEY, {})

func _on_enter_pressed() -> void:
	SceneManager.change_scene(MAIN_SCENE)
