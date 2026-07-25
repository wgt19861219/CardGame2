class_name LanguageManager
extends RefCounted

## 多语言管理器（Logic 层）— 照源 LocalString.lua:74 LSTR(key)=langs[currentLang][key]。
## 7 语言 LSTR_<lang>.json（ConfigManager.load_all 自动加载到 _tables）+ current_lang 持久化
## （ConfigFile user://lang.cfg，照源 CCUserDefault:getStringForKey("client_language")）+
## get_lstr 路由（找不到返 key 本身，照源 :76-78）。单机化：去联机 system_setting 网络消息 + needRestart 改运行时切换。

const DEFAULT_LANG: String = "zh-CN"
const LANG_CFG_PATH: String = "user://lang.cfg"
const LANG_CFG_SECTION: String = "language"
const LANG_CFG_KEY: String = "current"
const LANGS: Array[String] = ["zh-CN", "en-US", "de-DE", "ko-KR", "pt-BR", "ru-RU", "tr-TR"]

var _cm: ConfigManager
var _current_lang: String = DEFAULT_LANG


func init(p_cm: ConfigManager, p_saved_lang: String = "") -> void:
	_cm = p_cm
	var lang: String = p_saved_lang if p_saved_lang != "" else load_language()
	set_language(lang)


func set_language(lang: String) -> bool:
	if not LANGS.has(lang):
		return false
	_current_lang = lang
	return true


func get_language() -> String:
	return _current_lang


func get_lstr(key: String) -> String:
	var table: Dictionary = _cm.get_raw_table(StringName("LSTR_" + _current_lang))
	var val: Variant = table.get(key, key)
	return String(val)


func get_langs() -> Array[String]:
	return LANGS.duplicate()


## 目标无 arial_unicode_ms.ttf，Godot 默认字体支持 Unicode（含中文/韩文/俄文等），统一返空（用默认）。
## 下轮补字体文件后可按语言返 FontResource 路径。
func get_font_path() -> String:
	return ""


## 持久化 current_lang 到 user://lang.cfg（照源 CCUserDefault:setStringForKey("client_language")）。
func save_language() -> void:
	var cfg := ConfigFile.new()
	cfg.load(LANG_CFG_PATH)
	cfg.set_value(LANG_CFG_SECTION, LANG_CFG_KEY, _current_lang)
	cfg.save(LANG_CFG_PATH)


## 读取持久化语言（照源 checkCurrentLanguage 读 client_language，无则默认 zh-CN）。
func load_language() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(LANG_CFG_PATH) != OK:
		return DEFAULT_LANG
	var lang: String = String(cfg.get_value(LANG_CFG_SECTION, LANG_CFG_KEY, DEFAULT_LANG))
	return lang if LANGS.has(lang) else DEFAULT_LANG
