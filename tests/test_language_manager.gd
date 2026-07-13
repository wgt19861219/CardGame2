extends GutTest
# LanguageManager 多语言路由单测（照源 LocalString.lua:74 LSTR(key)=langs[currentLang][key]）。
# 7 语言 LSTR_<lang>.json（generate_lstr.py 生成），ConfigManager.load_all 自动加载。

var cm: ConfigManager
var lm: LanguageManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	lm = LanguageManager.new()
	lm.init(cm, "zh-CN")


# init 默认 zh-CN（照源 getDeviceLanguage 返 zh-CN）
func test_init_default_lang() -> void:
	assert_eq(lm.get_language(), "zh-CN", "默认 zh-CN")


# set_language 切换 + get_language
func test_set_language() -> void:
	assert_true(lm.set_language("en-US"), "en-US 合法")
	assert_eq(lm.get_language(), "en-US", "切换 en-US")
	assert_true(lm.set_language("ko-KR"), "ko-KR 合法")
	assert_eq(lm.get_language(), "ko-KR", "切换 ko-KR")


# set_language 非法 lang 返 false + 不切（源 langs 无 fr-FR 实际包，fallback en-US 但不单独生成）
func test_set_language_invalid() -> void:
	var before: String = lm.get_language()
	assert_false(lm.set_language("fr-FR"), "fr-FR 不在 7 实际语言")
	assert_eq(lm.get_language(), before, "非法 lang 不切换")


# get_lstr zh-CN 命中中文（源 langs["zh-CN"][key]）
func test_get_lstr_zh_cn() -> void:
	lm.set_language("zh-CN")
	assert_eq(lm.get_lstr("MERCHANTTALK.SHOP"), "百货小店", "zh-CN MERCHANTTALK.SHOP → 百货小店")


# get_lstr en-US 命中英文（源 langs["en-US"][key]，跨语言同 key 不同值）
func test_get_lstr_en_us() -> void:
	lm.set_language("en-US")
	var val: String = lm.get_lstr("MERCHANTTALK.SHOP")
	assert_true(val != "MERCHANTTALK.SHOP" and val != "百货小店", "en-US 命中英文（非 key 非中文）")


# get_lstr 未命中返 key 本身（源 :76-78 nil == str then return key）
func test_get_lstr_miss_returns_key() -> void:
	lm.set_language("zh-CN")
	var missing: String = "NOT_EXIST_KEY.XYZ"
	assert_eq(lm.get_lstr(missing), missing, "未命中返 key 本身")


# 7 实际语言列表（源 LocalString.lua:26-43）
func test_get_langs() -> void:
	var langs: Array[String] = lm.get_langs()
	assert_eq(langs.size(), 7, "7 实际语言")
	assert_true("zh-CN" in langs and "en-US" in langs and "de-DE" in langs, "含 zh-CN/en-US/de-DE")
	assert_true("ko-KR" in langs and "pt-BR" in langs and "ru-RU" in langs and "tr-TR" in langs, "含 ko-KR/pt-BR/ru-RU/tr-TR")


# CONFIGURE.LANGUAGE.<LANG> 语言名 key（2026-07-13 加 `-` 后入库）跨语言命中
func test_language_name_keys() -> void:
	lm.set_language("zh-CN")
	assert_eq(lm.get_lstr("CONFIGURE.LANGUAGE.EN-US"), "英语", "zh-CN 语言名 EN-US → 英语")
	assert_eq(lm.get_lstr("CONFIGURE.LANGUAGE.DE-DE"), "德语", "zh-CN 语言名 DE-DE → 德语")
