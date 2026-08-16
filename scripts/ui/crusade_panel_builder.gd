class_name CrusadePanelBuilder
extends RefCounted

## crusade 静态美术层 procedural 工厂（批3 Task 4 起 dungeon_map 侧已两件套静态化
## 进 dungeon_map_content.tscn，build_dungeon_map 退役；本文件仅剩 crusade 消费方，
## crusade panel 两件套改造时（批3 Task 5/6）整体消亡）。
## 照源 crusadeconfig.lua 补 5 类缺美术：
##   1. 三段滚动背景 crusade_detail_bg1/2/3.png（:17/30/43 pos 25/752/1477 scale=2.0）
##   2. 外框 crusade_map_frame.png（:919 pos 400,240）
##   3. 光效 crusade_map_frame_light1/2.png（:897/908 pos 400,240）
##   4. 标题底 crusade_title_bg.png（:930 pos 402,395）
##   5. 底部栏 crusade_reset_bg.png（:957 Scale9 560×58 pos 400,55）
## 资产全在 res://assets/ui/alpha/HVGA/crusade/。
##
## 坐标系：源 cocos(800×480 左下原点) → Godot(960×640 左上原点)：(cx+80, 560-cy)。
## 注：bg1/2/3 在滚动内容坐标系（cocos 滚动层），frame/light/title/reset 在视口坐标系。

const BG1_RES: String = "res://assets/ui/alpha/HVGA/crusade/crusade_detail_bg1.png"
const BG2_RES: String = "res://assets/ui/alpha/HVGA/crusade/crusade_detail_bg2.png"
const BG3_RES: String = "res://assets/ui/alpha/HVGA/crusade/crusade_detail_bg3.png"
const FRAME_RES: String = "res://assets/ui/alpha/HVGA/crusade/crusade_map_frame.png"
const LIGHT1_RES: String = "res://assets/ui/alpha/HVGA/crusade/crusade_map_frame_light1.png"
const LIGHT2_RES: String = "res://assets/ui/alpha/HVGA/crusade/crusade_map_frame_light2.png"
const TITLE_BG_RES: String = "res://assets/ui/alpha/HVGA/crusade/crusade_title_bg.png"
const RESET_BG_RES: String = "res://assets/ui/alpha/HVGA/crusade/crusade_reset_bg.png"

# 源 cocos(800×480 左下) → Godot(960×640 左上)：(cx+80, 560-cy)。
# frame/light/title/reset 均用此变换定位（视口坐标系，挂 _content 根）。
const FRAME_GODOT_CENTER: Vector2 = Vector2(480.0, 320.0)   # cocos (400,240)
const TITLE_GODOT_CENTER: Vector2 = Vector2(482.0, 165.0)   # cocos (402,395)
const RESET_GODOT_CENTER: Vector2 = Vector2(480.0, 505.0)   # cocos (400,55)
# reset_bg Scale9 560×58（源 :957）。
const RESET_BG_SIZE: Vector2 = Vector2(560.0, 58.0)
# bg 在滚动内容坐标系（cocos），三段水平铺底：源 pos 25/752/1477（三段每段 ~720px 宽，cs=2 拉伸后约 934×508）。
# bg 在 section 内居中（section 宽 640×350，crusade 三段映射到滚动条目）。


## 为 crusade 场景建静态美术层。
## content: crusade_content.tscn 根（含 %FrameworkBg/%StageScroll/%StageHBox）。
## bg 挂 %StageScroll 内随滚动（与 %StageHBox 同层 sibling），frame/light/title/reset 挂 content。
## z 序：bg 在 HBox 之下（move_child 到 scroll 首位）；frame/light/title/reset 在 content 末尾（z 序最上），
## 由于 frame png 中心透明（仅外边框有像素），覆盖在 StageScroll 上方仅绘制边框线，不挡关卡交互。
static func build_crusade(content: Control) -> void:
	if content == null:
		return
	var stage_scroll: ScrollContainer = content.get_node("%StageScroll") as ScrollContainer
	# 1. 三段滚动背景（铺在关卡下方，move 到 scroll 首位让其在 HBox 之前绘制 = z 序在下）。
	if stage_scroll != null:
		_add_scroll_bg(stage_scroll, BG1_RES, 0, true)
		_add_scroll_bg(stage_scroll, BG2_RES, 1, true)
		_add_scroll_bg(stage_scroll, BG3_RES, 2, true)
	# 2. 外框（z 序最上，frame 中心透明仅绘制边框）。
	_add_centered(content, FRAME_RES, FRAME_GODOT_CENTER)
	# 3. 外框光效（外框上层）。
	_add_centered(content, LIGHT1_RES, FRAME_GODOT_CENTER)
	_add_centered(content, LIGHT2_RES, FRAME_GODOT_CENTER)
	# 4. 标题底。
	_add_centered(content, TITLE_BG_RES, TITLE_GODOT_CENTER)
	# 5. 底部栏（Scale9 拉伸到 560×58）。
	_add_scaled(content, RESET_BG_RES, RESET_GODOT_CENTER, RESET_BG_SIZE)


# ==================== 内部辅助 ====================

# 滚动背景：ScrollContainer 内 sibling Control，避免 HBox layout 干扰。
# section_idx 0/1/2：cocos x 25/752/1477 → 每段约 720px，挂 Scroll 局部坐标。
# move_to_front=true 时移到 scroll 子序列首位（绘制顺序 = z 序在下，铺在 HBox 关卡之下）。
static func _add_scroll_bg(scroll: ScrollContainer, res: String, section_idx: int, move_to_front: bool) -> void:
	if not ResourceLoader.exists(res):
		return
	var tex: Texture2D = load(res) as Texture2D
	if tex == null:
		return
	var display_size: Vector2 = TexDisplaySize.display_size(res)
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		return
	# 源三段水平排（25/752/1477 cocos x 中心，每段宽约 display_size.x）。
	# 直接照源 x 中心摆放（cocos→godot 不缩放 x，仅平移到 section 起点）。
	var section_x_centers: Array[float] = [25.0, 752.0, 1477.0]
	var cx: float = section_x_centers[section_idx]
	# bg y 中心：源地图区水平线（cocos y≈250，godot 局部约 110）。bg 比关卡稍低，铺底。
	var cy: float = 110.0
	var node := TextureRect.new()
	node.name = "ScrollBg" + str(section_idx + 1)
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.size = display_size
	node.position = Vector2(cx - display_size.x * 0.5, cy - display_size.y * 0.5)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(node)
	if move_to_front:
		scroll.move_child(node, 0)


# content 子：纹理居中铺（用 display_size 自动含 ContentScale）。
static func _add_centered(parent: Node, res: String, godot_center: Vector2) -> void:
	if not ResourceLoader.exists(res):
		return
	var tex: Texture2D = load(res) as Texture2D
	if tex == null:
		return
	var display_size: Vector2 = TexDisplaySize.display_size(res)
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		return
	var node := TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.size = display_size
	node.position = godot_center - display_size * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)


# content 子：纹理拉伸到指定 size（源 Scale9 等价，本项目简单拉伸）。
static func _add_scaled(parent: Node, res: String, godot_center: Vector2, target_size: Vector2) -> void:
	if not ResourceLoader.exists(res):
		return
	var tex: Texture2D = load(res) as Texture2D
	if tex == null:
		return
	var node := TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.size = target_size
	node.position = godot_center - target_size * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
