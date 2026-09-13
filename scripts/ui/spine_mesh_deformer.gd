class_name SpineMeshDeformer
extends RefCounted

## Spine 2.1 skinnedmesh 顶点蒙皮计算（View 层）— 纯数学，无 Node 状态。
## 背景：region-only 降级把 mesh 整贴图挂 slot 骨骼原点渲染，丢失顶点级蒙皮姿态
##（2026-09-12 信箱歪斜根因：原画斜置设计 + 骨骼旋转粗补偿 ≈ 残差 7°，蒙皮顶点才是直立姿态）。
## vertices 格式（Spine 2.1）：[boneCount, (boneIdx, x, y, weight)×boneCount, ...] 连续平铺。

const BIND_STRIDE: int = 4   # 每条绑定占 4 元素：boneIdx, x, y, weight

var _bone_parent: Dictionary = {}   # bone name -> parent name（_compose_chain 用）


## 解析绑定结构：每顶点 → [[bone_name, x, y, weight], ...]。
static func parse_bindings(raw_vertices: Array, bone_order: PackedStringArray) -> Array:
	var bindings: Array = []
	var i: int = 0
	while i < raw_vertices.size():
		var cnt: int = int(raw_vertices[i])
		i += 1
		var per: Array = []
		for _b in cnt:
			per.append([bone_order[int(raw_vertices[i])], float(raw_vertices[i + 1]), float(raw_vertices[i + 2]), float(raw_vertices[i + 3])])
			i += BIND_STRIDE
		bindings.append(per)
	return bindings


## 从骨骼 Node2D 当前属性 compose 全骨骼「骨架空间」Transform2D（含 parent 链）。
## 返回 {bone name -> Transform2D}；调用时机 = _build 后(setup) / _apply 每帧(动画后)。
static func bone_xforms(bone_nodes: Dictionary, bones_data: Dictionary) -> Dictionary:
	var deformer := new()
	for name in bones_data:
		deformer._bone_parent[String(name)] = String(bones_data[name].get("parent", ""))
	var out: Dictionary = {}
	for name in bone_nodes:
		out[String(name)] = deformer._compose_chain(bone_nodes[String(name)], String(name), bone_nodes)
	return out


## 按骨骼骨架空间 Transform2D 加权混合全部顶点（Spine Skeleton.updateWorldTransform 后的 skinned 顶点语义）。
static func skin_points(bindings: Array, bone_xforms: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(bindings.size())
	for vi in bindings.size():
		var acc := Vector2.ZERO
		for bind in bindings[vi]:
			var xf: Transform2D = bone_xforms[bind[0]]
			acc += xf * Vector2(bind[1], bind[2]) * bind[3]
		pts[vi] = acc
	return pts


## 构建三角网格 ArrayMesh（MeshInstance2D 用；顶点/uv 变更时重建，量级 ≤百顶点成本可忽略）。
static func build_tri_mesh(pts: PackedVector2Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _compose_chain(node: Node2D, name: String, bone_nodes: Dictionary) -> Transform2D:
	# Node2D 变换顺序 = T(pos)·R(rot)·S(scale)；沿 parent 链左乘得骨架空间变换。
	# Node2D 数值空间（挂 scale.y=-1 镜像根下）与 Spine y-up 数值空间一致，rotation/pos 直接用。
	#（取负实验已否定：2026-09-12 对照 python 蒙皮模型姿态不符）
	var local := Transform2D(node.rotation, node.position) * Transform2D().scaled(node.scale)
	var parent: String = _bone_parent.get(name, "")
	if parent.is_empty() or not bone_nodes.has(parent):
		return local
	return _compose_chain(bone_nodes[parent], parent, bone_nodes) * local
