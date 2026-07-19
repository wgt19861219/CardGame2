# path_generator.gd
# 路径阵列纯几何静态类：折线 → segment 列表（discrete 采样点 / continuous 段阵列）。
# 不创建节点、不调 AssetFactory、不碰场景树（可独立 headless 校验）。
# 移植自 asset-forge path_generator.gd（删 class_name；删 v6 _compute_seg_heights 阻塞；加 resolve_points）。
# v5 端柱去重属放置层（T5 asset_placer），本文件不含。
@tool
extends RefCounted

const _EPS: float = 1e-4  # 米；与 forge_client.predict_n 同值（F1 同步约定）


# path_node 读场景 Path3D.curve.baked_points（节点须在活动场景且为 Path3D，否则返 []）；
# path 直用 [[x,y,z]...]（≥2 点，每点由 _to_vector3 解析，兼容 Array 与 PackedFloat64Array）。
# 返回 Vector3 数组（调用方据空与否决定 parent_not_found / invalid_params）。
static func resolve_points(root: Node, path: Array, path_node: String) -> Array:
	var pts: Array = []
	if path_node != "":
		var pn: Node = root.get_node_or_null(path_node)
		if pn == null or not (pn is Path3D):
			return []  # 调用方返 PARENT_NOT_FOUND
		var baked: PackedVector3Array = (pn as Path3D).curve.get_baked_points()
		for p in baked:
			pts.append(p)
	elif path.size() >= 2:
		for p in path:
			var v3: Variant = _to_vector3(p)
			if v3 == null:
				return []  # 调用方返 invalid_params
			pts.append(v3)
	return pts


# validate 已删（2026-07-11 清理 bug 3）：fbdd684 后 sample/_distances/_sample_continuous
# 已健壮处理 count 优先 / spacing / 非法值 early-return 防御，validate 闲置为死代码；且其
# spacing/count 互斥规则与 sample 的 count 优先逻辑冲突。mode/align 严格校验如需，后续在 handle_path 加


# 输入 → segment 列表，每项 {position: Vector3, rotation: Vector3, length: float, params: Dictionary}
# - discrete：等间距 spacing 或等数量 count 采样点（含 miter 切线；length=0 占位）
# - continuous：栏板首尾相连铺满，length 自适应段长（沿 chord）
# - align：none/path/normal（默认 path 沿切线）
# - v4 align_vertices：continuous+spacing 下折线顶点强制为段边界（短尾段保留）
# brief 锁定 6 必填参数；include_endpoints 可选默认 true（discrete spacing 补尾 / count 含两端）
static func sample(
	points: Array, mode: String, spacing: float, count: int, align: String,
	align_vertices: bool, include_endpoints := true
) -> Array:
	if mode == "continuous":
		return _sample_continuous(points, spacing, count, include_endpoints, align_vertices)
	var last: int = points.size() - 1
	var seg_len: Array = []
	var vertex_d: Array = [0.0]  # vertex_d[i] = 顶点 i 的累计弧长
	var acc := 0.0
	for i in last:
		var l: float = (points[i] as Vector3).distance_to(points[i + 1] as Vector3)
		seg_len.append(l)
		acc += l
		vertex_d.append(acc)
	var total: float = acc

	var distances := _distances(total, spacing, count, include_endpoints)

	var samples: Array = []
	for d_var in distances:
		var d: float = float(d_var)
		var pos := _position_at(d, seg_len, points, total)
		var tangent := _tangent_at(d, vertex_d, seg_len, points)
		var yaw := rad_to_deg(atan2(-tangent.x, -tangent.z))
		var rot := Vector3.ZERO
		if align == "path":
			rot = Vector3(0.0, yaw, 0.0)
		elif align == "normal":
			rot = Vector3(0.0, yaw + 90.0, 0.0)
		# discrete 采样点无 length；params 空字典占位（T5 调用方按需注入）
		samples.append({
			"position": pos,
			"rotation": rot,
			"length": 0.0,
			"params": {}
		})
	return samples


# continuous 模式：段 = 弧长边界相邻对，每段返回 {position, rotation, length, params}
# - count 模式：N 等长段（step=total/N），段数=N
# - spacing 模式：每 spacing 一段，段数=v1 离散点数 - 1
# - yaw=atan2(-chord.z, chord.x)（+X 对齐 chord，与 discrete 的切线 miter 不同）
# - 零长段（length<_EPS）跳过
# - v4 align_vertices：每折线段 [vertex_d[i], vertex_d[i+1]] 独立按 spacing 切 + 段末补尾（短尾段保留）
static func _sample_continuous(
	points: Array, spacing: float, count: int, include_endpoints: bool, align_vertices := false
) -> Array:
	# P0-3：defense-in-depth early-return（spacing<=0 + count<1 时返空；sample 是 public，
	# 但 sample 是 public，恶意/错误 client 直接调也不崩，不静默落入空 boundaries 分支）
	if spacing <= 0.0 and count < 1:
		return []
	var last: int = points.size() - 1
	var seg_len: Array = []
	var vertex_d: Array = [0.0]  # v4：va 分支激活此字段
	var acc := 0.0
	for i in last:
		var l: float = (points[i] as Vector3).distance_to(points[i + 1] as Vector3)
		seg_len.append(l)
		acc += l
		vertex_d.append(acc)
	var total: float = acc
	# 段边界
	var boundaries: Array = []
	if align_vertices:
		# P0(2026-07-13 审查·addons 第三轮): align_vertices 按 spacing 切折线段,需 spacing>0;
		# spacing<=0 时 while d += spacing 不收敛(=0 时 d 不变/负数时后退)→死循环卡 @tool 主线程。
		# 函数入口早退(spacing<=0.0 and count<1) 在 count>=1 时放行,故此分支需独立 spacing 守卫。
		if spacing <= 0.0:
			return []
		# v4：每折线段 [vertex_d[i], vertex_d[i+1]] 独立按 spacing 切 + 段末去重
		# sample 入口（mode==continuous 分支）+ align_vertices 需 spacing>0
		for i in range(last):
			var seg_start: float = float(vertex_d[i])
			var seg_end: float = float(vertex_d[i + 1])
			if float(seg_len[i]) < _EPS:
				continue  # 零长折线段跳过（其末顶点=下段起点，不丢）
			if boundaries.is_empty():
				boundaries.append(seg_start)  # 首段才补起点（跨段共享顶点）
			var d := seg_start + spacing
			while d < seg_end - _EPS:
				boundaries.append(d)
				d += spacing
			# 段末去重（复用 spacing 模式补尾，防御浮点近似整除重复边界）
			if (seg_end - float(boundaries[boundaries.size() - 1])) > _EPS:
				boundaries.append(seg_end)
	elif count >= 1:  # BUG2：count 优先于 spacing（显式"要 N 段"意图）
		if count == 1:
			boundaries = [0.0, total]
		else:
			var step := total / float(count)
			for i in range(count + 1):
				boundaries.append(step * float(i))
	elif spacing > 0.0:  # BUG2：仅 count<1 时才走 spacing
		var d := 0.0
		while d <= total + _EPS:
			boundaries.append(d)
			d += spacing
		if include_endpoints and (total - float(boundaries[boundaries.size() - 1])) > _EPS:
			boundaries.append(total)
	# 段 = 相邻边界对
	var segments: Array = []
	for i in range(boundaries.size() - 1):
		var d_start: float = float(boundaries[i])
		var d_end: float = float(boundaries[i + 1])
		var p_start := _position_at(d_start, seg_len, points, total)
		var p_end := _position_at(d_end, seg_len, points, total)
		var length: float = p_start.distance_to(p_end)
		if length < _EPS:
			continue  # 零长段跳过（不计 predict_n、不 place）
		var position := p_start.lerp(p_end, 0.5)
		var chord := p_end - p_start
		var yaw := rad_to_deg(atan2(-chord.z, chord.x))  # +X 对齐 chord
		segments.append({
			"position": position,
			"rotation": Vector3(0.0, yaw, 0.0),  # continuous 强制 align=path
			"length": length,
			"params": {}  # T5 调用方按需注入（如 ramp 高度，v6 阻塞故本文件不产）
		})
	return segments


# --- helpers ---


# 兼容 Array 与 PackedFloat64Array → Vector3；非法返 null
static func _to_vector3(p: Variant) -> Variant:
	var arr: Array = []
	if p is Array:
		arr = (p as Array).duplicate()
	elif p is PackedFloat64Array:
		for x in (p as PackedFloat64Array):
			arr.append(x)
	else:
		return null
	if arr.size() < 3:
		return null
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


static func _total_length(points: Array) -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += (points[i] as Vector3).distance_to(points[i + 1] as Vector3)
	return total


# discrete 采样距离序列（count 等数量优先 / spacing 等间距）
# BUG2 修复：count >= 1 优先于 spacing > 0.0。原 spacing 优先 + handle_path 默认 spacing=1.0
# → 用户传 count=N 仍走 spacing 分支，count 被吞（count=5 实落 13 段）。count 是显式"要 N 件"
# 意图，应优先于间距默认；仅 count<1（默认 0）时才走 spacing。discrete count 语义=采样点数。
static func _distances(
	total: float, spacing: float, count: int, include_endpoints: bool
) -> Array:
	var distances: Array = []
	if count >= 1:
		if count == 1:
			distances.append(total / 2.0)  # count==1 时 include_endpoints 须 false（discrete count==1 + endpoints ≥2 点矛盾）
		elif include_endpoints:
			var step := total / float(count - 1)
			for i in count:
				distances.append(step * float(i))
		else:
			var step := total / float(count)
			for i in count:
				distances.append(step * (float(i) + 0.5))
	elif spacing > 0.0:
		var d := 0.0
		while d <= total + _EPS:
			distances.append(d)
			d += spacing
		if include_endpoints and (total - float(distances[distances.size() - 1])) > _EPS:
			distances.append(total)
	return distances


	# 弧长 d 处的位置（沿折线分段线性插值）
static func _position_at(
	d: float, seg_len: Array, points: Array, total: float
) -> Vector3:
	if d >= total - _EPS:
		return points[points.size() - 1] as Vector3
	var acc := 0.0
	for i in seg_len.size():
		var l: float = float(seg_len[i])
		if d <= acc + l + _EPS:
			var t: float = (d - acc) / l if l > _EPS else 0.0
			return (points[i] as Vector3).lerp(points[i + 1] as Vector3, t)
		acc += l
	return points[points.size() - 1] as Vector3


# 弧长 d 处的切线方向（discrete miter：内部顶点取角平分线，端点取邻边方向）
static func _tangent_at(
	d: float, vertex_d: Array, seg_len: Array, points: Array
) -> Vector3:
	var last: int = points.size() - 1
	# 末点
	if abs(d - float(vertex_d[last])) < _EPS:
		var li := last - 1
		while li >= 0 and float(seg_len[li]) < _EPS:
			li -= 1
		if li < 0:
			return Vector3.FORWARD
		return ((points[li + 1] as Vector3) - (points[li] as Vector3)).normalized()
	# 首点
	if abs(d - 0.0) < _EPS:
		var fi := 0
		while fi < last and float(seg_len[fi]) < _EPS:
			fi += 1
		if fi >= last:
			return Vector3.FORWARD
		return ((points[fi + 1] as Vector3) - (points[fi] as Vector3)).normalized()
	# 内部顶点 → miter（角平分线）
	for i in range(1, last):
		if abs(d - float(vertex_d[i])) < _EPS:
			var a := _seg_dir(seg_len, points, i - 1)
			var b := _seg_dir(seg_len, points, i)
			var bisect := a + b
			if bisect.length_squared() < 1e-8:  # F3：a ≈ -b 180° 折返 → 回退入边
				return a
			return bisect.normalized()
	# 段内点
	for i in last:
		if d >= float(vertex_d[i]) and d < float(vertex_d[i + 1]):
			return _seg_dir(seg_len, points, i)
	return Vector3.FORWARD


static func _seg_dir(seg_len: Array, points: Array, i: int) -> Vector3:
	if float(seg_len[i]) < _EPS:
		return Vector3.FORWARD
	return ((points[i + 1] as Vector3) - (points[i] as Vector3)).normalized()
