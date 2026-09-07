extends GutTest

## 弹窗动态 z 栈守卫（2026-09-03 穿透根修方案 B）。
## 背景：PopWindow 根恒 z=100 时，子树内 relative z>0 节点（hero tab z=11/13 → effective
## 111/113）穿透兄弟弹窗（fragment/package/task 右侧 tab 区两层叠压不可读，实跑实锤）。
## 方案 B：show_window 入栈，z = Z_BASE + 栈位×Z_STEP（100/200/300…），remove/free 出栈
## 收缩重排——后开弹窗整棵子树（effective ≤ 基准+子树内最大 relative z）恒盖前开弹窗。
## 参照：审查报告-界面布局差异排查-2026-09-03.md。

var _host: Control


func before_each() -> void:
	# 静态栈是全局状态：清历史残留（前文件 queue_free 释放延迟到帧末，PREDELETE
	# 出栈晚于下一测试开局，跨文件污染使首个弹窗 z 偏移，2026-09-03 全量门禁抓出）。
	for p in PopWindow._open_stack.duplicate():
		if is_instance_valid(p):
			p.free()   # 同步 PREDELETE → 自动出栈
	_host = Control.new()
	add_child(_host)


func after_each() -> void:
	# 直接 free 全部（走 PREDELETE 兜底出栈，防跨测试栈泄漏）。
	for c in _host.get_children():
		if c is PopWindow:
			(c as PopWindow).free()
	_host.free()


func _show_popup() -> PopWindow:
	var p: PopWindow = PopWindow.new("zstack_test", {})
	p.show_window(_host)
	return p


func test_stack_assigns_increasing_z() -> void:
	var a := _show_popup()
	var b := _show_popup()
	var c := _show_popup()
	assert_eq(a.z_index, 100, "栈深 1 基准 100（旧行为兼容）")
	assert_eq(b.z_index, 200, "栈深 2 → 200")
	assert_eq(c.z_index, 300, "栈深 3 → 300")
	assert_false(a.z_as_relative, "根 z 绝对值（不随宿主累加）")


func test_child_relative_z_cannot_escape_next_popup() -> void:
	# 穿透守卫：先开弹窗子树内 relative z=13（hero tab 实测最大值）effective=100+13=113，
	# 必须低于后开弹窗整棵子树最低值（根 200）。
	var a := _show_popup()
	var child := Control.new()
	child.z_index = 13
	child.z_as_relative = true
	a.add_child(child)
	var b := _show_popup()
	var a_effective_max: int = a.z_index + 13
	assert_lt(a_effective_max, b.z_index,
		"先开弹窗子树最大 effective（%d）< 后开弹窗根 z（%d），穿透不可能" % [a_effective_max, b.z_index])


func test_remove_window_shrinks_stack() -> void:
	var a := _show_popup()
	var b := _show_popup()
	assert_eq(b.z_index, 200, "关闭前 B=200")
	a.remove_window()   # queue_free，栈同步收缩
	assert_eq(b.z_index, 100, "A 移除后 B 收缩回 100（其下已无弹窗）")


func test_free_without_remove_cleans_stack() -> void:
	var a := _show_popup()
	var b := _show_popup()
	b.free()   # 不走 remove_window 的路径（测试 free/异常释放）→ PREDELETE 兜底出栈
	var c := _show_popup()
	assert_eq(a.z_index, 100, "A 基准不变")
	assert_eq(c.z_index, 200, "B 已出栈，C 接管 200（栈位不泄漏）")


func test_reopen_after_full_close_starts_at_base() -> void:
	var a := _show_popup()
	var b := _show_popup()
	a.remove_window()
	b.remove_window()
	var c := _show_popup()
	assert_eq(c.z_index, 100, "全关后重开回到基准 100（栈不残留）")


# ===== push_external：非 PopWindow 全屏节点入栈（2026-09-07 布阵页章节标题穿透根修）=====
# 背景：BattlePreparePanel（Control 非 PopWindow）旧实现写死 z=210。HeroScene 链
# hero_package 占栈位使选关面板 z=200，其章节标题 relative z=22 → effective 222 > 210
# 穿透布阵页（用户报「战斗准备页面底下关卡的标题透过来了」）。push_external 拿栈最高位+1 恒压。

func _push_external_ctrl() -> CanvasItem:
	var c := Control.new()
	_host.add_child(c)
	PopWindow.push_external(c)
	return c


func test_push_external_tops_stack() -> void:
	var a := _show_popup()
	var b := _show_popup()
	var ext := _push_external_ctrl()
	assert_gt(ext.z_index, b.z_index, "external 拿栈最高位+1（> 栈顶弹窗根 z）")
	# 深栈穿透场景：栈顶弹窗子树内 relative z=22 节点（选关章节标题同款）恒低于 external
	var deep: CanvasItem = _show_popup()
	deep.z_index = 22
	deep.z_as_relative = true
	assert_lt(b.z_index + 22, ext.z_index,
		"栈顶弹窗子树 effective 上界（%d+22）< external z（%d），章节标题穿透不可能" % [b.z_index, ext.z_index])


func test_pop_external_shrinks_and_no_leak() -> void:
	var a := _show_popup()
	var ext := _push_external_ctrl()
	PopWindow.pop_external(ext)
	var c := _show_popup()
	assert_eq(a.z_index, 100, "A 基准不变")
	assert_eq(c.z_index, 200, "external 出栈后 C 接管 200（栈位不泄漏）")


func test_battle_prepare_uses_stack_not_hardcoded_z() -> void:
	# 源码守卫：布阵页入动态 z 栈，写死 z=210 根除（HeroScene 深栈 210 < 222 穿透根因）
	var src: String = FileAccess.get_file_as_string("res://scripts/view/battle/battle_prepare_panel.gd")
	assert_false(src.contains("z_index = 210"), "布阵页无写死 z=210（HeroScene 链穿透根因）")
	assert_true(src.contains("PopWindow.push_external"), "布阵页经 push_external 入动态 z 栈")
	assert_true(src.contains("PopWindow.pop_external"), "布阵页 tree_exited 配对出栈")
