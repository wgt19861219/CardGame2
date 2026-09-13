class_name MainSceneEntries
extends RefCounted

## 主菜单 15 入口按钮数据（照源 mainres.lua res_pos + button_key）。
## 从 main_scene.gd 拆出控 LINT005 ≤400（第九轮 P1-B 入口接线外移）。
# pos = 源 ccp(左下原点) → Godot(左上原点)：godot_y = 480 - cocos_y（Task2 迁移，pos 已是 godot
# 中心直存；旧 536 基准 + main_scene +104 补差已废）。ssshop 保留旧版 (x+100,y+45) 人为调整
#（源 ccp(-90,175) 中心在屏外左缘，拖到最右才可见，旧版挪进容器内沿用）。
# pos 存源按钮中心点（CCSprite anchorPoint 0.5），_make_entry 转 Button 左上角（pos - BTN_SIZE/2）。
# title 存源 mainres.lua 的 LSTR key（mainres.Campaign / TimeRift / Trials / Crusade 等，zh-CN.lua:4857-4871），_make_entry 显示时 get_lstr 解析中文（照源 main.lua:533 br.title=T(LSTR(...))）。
# scale 照源（defence=0.9 / shop=0.8 / starshop=0.8，其余默认 1；mainres 多数 scale 注释掉）。
# unlock 照源 unlock_keys（defence=COT/pvp=PVP/shop=shop/estren=Enhance/exercise=Exercise/volcano=Crusade/guild=Guild/excavate=Excavate；源内部键名 handbook→2026-09-13 恢复公会名义后本表用 guild）。
#   shop/Crusade/Guild/Excavate 不在 PlayerLevel.Unlock 表 → FeatureLimit 默认解锁（照源 playerlimit 设计）+ push_warning（照源 :74 print）。
#   sshop/ssshop 子商店走 PlayerLevel.Unlock（源 shopButtonType summon/into，简化为等级解锁）。
# light 照源 mainres.lightPos + lightSize（[px, py, sw, sh]；py 源 y 上 → Godot y 下翻 Y），press 光效按下显示（源 :592-604）。
# 路由照源 getMainButtonHandler（main.lua:1328-1514），见 main_scene._on_entry_pressed。
# starshop 源走 FCA（无 aniType，.abc），本项目 spine/ 无资源 → load_skeleton 失败降级（待 FcaAnimation 接入）。
const ENTRIES: Array = [
	{"id": "pve", "title": "mainres.Campaign", "pos": [625, 345], "parent": 4, "res": "eff_UI_Main_Pve", "touch": [-10, 0], "radius": 100, "light": [0, 19, 230, 350]},
	{"id": "pvp", "title": "mainres.Arean", "pos": [355, 330], "unlock": "PVP", "res": "eff_UI_Main_Pvp", "touch": [-15, 0], "radius": 65, "light": [0, 40, 350, 400]},
	{"id": "shop", "title": "mainres.Merchant", "pos": [1000, 255], "unlock": "shop", "scale": 0.8, "res": "eff_UI_Main_Shop", "gap": [2.75, 2.75, 1.71, 2, 6], "touch": [25, 0], "radius": 68, "light": [0, 50, 300, 300]},
	{"id": "tavern", "title": "mainres.Chests", "pos": [1290, 390], "res": "eff_UI_Main_Tarven", "touch": [0, 13], "radius": 100, "light": [0, 30, 300, 200]},
	{"id": "defence", "title": "mainres.TimeRift", "pos": [1270, 200], "unlock": "COT", "scale": 0.9, "res": "eff_UI_Main_Guard", "touch": [-10, 10], "radius": 65, "light": [0, 40, 300, 300]},
	{"id": "estren", "title": "mainres.Enchanting", "pos": [475, 205], "unlock": "Enhance", "res": "eff_UI_Main_Skill", "touch": [-10, 2], "radius": 85, "light": [0, 60, 250, 250]},
	{"id": "exercise", "title": "mainres.Trials", "pos": [1150, 295], "unlock": "Exercise", "res": "eff_UI_Main_Exercise", "touch": [0, 13], "radius": 85, "light": [0, 35, 200, 250]},
	{"id": "volcano", "title": "mainres.Crusade", "pos": [670, 130], "parent": 2, "unlock": "Crusade", "res": "eff_UI_Main_Volcano", "touch": [0, -30], "radius": 100, "light": [0, 40, 250, 250]},
	# 第九轮 P1-B2（用户决策 B）：title 改「图鉴」对齐实际行为（click 开 HandbookPanel 装备图鉴）。
	# 公会建筑（源内部键名即 handbook，title=mainres.Guild「公会」，联机功能单机裁剪）。
	# 2026-07-23 决策 B 曾改图鉴入口，2026-09-13 用户拍板②恢复公会名义（图鉴有背包面板
	# 专属入口 %HandbookBtn，主城建筑不再兼任）——id 改 guild、title 回 mainres.Guild，
	# 点击 Toast「公会功能未开放」（guild handler 在 SKIPPED_HANDLERS 裁剪清单）。
	# pos 2026-09-13 四轮：原左下台面 [115,390] 让位给 ssshop（用户点名黑市回左下，台面
	# 只容一个建筑）→ 挪右段 [1450,420] 藏宝地穴正下方草地（几何排档：贴图 y 342-475 落
	# 连续草地/excavate label 底 331 间距 11/召唤法阵 x 间距 34/x>887 战役跨视差安全带）。
	{"id": "guild", "title": "mainres.Guild", "pos": [1450, 420], "unlock": "Guild", "res": "eff_UI_Main_Guild", "touch": [0, -5], "radius": 150, "light": [0, 30, 500, 500]},
	{"id": "mailbox", "title": "mainres.Mailbox", "pos": [1000, 410], "res": "eff_UI_Main_Mailbox", "gap": [2, 4, 0, 0, 0], "touch": [0, 40], "radius": 60, "light": [8, 45, 200, 200]},
	{"id": "sshop", "title": "mainres.GoblinMerchant", "pos": [195, 280], "unlock": "sshop", "res": "eff_UI_Main_Shop2", "gap": [1.46, 1.46, 1.46, 1, 6], "touch": [0, 0], "radius": 68, "light": [0, 25, 317, 300]},
	# ssshop（Godfather=黑市商人，zh-CN:55）pos 2026-09-13 四轮调整（受控偏离源 (10,260)）：
	# ①[105,395] 左下草皮台面 → 与同台面 handbook 图鉴同心全遮；②[605,265] 中下部东草台 →
	# 与 pve 战役（verytop 层 pos[625,345]，视差系数 0.9≠top 层 1）跨视差互穿——两建筑随拖动
	# 相对滑移 ±139 逻辑像素（top.x∈[-1388,212]×0.1），任何贴近必互穿；③[1450,405] 右段 →
	# 用户不接受（默认视口屏外，须拖到最左才可见）；④终位回 [105,395] 左下草皮台面（①的四验
	# 全过位），handbook 图鉴挪右段 [1450,420] 让台（2026-09-13 用户点名黑市优先回左下）。
	{"id": "ssshop", "title": "mainres.Godfather", "pos": [105, 395], "unlock": "ssshop", "res": "eff_UI_Main_Shop3", "gap": [2, 4, 0, 0, 0], "touch": [0, 0], "radius": 40, "light": [0, 45, 307, 200]},
	{"id": "starshop", "title": "mainres.StarShop", "pos": [82, 240], "scale": 0.8, "res": "eff_UI_Main_Shop_Star", "gap": [1.4583, 1.4583, 2.04167, 3, 10], "touch": [0, 35], "radius": 60, "light": [-6, 30, 150, 180]},
	{"id": "excavate", "title": "mainres.Excavate", "pos": [1450, 290], "unlock": "Excavate", "res": "eff_UI_Main_Treasure", "touch": [0, -50], "radius": 100, "light": [0, 75, 600, 400]},
	{"id": "ranklist", "title": "mainres.Rank", "pos": [860, 330], "res": "eff_UI_Main_Rank", "touch": [0, 30], "radius": 50, "light": [0, 30, 150, 250]},
]
