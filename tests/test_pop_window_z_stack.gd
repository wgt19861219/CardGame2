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
