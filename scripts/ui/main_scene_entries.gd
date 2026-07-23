class_name MainSceneEntries
extends RefCounted

## 主菜单 15 入口按钮数据（照源 mainres.lua res_pos + button_key）。
## 从 main_scene.gd 拆出控 LINT005 ≤400（第九轮 P1-B 入口接线外移）。
# pos = 源 ccp(左下原点) → Godot(左上原点)：godot_y = MAP_H - cocos_y（main_scene 计算）。
# pos 存源按钮中心点（CCSprite anchorPoint 0.5），_make_entry 转 Button 左上角（pos - BTN_SIZE/2）。
# title 存源 mainres.lua 的 LSTR key（mainres.Campaign / TimeRift / Trials / Crusade 等，zh-CN.lua:4857-4871），_make_entry 显示时 get_lstr 解析中文（照源 main.lua:533 br.title=T(LSTR(...))）。
# scale 照源（defence=0.9 / shop=0.8 / starshop=0.8，其余默认 1；mainres 多数 scale 注释掉）。
# unlock 照源 unlock_keys（defence=COT/pvp=PVP/shop=shop/estren=Enhance/exercise=Exercise/volcano=Crusade/handbook=Guild/excavate=Excavate）。
#   shop/Crusade/Guild/Excavate 不在 PlayerLevel.Unlock 表 → FeatureLimit 默认解锁（照源 playerlimit 设计）+ push_warning（照源 :74 print）。
#   sshop/ssshop 子商店走 PlayerLevel.Unlock（源 shopButtonType summon/into，简化为等级解锁）。
# light 照源 mainres.lightPos + lightSize（[px, py, sw, sh]；py 源 y 上 → Godot y 下翻 Y），press 光效按下显示（源 :592-604）。
# 路由照源 getMainButtonHandler（main.lua:1328-1514），见 main_scene._on_entry_pressed。
# starshop 源走 FCA（无 aniType，.abc），本项目 spine/ 无资源 → load_skeleton 失败降级（待 FcaAnimation 接入）。
const ENTRIES: Array = [
	{"id": "pve", "title": "mainres.Campaign", "pos": [625, 401], "parent": 4, "res": "eff_UI_Main_Pve", "touch": [-10, 0], "radius": 100, "light": [0, 19, 230, 350]},
	{"id": "pvp", "title": "mainres.Arean", "pos": [355, 386], "unlock": "PVP", "res": "eff_UI_Main_Pvp", "touch": [-15, 0], "radius": 65, "light": [0, 40, 350, 400]},
	{"id": "shop", "title": "mainres.Merchant", "pos": [1000, 311], "unlock": "shop", "scale": 0.8, "res": "eff_UI_Main_Shop", "gap": [2.75, 2.75, 1.71, 2, 6], "touch": [25, 0], "radius": 68, "light": [0, 50, 300, 300]},
	{"id": "tavern", "title": "mainres.Chests", "pos": [1290, 446], "res": "eff_UI_Main_Tarven", "touch": [0, 13], "radius": 100, "light": [0, 30, 300, 200]},
	{"id": "defence", "title": "mainres.TimeRift", "pos": [1270, 256], "unlock": "COT", "scale": 0.9, "res": "eff_UI_Main_Guard", "touch": [-10, 10], "radius": 65, "light": [0, 40, 300, 300]},
	{"id": "estren", "title": "mainres.Enchanting", "pos": [475, 261], "unlock": "Enhance", "res": "eff_UI_Main_Skill", "touch": [-10, 2], "radius": 85, "light": [0, 60, 250, 250]},
	{"id": "exercise", "title": "mainres.Trials", "pos": [1150, 351], "unlock": "Exercise", "res": "eff_UI_Main_Exercise", "touch": [0, 13], "radius": 85, "light": [0, 35, 200, 250]},
	{"id": "volcano", "title": "mainres.Crusade", "pos": [670, 186], "parent": 2, "unlock": "Crusade", "res": "eff_UI_Main_Volcano", "touch": [0, -30], "radius": 100, "light": [0, 40, 250, 250]},
	# 第九轮 P1-B2（用户决策 B）：title 改「图鉴」对齐实际行为（click 开 HandbookPanel 装备图鉴）。
	# 源该按钮=公会（联机 mainres.Guild / eff_UI_Main_Guild），源 main 无图鉴入口；目标单机化自建图鉴入口。
	# 图标保留 eff_UI_Main_Guild：源 main 无图鉴按钮→无专属建筑图标，借用公会建筑图标，待补图鉴建筑资源。
	{"id": "handbook", "title": "图鉴", "pos": [115, 446], "unlock": "Guild", "res": "eff_UI_Main_Guild", "touch": [0, -5], "radius": 150, "light": [0, 30, 500, 500]},
	{"id": "mailbox", "title": "mainres.Mailbox", "pos": [1000, 466], "res": "eff_UI_Main_Mailbox", "gap": [2, 4, 0, 0, 0], "touch": [0, 40], "radius": 60, "light": [8, 45, 200, 200]},
	{"id": "sshop", "title": "mainres.GoblinMerchant", "pos": [195, 336], "unlock": "sshop", "res": "eff_UI_Main_Shop2", "gap": [1.46, 1.46, 1.46, 1, 6], "touch": [0, 0], "radius": 68, "light": [0, 25, 317, 300]},
	{"id": "ssshop", "title": "mainres.Godfather", "pos": [10, 316], "unlock": "ssshop", "res": "eff_UI_Main_Shop3", "gap": [2, 4, 0, 0, 0], "touch": [0, 0], "radius": 40, "light": [0, 45, 307, 200]},
	{"id": "starshop", "title": "mainres.StarShop", "pos": [82, 296], "scale": 0.8, "res": "eff_UI_Main_Shop_Star", "gap": [1.4583, 1.4583, 2.04167, 3, 10], "touch": [0, 35], "radius": 60, "light": [-6, 30, 150, 180]},
	{"id": "excavate", "title": "mainres.Excavate", "pos": [1450, 346], "unlock": "Excavate", "res": "eff_UI_Main_Treasure", "touch": [0, -50], "radius": 100, "light": [0, 75, 600, 400]},
	{"id": "ranklist", "title": "mainres.Rank", "pos": [860, 386], "res": "eff_UI_Main_Rank", "touch": [0, 30], "radius": 50, "light": [0, 30, 150, 250]},
]
