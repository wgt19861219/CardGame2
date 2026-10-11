#!/usr/bin/env python3
"""ch203 冰封王座三部曲：静态表项目新增段注入（2026-10-08 设计方案，源无对应）。

StageDungeon/Battle 的 ch203 段由 expand_stage_dungeon.py / expand_battle_dungeon.py
生成（base 关与波次），本工具注入其余三处静态表数据（均为 lua_to_json 产物，直接改
JSON 会被重转覆盖，故照 expand 范式集中在此、build_data 编排幂等再生）：

  ① ActStageGroupDungeon.json：3 组（50008 毒蛇神殿/50009 海加尔山/50010 冰冠堡垒），
     字段模板照 50005 纳克萨玛斯（DailyLimit 1 + MaxBuyPerDay 2 + BuyCost 100 龙鳞硬币）。
  ② LSTR_zh-CN.json：22 键（组名 3 + Boss 名 9 + Boss 描述 9 + 主城入口 1）。
     先例：DUNGEON.* 键源各语言包仅 zh-CN 有值，故只注入 zh-CN。
  ③ Equip.json：断点装备 Drop 1-3 获取途径展示指向（8 基件→材料产地三关、8 组件+8 碎片
     +万能碎片→所在关，共 25 条）。
  ④ StageDungeon.json：ch203 段 Boss Skills（每 Boss 4 组现成技能，魔兽原型化；
     引擎 boss 构建 override，玩家英雄技能栏不受影响）。

用法：python tools/expand_lich_data.py
编排：python tools/build_data.py
"""
import copy
import json
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(PROJECT_ROOT, "resources", "data")

# ── ① ActStageGroupDungeon 3 组（模板照 50005）─────────────────────────────────
WEEK_DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

_LICH_GROUPS = [
    # (组号, 组名键, Stages, UI reward 预览 3 槽)
    (50008, "DUNGEON.SERPENTSHRINE", [50022, 50023, 50024], [455, 452, 443]),
    (50009, "DUNGEON.HYJAL_SUMMIT", [50025, 50026, 50027], [446, 449, 458]),
    (50010, "DUNGEON.ICECROWN_CITADEL", [50028, 50029, 50030], [461, 464, 335]),
]


def inject_groups() -> None:
    path = os.path.join(DATA_DIR, "ActStageGroupDungeon.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    for gid, name_key, stages, previews in _LICH_GROUPS:
        entry = {
            "CD": 0, "DailyLimit": 1, "MaxBuyPerDay": 2, "BuyCost": 100,
            "Currency": "dungeonpoint", "Group Name": name_key, "Difficulty": 2,
            "Stage Group": gid,
        }
        for d in WEEK_DAYS:
            entry[d] = True
        entry["Stages"] = stages + [0] * (8 - len(stages))
        entry["UI reward1"] = previews[0]
        entry["UI reward2"] = previews[1]
        entry["UI reward3"] = previews[2]
        data[str(gid)] = entry
    ordered = {k: data[k] for k in sorted(data, key=int)}
    with open(path, "w", encoding="utf-8") as f:
        json.dump(ordered, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"ActStageGroupDungeon.json: 注入 ch203 3 组（50008-50010）")


# ── ② LSTR zh-CN 22 键 ────────────────────────────────────────────────────────
_LSTR_KEYS = {
    "DUNGEON.SERPENTSHRINE": "毒蛇神殿",
    "DUNGEON.HYJAL_SUMMIT": "海加尔山",
    "DUNGEON.ICECROWN_CITADEL": "冰冠堡垒",
    "DUNGEON.BOSS_KARATHESS": "深水领主卡拉瑟雷斯",
    "DUNGEON.BOSS_MOROGRIM": "莫洛格里·踏潮者",
    "DUNGEON.BOSS_VASHJ": "瓦丝琪",
    "DUNGEON.BOSS_RAGE_WINTERCHILL": "雷基·冬寒",
    "DUNGEON.BOSS_ANETHERON": "安纳塞隆",
    "DUNGEON.BOSS_ARCHIMONDE": "阿克蒙德",
    "DUNGEON.BOSS_SINDRAGOSA": "辛达苟萨",
    "DUNGEON.BOSS_BLOOD_QUEEN": "血腥女王兰娜瑟尔",
    "DUNGEON.BOSS_LICH_KING": "巫妖王",
    "DUNGEON.DESC_KARATHESS": "盘牙水库的激流深处，深水领主统御着狂暴的水元素。他麾下的鲨鱼猎手从不留活口，沉入深渊者无人归还。",
    "DUNGEON.DESC_MOROGRIM": "踏潮者莫洛格里行走在海沟之间，他的每一次踏步都掀起吞没舰队的巨浪。被他盯上的猎物，终将葬身鱼腹。",
    "DUNGEON.DESC_VASHJ": "纳迦皇后瓦丝琪，深海之主的忠诚仆从。她的毒蛇发丝缠绕着无数寻宝者的白骨，海神的三叉戟与号角正是她最珍视的战利品。",
    "DUNGEON.DESC_RAGE_WINTERCHILL": "雷基·冬寒，天灾军团的首席巫妖。他所过之处，盛夏凝为凛冬，溪流冻作寒冰。凛冽的霜寒之下，是无尽的死亡。",
    "DUNGEON.DESC_ANETHERON": "恐惧魔王安纳塞隆以噩梦为食。他潜入勇士的梦境播撒绝望，待其心防崩塌之时，便是恶魔大军踏平营地之日。",
    "DUNGEON.DESC_ARCHIMONDE": "燃烧军团的统帅阿克蒙德，一步跨越山海，只手撕裂世界之树的结界。无数勇士的披风，至今仍在他脚下飘扬。",
    "DUNGEON.DESC_SINDRAGOSA": "辛达苟萨，冰冠堡垒的霜翼女王。这头远古巨龙的悲鸣化作毁灭的寒潮，被冻结的灵魂将在她的巢穴中永世哀嚎。",
    "DUNGEON.DESC_BLOOD_QUEEN": "血腥女王兰娜瑟尔统治着猩红之厅。她的吻既是恩赐也是诅咒——被赐予永血的仆从，将带着无尽的渴望为她而战。",
    "DUNGEON.DESC_LICH_KING": "冰封王座之上，巫妖王阿尔萨斯手持霜之哀伤，统御着无尽的亡灵军团。那顶统御之盔，正是整个天灾军团力量的源泉。",
    "mainres.Icecrown": "冰封王座",
}


def inject_lstr() -> None:
    path = os.path.join(DATA_DIR, "LSTR_zh-CN.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    data.update(_LSTR_KEYS)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"LSTR_zh-CN.json: 注入 ch203 {len(_LSTR_KEYS)} 键")


# ── ③ Equip Drop 获取途径展示指向 ────────────────────────────────────────────
# 基件 → 材料产地三关（首槽=断点组件所在关）；组件/碎片 → 所在关；335 → 巫妖王关。
_DROP_PATCH = {
    # 8 基件
    "442": [50024, 50022, 50023],  # 正义风衣（443 海军勋章@瓦丝琪关）
    "445": [50025, 50026, 50027],  # 惩罚之雷（446 冥王之眼@雷基·冬寒关）
    "448": [50026, 50025, 50027],  # 暮光圣经（449 暮光晶体@安纳塞隆关）
    "451": [50023, 50022, 50024],  # 海斗士鳞衣（452 海洋之心@踏潮者关）
    "454": [50022, 50023, 50024],  # 海神三叉戟（455 海神之螺@深水领主关）
    "457": [50027, 50025, 50026],  # 斯巴达披风（458 斯巴达矛尖@阿克蒙德关）
    "460": [50028, 50029, 50030],  # 主导者之盔（461 九头蛇指爪@辛达苟萨关）
    "463": [50029, 50028, 50030],  # 男爵手套（464 恶魔之血@血腥女王关）
    # 8 组件 → 所在关（Drop 1；2/3 槽同关不同 Boss 变体无意义，置同值保持展示单来源）
    "455": [50022, 0, 0], "452": [50023, 0, 0], "443": [50024, 0, 0],
    "446": [50025, 0, 0], "449": [50026, 0, 0], "458": [50027, 0, 0],
    "461": [50028, 0, 0], "464": [50029, 0, 0],
    # 8 碎片 → 所在关
    "456": [50022, 0, 0], "453": [50023, 0, 0], "444": [50024, 0, 0],
    "447": [50025, 0, 0], "450": [50026, 0, 0], "459": [50027, 0, 0],
    "462": [50028, 0, 0], "465": [50029, 0, 0],
    # 万能碎片 → 巫妖王关
    "335": [50030, 0, 0],
}


def inject_equip_drops() -> None:
    path = os.path.join(DATA_DIR, "Equip.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    for item_id, drops in _DROP_PATCH.items():
        if item_id not in data:
            raise SystemExit(f"Equip.json 缺条目 {item_id}，中止（防静默漏改）")
        for i, v in enumerate(drops, start=1):
            data[item_id][f"Drop {i}"] = v
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"Equip.json: 注入 {len(_DROP_PATCH)} 条 Drop 获取途径指向")


# ── ④ PlayerLevel.json lv80 Unlock +Icecrown（主城入口 80 级门槛）──────────────
def inject_player_unlock() -> None:
    path = os.path.join(DATA_DIR, "PlayerLevel.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    lv = data.get("80", {})
    unlock: dict = lv.get("Unlock", {})
    if "Icecrown" not in unlock.values():
        # 槽位号顺延（lv80 既有 {"1": "Chapter"}；源键序习惯数字槽位）
        next_slot = str(len(unlock) + 1)
        unlock[next_slot] = "Icecrown"
        lv["Unlock"] = unlock
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print("PlayerLevel.json: lv80 Unlock +Icecrown（80 级解锁主城入口）")
    else:
        print("PlayerLevel.json: Icecrown 已在 lv80 Unlock，跳过")


# ── ④ StageDungeon Boss Skills：Boss 战技能魔兽化（2026-10-09 用户需求）────────
# 借 Skill 表现成技能组（动画/特效/Buff 全原生），每 Boss 4 组 [普攻, 技能1, 技能2, 大招]。
# 怪物 rank 按等级估算（80 级→rank 8），槽全解锁；battle_engine_waves 构建 boss 时读
# 本字段 override 默认 SkillGroup 槽（该单位作为玩家英雄的技能栏不受影响）。
_BOSS_SKILLS = {
    # 深水领主卡拉瑟斯（大鱼人 SG）：水花环+碎击眩晕（猎手重击）+潮汐巨浪
    50022: [141, 132, 142, 150],   # 三组=SG_atk2（2026-10-10 修：旧 191 SNK_atk 是别家普攻，AI 拿普攻当主动技反复选致 Boss 抖动）
    # 莫洛格里·踏潮者（潮汐 TH）：水浪+水环+潮汐毁灭
    50023: [151, 152, 12, 150],
    # 瓦丝琪（小娜迦）：月刃连环（多重箭）+束缚箭（缠绕定身 buff=stun）+月刃风暴
    50024: [131, 312, 112, 330],
    # 雷基·冬寒（巫妖）：冰箭+冰冻箭+极寒领域
    50025: [351, 122, 22, 120],
    # 安纳塞隆（恐惧魔王 Lion）：沉睡（沉默 buff）+地狱火（烈焰波）+死亡之指
    50026: [61, 262, 383, 60],
    # 阿克蒙德（灵魂守卫 TB）：暗影冲击波+压魂+魂之挽歌（毁灭之雨意象）
    50027: [471, 73, 253, 250],
    # 辛达苟萨（亚龙 Viper）：毒液+冰爆+极寒领域（冰霜吐息）
    50028: [371, 372, 123, 120],
    # 血腥女王兰娜瑟尔（痛苦女王 QOP）：毒匕+燃血+超声尖叫
    50029: [71, 72, 342, 70],
    # 巫妖王阿尔萨斯（死骑 LOA）：冰环+死亡凋零（DP circle+沉默哀嚎）+连环霜冻（霜之哀伤）
    50030: [421, 352, 403, 350],
}


# ── ⑥ StageDungeon Boss Aura：元素光环粒子类型（mist/frost/flame/spark/blood）──
# battle_engine_waves boss 构建 config 透传 → BattleActor 挂 BossAura CPUParticles2D。
_BOSS_AURAS = {
    50022: "mist", 50023: "mist", 50024: "mist",        # 毒蛇神殿：水雾
    50025: "frost", 50026: "flame", 50027: "spark",      # 海加尔：冷气/地狱火/毁灭电光
    50028: "frost", 50029: "blood", 50030: "frost",      # 冰冠：冷气/血雾/巫妖王冷气
}


def inject_boss_auras() -> None:
    path = os.path.join(DATA_DIR, "StageDungeon.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    changed = 0
    for sid, aura in _BOSS_AURAS.items():
        if data[str(sid)].get("Boss Aura") != aura:
            data[str(sid)]["Boss Aura"] = aura
            changed += 1
    if changed:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
    print(f"StageDungeon.json: Boss Aura 注入/核对 {len(_BOSS_AURAS)} 关（{changed} 处更新）")


def inject_boss_skills() -> None:
    path = os.path.join(DATA_DIR, "StageDungeon.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    changed = 0
    for sid, groups in _BOSS_SKILLS.items():
        if str(sid) not in data:
            raise SystemExit(f"StageDungeon.json 缺关 {sid}，中止（先跑 expand_stage_dungeon）")
        if data[str(sid)].get("Boss Skills") != groups:
            data[str(sid)]["Boss Skills"] = groups
            changed += 1
    if changed:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
    print(f"StageDungeon.json: Boss Skills 注入/核对 {len(_BOSS_SKILLS)} 关（{changed} 处更新）")


def main() -> None:
    inject_groups()
    inject_lstr()
    inject_equip_drops()
    inject_player_unlock()
    inject_boss_skills()
    inject_boss_units()
    inject_boss_unit_ranks()
    inject_boss_puppets()
    inject_boss_anim_tables()
    inject_boss_auras()


# ── ⑤ Unit 换皮新角色段：tid 90000+（2026-10-09，Angel 换皮管线接入战斗）──
# 照模板 Unit 整行复制，仅改 ID/名字/Puppet→assets/anim_frames/<新名>（程序化调色换皮，
# recolor_lich_bosses.py 批量产物）；战斗由 Battle boss 槽引用 + Boss Skills override。
# Unit Type=Monster：不进抽卡/GM 英雄池（tavern_data 按 Hero 过滤）。
# (tid, 模板tid, 新Puppet名, 中文名)
_LICH_BOSS_UNITS = [
    (90001, 42, "LichKing", "巫妖王阿尔萨斯"),
    (90002, 14, "Karathress", "深水领主卡拉瑟雷斯"),
    (90003, 15, "Tidewalker", "莫洛格里·踏潮者"),
    (90004, 13, "LadyVashj", "瓦丝琪女士"),
    (90005, 35, "RageWinter", "雷基·冬寒"),
    (90006, 6, "Anetheron", "安纳塞隆"),
    (90007, 47, "Archimonde", "阿克蒙德"),
    (90008, 37, "Sindragosa", "辛达苟萨"),
    (90009, 7, "BloodQueen", "血腥女王兰娜瑟尔"),
]


def inject_boss_units() -> None:
    path = os.path.join(DATA_DIR, "Unit.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    new_units = [t for t in _LICH_BOSS_UNITS if str(t[0]) not in data]
    for tid, tpl_tid, puppet, _zh in new_units:
        row = dict(data[str(tpl_tid)])   # 模板整行复制
        row["ID"] = tid
        row["Name"] = puppet
        row["Display Name"] = f"Unit.hero.alias.{tid}"
        row["Puppet"] = puppet + ".cha"   # Puppet 表键格式带 .cha（unit_sprite: Unit.Puppet→Puppet 表→Resource）
        row["Unit Type"] = "Monster"   # Boss 专用：不进抽卡/GM 英雄池
        row["Portrait"] = f"UI/HERO/{puppet}.jpg"   # 换色头像（recolor_lich_portraits.py 产物，2026-10-10）
        # Boss Portrait（战斗大血条 icon，battle_big_hp_bar boss_icon_name 链；源公会 Boss
        # 用 guild/boss/boss_avatar_*.png 同字段）同指换色头像
        row["Boss Portrait"] = f"UI/HERO/{puppet}.jpg"
        row["HP Layers"] = 3   # 多血段大血条（battle_scene hp_layer!=0 才建条+icon；模板英雄=0 无条）
        data[str(tid)] = row
    # 存量校正：首版注入漏 .cha 后缀致战斗 puppet 解析失败回落占位图（2026-10-09）；
    # Portrait/Boss Portrait 原指模板原图，2026-10-10 换色头像落地后指向自有图
    # （UI 头像与战斗形象一致；Boss Portrait 走战斗大血条 icon 链）
    fixed_puppet = fixed_portrait = 0
    for tid, _t, puppet, _zh in _LICH_BOSS_UNITS:
        if str(tid) not in data:
            continue
        if data[str(tid)].get("Puppet") != puppet + ".cha":
            data[str(tid)]["Puppet"] = puppet + ".cha"
            fixed_puppet += 1
        portrait = f"UI/HERO/{puppet}.jpg"
        if (data[str(tid)].get("Portrait") != portrait or data[str(tid)].get("Boss Portrait") != portrait
                or int(data[str(tid)].get("HP Layers", 0)) != 3):
            data[str(tid)]["Portrait"] = portrait
            data[str(tid)]["Boss Portrait"] = portrait
            data[str(tid)]["HP Layers"] = 3
            fixed_portrait += 1
    if new_units or fixed_puppet or fixed_portrait:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
    print(f"Unit.json: ch203 换皮新角色 {len(_LICH_BOSS_UNITS) - len(new_units)} 已在 / +{len(new_units)} 新增"
          f" / .cha 校正 {fixed_puppet} / Portrait 校正 {fixed_portrait}")
    # LSTR 名字键
    lp = os.path.join(DATA_DIR, "LSTR_zh-CN.json")
    with open(lp, encoding="utf-8") as f:
        lstr = json.load(f)
    new_keys = {f"Unit.hero.alias.{tid}": zh for tid, _t, _p, zh in _LICH_BOSS_UNITS
                if f"Unit.hero.alias.{tid}" not in lstr}
    if new_keys:
        lstr.update(new_keys)
        with open(lp, "w", encoding="utf-8") as f:
            json.dump(lstr, f, ensure_ascii=False, indent=2)
            f.write("\n")
    print(f"LSTR_zh-CN.json: +{len(new_keys)} Boss 名字键")


def inject_boss_puppets() -> None:
    # Puppet 表条目（unit_sprite.gd: Unit.Puppet → Puppet 表 → Resource=anim_frames 目录）。
    # 照模板 Unit 的 Puppet 行整行复制（保 Scale/ScaleX Inverse 体型标记），仅换 ID/Resource/键名。
    upath = os.path.join(DATA_DIR, "Unit.json")
    ppath = os.path.join(DATA_DIR, "Puppet.json")
    with open(upath, encoding="utf-8") as f:
        units = json.load(f)
    with open(ppath, encoding="utf-8") as f:
        puppets = json.load(f)
    added = 0
    for tid, tpl_tid, puppet, _zh in _LICH_BOSS_UNITS:
        key = puppet + ".cha"
        if key in puppets:
            continue
        tpl_puppet = str(units[str(tpl_tid)]["Puppet"])   # 模板 Puppet 键（如 LOA.cha）
        row = dict(puppets[tpl_puppet])
        row["ID"] = key
        row["Resource"] = puppet
        puppets[key] = row
        added += 1
    if added:
        with open(ppath, "w", encoding="utf-8") as f:
            json.dump(puppets, f, ensure_ascii=False, indent=2)
            f.write("\n")
    print(f"Puppet.json: ch203 换皮条目 {len(_LICH_BOSS_UNITS) - added} 已在 / +{added} 新增")


def inject_boss_anim_tables() -> None:
    # AnimAtkFrame/AnimDuration 动画时序表：换皮资源照模板资源键整块深拷贝（recolor 只
    # 调色不改骨架，帧时序数值照抄）。缺条目时 BattleSkillPhase.rebuild_phase_list 拿不到
    # 任何 phase → 技能 start 不设动作、完成回调永不触发，Boss 钉死 ATTACK 态原地循环
    # Move 动画 =「抖来抖去不攻击不放技能」（2026-10-10 根修）。
    upath = os.path.join(DATA_DIR, "Unit.json")
    ppath = os.path.join(DATA_DIR, "Puppet.json")
    with open(upath, encoding="utf-8") as f:
        units = json.load(f)
    with open(ppath, encoding="utf-8") as f:
        puppets = json.load(f)
    res_map: dict[str, str] = {}
    for _tid, tpl_tid, puppet, _zh in _LICH_BOSS_UNITS:
        tpl_puppet = str(units[str(tpl_tid)]["Puppet"])
        res_map[puppet + ".cha"] = str(puppets[tpl_puppet]["Resource"]) + ".cha"
    for table in ("AnimAtkFrame", "AnimDuration"):
        path = os.path.join(DATA_DIR, table + ".json")
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        added = 0
        for new_key, tpl_key in res_map.items():
            if new_key not in data:
                if tpl_key not in data:
                    raise SystemExit(f"{table}.json 缺模板条目 {tpl_key}，中止（防静默漏拷）")
                data[new_key] = copy.deepcopy(data[tpl_key])
                added += 1
        if added:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
                f.write("\n")
        print(f"{table}.json: 换皮时序条目 {len(res_map) - added} 已在 / +{added} 新增（照模板复制）")


def inject_boss_unit_ranks() -> None:
    # UnitRank 表：换皮 Boss 照模板英雄整块深拷贝（12 rank 档 E.HP/E.AD 等战斗修正）。
    # 缺条目时 rebuild 的 rankInfo 插值恒 0——Boss 只有 Unit 基础值+三维成长，
    # 80 级实测 AD 仅为同波小怪 23%（2026-10-10「Boss 比小怪还弱」根修一）。
    path = os.path.join(DATA_DIR, "UnitRank.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    added = 0
    for tid, tpl_tid, _p, _zh in _LICH_BOSS_UNITS:
        if str(tid) in data:
            continue
        tpl_key = str(tpl_tid)
        if tpl_key not in data:
            raise SystemExit(f"UnitRank.json 缺模板条目 {tpl_key}，中止（防静默漏拷）")
        data[str(tid)] = copy.deepcopy(data[tpl_key])
        added += 1
    if added:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
    print(f"UnitRank.json: 换皮 Boss rank 表 {len(_LICH_BOSS_UNITS) - added} 已在 / +{added} 新增（照模板复制）")


if __name__ == "__main__":
    main()
