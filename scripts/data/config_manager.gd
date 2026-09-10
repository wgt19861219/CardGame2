class_name ConfigManager
extends RefCounted

## 配置表管理（Data 层）：加载 resources/data/*.json，按 表名 + id 查询。
## typed 访问辅助内部做类型规范化（治 JSON.parse_string 把整数解析成 float 的坑）
## 与字段缺失校验。Logic 层通过依赖注入获得实例，可 headless 单测。

const _DEFAULT_DATA_DIR := "res://resources/data/"

var _tables: Dictionary = {}  # StringName(表名) -> Dictionary(id字符串 -> 字段字典)
var _loaded: bool = false
var _lang: LanguageManager = null   # i18n 路由（load_all 后 init_language，get_lstr 委托）
# P2-GUT-1：进程级 JSON 缓存（static var）。测试跨 91 类 new ConfigManager + load_all，
# 首次加载后缓存，后续实例直接复制（深拷贝防测试间互改）。生产运行仅 1 实例无影响。
static var _cache_tables: Dictionary = {}
static var _cache_loaded: bool = false

## 扫描 data_dir 下所有 .json 加载到内存；重复调用会先清空。
## P2-GUT-1：首次加载后存 static cache，后续实例复制缓存（91 测试类重复 load_all 加速）。
func load_all(data_dir: String = _DEFAULT_DATA_DIR) -> void:
	if _cache_loaded and data_dir == _DEFAULT_DATA_DIR:
		_tables = _cache_tables.duplicate(true)   # 深拷贝防测试间互改
	else:
		_tables.clear()
		var dir := DirAccess.open(data_dir)
		assert(dir != null, "无法打开数据目录: " + data_dir)
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var table_name := file_name.get_basename()
				if table_name == "AffixCount":
					file_name = dir.get_next()
					continue
				_tables[StringName(table_name)] = _load_table(data_dir + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		if data_dir == _DEFAULT_DATA_DIR:
			_cache_tables = _tables.duplicate(true)
			_cache_loaded = true
	_loaded = true
	init_language()

func _load_table(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法读取配置表: " + path)
		return {}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges() == "" or text.strip_edges() == "{}":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("配置表非字典结构: " + path)
		return {}
	return parsed

func is_loaded() -> bool:
	return _loaded

func has_table(table: StringName) -> bool:
	return _tables.has(table)

func has_entry(table: StringName, id: int) -> bool:
	if not _tables.has(table):
		return false
	return _tables[table].has(str(id))

## 返回 id 对应的字段字典；缺失则报错并返回空字典（不崩溃）。
func get_entry(table: StringName, id: int) -> Dictionary:
	if not has_entry(table, id):
		push_error("配置缺失: 表 %s 无 id %d" % [str(table), id])
		return {}
	return _tables[table][str(id)]

## 以下 typed 访问：字段缺失或类型不符时返回类型默认值并报错（不崩溃）。
func get_int(table: StringName, id: int, field: StringName) -> int:
	var value: Variant = _get_field(table, id, field)
	return int(value) if value != null else 0

func get_float(table: StringName, id: int, field: StringName) -> float:
	var value: Variant = _get_field(table, id, field)
	return float(value) if value != null else 0.0

func get_string(table: StringName, id: int, field: StringName) -> String:
	var value: Variant = _get_field(table, id, field)
	return str(value) if value != null else ""

func get_bool(table: StringName, id: int, field: StringName) -> bool:
	var value: Variant = _get_field(table, id, field)
	return bool(value) if value != null else false

func _get_field(table: StringName, id: int, field: StringName) -> Variant:
	var entry := get_entry(table, id)
	if entry.is_empty():
		return null
	if not entry.has(field):
		push_error("字段缺失: 表 %s id %d 无字段 %s" % [str(table), id, str(field)])
		return null
	return entry[field]

## 返回表的原始结构（含嵌套，如 Skill 的 group→level 两层）。供 Data 层专用加载器解析。
func get_raw_table(table: StringName) -> Dictionary:
	return _tables.get(table, {})


## i18n 路由初始化（load_all 后调）：LanguageManager 加载持久化语言 user://lang.cfg + set 当前。
func init_language() -> void:
	_lang = LanguageManager.new()
	_lang.init(self)


## _lang 未 init（测试直接 new ConfigManager 未 load_all） fallback LSTR（zh-CN，向后兼容）。
func get_lstr(key: String) -> String:
	if _lang != null:
		return _lang.get_lstr(key)
	return String(_tables.get(&"LSTR", {}).get(key, key))

## 按 key 取行——数字 id 直接命中 JSON key（str(key)）；否则按 row["Name"] 字段查
## （源 Buff 表经 dataTableMetaTables metatable __index 支持 name 查询，JSON 数字 key 需遍历等价）。
## column 空（""）返整行 Dictionary，非空返该字段 Variant；查不到返空字典（column 空）/ null（column 非空）。
func lookup(table: StringName, column: String, key: Variant) -> Variant:
	var raw: Dictionary = _tables.get(table, {})
	var skey: String = str(key)
	var row: Dictionary = raw.get(skey, {})
	if row.is_empty():
		for k in raw:
			var r: Dictionary = raw[k]
			if String(r.get("Name", "")) == skey:
				row = r
				break
	if column.is_empty():
		return row
	if row.is_empty():
		return null
	return row.get(column, null)


## lookup 的 String 安全版：字段缺失/值为 null/非 String 一律返 ""（区别于 get_string 走
## _get_field 的 push_error——字段缺失在源表是正常形态如 Unit.Narrative 9 英雄无此字段，
## 不该灌错误日志）。Godot 4 String(null) 构造器直接崩，调用方禁 String(lookup(...)) 裸写。
func lookup_str(table: StringName, column: String, key: Variant) -> String:
	var v: Variant = lookup(table, column, key)
	return v if v is String else ""

func get_table_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key in _tables:
		names.append(key)
	names.sort()
	return names
