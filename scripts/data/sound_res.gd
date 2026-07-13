class_name SoundRes
extends RefCounted

## 音效/音乐资源映射（Data 层）— 照源 soundres.lua ed.sound.deo + ed.music。
## deo：基础音效 key→"sound_menu/xx.mp3"（源 :26-68，common_exp_up=nil 跳过）。
## music：chapter→bgm path（源 :3-25）。register_all 注册 deo 到 AudioManager.sfx_map。


# 源 soundres.lua:26-68 ed.sound.deo（基础音效，common_exp_up=nil 不注册）。
const DEO_MAP: Dictionary = {
	"common_click_feedback": "sound_menu/common_click_feedback.mp3",
	"common_back": "sound_menu/common_back.mp3",
	"common_popup_small": "sound_menu/common_popup_small.mp3",
	"common_change_filter": "sound_menu/common_change_filter.mp3",
	"common_popup_window": "sound_menu/common_popup_window.mp3",
	"common_add_queue": "sound_menu/common_add_queue.mp3",
	"common_remove_queue": "sound_menu/common_remove_queue.mp3",
	"common_alert": "sound_menu/common_alert.mp3",
	"common_switch_on": "sound_menu/common_switch_on.mp3",
	"common_switch_off": "sound_menu/common_switch_off.mp3",
	"common_hero_lvlup": "sound_menu/common_hero_lvlup.mp3",
	"common_close_popup_window": "sound_menu/common_close_popup_window.mp3",
	"common_coin_change": "sound_menu/common_coin_change.mp3",
	"common_craft_success": "sound_menu/common_craft_success.mp3",
	"common_equip_success": "sound_menu/common_equip_success.mp3",
	"common_hero_upgrade": "sound_menu/common_hero_upgrade.mp3",
	"common_shop_refresh_success": "sound_menu/common_shop_refresh_success.mp3",
	"battledown_star_three": "sound_menu/battledown_star_three.mp3",
	"battledown_star_two": "sound_menu/battledown_star_two.mp3",
	"battledown_star_one": "sound_menu/battledown_star_one.mp3",
	"map_change_chapter": "sound_menu/map_change_chapter.mp3",
	"battle_fury_full": "sound_menu/battle_fury_full.mp3",
	"battle_begin": "sound_menu/battle_begin.mp3",
	"map_stage_detail": "sound_menu/map_stage_detail.mp3",
	"skill_att_bar_change": "sound_menu/skill_att_bar_change.mp3",
	"skill_unlock_success": "sound_menu/skill_unlock_success.mp3",
	"battle_loot": "sound_menu/battle_loot.mp3",
	"skill_upgrade_fail": "sound_menu/skill_upgrade_fail.mp3",
	"skill_upgrade_success_blue": "sound_menu/skill_upgrade_success_blue.mp3",
	"skill_upgrade_success_gold": "sound_menu/skill_upgrade_success_gold.mp3",
	"flip_book_page": "sound_menu/flip_book_page.mp3",
	"flip_book": "sound_menu/flip_book.mp3",
	"battle_drop": "sound_menu/battle_drop.mp3",
	"map_bgm": "sound_menu/stage_select_bgm.mp3",
	"skill_remove_blue_star_success": "sound_menu/skill_remove_blue_star_success.mp3",
	"battle_next_wave": "sound_menu/battle_next_wave.mp3",
	"battle_win": "sound_menu/battle_win.mp3",
	"battle_lose": "sound_menu/battle_lose.mp3",
	"battle_cheer": "sound_menu/battle_cheer.mp3",
	"battledown_pop_loot": "sound_menu/battledown_pop_loot.mp3",
}


# 源 soundres.lua:3-25 ed.music（chapter→bgm）。
const MUSIC_MAP: Dictionary = {
	"map": "installer/stage_select_bgm.mp3",
	"chapter1": "sound_menu/battle_bgm.mp3",
	"chapter2": "sound_menu/battle_bgm.mp3",
	"chapter3": "sound_menu/battle_bgm.mp3",
	"chapter4": "sound_menu/battle_bgm.mp3",
	"chapter5": "sound_menu/battle_bgm.mp3",
	"chapter6": "sound_menu/battle_bgm.mp3",
	"chapter7": "sound_menu/battle_bgm.mp3",
	"chapter8": "sound_menu/battle_bgm.mp3",
	"chapter9": "sound_menu/battle_bgm.mp3",
	"chapter10": "sound_menu/battle_bgm.mp3",
	"chapter11": "sound_menu/battle_bgm.mp3",
	"chapter12": "sound_menu/battle_bgm.mp3",
	"chapter13": "sound_menu/battle_bgm.mp3",
	"chapter14": "sound_menu/battle_bgm.mp3",
	"chapter101": "sound_menu/battle_bgm.mp3",
	"chapter102": "sound_menu/battle_bgm.mp3",
	"chapter103": "sound_menu/battle_bgm.mp3",
	"chapter-3": "sound_menu/battle_bgm_crusade.mp3",
	"chapter-1": "sound_menu/battle_bgm_arena.mp3",
	"chapter104": "sound_menu/battle_bgm.mp3",
}


# 注册 deo 全部到 AudioManager.sfx_map（AudioPlayer _init 调）。
static func register_all(am: AudioManager) -> void:
	for key in DEO_MAP:
		am.register_sfx(StringName(key), String(DEO_MAP[key]))


# 源 ed.music[chapter] 查询。
static func get_music(chapter: String) -> String:
	return String(MUSIC_MAP.get(chapter, ""))
