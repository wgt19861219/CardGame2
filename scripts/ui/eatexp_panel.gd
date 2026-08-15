class_name EatexpPanel
extends PopWindow

## 消耗经验药弹窗（View 层）— 照源 ui/popwindow/eatexplist.lua（723 行）。
## 从 EquipboardPanel consume 分支进入。选英雄喂药：扣物品 + 加经验 + 经验条动画 + 飘字。
## 单机化：去掉 doSendConsume 网络上报（源 ed.send consume_item + registerNetReply eat_exp），
## 改即时生效（do_eat_hero 直接 pd.remove_item + hero_manager.add_hero_exp，无 useAmount 延迟累计）。
## 长按连续喂药：源 keepeatHandler 加速曲线（oriSpeed/accAcc）简化为固定间隔 repeat。
##
## 两件套范式（批 1 Task 3，2026-08-15）：框架静态树进 eatexp_content.tscn（frame/title/
## close/滚动层/顶部提示行），英雄行结构进 eatexp_item.tscn（行模板）；本文件只做业务、
## 信号 connect、fill（零静态节点构造，工厂调用除外）。静态色/字号走 Eatexp* variation。
## 坐标：源 cocos(800x480 左下) → Godot(960x640 左上)；行内 bg 局部 y-up → 行局部
## y-down（gy=96-y），换算细节见两 tscn 头注。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/eatexp_content.tscn")
const ITEM_SCENE: PackedScene = preload("res://scenes/ui/eatexp_item.tscn")

# ── 动画/长按时序（源 getBarAction animDuration=0.5 + keepeatHandler delay=0.5）──
const ANIM_DUR: float = 0.4
const ANIM_FILL_RATIO: float = 0.4   # 升级动画填满段时长占比
const ANIM_END_RATIO: float = 0.6    # 升级动画末段时长占比
const KEEPEAT_DELAY: float = 0.5
const KEEPEAT_INTERVAL: float = 0.08
const EAT_LIFETIME: float = 0.3
const EAT_FADE: float = 0.2

# ── 行内动态布局（静态定位已进行模板；源 ow=100 名字超宽等比缩）──
const NAME_MAX_W: float = 100.0        # 源 :242 ow
const NAME_RIGHT_X: float = 178.0      # 源 :246 名字右端 x
# ── 列表布局（源 createList :186-199 两列 245 列距/100 行距；:199 initListHeight 尾部 -5+70）──
const GRID_COLS: int = 2
const LIST_ROW_PITCH: float = 100.0
const LIST_HEIGHT_TAIL: float = 65.0
const LIST_HOST_W: float = 570.0
# ── 吃经验飘字（源 showEatAmount :534-545 "x"+累计 at (210,42) → 行局部 (210, 96-42)；
#    源 light_orange 数字图无迁移资源 → Label 近似，受控偏离见任务报告）──
const EAT_LBL_POS: Vector2 = Vector2(210.0, 54.0)
const EAT_LBL_COLOR: Color = Color(1.0, 200.0 / 255.0, 0.0)
const EAT_LBL_FONT_SIZE: int = 20
# ── 属性 mark（源 :248-260 HERO_EQUIP.STRENGTH/AGILITY/INTELLIGENCE → Unit.Main Attrib，
#    同 hero_package_item 口径；icon 资产 2026-07-18 已补齐）──
const MARK_RES: Dictionary = {
	"STR": "res://assets/ui/alpha/HVGA/icon_str.png",
	"AGI": "res://assets/ui/alpha/HVGA/icon_agi.png",
	"INT": "res://assets/ui/alpha/HVGA/icon_int.png",
}

# ── 文本（源 LSTR key，运行时 cm.get_lstr 解析）──
const LSTR_TITLE: String = "EATEXPLIST.CHOOSE_A_HERO"
const LSTR_PROMPT: String = "eatexplist.1.10.1.001"
const LSTR_EXP_FULL: String = "EATEXPLIST.EXPERIENCE_FULL"
const LSTR_HERO_EXP_FULL: String = "EATEXPLIST.HERO_EXPERIENCE_FULL"
const LSTR_ALL_USED: String = "EATEXPLIST.ALL_COMSUMED"

var cm: Variant = null
var pd: PlayerData = null
var _item_id: int = 0          # 经验药物品 id（源 self.id）
var _exp_per_pill: int = 0
var _content: Control = null   # .tscn 根
var _grid: GridContainer = null
var _list_host: Control = null
var _cells: Dictionary = {}    # inst_id → {cell, level_label, exp_bar, display_level, eat_count, is_max}
var _keepeat_inst: int = -1    # 长按目标 inst_id（-1=空闲）


# LSTR 解析包装（源 T(LSTR(key)) 等价；cm 缺失返空串避免 null 解引用）。
func _T(key: String) -> String:
	if cm == null:
		return ""
	return String(cm.get_lstr(key))


# 经验药物品名（源 useProp :8 equip[id].Name，LSTR key → 当前语言）
func _equip_name() -> String:
	var name_key: String = String(cm.get_raw_table(&"Equip").get(str(_item_id), {}).get("Name", ""))
	return _T(name_key)


func setup_panel(item_id: int, p_cm: Variant, p_pd: PlayerData) -> void:
	play_open_sfx = true   # T4：原 register_on_enter 音效样板上收基类
	_item_id = item_id
	cm = p_cm
	pd = p_pd
	_exp_per_pill = int(cm.get_raw_table(&"Equip").get(str(item_id), {}).get(&"Exp", 0))
	setup()
	_build_content()
	# 行 fill 挂 on_enter：入树后 theme 上下文才准（name 拼宽依赖 get_combined_minimum_size，
	# stone_detail 同款时序结论）。
	register_on_enter(_build_hero_rows)


# 绑定 .tscn 静态节点 + fill 静态文案（动态数据行走 _build_hero_rows）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	(_content.get_node("%TitleLabel") as Label).text = _T(LSTR_TITLE)
	# 顶部提示行（源 createList :176-185 "长按英雄头像…" + 物品名，迁移期漏译本批补全）
	(_content.get_node("%PromptLabel") as Label).text = "%s %s" % [_T(LSTR_PROMPT), _equip_name()]
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close_pressed)
	_grid = _content.get_node("%Grid") as GridContainer
	_list_host = _content.get_node("%ListHost") as Control


# 英雄行列表（源 createList :171-201）：行模板 instantiate + fill 挂 Grid 两列；
# 滚动内容高照源 initListHeight(:199) = ceil(len/2)*100 - 5 + 70。
func _build_hero_rows() -> void:
	var inst_ids: Array = pd.hero_manager.heroes.keys()
	inst_ids.sort()
	for inst_id in inst_ids:
		var hero: HeroInstance = pd.hero_manager.get_hero(int(inst_id))
		if hero == null:
			continue
		var row: Control = _build_one_row(int(inst_id), hero)
		_grid.add_child(row)
		# name 定位须在行入树后（get_combined_minimum_size 需 theme 上下文，stone_detail 同款）
		_fill_name(row, hero)
	var rows: int = (inst_ids.size() + GRID_COLS - 1) / GRID_COLS
	_list_host.custom_minimum_size = Vector2(LIST_HOST_W, rows * LIST_ROW_PITCH + LIST_HEIGHT_TAIL)


# 单行英雄（源 createHero :204-302）：行模板静态结构 + 动态数据 fill。
func _build_one_row(inst_id: int, hero: HeroInstance) -> Control:
	var row: Control = ITEM_SCENE.instantiate() as Control
	var cd: Dictionary = {
		"cell": row,
		"level_label": row.get_node("%LevelLabel") as Label,
		"exp_bar": row.get_node("%ExpBar") as TextureRect,
		"display_level": int(hero.level),
		"eat_count": 0,
		"is_max": false,
	}
	_cells[inst_id] = cd
	# head（源 :210-224 readhero.createIconByID + setLevelVisible(false) → setup 不传 level）
	var head := ReadheroIcon.new()
	head.setup({"id": int(hero.tid), "rank": int(hero.rank), "stars": int(hero.stars)}, cm)
	(row.get_node("%HeadHost") as Control).add_child(head)
	(cd["level_label"] as Label).text = "LV:%d" % int(hero.level)
	_fill_mark(row, hero)
	_fill_exp_state(row, cd, hero)
	row.gui_input.connect(func(ev: InputEvent) -> void: _on_cell_gui_input(ev, inst_id))
	return row


# 名字 + rank 星后缀（源 :239-247 createHeroNameByInfo readhero.lua:939-985）：
# 名字白 size20 黑阴影(0,2)（variation）；"+星" 后缀色 getHeroNameColorByRank；
# 整体右端对齐 178（源 nameLabel 右端 x=178 向左延伸），超宽等比缩 min(ow=100, w)。
func _fill_name(row: Control, hero: HeroInstance) -> void:
	var name_lbl: Label = row.get_node("%NameLabel") as Label
	var suffix_lbl: Label = row.get_node("%SuffixLabel") as Label
	name_lbl.text = cm.get_lstr(String(cm.get_raw_table(&"Unit").get(str(hero.tid), {}).get("Display Name", str(hero.tid))))
	var rank: int = int(hero.rank)
	var star: int = ReadheroHandbook.get_hero_star_by_rank(rank)
	var name_w: float = name_lbl.get_combined_minimum_size().x
	var total_w: float = name_w
	if star > 0:
		suffix_lbl.text = "+%d" % star
		suffix_lbl.add_theme_color_override("font_color", ReadheroHandbook.get_hero_name_color_by_rank(rank))
		suffix_lbl.visible = true
		total_w += suffix_lbl.get_combined_minimum_size().x
	var scale_v: float = min(1.0, NAME_MAX_W / total_w) if total_w > 0.0 else 1.0
	name_lbl.scale = Vector2(scale_v, scale_v)
	suffix_lbl.scale = Vector2(scale_v, scale_v)
	var render_w: float = total_w * scale_v
	name_lbl.position = Vector2(NAME_RIGHT_X - render_w, name_lbl.position.y)
	suffix_lbl.position = Vector2(NAME_RIGHT_X - render_w + name_w * scale_v, suffix_lbl.position.y)


# 属性 mark（源 :248-260 icon_str/agi/int 中心 (110,72) scale 0.8）：
# 按Unit.Main Attrib 选图（hero_package_item 同口径），无对应隐藏。
func _fill_mark(row: Control, hero: HeroInstance) -> void:
	var mark: TextureRect = row.get_node("%MarkRect") as TextureRect
	var attrib: String = String(cm.get_raw_table(&"Unit").get(str(hero.tid), {}).get("Main Attrib", ""))
	var res_path: String = String(MARK_RES.get(attrib, "")) if not attrib.is_empty() else ""
	if res_path.is_empty():
		mark.visible = false
		return
	var tex: Texture2D = _load_tex(res_path)
	if tex == null:
		mark.visible = false
		return
	mark.texture = tex
	mark.visible = true


# 经验条初始态（源 :282-300：满级走 setExpMax 三件，普通 expBar scaleX=min(exp/maxExp,1)）。
func _fill_exp_state(row: Control, cd: Dictionary, hero: HeroInstance) -> void:
	if _is_hero_max_level(hero):
		_apply_max_visual(row, cd)
		return
	var bar: TextureRect = cd["exp_bar"]
	bar.scale = Vector2(_bar_scale(hero), 1.0)


# 满级视觉（源 setExpMax :397-437）：expBar 隐 + fullBar(heroxp-progress-full) +
# 整行 package_hero_shade + "经验已满" size22 (255,148,62)。初始与升级到满共用。
func _apply_max_visual(row: Control, cd: Dictionary) -> void:
	(row.get_node("%ExpBar") as TextureRect).visible = false
	(row.get_node("%ExpFullBar") as TextureRect).visible = true
	(row.get_node("%MaxShade") as TextureRect).visible = true
	var shade_lbl: Label = row.get_node("%ShadeLabel") as Label
	shade_lbl.text = _T(LSTR_EXP_FULL)
	shade_lbl.visible = true
	cd["exp_bar"] = null
	cd["is_max"] = true


func do_eat_hero(inst_id: int) -> void:
	if not is_instance_valid(self):
		return
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	if hero == null:
		return
	if _is_hero_max_level(hero):
		_show_toast(_T(LSTR_HERO_EXP_FULL))
		return
	if int(pd.items.get(_item_id, 0)) <= 0:
		_show_toast("%s %s" % [_equip_name(), _T(LSTR_ALL_USED)])
		return
	var olevel: int = hero.level
	var oexp: int = hero.exp
	if pd.remove_item(_item_id, 1) <= 0:
		return
	pd.hero_manager.add_hero_exp(inst_id, _exp_per_pill)
	GameData.save()
	_play_bar_anim(inst_id, olevel, oexp, hero.level, hero.exp)
	_show_eat_amount(inst_id)


# 简化：单段或升级两段 Tween（保留升级视觉，简化加速曲线）；吃到满级后切满级三件。
func _play_bar_anim(inst_id: int, olevel: int, oexp: int, nlevel: int, nexp: int) -> void:
	var cd: Dictionary = _cells.get(inst_id, {})
	if cd.is_empty():
		return
	var bar: TextureRect = cd["exp_bar"]
	var lvl_lbl: Label = cd["level_label"]
	var is_max: bool = _is_hero_max_level_by_level(nlevel)
	var start_scale: float = _scale_for(oexp, olevel)
	var end_scale: float = 1.0 if is_max else _scale_for(nexp, nlevel)
	bar.scale.x = start_scale
	var tw := create_tween()
	if nlevel > olevel:
		tw.tween_property(bar, "scale:x", 1.0, ANIM_DUR * ANIM_FILL_RATIO)
		tw.tween_callback(_make_levelup_callback(bar, cd, lvl_lbl))
		tw.tween_property(bar, "scale:x", end_scale, ANIM_DUR * ANIM_END_RATIO)
	else:
		tw.tween_property(bar, "scale:x", end_scale, ANIM_DUR)
	if is_max:
		tw.tween_callback(_make_max_callback(cd["cell"], cd))


# 升级 callback 工厂（避免内联多行 lambda 在 tween_callback 内的缩进歧义）。
func _make_levelup_callback(bar: TextureRect, cd: Dictionary, lvl_lbl: Label) -> Callable:
	return func() -> void:
		bar.scale.x = 0.0
		cd["display_level"] = int(cd["display_level"]) + 1
		lvl_lbl.text = "LV:%d" % int(cd["display_level"])


# 满级切换 callback 工厂（动画播完切 setExpMax 视觉，源 getBarAction 末段 isMax 分支）。
func _make_max_callback(row: Control, cd: Dictionary) -> Callable:
	return func() -> void:
		_apply_max_visual(row, cd)


func _scale_for(exp: int, level: int) -> float:
	var lv_exp: int = _levelup_exp(level)
	if lv_exp <= 0:
		return 1.0
	return clampf(float(exp) / float(lv_exp), 0.0, 1.0)


func _bar_scale(hero: HeroInstance) -> float:
	return _scale_for(int(hero.exp), int(hero.level))


# 吃经验飘字（源 showEatAmount :519-557）："x"+该英雄本次弹窗累计次数，0.3s 后淡出销毁；
# 满级行不显示（源 isExpMax return）。
func _show_eat_amount(inst_id: int) -> void:
	var cd: Dictionary = _cells.get(inst_id, {})
	if cd.is_empty() or bool(cd["is_max"]):
		return
	var count: int = int(cd["eat_count"]) + 1
	cd["eat_count"] = count
	var lbl := Label.new()
	lbl.text = "x%d" % count
	lbl.position = EAT_LBL_POS
	lbl.modulate = EAT_LBL_COLOR
	lbl.add_theme_font_size_override("font_size", EAT_LBL_FONT_SIZE)
	(cd["cell"] as Control).add_child(lbl)
	var tw := create_tween()
	tw.tween_interval(EAT_LIFETIME)
	tw.tween_property(lbl, "modulate:a", 0.0, EAT_FADE)
	tw.tween_callback(lbl.queue_free)


func _on_cell_gui_input(event: InputEvent, inst_id: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		do_eat_hero(inst_id)
		_start_keepeat(inst_id)
	else:
		_stop_keepeat()


func _start_keepeat(inst_id: int) -> void:
	_keepeat_inst = inst_id
	var target: int = inst_id
	await get_tree().create_timer(KEEPEAT_DELAY).timeout
	while _keepeat_inst == target and is_instance_valid(self):
		do_eat_hero(target)
		await get_tree().create_timer(KEEPEAT_INTERVAL).timeout


func _stop_keepeat() -> void:
	_keepeat_inst = -1


# 单机化：无 playerlimit，靠 Levels 表末位（levelup_exp<=0）判满级。
func _is_hero_max_level(hero: HeroInstance) -> bool:
	return _levelup_exp(int(hero.level)) <= 0


func _is_hero_max_level_by_level(level: int) -> bool:
	return _levelup_exp(level) <= 0


func _levelup_exp(level: int) -> int:
	return int(cm.get_raw_table(&"Levels").get(str(level), {}).get(&"Exp", 0))


func _on_close_pressed() -> void:
	_stop_keepeat()
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
