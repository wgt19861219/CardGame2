class_name EatexpPanel
extends PopWindow

## 消耗经验药弹窗（View 层）— 照源 ui/popwindow/eatexplist.lua（724 行）。
## 从 EquipboardPanel consume 分支进入。选英雄喂药：扣物品 + 加经验 + 经验条动画 + 飘字。
## 单机化：去掉 doSendConsume 网络上报（源 ed.send consume_item + registerNetReply eat_exp），
## 改即时生效（do_eat_hero 直接 pd.remove_item + hero_manager.add_hero_exp，无 useAmount 延迟累计）。
## 长按连续喂药：源 keepeatHandler 加速曲线（oriSpeed/accAcc）简化为固定间隔 repeat。

# ── 坐标（源 ui_info + createHero cocos 值，frame 内相对）──
const FRAME_POS: Vector2 = Vector2(400.0, 215.0)    # 源 frame ccp(400,215)
const FRAME_SIZE: Vector2 = Vector2(570.0, 345.0)   # 源 fix_wh h=345 + draglist rect w=570
const TITLE_POS: Vector2 = Vector2(190.0, 8.0)      # 源 title ccp(400,379) → frame 内
const CLOSE_POS: Vector2 = Vector2(515.0, 5.0)      # 源 close ccp(668,360) → frame 内
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const SCROLL_POS: Vector2 = Vector2(20.0, 45.0)
const SCROLL_SIZE: Vector2 = Vector2(530.0, 290.0)
const CELL_MIN_SIZE: Vector2 = Vector2(255.0, 110.0)
const HEAD_POS: Vector2 = Vector2(8.0, 3.0)         # 源 createHero headPos ccp(7,9)
const LEVEL_POS: Vector2 = Vector2(115.0, 70.0)     # 源 level ccp(96,40) 调整
const NAME_POS: Vector2 = Vector2(115.0, 8.0)       # 源 nameLabel ccp(178-w/2,72) 调整
const EXP_BAR_POS: Vector2 = Vector2(110.0, 92.0)   # 源 expBarBg ccp(162,20) 调整
const EAT_LBL_POS: Vector2 = Vector2(180.0, 50.0)   # 源 amountLabel ccp(210,42)

# ── 动画/长按时序（源 getBarAction animDuration=0.5 + keepeatHandler delay=0.5）──
const ANIM_DUR: float = 0.4
const ANIM_FILL_RATIO: float = 0.4   # 升级动画填满段时长占比
const ANIM_END_RATIO: float = 0.6    # 升级动画末段时长占比
const KEEPEAT_DELAY: float = 0.5
const KEEPEAT_INTERVAL: float = 0.08
const EAT_LIFETIME: float = 0.3
const EAT_FADE: float = 0.2
# 源 hello.lua:311 setContentScaleFactor=1.28125，cocos CCSprite 显示=texture/CS。
# Godot TextureRect 默认 KEEP_SIZE 用纹理原始尺寸偏大 1.28；经验条普通态源 eatexplist.lua:287 纯 sprite
# scalexy 进度（无 fix_size）→ 显示=texture/CS；满级态 :403 fix_size=CCSizeMake(145,20) 保留。
const CONTENT_SCALE: float = 1.28125

const TITLE_BG_H: float = 36.0                  # title_bg 高（源 equip_detail_title_bg 尺寸）
const EXP_BAR_SIZE: Vector2 = Vector2(140.0, 14.0)   # 经验条尺寸（保留布局参考，实际 bar 用动态 tex/CS）
# 源 eatexplist.lua:403 heroxp-progress-full.png fix_size=CCSizeMake(145,20)（满级条，源指定尺寸非 tex/CS）。
const FULL_BAR_FIX_SIZE: Vector2 = Vector2(145.0, 20.0)

# ── 资源 ──
const FRAME_PATH: String = "res://assets/ui/alpha/HVGA/package_herolist_bg.png"
const TITLE_BG_PATH: String = "res://assets/ui/alpha/HVGA/equip_detail_title_bg.png"
const HERO_BG_PATH: String = "res://assets/ui/alpha/HVGA/package_hero_bg.png"
const EXP_BAR_BG_PATH: String = "res://assets/ui/alpha/HVGA/package_exp_bar_bg.png"
const EXP_BAR_PATH: String = "res://assets/ui/alpha/HVGA/package_exp_bar.png"
const EXP_FULL_PATH: String = "res://assets/ui/alpha/HVGA/heroxp-progress-full.png"

# ── 文本（源 LSTR key，运行时 cm.get_lstr 解析；2026-07-16 精修 LSTR 化）──
const LSTR_TITLE := "EATEXPLIST.CHOOSE_A_HERO"             # 源 create title
const LSTR_EXP_FULL := "EATEXPLIST.EXPERIENCE_FULL"        # 源 setExpMax shade label "经验已满"
const LSTR_HERO_EXP_FULL := "EATEXPLIST.HERO_EXPERIENCE_FULL"  # 源 doEat 满级 toast "英雄经验已满"
const LSTR_ALL_USED := "EATEXPLIST.ALL_COMSUMED"           # 源 useProp 全消耗 toast 后缀

const TITLE_COLOR: Color = Color(250.0 / 255.0, 205.0 / 255.0, 16.0 / 255.0)   # 源 ccc3(250,205,16)
const EAT_LBL_COLOR: Color = Color(1.0, 200.0 / 255.0, 0.0)                    # 源 light_orange

var cm: Variant = null
var pd: PlayerData = null
var _item_id: int = 0          # 经验药物品 id（源 self.id）
var _exp_per_pill: int = 0     # 源 self.exp = Equip[id].Exp
var _cells: Dictionary = {}    # inst_id → {cell, level_label, exp_bar, display_level}
var _keepeat_inst: int = -1    # 长按目标 inst_id（-1=空闲）


# 源 cocos(800×480 左下) → Godot(960×640 左上):cx+80, 560-cy（同 battle_view_coords 标准）。
# Phase 4 早期直接用源值漏转，2026-07-14 补 to_godot（frame 内子元素已手工算 Godot 局部，只转 frame 全局位置）。
func _g(pos: Vector2) -> Vector2:
	return BattleViewCoords.to_godot(pos.x, pos.y)


# LSTR 解析包装（源 T(LSTR(key)) 等价；cm 缺失返空串避免 null 解引用）。
func _T(key: String) -> String:
	if cm == null:
		return ""
	return String(cm.get_lstr(key))


# 经验药物品名（源 useProp :8 equip[id].Name，LSTR key → 当前语言）
func _equip_name() -> String:
	var name_key: String = String(cm.get_raw_table(&"Equip").get(str(_item_id), {}).get("Name", ""))
	return _T(name_key)


# 源 create(id, amount, param) :25-126。item_id=经验药物品 id；amount 从 pd.items 实时读。
func setup_panel(item_id: int, p_cm: Variant, p_pd: PlayerData) -> void:
	_item_id = item_id
	cm = p_cm
	pd = p_pd
	_exp_per_pill = int(cm.get_raw_table(&"Equip").get(str(item_id), {}).get(&"Exp", 0))
	setup()
	_build_ui()
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))


func _build_ui() -> void:
	var frame := Control.new()
	frame.position = _g(FRAME_POS) - FRAME_SIZE / 2.0
	frame.size = FRAME_SIZE
	container.add_child(frame)
	_add_bg(frame)
	_add_title(frame)
	_add_close(frame)
	_add_hero_list(frame)


func _add_bg(parent: Control) -> void:
	if not ResourceLoader.exists(FRAME_PATH):
		return
	var bg := TextureRect.new()
	bg.texture = load(FRAME_PATH)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.custom_minimum_size = Vector2.ZERO
	bg.size = FRAME_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


# 源 title_bg + title 标签。
func _add_title(parent: Control) -> void:
	if ResourceLoader.exists(TITLE_BG_PATH):
		var title_bg := TextureRect.new()
		title_bg.texture = load(TITLE_BG_PATH)
		title_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_bg.custom_minimum_size = Vector2.ZERO
		title_bg.size = Vector2(FRAME_SIZE.x, TITLE_BG_H)
		title_bg.position = Vector2(0.0, 0.0)
		title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(title_bg)
	var lbl := Label.new()
	lbl.text = _T(LSTR_TITLE)
	lbl.position = TITLE_POS
	lbl.modulate = TITLE_COLOR
	lbl.size = Vector2(180.0, 30.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)


func _add_close(parent: Control) -> void:
	var btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_POS)
	btn.pressed.connect(_on_close_pressed)
	parent.add_child(btn)


# 源 createListLayer + createList :152-201：draglist 列英雄。本项目 ScrollContainer+GridContainer columns=2。
func _add_hero_list(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.position = SCROLL_POS
	scroll.size = SCROLL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size = Vector2(SCROLL_SIZE.x, 0.0)
	scroll.add_child(grid)
	var inst_ids: Array = pd.hero_manager.heroes.keys()
	inst_ids.sort()
	for inst_id in inst_ids:
		var hero: HeroInstance = pd.hero_manager.heroes[inst_id]
		grid.add_child(_create_hero_cell(int(inst_id), hero))


# 源 createHero :204-302：bg + head + level + name + 类型mark + exp bar。
# 单机化简化：类型 mark（icon_str/agi/int 缺图）跳过；满级特效（playEatEffect/playLevelupEffect）跳过。
func _create_hero_cell(inst_id: int, hero: HeroInstance) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = CELL_MIN_SIZE
	cell.size = CELL_MIN_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(HERO_BG_PATH):
		var bg := TextureRect.new()
		bg.texture = load(HERO_BG_PATH)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.custom_minimum_size = Vector2.ZERO
		bg.size = CELL_MIN_SIZE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(bg)
	# head（源 readhero.createIconByID，setLevelVisible(false) → 不传 level）
	var head := ReadheroIcon.new()
	head.setup({"id": int(hero.tid), "rank": int(hero.rank), "stars": int(hero.stars)}, cm)
	head.position = HEAD_POS
	cell.add_child(head)
	# name（源 unit["Display Name"]）
	var name_lbl := Label.new()
	name_lbl.text = cm.get_lstr(String(cm.get_raw_table(&"Unit").get(str(hero.tid), {}).get("Display Name", str(hero.tid))))
	name_lbl.position = NAME_POS
	name_lbl.size = Vector2(130.0, 22.0)
	cell.add_child(name_lbl)
	# level（源 LV:%d）
	var level_lbl := Label.new()
	level_lbl.text = "LV:%d" % int(hero.level)
	level_lbl.position = LEVEL_POS
	level_lbl.size = Vector2(70.0, 20.0)
	cell.add_child(level_lbl)
	# exp bar（源 expBarBg + expBar scaleX=min(exp/maxExp,1)）
	var bar := _create_exp_bar(cell, hero)
	_cells[inst_id] = {
		"cell": cell, "level_label": level_lbl, "exp_bar": bar,
		"display_level": int(hero.level),
	}
	cell.gui_input.connect(func(ev: InputEvent) -> void: _on_cell_gui_input(ev, inst_id))
	return cell


func _create_exp_bar(parent: Control, hero: HeroInstance) -> TextureRect:
	var bg_tex: Texture2D = _load_tex(EXP_BAR_BG_PATH)
	var bar_tex: Texture2D = _load_tex(EXP_BAR_PATH)
	var full_tex: Texture2D = _load_tex(EXP_FULL_PATH)
	var is_max: bool = _is_hero_max_level(hero)
	var bar := TextureRect.new()
	bar.texture = full_tex if is_max else bar_tex
	# 源 eatexplist.lua:287 普通 bar 纯 sprite scalexy 进度（无 fix_size）→ 显示=texture/CS；
	# :403 满 bar fix_size=CCSizeMake(145,20) 保留。原 EXPAND_KEEP_SIZE 是 CS 遗漏（偏大 1.28），改 IGNORE_SIZE。
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.position = EXP_BAR_POS
	bar.size = FULL_BAR_FIX_SIZE if is_max else (bar.texture.get_size() / CONTENT_SCALE)
	bar.scale.x = _bar_scale(hero)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bg_tex != null:
		var bar_bg := TextureRect.new()
		bar_bg.texture = bg_tex
		# 源 :264 expBarBg createSprite 无 fix_size → 显示=texture/CS（原 EXP_BAR_SIZE 估算 140×14 近似 178/CS=139）
		bar_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bar_bg.custom_minimum_size = Vector2.ZERO
		bar_bg.position = EXP_BAR_POS
		bar_bg.size = bg_tex.get_size() / CONTENT_SCALE
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(bar_bg)
	parent.add_child(bar)
	return bar


# 源 doEat :659-681 + useProp + refreshExp。单机化：去 eatLocked/doSendConsume 网络，即时扣物品+加经验。
func do_eat_hero(inst_id: int) -> void:
	if not is_instance_valid(self):
		return
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	if hero == null:
		return
	if _is_hero_max_level(hero):
		_show_toast(_T(LSTR_HERO_EXP_FULL))   # 源 doEat :666 单条 toast（不含英雄名）
		return
	if int(pd.items.get(_item_id, 0)) <= 0:
		_show_toast("%s %s" % [_equip_name(), _T(LSTR_ALL_USED)])   # 源 useProp :8 物品名 + ALL_COMSUMED
		return
	var olevel: int = hero.level
	var oexp: int = hero.exp
	if pd.remove_item(_item_id, 1) <= 0:
		return
	pd.hero_manager.add_hero_exp(inst_id, _exp_per_pill)
	_play_bar_anim(inst_id, olevel, oexp, hero.level, hero.exp)
	_show_eat_amount(inst_id)


# 源 refreshExp + getBarAction :347-517：bar 多段动画（升级时填满→重置→lv+1→末段）。
# 简化：单段或升级两段 Tween（保留升级视觉，简化加速曲线）。
func _play_bar_anim(inst_id: int, olevel: int, oexp: int, nlevel: int, nexp: int) -> void:
	var cd: Dictionary = _cells.get(inst_id, {})
	if cd.is_empty():
		return
	var bar: TextureRect = cd["exp_bar"]
	var lvl_lbl: Label = cd["level_label"]
	var start_scale: float = _scale_for(oexp, olevel)
	var end_scale: float = _scale_for(nexp, nlevel) if not _is_hero_max_level_by_level(nlevel) else 1.0
	if _is_hero_max_level_by_level(nlevel) and bar.texture != _load_tex(EXP_FULL_PATH):
		bar.texture = _load_tex(EXP_FULL_PATH)
		bar.size = FULL_BAR_FIX_SIZE   # 切满级 fix_size=CCSizeMake(145,20)（与普通 bar 的 tex/CS 不同）
	bar.scale.x = start_scale
	var tw := create_tween()
	if nlevel > olevel:
		tw.tween_property(bar, "scale:x", 1.0, ANIM_DUR * ANIM_FILL_RATIO)
		tw.tween_callback(_make_levelup_callback(bar, cd, lvl_lbl))
		tw.tween_property(bar, "scale:x", end_scale, ANIM_DUR * ANIM_END_RATIO)
	else:
		tw.tween_property(bar, "scale:x", end_scale, ANIM_DUR)


# 升级 callback 工厂（避免内联多行 lambda 在 tween_callback 内的缩进歧义）。
func _make_levelup_callback(bar: TextureRect, cd: Dictionary, lvl_lbl: Label) -> Callable:
	return func() -> void:
		bar.scale.x = 0.0
		cd["display_level"] = int(cd["display_level"]) + 1
		lvl_lbl.text = "LV:%d" % int(cd["display_level"])


func _scale_for(exp: int, level: int) -> float:
	var lv_exp: int = _levelup_exp(level)
	if lv_exp <= 0:
		return 1.0
	return clampf(float(exp) / float(lv_exp), 0.0, 1.0)


func _bar_scale(hero: HeroInstance) -> float:
	return _scale_for(int(hero.exp), int(hero.level))


# 源 showEatAmount :519-556：飘字 x N（源累计 ea，本项目单次 +exp_per_pill）。
func _show_eat_amount(inst_id: int) -> void:
	var cd: Dictionary = _cells.get(inst_id, {})
	if cd.is_empty():
		return
	var cell: Control = cd["cell"]
	var lbl := Label.new()
	lbl.text = "+%d" % _exp_per_pill
	lbl.position = EAT_LBL_POS
	lbl.modulate = EAT_LBL_COLOR
	cell.add_child(lbl)
	var tw := create_tween()
	tw.tween_interval(EAT_LIFETIME)
	tw.tween_property(lbl, "modulate:a", 0.0, EAT_FADE)
	tw.tween_callback(lbl.queue_free)


# 源 doPressList + endPressList :615-704：点击喂药 + 长按连续。
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


# 源 keepeatHandler :558-589：delay 0.5s 后 repeat（源 accAcc 加速曲线 → 简化固定间隔）。
func _start_keepeat(inst_id: int) -> void:
	_keepeat_inst = inst_id
	var target: int = inst_id
	await get_tree().create_timer(KEEPEAT_DELAY).timeout
	while _keepeat_inst == target and is_instance_valid(self):
		do_eat_hero(target)
		await get_tree().create_timer(KEEPEAT_INTERVAL).timeout


func _stop_keepeat() -> void:
	_keepeat_inst = -1


# 源 setExpMax 满级判定：info._level == heroLevelLimit && maxExp <= exp。
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


func _show_toast(text: String) -> void:
	if Engine.is_editor_hint():
		return
	var toast_node: Node = Engine.get_main_loop().root.get_node_or_null("/root/Toast")
	if toast_node != null and toast_node.has_method("show_message"):
		toast_node.show_message(text)


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
