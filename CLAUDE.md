# CardGame2 — 项目规范手册

Axmol/Lua 卡牌手游 `D:\workspace\projects\CardGameAxmol` 的 Godot **完全复刻**（单机版）——**源码即设计，照源翻译，不做额外设计**（详见「复刻铁律」）。旧 Godot 版 `D:\workspace\projects\CardGame`（知识库 `CardGameGodot/`）因四大病根作废，**仅作反面教材 + 复用产物（data/tables JSON、美术音频、踩坑经验）**，不复用其代码。

## 项目信息

- **引擎**：Godot 4.7（`D:\godot\Godot_v4.7-stable_win64_console.exe`）—— 由 4.6.3 升级（2026-06-24，GUT 9.6.0 兼容验证 185 单测全绿）
- **渲染器**：gl_compatibility
- **分辨率**：960×640 横屏 HVGA
- **语言**：GDScript（strict 类型）
- **测试**：GUT v9.6.0
- **Spine**：方案 C（JSON 解析器，复用旧版，无阻塞）
- **源项目基线**：`D:\workspace\projects\CardGameAxmol @ bf79ee2a1484e479a24f7014f0808a9a543d06a5`
- **施工蓝图**：`D:\workspace\Obsidian\CardGameGodot2\系统文档\施工蓝图-全局重制.md`
- **知识库**：`D:\workspace\Obsidian\CardGameGodot2\`

## 复刻铁律（最高优先级，凌驾所有流程之上）

本项目 = `D:\workspace\projects\CardGameAxmol` 的 Godot **完全复刻**（单机化）。

- **源码即设计**：原项目代码是唯一设计来源。**不做额外设计、不提 A/B/C 方案、不裁剪范围、不"优化"**——源里有什么就复刻什么，按源的结构/布局/逻辑/数值翻译为 Godot 等价代码。
- **工作模式 = 读源 → 翻译**：每个功能先读源 Lua（`CardGameAxmol\Content\src\...`）搞清实现，再翻译成 GDScript。**禁用 brainstorming / writing-plans / blueprint 等"创造性设计"流程**（那是在发明源里没有的东西）。仅当遇到源无对应的纯 Godot 引擎适配（Cocos→Godot 节点映射、Spine 方案 C、cocos Studio→.tscn）时，做最小技术适配，目标仍是"等价复刻"。
- **禁范围裁剪**：除非用户明确要分阶段，否则不搞"核心闭环 / 留迭代 / 最小可用"——源的完整表现（飘字 / 大招 / 结算 / 暂停 / HUD 全元素）都照搬。"先做核心再迭代"是违规信号。
- **遇决策回头查源**：布局坐标、数值公式、UI 结构、流程分支全部从源代码读取，不猜测、不自行拍板。
- **唯一允许的偏差 = 单机化**：去掉联机 / 服务端 / 登录依赖；玩法、表现、数值、流程全部照源。

## 四大架构原则（每个 PR 必须满足，CI 门禁强制）

### 1. 三层分离（治架构耦合）
- `scenes/<feature>/` — **View 层**：纯 UI，只显示 + 发信号，禁含业务逻辑
- `scripts/systems/` — **Logic 层**：纯业务逻辑，不依赖 Node/Control，可 headless 单测
- `scripts/data/` — **Data 层**：PlayerData / SaveManager / ConfigManager
- **铁律**：Logic 层禁止 import 任何 `scenes/` 或 `Control` 子类（AST 检查器拦截，CI fail）

### 2. 单文件 ≤ 300 行（场景脚本 ≤ 400）
- 旧版 hero_scene.gd 1764 行是反面教材。超限 CI fail。

### 3. strict 类型 + 零魔法数字
- 所有 `.gd`：`class_name` + 全参数/返回类型注解
- lint 门禁禁止 Logic 层裸数字常量（白名单 0/1/-1）；数值/公式走 `resources/data/*.json` 或 `resources/constants/*.tres`

### 4. 测试先行
- 每个 Logic 模块配 GUT 单测，不过禁合并。
- headless 跑测试：**先 `godot --headless --import` 再 `-s res://addons/gut/gut_cmdln.gd -gexit`**

## 反模式清单（全部来自旧版血泪，禁踩）

| 反模式 | 预防 |
|--------|------|
| 场景脚本塞业务逻辑 | 原则 1 三层分离 + AST 检查器 + 行数检查 |
| class_name 跨脚本交叉引用 | 跨脚本用 `preload` + 接口，不依赖 class_name 强引用 |
| 装饰节点 `mouse_filter=STOP` 吞点击 | 装饰节点强制 `mouse_filter=IGNORE` |
| 外部脚本改 `.tscn` | `.tscn` 只在编辑器/MCP 内改，禁外部 patch |
| sed 批量替换缩进代码 | GDScript 禁 sed，用 MCP `edit_script search_and_replace` |
| 拼写错误潜伏（immoblilize） | buff/技能效果全枚举单测 |
| JSON float→int | PlayerData 入口统一 int 校验 |
| 非原子存档崩溃丢档 | SaveManager 临时文件 + rename |
| 硬编码 TICK_STEP 等 | lint 禁魔法数字 |
| UID 猜测 | UID 从 `.import` 读 |
| headless class_name 不可见 | **CI 先 `--import`**（根因是没 import，非 class_name 本身） |

## Godot 引擎规范速查

- 跨脚本引用：`preload` + 鸭子类型/接口，避免 class_name 解析时序问题
- headless 测试/运行前必须 `godot --headless --import`（首次/资源变动后）
- 装饰性 Control 节点 `mouse_filter = IGNORE`（值 2）
- UID 从 `.import` 文件读，不猜
- `.tscn` 只用编辑器或 godot-mcp 改

### UI 子场景 .tscn 范式（2026-07-17 hero_detail 首立，位置/size 编辑器可视化调）

procedural UI（动态建节点 + 硬编码坐标）反复试错（坐标试 4 轮、size 试 3 轮）时，把位置/size 静态化进 `.tscn` 子场景，Godot 编辑器 2D 视图可视化调：

- **instantiate + fill**：panel `preload(.tscn).instantiate()` + `container.add_child` + `get_node("%...")` 取节点；builder `fill_*` 往节点填动态数据（texture/text/visible），**位置/size 留 .tscn 固化**（用户编辑器拖 offset 调，Ctrl+S 持久化）。
- **Scale9 按钮**：.tscn 普通 `Button`（位置可视化），builder 运行时套 `StyleBoxTexture`（`_apply_detail_style`/`set_tab_selected`）补九宫格图保视觉等价（勿建无图普通 Button 致降级）。
- **unique_name_in_owner**：被 `get_node("%Name")` 引用的节点必须开；**同名节点不能都开**（scene 内 unique name 须唯一，冲突致 engine warning → GUT 报失败）。静态背景节点（不被代码引用）不开。
- **visible 切换**（多 tab 内容）：tab view 常驻 .tscn，`_tab_views[k].visible = (k==key)` 切换，不再 free+重建；动态内容 fill 一次到各 host（`%XxxHost`），切 tab 只切 visible。
- **strict 类型**：`instantiate()`/`get_node()` 返回 Node，赋 Control/Label/Dictionary 字段必须 `as`（strict 编译报）。
- **测试扫描深度**：.tscn instantiate 多一层 content（container→content→%BaseLayer→节点），扫 base/tab 子树改递归（`_count_meta_recursive`/`_count_if_recursive`）；扫特定 view 用 `_tab_views[k]` 锚定避开其他层（如 portrait FCA 的 Sprite2D）。

## 开发协议

遵循 `D:\workspace\Obsidian\CLAUDE.md` 的 READ → CODE → WRITE 三阶段：**READ = 读源 Lua 搞清实现（不是想需求/做设计），CODE = 照源翻译为 GDScript**。本项目功能复刻**跳过 brainstorming / writing-plans / blueprint 等设计类 skill**（见「复刻铁律」）。日志写 `D:\workspace\Obsidian\CardGameGodot2\开发日志\`，任务变动同步 `CardGameGodot2/任务看板.md`。

### 本地门禁（Step 0.2 立地基，不过禁合并）

从项目根跑 `bash tools/ci/check.sh`（脚本路径 `D:\workspace\projects\CardGame2\tools\ci\check.sh`），三步串联：① 分层 + lint（Python/gdtoolkit）② headless `--import` ③ GUT 单测。任一失败非零退出。规则清单与用法见知识库 `D:\workspace\Obsidian\CardGameGodot2\wiki\工程化地基.md`。

- 测试文件必须 `test_` 前缀（GUT 默认只发现此前缀）
- 新增/改测试后 `check.sh` 会自动 import；手动单跑 gut 前必须先 `--import`

## 知识库三步硬检查点（本项目专属，防遗漏）

触发：审查报告 / 验收记录 / 架构决策 / 调试结论 等产出可执行结论的操作（全局 AGENTS.md「重要操作必须文档化 + 待办化」的本项目落地）。纯研究、闲聊、一次性问答不触发。

**完成 = 三件事全做，缺任一算未完成：**

1. **写文档**：报告落盘成项目文件（`D:\workspace\projects\CardGame2\审查报告-<主题>-<日期>.md` 或 `验收记录-`），含位置/问题/原因/修复/验证五要素
2. **更看板**：发现进 `D:\workspace\Obsidian\CardGameGodot2\任务看板.md` 对应子区（按 P0/P1/P2/P3 分级 + `- [ ]` todo），frontmatter 计数实测核对后更新（total/todo/done/blocked）
3. **同步索引**：`CardGameGodot2 首页.md` 的 `上次会话` 字段 + `wiki/MOC - 开发时间线.md` 表格顶部追加一行

**执行机制：**

- 这类任务开头建 TodoWrite 时，**最后一条 todo 固定为「知识库同步：报告+看板+首页+MOC」**，in_progress 推进到它时必须做完才能收工——不靠记忆，靠可见 todo 强制
- 完成后用「基于之前的经验：知识库三步硬检查点」echo 一句
- **写入前实测核对（强制）**：版本号读项目版本源（package.json/project.godot）、commit 数 `git rev-list --count`、defect 计数用 grep 实测，**不盲信看板已有记录**（曾发生读 06-28 旧快照当事实、未发现已滞后到 07-10 的情况）

## 规划工作流（ecc:blueprint）

> [!warning] 本项目是纯复刻，**功能开发不用 blueprint 做设计**（源即设计）。blueprint 仅用于组织大规模移植的工程路径与知识库回流，不发明源里没有的设计。

用 `ecc:blueprint` 规划任务时，**必须遵循**知识库集成规则 `D:\workspace\Obsidian\.claude\rules\blueprint-kb-integration.md`：Research 先读本项目知识库（首页/MOC 索引/差距分析/跨项目经验）并交叉验证源码 → Draft 把蓝图写入知识库 `系统文档/`（不写游离 plans/）→ Review 发现回流知识库 → Register 更新首页/任务看板/MOC 时间线。本项目知识库：`D:\workspace\Obsidian\CardGameGodot2\`。
