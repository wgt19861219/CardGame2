# CardGame2 — 项目规范手册

> **方向性内容（项目阶段 / 工作流 / 红线）以 `AGENTS.md` 为单一来源；本文件为 Claude 专用镜像，二者保持同步，改方向必须同步两处。**

原 Axmol/Lua 卡牌手游 `D:\workspace\projects\CardGameAxmol` 的 Godot 版（单机化）。**迁移阶段（读源 → 翻译为 GDScript）已基本完成，现进入 Godot 原生适配与优化阶段**（详见「项目阶段」）。旧 Godot 版 `D:\workspace\projects\CardGame`（知识库 `CardGameGodot/`）因四大病根作废，**仅作反面教材 + 复用产物（data/tables JSON、美术音频、踩坑经验）**，不复用其代码。

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

## 项目阶段（当前阶段：Godot 原生适配 / 优化）

本项目源自 `D:\workspace\projects\CardGameAxmol`（Axmol/Lua 卡牌手游）的 Godot 迁移。**迁移阶段（读源 → 翻译为 GDScript）已基本完成，现进入 Godot 原生适配与优化阶段。**

- **源代码地位 = 参考资料**：原 Axmol/Lua 源码（`CardGameAxmol\Content\src\...`）仅作行为参考与回归对照，**不再强制对齐**。允许基于 Godot 引擎特性、最佳实践、设计判断进行重构、优化、范围调整。
- **工作模式 = 设计 → 实现**：以设计者视角评估现状，提出优化方案，**解禁** brainstorming / writing-plans / blueprint 等设计类 skill。遇到不确定的设计决策，主动与用户对齐。
- **允许的改动**：架构重构、UI 重构（含 .tscn 重新设计、布局/视觉/交互优化）、性能优化、Godot 原生特性替代（如用 Theme/容器布局替代硬编码坐标）、范围裁剪与合并。
- **参考边界**：数值/玩法/表现等核心行为可参考源以保持游戏完整性，但**不作硬约束**；优化时优先服务目标体验与工程质量。
- **保留约束**：单机化（无联机/服务端/登录依赖）保持不变；三层分离、CI 门禁、测试覆盖等工程红线仍然有效（见下文各节）。
- **受控偏离 vs 偷懒漏译（关键区分）**：迁移完成后的"有意识的设计裁剪/优化"（需记录决策依据）合规；迁移阶段的"偷懒漏译"（源有对应物而本项目缺）仍是债。判断时以**源是否有对应物**为准——源本就无集中 UI 主题/间距系统（ccc3 颜色调用散落 150 文件），故引入 Theme 系统属"受控偏离"非"漏译"；但影响玩法的 View 缺口仍需照源补全以保游戏完整性。

## 四大架构原则（每个 PR 必须满足，CI 门禁强制）

### 1. 三层分离（治架构耦合）
- `scenes/<feature>/` — **View 资产层**：入口场景 tscn（3 个，绑同目录本地脚本）+ content 底板 tscn（69 个，无脚本）
- `scripts/systems/` — **Logic 层**：纯业务逻辑，不依赖 Node/Control，可 headless 单测
- `scripts/data/` — **Data 层**：PlayerData / SaveManager / ConfigManager + feature_catalog
- `scripts/ui/` — **主 View 层**：功能 panel + builder + 跨域通用展示工具
- `scripts/view/battle/` — **战斗 View 子域**：battle 场景 / actor / HUD / 战前布阵
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
| 外部脚本改 `.tscn` 结构 | `.tscn` **结构性改动**（节点/ext_resource/uid/unique_id/load_steps）只在编辑器/MCP 内改；**纯数值改动**（offset/size/color 等）允许 Edit + import/CI 兜底（2026-07-27 修订） |
| sed 批量替换缩进代码 | GDScript 禁 sed，用 MCP `edit_script search_and_replace` |
| 拼写错误潜伏（immoblilize） | buff/技能效果全枚举单测 |
| JSON float→int | PlayerData 入口统一 int 校验 |
| 非原子存档崩溃丢档 | SaveManager 临时文件 + rename |
| 硬编码 TICK_STEP 等 | lint 禁魔法数字 |
| UID 猜测 | UID 从 `.import` 读 |
| headless class_name 不可见 | **CI 先 `--import`**（根因是没 import，非 class_name 本身） |
| `ScrollContainer.gui_input` 接管滚轮 | **gui_input 信号对滚轮事件完全不触发**（ScrollContainer 内置 `_gui_input` 处理后 `accept_event`，既不 emit 信号也不冒泡）。改走 `_input`（顶层钩子，所有事件先过）+ `host.get_global_rect().has_point(mb.global_position)` 鼠标位置命中检测。详见 `验收记录-hero_detail滚动根因-2026-07-21.md` |
| 凭 commit message 假设验收通过 | d8afa50 commit message 写"用户实跑验收滚动能用了"但实际是误判（鼠标边缘偶然命中 / 测试不充分 / 把中键当滚轮）。**commit message 不是验收证据，数据才是**（实证 print + scroll_vertical 实测变化） |

## Godot 引擎规范速查

- 跨脚本引用：`preload` + 鸭子类型/接口，避免 class_name 解析时序问题
- headless 测试/运行前必须 `godot --headless --import`（首次/资源变动后）
- 装饰性 Control 节点 `mouse_filter = IGNORE`（值 2）
- UID 从 `.import` 文件读，不猜
- `.tscn` **结构性改动**（节点/ext_resource/uid/unique_id/load_steps）只用编辑器或 godot-mcp 改；**纯数值改动**（offset/size/color 等）允许 Edit 改 + import/CI 兜底（2026-07-27 修订）

### tscn↔gd 绑定规范（一轨制，2026-08-14 阶段二立）

按用途三轨、每轨唯一绑定方式（基线 76 tscn = 69 + 4 + 3）：**A** content 底板无脚本（builder instantiate + fill，主体范式）｜**B** 战斗完整场景绑远端 `scripts/view/battle/*.gd`（4 个）｜**C** 入口场景绑同目录本地脚本（3 个，固定不再增）。禁 content tscn 绑脚本；panel 脚本归位 battle 专属进 `scripts/view/battle/`、跨域通用进 `scripts/ui/`（依赖方向恒为 view/battle → ui）；`scenes/` 只放 tscn 资产与入口脚本。详见 AGENTS.md 同名节。

### UI 两件套范式 SOP（2026-08-15 试点 shop+hero_detail 定稿，取代 2026-07-17 三件套范式）

每个功能 panel = **完整静态 `*_content.tscn`（无脚本）+ `*_panel.gd`（业务+信号+fill）** 两个文件；builder 层退役（`scripts/ui/` 下 `_builder.gd` 随批次消亡，试点前 10 个→9 个）。位置/贴图/字号全进 tscn+theme，编辑器所见即所得，调布局只动 tscn 一个文件。

- **content tscn**：完整静态节点树。被引用节点开 `unique_name_in_owner`（同名节点不能都开）；静态背景节点不开；`.tscn` 禁 `#` 注释用 `;`；ext_resource 不写 uid。
- **panel.gd**：只做业务、信号 connect、fill（`get_node("%Xxx")` 取节点填动态数据）。fill 并入后逼近 View 550 行门槛时，fill 函数下沉独立 fills helper（如 `hero_detail_fills.gd`：纯数据绑定，禁建静态节点/禁样式 override）。
- **动态行**（商品格/邮件行/任务行）：行模板 `*_item.tscn`（行内静态结构模板化）+ 轻量 `*_row_builder.gd`（只定位行+填数据+徽标切换，禁建静态结构）。
- **theme 优先**：字号/颜色/描边走 `theme_type_variation`（`resources/themes/default_theme.tres`，试点后 41 个 variation）；按钮 Scale9 样式走 Button variation（normal/hover/pressed 三态入 theme），**禁**运行时 `add_theme_stylebox_override` 套样式（滚动条等 Godot 引擎缺口例外）。
- **坐标照源直译**（Cocos 800×480 左下原点 → Godot 960×640 左上）：`to_godot(x,y)=(x+80, 560-y)`；带尺寸 `CCRect(x,y,w,h)` 左下角 → `offset_top=560-(cy+h)`；**贴图显示尺寸 = 纹理÷CS(1.28125) × TextureConfig 条目 ContentScale（无条目=÷CS）**——cocos `Texture:getContentSize()` 返回点尺寸（像素÷ContentScaleFactor），createSprite 再乘条目 scale（2026-08-15 货币栏三轮实证终版）；**条目 Prescaled=false 或 ContentScale=0 时不施加条目 CS，只乘代码显式 scale 累乘**（win32 路径 resource_manager.getSpriteOriginalScale，2026-08-16 批3 Task 4 五重证据定稿；crusade/dungeon 系 9 条即此类，Prescaled=true 域如 stageselect_map_bg 维持原公式）；⚠️ `tex_display_size.gd` 现公式 `base×cs` 漏除 CS 致无条目散图偏大 1.28×，全局修复影响 73 处调用待专项决策，新代码先按本条口径手算；非正方形纹理须等比，勿强拉正方形 rect。
- **坐标系三坑（Task 5 三轮修复教训，全批次必查）**：① 源里元素坐标多为**场景空间**（含 draglist 子层），塞进面板局部空间必须减面板/裁剪层原点（shop 商品行曾整体偏移一个面板原点）；② 源 `createNode` 元素默认锚点 **(0.5,0.5)=中心**，tscn 中心定位用四锚同点+grow both（单侧锚点写法会钉死左上）；③ 可滚动列表源用 cliprect 裁剪 → Godot 用场景级裁剪层（`clip_contents=true`，rect=源 cliprect 的 to_godot 映射）。
- **迁移发明元素要甄别**：源里没有的 UI（如 shop 的常驻花费标签/面板内货币行）删（受控裁剪，记录进验收记录），别当资产保留。
- **主题链红线**：临时预览/测试场景**根节点必须 Control**——Control 主题解析沿 Control 祖先上溯，普通 Node 断链 → 回落引擎默认灰样式（曾致预览误判"按钮灰扁平"）。
- **visible 切换**（多 tab）：tab view 常驻 .tscn，`_tab_views[k].visible = (k==key)`；tab 选中态用 `theme_type_variation` 字符串切换（两 variation 方案，见 hero_detail）。
- **strict 类型**：`instantiate()`/`get_node()` 返回 Node，赋具体类型必须 `as`。
- **测试**：断言走 `%` 唯一名；tscn instantiate 多层扫描用递归；每 panel 改造配守卫测试（builder 退役 grep 断言/静态 rect 断言）。

## 开发协议

遵循 DESIGN → CODE → VERIFY 三阶段：**DESIGN = 以设计者视角评估现状，用 brainstorming / writing-plans 等设计类 skill 与用户对齐目标与方案（源仅作参考）→ CODE = 按对齐后的方案以 Godot 原生方式实现 → VERIFY = 跑 CI 门禁，必要时附截图/实测值**。日志写 `D:\workspace\Obsidian\CardGameGodot2\开发日志\`，任务变动同步 `CardGameGodot2/任务看板.md`。

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

> [!note] 大规模重构/优化任务（如全量 UI 的 .tscn 重构）可用 `ecc:blueprint` 组织工程路径与知识库回流。

用 `ecc:blueprint` 规划任务时，**必须遵循**知识库集成规则 `D:\workspace\Obsidian\.claude\rules\blueprint-kb-integration.md`：Research 先读本项目知识库（首页/MOC 索引/差距分析/跨项目经验）并交叉验证源码 → Draft 把蓝图写入知识库 `系统文档/`（不写游离 plans/）→ Review 发现回流知识库 → Register 更新首页/任务看板/MOC 时间线。本项目知识库：`D:\workspace\Obsidian\CardGameGodot2\`。
