class_name AudioManager
extends RefCounted

## 音频管理（Logic 部分，Step 5.1）：音效映射 + 错误处理。
## 治旧版 pcall 吞 C++ 错误（音频加载失败被 pcall 静默）——新版 push_error 显式报错，不吞。
## 运行时播放（AudioStreamPlayer/BGM/英雄专属音效）在 View 层 autoload 接入。

var sfx_map: Dictionary = {}  # name(StringName) -> path(String)
var hero_sfx_map: Dictionary = {}  # hero_tid(int) -> {event(StringName): path}
var bgm_path: String = ""

func register_sfx(name: StringName, path: String) -> void:
	sfx_map[name] = path

func register_hero_sfx(hero_tid: int, event: StringName, path: String) -> void:
	if not hero_sfx_map.has(hero_tid):
		hero_sfx_map[hero_tid] = {}
	hero_sfx_map[hero_tid][event] = path

## 查询音效路径；未注册 push_error 并返回空（治 pcall 静默吞错）。
func get_sfx_path(name: StringName) -> String:
	if not sfx_map.has(name):
		push_error("音效未注册: " + str(name))
		return ""
	return sfx_map[name]

func get_hero_sfx_path(hero_tid: int, event: StringName) -> String:
	if not hero_sfx_map.has(hero_tid):
		push_error("英雄音效未注册: tid=" + str(hero_tid) + " event=" + str(event))
		return ""
	var events: Dictionary = hero_sfx_map[hero_tid]
	if not events.has(event):
		push_error("英雄音效事件缺失: tid=" + str(hero_tid) + " event=" + str(event))
		return ""
	return events[event]

func has_sfx(name: StringName) -> bool:
	return sfx_map.has(name)

func set_bgm(path: String) -> void:
	bgm_path = path
