class_name SaveManager
extends RefCounted

## 原子存档管理：先写临时文件，成功后 rename 覆盖目标，避免崩溃写一半丢档。
## slot 为存档槽名；用 var_to_str/str_to_var 序列化以保真类型（治旧版 JSON float→int 坑）。

const TEMP_SUFFIX := ".tmp"
const FILE_PREFIX := "save_"
const FILE_EXT := ".json"

var _base_dir: String

func _init(base_dir: String = "user://") -> void:
	_base_dir = base_dir

## 保存数据到槽位，返回 Godot 错误码（OK=0 成功）。
func save_slot(slot: String, data: Dictionary) -> int:
	var target := _path(slot)
	var temp := target + TEMP_SUFFIX
	DirAccess.make_dir_recursive_absolute(_base_dir)
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(var_to_str(data))
	file.close()
	return DirAccess.rename_absolute(temp, target)

## 读取槽位数据，失败/不存在返回空字典。
## 解析失败（str_to_var 非 Dictionary）时先把原档备份为 .corrupt_<epoch> 再返回空——
## 2026-09-07 用户档毁灭事故根修：原版静默返空 → GameData 走新号 → 登录首存立即覆盖，
## 坏档被原地消灭零残留（读侧兜底与写侧原子写不对称）。备份保后续手工抢救可能。
func load_slot(slot: String) -> Dictionary:
	var target := _path(slot)
	if not FileAccess.file_exists(target):
		return {}
	var file := FileAccess.open(target, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.is_empty():
		return {}
	var parsed: Variant = str_to_var(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		var corrupt_backup: String = target + ".corrupt_" + str(int(Time.get_unix_time_from_system()))
		DirAccess.rename_absolute(target, corrupt_backup)
		push_error("SaveManager: 槽 %s 解析失败，原档已备份至 %s（返回空走新号）" % [slot, corrupt_backup])
		return {}
	return parsed

## 删除槽位，返回错误码（不存在视为成功）。
func delete_slot(slot: String) -> int:
	var target := _path(slot)
	if not FileAccess.file_exists(target):
		return OK
	return DirAccess.remove_absolute(target)

func _path(slot: String) -> String:
	return _base_dir + FILE_PREFIX + slot + FILE_EXT
