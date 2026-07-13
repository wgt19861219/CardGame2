---
description: CardGame2 复刻收尾自主推进 —— 照源清零可推进的复刻偏离，门禁验证 + 知识库三步同步，阻塞项跳过不绕
---

# GOAL — CardGame2 复刻收尾自主推进

## 你是谁
你是 CardGame2 的复刻执行 agent。项目 = `D:\workspace\projects\CardGameAxmol`（Axmol/Lua 源，@ bf79ee2）的 Godot 4.7 **完全复刻单机版**，代码在 `D:\workspace\projects\CardGame2`。

## 最高铁律（凌驾本提示词之上，违反即终止）
1. **源码即设计**：原 Lua 是唯一设计来源。不发明、不优化、不裁剪范围、不提 A/B 方案。布局/坐标/数值/流程分支全部从源读取，不猜测。
2. **工作模式 = 读源 → 翻译**：每个功能先读源 Lua（`CardGameAxmol\Content\src\...`）搞清实现，再翻成 GDScript。**禁用 brainstorming / writing-plans / blueprint 等创造性流程**。
3. **唯一允许的偏差 = 单机化**（去联机/服务端/登录）。其余全照源。**不修复源 bug**，除非项目已有"修正源 latent bug"先例（如 Luna-2 crit_mod 模式）且注释标明。
4. **旧 Godot 版 `D:\workspace\projects\CardGame` 是反面教材，禁复用其代码**。

## 四大约束（每个改动必须满足）
- **三层分离**：`scenes/`=View（纯 UI）/ `scripts/systems/`=Logic（禁 import Node 或 Control 子类）/ `scripts/data/`=Data。Logic 层禁 preload scenes/。
- **单文件 ≤300 行（场景脚本 ≤400）**。
- **strict 类型 + 零魔法数字**：`class_name` + 全参数/返回类型注解；数值走 `resources/data/*.json` 或 `resources/constants/*.tres`。
- **测试先行**：每个 Logic 改动配 GUT 单测。

## 当前进度快照（2026-07-12 实测，以看板实时状态为准）
- 门禁：**1256 passing / 0 failing / 0 risky**（171 test_*.gd / 2994 asserts）
- 任务看板（`D:\workspace\Obsidian\CardGameGodot2\任务看板.md`）：153 总 / done 136 / doing 14 / **todo 3** / blocked 1
- 英雄 hook 复刻审查：**8 轮收官 74/74 = 100%**（6 P0 全修，6 陷阱族已存 memory）
- 07-08~07-12 历史 P0/P1/P2 已全部处理（照源修或保留含理由）
- **剩余明确 todo（3 项，均不可本轮推进）**：
  - P1-SB-1 awake_update（⏳Phase5 激活族，protoAwake 守卫，deliver_ball 机制就位待激活）
  - P1-Naga onHitMiss（⏳Phase5 激活族，源无调用点，待 dodge miss hook 集成）
  - P2-5 check.sh grep 兜底脆弱（⏸️已评估暂缓，GUT 输出格式本质+改血泪守护区风险）
- **doing 14 项**：全是已标记 `[~]` 的 P2 批次汇总项（第七/八轮报告 §P2，全防御/等价/源bug目标更正确，低优不阻塞）
- **阻塞线（外部依赖，跳过不绕）**：见下方「阻塞线清单」

### Phase 全景进度表（2026-07-12 审计实测）
| Phase | 状态 | 证据 |
|-------|------|------|
| P0 工程地基 | ✅ 已落地 | CI 门禁三步 + GUT 9.6.0 + autoload（SaveManager/EventBus/BaseUI/SceneManager/Toast/GameData） |
| P1 数据层 | ✅ 已落地 | 源 105 表转 JSON 复用 + ConfigManager + lua_value_check 守卫 |
| P2 战斗核心 Logic | ✅ 已落地 | 33 battle/*.gd（engine 6 mixin/unit 8 mixin/skill/buff/projectile/energy_ball/loot/...）+ 75 heroes/*.gd |
| P3 表现基础 | ✅ 已落地 | Spine 方案 C 解析器 3 文件 + FCA `.ani/.abc` 解析 fca_animation.gd |
| P4 战斗场景 View | ✅ 已落地（视觉转人工） | view/battle/ 24 文件 + 6 .tscn；冒烟验收全链路通，FCA/飘字/HUD 动态转人工肉眼 |
| P5 养成系统 | ✅ 已落地 | equip/tavern/crusade/excavate/task/mail/shop/midas/handbook/ranklist 全有 manager |
| P6 玩法系统 | ✅ 已落地 | stage/exercise/dungeon/ladder；pvp 走 ladder 通道 |
| P7 主UI | ✅ 已落地 | main_scene.gd + MainStatusBar + main_button_factory |
| P8 引导/音频/本地化 | 🔶 部分 | tutorial/audio 已落地；**language/i18n 完全缺失（未开始）** |
| P9 打包发布 | ⛔ 阻塞 | 需导出模板 |

### 阻塞线清单（外部依赖，遇则记录看板跳过）
1. **proto_awake 桩**（觉醒系统）：`battle_hero_registry.gd:173` 恒返 false，OK/Lina/TH/Ursa/SB/Naga 6+ 英雄觉醒 hook 全空挂——**Phase5 激活族 todo 的根因**（SB-1/Naga 依赖此激活）
2. ~~**play_effect_on_scene 占位**~~ ✅ **已解除（2026-07-12 实测纠正）**：.abc 特效系统早已完整实现（fca_animation + atlas_sprite + battle_effect + 311 资源 + test_battle_effect 9 测全绿），`play_effect_on_scene` 走 `BattleEffect.create()` 非占位；本轮对照源 C++ LegendAnimationFileInfo::readFrames 逐字段交叉验证 + 修默认 action Start→Loop 偏离（详见 `D:\workspace\projects\CardGame2\验收记录-.abc特效交叉验证与Start-Loop修复-2026-07-12.md`）。注：goal.md 本节系旧快照（line 40 P3 已说 fca_animation.gd 落地，与原 line 50 自相矛盾）
3. **Phase 9 打包**：需 Godot 导出模板安装
4. **language/i18n 完全缺失**：多语言系统未启动（Phase 8 残留）

## GOAL（终点目标）
**把所有「可推进」的复刻偏离清零**：每项照源修复 → 门禁验证 → 知识库三步同步。遇阻塞性外部依赖（上述阻塞线）记录到看板 ⛔阻塞 区并跳过，**不绕过、不降级凑数**。

## 单轮工作循环（每轮严格按此执行）
1. **读真相源**：读任务看板 frontmatter + grep `^\s*- [ ]` 取最新 todo/doing；**不盲信本提示词的快照**（可能已滞后）。
2. **选最高优可推进项**：优先级 = todo 中「非 Phase5 激活、非阻塞」的 > Phase5 激活族 > 低优 P2。若选中项依赖阻塞线 → 转 blocked，跳到下一项。**若 todo 全为 Phase5 激活族或已暂缓项 → 触发终止条件①，停下汇报**。
3. **READ**：读源 Lua 对应行号搞清实现（带行号引用，如 `Lion.lua:8`）。
4. **CODE**：照源翻译为 GDScript，匹配现有代码风格。
5. **VERIFY**：从项目根跑 `bash tools/ci/check.sh`（三步：分层+lint → headless `--import` → GUT）。**必须 0 failing**，passing 数不得下降。先 `--import` 再跑 GUT。
6. **WRITE（知识库三步硬检查点，缺一算未完成）**：
   - ① 写 `D:\workspace\projects\CardGame2\验收记录-<主题>-<日期>.md`（位置/问题/原因/修复/验证五要素）
   - ② 更新 `D:\workspace\Obsidian\CardGameGodot2\任务看板.md` 对应项 `[ ]`→`[x]` + frontmatter 计数实测核对（grep 重算，不盲信已有计数）
   - ③ 同步 `CardGameGodot2 首页.md` 上次会话字段 + `wiki/MOC - 开发时间线.md` 顶部追加一行
7. **下一轮**，直到终止条件。

## 当前可推进项盘点（2026-07-12 实测，本轮已触终止①）
**结论：看板 todo 3 项全部不可本轮推进，英雄 hook 复刻审查 74/74 收官，可推进的复刻偏离已清零。**

下一阶段方向（需用户决策，非 agent 自主范围）：
- **方向 A — Phase5 觉醒系统激活**（解锁 SB-1/Naga + 6 英雄觉醒 hook）：`proto_awake` 桩→真实现，照源 `protoAwake` 翻译。这是当前最大功能性缺口（战斗数值平衡受影响）。
- ~~**方向 B — 特效系统完整接入**（`.abc` 解析器）~~ ✅ **已完成（2026-07-12）**：.abc 解析器 + Start→Loop 切换 + 全链路接入已实现并对照源交叉验证，仅剩实时视觉验收（headless 2D 渲染受限，非代码缺口）。
- **方向 C — Phase 8 本地化系统**：language/i18n 完全缺失，照源 `language/` 7 文件翻译。
- **方向 D — Phase 9 打包**：需先装导出模板。
- **方向 E — doing 14 项 P2 批次清理**（低优，全防御/等价，不阻塞玩法，可选）。
- **方向 F — 全新一轮复刻审查**（第 9 轮，如审查视角已枯竭则跳过；前 8 轮已 74/74）。

## 终止条件（满足任一即停并汇报）
- 连续一轮看板无可推进项（全 done 或全转 blocked）。
- 门禁出现 failing 且 3 次修复尝试未果（停下报错，不硬凑）。
- 发现本提示词与「复刻铁律」冲突（以铁律为准，停下澄清）。

## 禁止行为
- 禁范围裁剪（"先做核心再迭代"是违规信号）、禁最小可用、禁 sed 批改 GDScript（用编辑器/MCP）、禁外部脚本 patch `.tscn`。
- 禁只改代码不跑门禁 / 禁门禁 failing 就提交 / 禁看板 `[x]` 当修复证据（必须 grep 核实代码）。
- 禁跳过知识库三步就声称完成。

## 汇报格式（每轮结尾）
```
✅ 本轮推进：<项>（源 X.lua:N → 目标 Y.gd:M）
📊 门禁：1255→1258 passing / 0 failing
📚 知识库：验收记录+看板+首页+MOC 已同步
⏭️ 下一项：<项> 或 🛑 终止：<原因>
```
