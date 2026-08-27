extends Node

## QA 全量走查调试注入（install_override 临时 autoload，测完即卸载删除）。
## 用途：新档跳过教程 + 解锁全功能（team_level=99）+ 发足资源，
## 暴露 qa_open/qa_state/qa_close_all/qa_grant/qa_walk/qa_walk_result/qa_shot 驱动方法。
## bridge call_method 不 await 协程 → qa_walk 立返 "started"，走查后台续跑，
## 结果存 _walk_report 由 qa_walk_result 轮询取（非协程方法，返回值可见）。

const MainSceneEntryRouter = preload("res://scripts/ui/main_scene_entry_router.gd")
const ConfigurePanel = preload("res://scripts/ui/configure_panel.gd")
const HeroSplitExplain = preload("res://scripts/ui/hero_split_explain.gd")
const HeroSplitConfirm = preload("res://scripts/ui/hero_split_confirm.gd")
const EatexpPanel = preload("res://scripts/ui/eatexp_panel.gd")
const FragmentComposePanel = preload("res://scripts/ui/fragment_compose_panel.gd")
const RanklistSummary = preload("res://scripts/ui/ranklist_summary.gd")
const UnlockAnnounceView = preload("res://scripts/ui/unlock_announce_view.gd")
const StoryView = preload("res://scripts/ui/story_view.gd")
const BattlePreparePanel = preload("res://scripts/view/battle/battle_prepare_panel.gd")

const QA_LEVEL: int = 99
const QA_DIAMOND: int = 1000000
const QA_GOLD: int = 5000000
const QA_POINTS: Dictionary = {"crusadepoint": 100000, "guildpoint": 100000, "arenapoint": 100000, "dungeonpoint": 1000}
const WARMUP_SEC: float = 0.6   # 开面板后等入场动画+fill
const COOLDOWN_SEC: float = 0.2   # 关面板后等释放

var _walk_report: String = ""
var _walk_running: bool = false
var _shot_dir: String = "user://qa_shots/"


func _ready() -> void:
	# install_override 把本 autoload 插到列表最顶（GameData 之前）→ player 可能未建；
	# 等 GameData.ready（其 _ready 完成信号），主场景在全部 autoload 之后才加载，时序仍来得及。
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	if pd == null:
		push_error("QA_OVERRIDE: GameData.player 为空")
		return
	pd.tutorial_manager.skip_all()
	pd.team_level = QA_LEVEL
	pd.add_diamond(QA_DIAMOND)
	pd.hero_manager.add_money(QA_GOLD)
	pd.vitality = pd.vitality_max
	for k in QA_POINTS:
		pd.add_point(String(k), int(QA_POINTS[k]))
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	print("QA_OVERRIDE: booted level=", pd.team_level, " diamond=", pd.diamond)


## 当前场景/面板栈/资源快照（bridge 轮询用）。
func qa_state() -> String:
	var scene: Node = get_tree().current_scene
	var pd: Variant = GameData.player
	var tops: Array = []
	for c in scene.get_children():
		tops.append(String(c.name))
	var panels: Array = []
	for c in scene.get_children():
		if c is PopWindow:
			panels.append(String(c.name) + ":" + String(c.identity))
	var info: Dictionary = {
		"scene": scene.scene_file_path,
		"top_children": tops,
		"pop_windows": panels,
		"level": pd.team_level,
		"diamond": pd.diamond,
		"gold": pd.hero_manager.gold,
		"vitality": pd.vitality,
	}
	return JSON.stringify(info)


## 按功能 id 打开面板（走真实路由）。主入口 id 见 main_scene_entries ENTRIES 15 项；
## 额外支持 configure/avatar/name/daily/task/package/midas（HUD/快捷栏同源路由）。
func qa_open(id: String) -> String:
	return _open_page(id)


func _open_page(id: String) -> String:
	var scene: Node = get_tree().current_scene
	var pd: Variant = GameData.player
	match id:
		"configure":
			ConfigurePanel.open(scene)
		"avatar":
			MainSceneEntryRouter.open_avatar(scene)
		"name":
			MainSceneEntryRouter.open_name(scene)
		"daily":
			MainSceneEntryRouter.open_daily_login(scene)
		"task":
			MainSceneEntryRouter.open_task(scene)
		"package":
			MainSceneEntryRouter.open_package(scene, "package")
		"midas":
			MainSceneEntryRouter.open_midas(scene)
		# —— 子面板直构（真实入口需特定资源/状态，参数照各 panel 调用方）——
		"herosplitexplain":
			var he := HeroSplitExplain.new()
			he.setup(pd.cm)
			scene.add_child(he)
		"herosplitconfirm":
			var hero0: Variant = pd.hero_manager.get_hero(pd.team[0]) if pd.team.size() > 0 else null
			if hero0 == null:
				return "ERR: no hero"
			var hc := HeroSplitConfirm.new()
			hc.setup(hero0, pd.cm)
			scene.add_child(hc)
		"eatexp":
			var ee := EatexpPanel.new("eatexp", {})
			ee.setup_panel(101, pd.cm, pd)
			ee.show_window(scene)
		"fragmentcompose":
			var fc := FragmentComposePanel.new("fragmentcompose", {})
			fc.setup_panel(1, pd.cm, pd)
			fc.show_window(scene)
		"ranksummary":
			var rs := RanklistSummary.new("ranklistsummary", {})
			rs.setup_panel("QA测试玩家", 99, 12345, 0, 1, pd.cm)
			rs.show_window(scene)
		"unlockannounce":
			var ua := UnlockAnnounceView.new("unlockannounce", {})
			ua.show_step(&"unlockpvp", scene)
		"story":
			var sv := StoryView.new()
			scene.add_child(sv)
			sv.show_story("Stage1Wave3", pd.cm)
		_:
			if scene.has_method("_on_entry_pressed"):
				scene._on_entry_pressed(id)
			else:
				return "ERR: scene 无 _on_entry_pressed: " + scene.scene_file_path
	return "OK"


## 直进指定关卡战斗（复现结算页问题用；走 BattlePreparePanel 真实开战链：
## setup → _ready 默认阵容 → _on_go_pressed assemble+change_scene）。
## call_method 不等协程：await 帧后 fire-and-forget 续跑，返回 "started"。
func qa_start_stage(sid: int) -> String:
	var scene: Node = get_tree().current_scene
	var pd: Variant = GameData.player
	var mgr: Variant = pd.stage_manager
	var rng := BattleRng.new(randi())
	var panel := BattlePreparePanel.new()
	panel.setup(sid, pd, mgr, rng, pd.cm)
	scene.add_child(panel)
	await get_tree().process_frame
	panel._on_go_pressed()
	return "started sid=" + str(sid)


## 关闭当前场景顶层全部 PopWindow（嵌套子面板随宿主一起释放）。
func qa_close_all() -> String:
	var n: int = _close_all()
	HudOverlay.apply_identity("main")
	return "closed=" + str(n)


func _close_all() -> int:
	var scene: Node = get_tree().current_scene
	var n: int = 0
	for c in scene.get_children():
		if c is PopWindow and is_instance_valid(c):
			c.remove_window()
			n += 1
	return n


## 流程测试中资源耗尽时补发（钻石/金币/体力）。
func qa_grant() -> String:
	var pd: Variant = GameData.player
	pd.add_diamond(QA_DIAMOND)
	pd.hero_manager.add_money(QA_GOLD)
	pd.vitality = pd.vitality_max
	HudOverlay.refresh()
	return "granted"


## 手动截图（流程测试用）：存 user://qa_shots/<name>.png，返回相对路径。
func qa_shot(name: String) -> String:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return "ERR: no image"
	var path := _shot_dir + name + ".png"
	var err := img.save_png(path)
	return path if err == OK else "ERR: save %d" % err


## 批量走查：pages_json = ["pve","tavern",...]。每页：打开→等 WARMUP→结构校验+截图→关闭。
## 后台协程续跑，qa_walk_result() 轮询取 JSON 报告。
func qa_walk(pages_json: String) -> String:
	if _walk_running:
		return "ERR: walk already running"
	var parsed: Variant = JSON.parse_string(pages_json)
	if parsed is Array:
		_walk_running = true
		_walk_report = ""
		_run_walk(parsed as Array)
		return "started"
	return "ERR: bad json"


func qa_walk_result() -> String:
	if _walk_running:
		return "RUNNING"
	return _walk_report


func _run_walk(pages: Array) -> void:
	var out: Array = []
	for i in range(pages.size()):
		var page := String(pages[i])
		var rec: Dictionary = {"page": page}
		var t0 := Time.get_ticks_msec()
		rec["open"] = _open_page(page)
		await get_tree().create_timer(WARMUP_SEC).timeout
		var scene: Node = get_tree().current_scene
		var panels: Array = []
		for c in scene.get_children():
			if c is PopWindow and is_instance_valid(c):
				panels.append({"name": String(c.name), "identity": String(c.identity), "children": c.get_child_count()})
		rec["panels"] = panels
		rec["scene"] = scene.scene_file_path
		rec["shot"] = qa_shot("%03d_%s" % [i, page])
		rec["ms"] = Time.get_ticks_msec() - t0
		out.append(rec)
		_close_all()
		await get_tree().create_timer(COOLDOWN_SEC).timeout
	_walk_report = JSON.stringify(out)
	_walk_running = false


## 诊断：全树枚举 SpineSkeleton（槽贴图路径+变换+全局坐标），定位错位/错绑渲染用。
func qa_dump_spine() -> String:
	var out: Array = []
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is SpineSkeleton:
			var sk := n as SpineSkeleton
			var slots_info: Array = []
			var stack2: Array = [sk]
			while not stack2.is_empty():
				var m: Node = stack2.pop_back()
				for mc in m.get_children():
					stack2.push_back(mc)
					if mc is Sprite2D and (mc as Sprite2D).texture != null:
						var sp := mc as Sprite2D
						slots_info.append("%s@p%s r%s s%s" % [
							String(sp.texture.resource_path).get_file(),
							str(sp.position.round()), str(snappedf(sp.rotation_degrees, 0.1)), str(sp.scale)])
			out.append("sk@%s parent=%s gpos=%s nscale=%s slots=[%s]" % [
				sk.name, sk.get_parent().name if sk.get_parent() else "-",
				str(sk.global_position.round()), str(sk.scale), "; ".join(slots_info)])
	return "\n".join(out)
