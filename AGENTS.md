# CardGame2 AGENTS.md

> **适用范围**：本目录及子目录。
> **文件定位**：单一项目配置（Godot 卡牌游戏，原 Axmol/Lua 手游的迁移已完成，现进入 Godot 原生适配与优化阶段）。本文件自包含，不依赖 `@import`。
> **单一来源**：本文件是项目方向（阶段/工作流/红线）的**单一来源**；`CLAUDE.md` 为 Claude 专用镜像，二者必须同步，**改方向必须同步两处**。

---

## TL;DR 速查表（agent 必读）

| 维度 | 规则 |
|------|------|
| 🎯 核心模式 | **迁移已完成，进入 Godot 原生适配/优化阶段**——源仅作参考，以设计者视角重构/优化（见「项目阶段」） |
| 🌐 语言 | 简体中文回复（代码/命令/标识符除外） |
| 📁 路径 | 文件引用一律绝对路径 |
| 🛑 红线 | 见 Non-Negotiables 节 |
| ✅ 完成前 | 必须说验证方式（命令/输出/截图/实测值） |
| 🧪 提交前 | 必须跑 `bash tools/ci/check.sh` 全绿 |
| 🤔 不确定 | 跨模块改动/删非自己文件/连续失败 2 次 → 停下问 |
| 📝 commit | Conventional Commits（见 Commit 规范节） |

---

## 项目阶段（当前阶段：Godot 原生适配 / 优化）

本项目源自 `D:\workspace\projects\CardGameAxmol`（Axmol/Lua 卡牌手游）的 Godot 迁移。**迁移阶段（读源 → 翻译为 GDScript）已基本完成，现进入 Godot 原生适配与优化阶段。**

- **源代码地位 = 参考资料**：原 Axmol/Lua 源码（`CardGameAxmol\Content\src\...`）仅作行为参考与回归对照，**不再强制对齐**。允许基于 Godot 引擎特性、最佳实践、设计判断进行重构、优化、范围调整。
- **工作模式 = 设计 → 实现**：以设计者视角评估现状，提出优化方案，**解禁** brainstorming / writing-plans / blueprint 等设计类 skill（见「项目工作流」）。遇到不确定的设计决策，主动与用户对齐。
- **允许的改动**：架构重构、UI 重构（含 .tscn 重新设计、布局/视觉/交互优化）、性能优化、Godot 原生特性替代（如用 Theme/容器布局替代硬编码坐标）、范围裁剪与合并。
- **参考边界**：数值/玩法/表现等核心行为可参考源以保持游戏完整性，但**不作硬约束**；优化时优先服务目标体验与工程质量。
- **保留约束**：单机化（无联机/服务端/登录依赖）保持不变；三层分离、CI 门禁、测试覆盖等工程红线仍然有效（见下文各节）。
- **受控偏离 vs 偷懒漏译（关键区分）**：迁移完成后的"有意识的设计裁剪/优化"（需记录决策依据）合规；迁移阶段的"偷懒漏译"（源有对应物而本项目缺）仍是债。判断时以**源是否有对应物**为准——源本就无集中 UI 主题/间距系统（ccc3 颜色调用散落 150 文件），故引入 Theme 系统属"受控偏离"非"漏译"；但影响玩法的 View 缺口仍需照源补全以保游戏完整性。

旧 Godot 版 `D:\workspace\projects\CardGame`（知识库 `CardGameGodot/`）因四大病根作废，**仅作反面教材 + 复用产物（data/tables JSON、美术音频、踩坑经验）**，不复用其代码。

---

## Non-Negotiables（不可妥协红线）

**触发即停**：

### 密钥

- 禁止打印/粘贴 secret（token、API key、cookie、密码）到聊天、commit、日志。
- CI env 变量**只照搬名字不照搬真值**；缺 secret 时停下问用户，不编造占位符。
- 只认 `.env.example`，真凭证永不入库。
- **密钥不入 config**：工具配置文件里**不要 inline 写 API Key**；改用环境变量或独立 secrets 文件。

### 危险命令

执行以下命令前**必须先向用户确认**：

- `rm -rf /`、`rm -rf ~`、`rm -rf /*`、`rm -rf C:/*`（递归删根/家目录）
- `git push --force *`、`git push -f *`（强推覆盖远端）
- `mkfs*`（格式化）、`*dd*of=/dev/*`（块设备覆写）
- `chmod -R 777 /`、`chmod -R 777 /etc*`、`chmod -R 777 /usr*`（系统目录权限放开）

非上述清单的危险操作（删库、删大目录、跨盘移动）同样先确认。

### 禁止编辑的文件类别

agent 不得直接编辑（需改时改源文件并说明同步方式）：

- **生成目录**：`.godot/`（Godot 生成）、`.import/`
- **第三方代码**：`addons/` 下第三方插件源码
- **锁文件**：只让对应包管理器改
- **VCS 元数据**：`.git/`（尤其 `hooks/`、`config`）
- **带 `DO NOT EDIT` banner 的文件**（codegen / 同步产物）
- **`.tscn` 结构性改动禁外部 patch**：节点增删/重命名/parent 调整/ext_resource/uid/unique_id/load_steps 这些**结构性改动**只用编辑器或 godot-mcp（headless mcp scene 不可用时启动 editor 模式）。**纯数值改动**（offset/size/position/scale/rotation/color/modulate/visible 等）允许 Edit 工具改，但改完必须 `--import` + CI 验证兜底（2026-07-27 修订：实测 4 节点 8 行 offset 替换 + CI 1732/1732 全绿验证风险可控，旧版铁律源于 ext_resource id/uid 错乱致引用断裂的血泪，对纯数值改动过严）

### 完成前必说验证方式

声明任务"完成"前，**必须明确说出验证方式**（跑了什么命令 / 看了什么输出 / 截图编号 / `scroll_vertical` 实测值等）。只说"已完成"不说"怎么验证的"，视为未完成。

> 项目特化：commit message 不是验收证据，数据才是（实证 print + 实测变化）。曾发生 d8afa50 commit message 写"用户实跑验收滚动能用了"但实际是误判。

### 不确定就停

满足任一条件，**停下问用户**而不是继续猜：

- 改动会影响多个模块 / 多个子项目
- 要删除/覆盖非自己创建的文件
- 命令涉及网络下载 / 外部 API / 大额付费操作
- 路径不在项目工作区内
- 同一问题连续尝试 2 次失败（贴已试方法 + 报错，问用户）

---

## 语言

- **必须简体中文回复**。
- 代码、命令、标识符保持原样（英文不翻译）。
- commit message 的 type 前缀英文，subject 可中文。

---

## 行为准则（Karpathy 编程四原则 + 验证优先）

1. **先想后写** — 不确定就问，不瞎猜；发现更简单的方案主动说出来。
2. **简约至上** — 不写没被要求的功能，不为单次使用建抽象层；能 50 行解决别写 200 行。
3. **精确编辑** — 只动被要求的部分，匹配已有风格；不相关问题提一嘴别动手。
4. **目标驱动** — 给验收标准而非步骤：写测试→让它通过；复杂任务列分步计划带验证点。
5. **验证优先** — 写进文档的具体数字/commit SHA/行号，落盘前必须用代码命令（`grep`/`git show`）亲自验证；不验证就只写方法论 + 核查命令，不写具体数字。

---

## 路径规范

- **所有文档与回复中引用文件，一律使用绝对路径**（如 `D:\workspace\projects\CardGame2\scripts\foo.gd`），禁止相对路径。
- 适用范围：代码定位（`绝对路径:行号`）、日志/笔记里的文件清单、提交信息、报告。
- **例外**：代码内 `import`/`require`/资源路径（`res://`）等代码本身所需的相对路径照常使用。

---

## 错误处理 / 失败时行为

- 同一问题**连续尝试 2 次失败后停下汇报**：贴出已尝试的方法 + 报错输出，问用户而不是继续试第三种。
- 不要悄悄吞错：命令报错时把 stderr 完整贴出来，不只说"失败了"。
- 命令涉及网络下载 / 外部 API / 大额付费操作时，先确认再执行。

---

## Commit 规范

> 本项目不在 ZCode workspace `C:\Users\wgt\ZCodeProject` 内，全局 AGENTS.md 不会被加载，故本节自包含。

### 格式：Conventional Commits

```
<type>(<scope 可选>): <subject>

<body 可选>

<footer 可选>
```

### type 取值

| type | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修 bug |
| `docs` | 文档改动（AGENTS.md、README、开发日志等） |
| `refactor` | 重构（不改行为） |
| `perf` | 性能优化 |
| `test` | 加测试 / 改测试 |
| `chore` | 构建、依赖、脚本、配置（不改产品代码） |
| `style` | 格式化（不改逻辑） |
| `ci` | CI 配置 |
| `build` | 构建系统 / 依赖 |

### subject 规则

- **祈使句**：写"add X"不写"added X"，写"fix Y"不写"fixes Y"
- 不加句号结尾
- Subject 长度 ≤ 72 字符（英文）或 ≤ 40 汉字
- 中英文混合允许：type 前缀必须英文，subject 可中文

### 示例

```
feat: 新增 hero_detail 技能 tab 静态化
fix(scroll): 修复 hero_detail 详细属性 tab 滚轮失效
docs(agents): 重组 AGENTS.md 对齐模板维度
refactor(package): 用字典替代 switch-case 简化排列
chore: 升级 Godot 到 4.7
```

### 何时提交 / 何时问

- **提交前必跑 `bash tools/ci/check.sh`**，全绿才提交。
- **不替用户提交**，除非用户明确说"提交吧"。
- 默认分支（`main`）上**不开新 commit**，先开分支。
- commit message 正文用中文；type 前缀用英文（语法约定，不变）。
- PR 标题与 commit subject 同格式；描述里给出**改了什么** / **为什么** / **怎么验证**（贴命令或截图）。

### 不做这些

- 不 `--no-verify` 跳过 hook（除非用户明确要跳且知道后果）。
- 不 amend / rebase 已 push 的 commit（等于改写历史，需先确认）。
- **不 force push 到共享分支**（`main`/`develop`/`release/*`）——改写共享历史是高风险操作。
- **不在 commit 里暴露敏感信息**——token、内部 URL、客户数据绝不进 commit（就算后续删了也会留在 git 历史里）。
- **不提交大文件**——二进制资源（图片/视频/数据集）走 Git LFS 或外部存储。
- 不写"fix typo"作为唯一信息的连环小提交超 3 次——攒一个 `style:` 或 `chore:` 合并。

---

## 项目概述

- **项目类型**：游戏（原 Axmol/Lua 卡牌手游的 Godot 版，单机，迁移已完成，当前为 Godot 原生适配/优化阶段）
- **技术栈**：
  - 引擎：Godot 4.7（`D:\godot\Godot_v4.7-stable_win64_console.exe`）—— 由 4.6.3 升级（GUT 9.6.0 兼容验证，`tests/` 下 187 个 `test_*.gd` 文件；核查命令 `ls tests/test_*.gd | wc -l`）
  - 渲染器：gl_compatibility
  - 分辨率：960×640 横屏 HVGA
  - 语言：GDScript（strict 类型）
  - 测试：GUT v9.6.0
  - Spine：方案 C（JSON 解析器，复用旧版，无阻塞）
- **源项目基线**：`D:\workspace\projects\CardGameAxmol @ bf79ee2a1484e479a24f7014f0808a9a543d06a5`
- **施工蓝图**：`D:\workspace\Obsidian\CardGameGodot2\系统文档\施工蓝图-全局重制.md`
- **知识库**：`D:\workspace\Obsidian\CardGameGodot2\`
- **仓库结构**：
  - `scenes/<feature>/` — View 资产层：入口场景 tscn（3 个，绑同目录本地脚本）+ content 底板 tscn（69 个，无脚本）
  - `scripts/systems/` — Logic 层：纯业务逻辑，不依赖 Node/Control，可 headless 单测
  - `scripts/data/` — Data 层：PlayerData / SaveManager / ConfigManager + feature_catalog（源 71 handler 功能对照清单，CI catalog_check 依赖）
  - `scripts/autoload/` — 自动加载单例
  - `scripts/ui/` — 主 View 层：功能 panel + builder + 跨域通用展示工具（atlas_sprite / fca_animation / readhero_icon 等）
  - `scripts/view/battle/` — 战斗 View 子域：battle 场景 / actor / HUD / 战前布阵等 battle 专属 View
  - `tests/` — GUT 单测（`test_` 前缀）
  - `resources/` — 数据/配置（`data/*.json`、`constants/*.tres`）
  - `addons/` — 第三方插件（GUT、godot_mcp_server）
  - `tools/ci/` — 本地门禁脚本

---

## 开发命令

```bash
# 本地门禁（三步串联：分层+lint → headless import → GUT 单测），提交前必跑
bash tools/ci/check.sh

# 手动跑 GUT 单测（必须先 import）
"D:/godot/Godot_v4.7-stable_win64_console.exe" --headless --import
"D:/godot/Godot_v4.7-stable_win64_console.exe" --headless -s res://addons/gut/gut_cmdln.gd -gexit

# 启动编辑器
"D:/godot/Godot_v4.7-stable_win64_console.exe" -e
```

---

## 完成前强制检查（MANDATORY）

改动代码后，**报告完成 / 提交 / 开 PR 前**必须依次跑：

1. `bash tools/ci/check.sh` — 分层 + lint（Python/gdtoolkit）+ headless `--import` + GUT 单测三步串联

任一失败：修复后重跑，直到全绿。**不允许跳过**。

- 测试文件必须 `test_` 前缀（GUT 默认只发现此前缀）
- 新增/改测试后 `check.sh` 会自动 import；手动单跑 gut 前必须先 `--import`

---

## 代码风格

- **strict 类型**：所有 `.gd` 文件 `class_name` + 全参数/返回类型注解
- **跨脚本引用**：`preload` + 鸭子类型/接口，避免 class_name 解析时序问题（class_name 跨脚本交叉引用是反模式）
- **装饰节点**：`mouse_filter = IGNORE`（值 2），避免吞点击
- **UID**：从 `.import` 文件读，不猜
- **`.tscn`**：**结构性改动**（节点增删/重命名/parent/ext_resource/uid/unique_id/load_steps）只用编辑器或 godot-mcp，禁外部 patch；**纯数值改动**（offset/size/position/scale/color 等）允许 Edit 改但必跑 `--import`+CI 兜底；`.tscn` 禁 `#` 注释（报 Parse Error），注释用 `;`
- **零魔法数字**：lint 门禁禁止 Logic 层裸数字常量（白名单 0/1/-1）；数值/公式走 `resources/data/*.json` 或 `resources/constants/*.tres`

---

## 架构约束

### 三层分离（治架构耦合，每个 PR 必须满足，CI 门禁强制）

- `scenes/<feature>/` — **View 层**：纯 UI，只显示 + 发信号，禁含业务逻辑
- `scripts/systems/` — Logic 层：纯业务逻辑，不依赖 Node/Control，可 headless 单测
- `scripts/data/` — Data 层：PlayerData / SaveManager / ConfigManager
- **铁律**：Logic 层禁止 import 任何 `scenes/` 或 `Control` 子类（AST 检查器拦截，CI fail）

### 单文件 ≤ 300 行（场景脚本 ≤ 400）

旧版 hero_scene.gd 1764 行是反面教材。超限 CI fail。

### 反模式清单（全部来自旧版血泪，禁踩）

| 反模式 | 预防 |
|--------|------|
| 场景脚本塞业务逻辑 | 三层分离 + AST 检查器 + 行数检查 |
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
| `ScrollContainer.gui_input` 接管滚轮 | **gui_input 信号对滚轮事件完全不触发**（内置 `_gui_input` 处理后 `accept_event`，既不 emit 信号也不冒泡）。改走 `_input` + `host.get_global_rect().has_point()` 鼠标位置命中检测。详见 `验收记录-hero_detail滚动根因-2026-07-21.md` |
| 凭 commit message 假设验收通过 | commit message 不是验收证据，数据才是（实证 print + scroll_vertical 实测变化） |
| headless 截图验证坐标/布局 | **headless 模式 RendererDummy 无 GPU 渲染，`mcp__godot__screenshot capture` 截图全空白**。验证运行时坐标/布局必须用 `mcp__godot__game` bridge（game_query get_node_properties 读真实 position/size/global_position + take_screenshot 真 GPU 截图）。详见 `验收记录-英雄详情装备槽对齐源-2026-07-26.md` |
| 纸面算坐标不实测 | **Sprite2D centered=false/TextureRect position/anchor 相对父尺寸——三者坐标系不同，纸面推算易错**。装备槽 lock/角标定位反复改 4 次都不对，根因是 container size(72) vs frame texture 渲染区(94×95) 不一致 + 误判元素（把角标当 lock）。教训：定位类问题**先用 game bridge 读真实坐标再改**，不要盲改反复试 |
| 误判调试目标元素 | 装备槽"偏右上"反馈，想当然以为是 lock 占位，实测发现 6 槽全是"有配方未装"无 lock，偏的是 +号角标。教训：**先 game bridge find_nodes + get_node_properties 确认实际渲染的元素类型/坐标，再动手**，不要凭反馈关键词猜元素 |
| View 文件放错域（battle panel 进 ui/、通用工具进 view/battle） | battle 专属 View 进 `scripts/view/battle/`，跨域通用工具进 `scripts/ui/`；依赖方向恒为 view/battle → ui（见「tscn↔gd 绑定规范」节） |

### Godot 引擎规范速查

- headless 测试/运行前必须 `godot --headless --import`（首次/资源变动后）

### tscn↔gd 绑定规范（一轨制，2026-08-14 阶段二立）

按 tscn 用途分三轨，每轨固定唯一绑定方式，禁混用（基线实测 76 tscn = 69 + 4 + 3）：

| 轨 | 用途 | 绑定方式 | 实例 |
|----|------|---------|------|
| A（69 个，主体） | panel content 底板 | **无脚本**；panel/builder `preload(.tscn).instantiate()` + fill（详见下节范式） | `scenes/ui/*_content.tscn` |
| B（4 个） | 战斗完整场景 | 绑远端 `scripts/view/battle/*.gd`（root 节点 ext_resource Script） | battle_scene / battle_hud / stage_done / stage_failed |
| C（3 个） | 游戏入口场景 | 绑**同目录本地脚本** | main_scene / loading_scene / hero_scene |

- 新增 panel 默认走轨 A；新增战斗整场景走轨 B；入口场景固定三个不再增。
- **禁止**：content tscn 绑脚本（与 fill 范式双头管理）、非 root 节点绑业务脚本。
- panel 脚本归位：battle 专属进 `scripts/view/battle/`，跨域通用进 `scripts/ui/`（依赖方向恒为 view/battle → ui，禁反向）。

### UI 子场景 .tscn 范式（2026-07-17 hero_detail 首立，位置/size 编辑器可视化调）

procedural UI（动态建节点 + 硬编码坐标）反复试错时，把位置/size 静态化进 `.tscn` 子场景，Godot 编辑器 2D 视图可视化调：

- **instantiate + fill**：panel `preload(.tscn).instantiate()` + `container.add_child` + `get_node("%...")` 取节点；builder `fill_*` 往节点填动态数据，**位置/size 留 .tscn 固化**。
- **Scale9 按钮**：.tscn 普通 `Button`，builder 运行时套 `StyleBoxTexture` 补九宫格图保视觉等价。
- **unique_name_in_owner**：被 `get_node("%Name")` 引用的节点必须开；**同名节点不能都开**（冲突致 engine warning → GUT 报失败）。静态背景节点不开。
- **visible 切换**（多 tab）：tab view 常驻 .tscn，`_tab_views[k].visible = (k==key)` 切换，不再 free+重建。
- **strict 类型**：`instantiate()`/`get_node()` 返回 Node，赋 Control/Label 字段必须 `as`。
- **测试扫描深度**：.tscn instantiate 多一层 content，扫 base/tab 子树改递归；扫特定 view 用 `_tab_views[k]` 锚定。
- **.tscn 禁 `#` 注释**：用 `;`。
- **子组件保留 procedural 挂 host**：panel 层静态化进 .tscn，子组件保留 procedural 挂 `%XxxHost`（pos=0,0）。
- **带 size rect 坐标照源翻译**：Cocos `CCRect(x,y,w,h)` 的 (x,y) 是**左下角**，转 Godot（左上原点）左上角 `offset_top = 560-(cy+h)`、底边 `560-cy`，**勿把底边当 offset_top**。

---

## 测试策略

- **框架**：GUT v9.6.0
- **测试先行**：每个 Logic 模块配 GUT 单测，不过禁合并
- **测试文件**：必须 `test_` 前缀（GUT 默认只发现此前缀）
- **headless 跑测试**：先 `godot --headless --import` 再 `-s res://addons/gut/gut_cmdln.gd -gexit`
- **覆盖要求**：buff/技能效果全枚举单测（防拼写错误潜伏）

---

## 项目工作流

### 开发协议（DESIGN → CODE → VERIFY）

迁移阶段结束后，开发协议由原来的「READ 源 → 翻译」转为「**DESIGN → CODE → VERIFY**」：

1. **DESIGN**：以设计者视角评估现状，用 brainstorming / writing-plans 等设计类 skill 与用户对齐目标与方案；源仅作参考。
2. **CODE**：按对齐后的方案，以 Godot 原生方式实现（Theme、容器布局、.tscn 可视化设计等）。
3. **VERIFY**：按「完成前强制检查」跑 CI 门禁，必要时附截图/实测值。

### 知识库三步硬检查点（本项目专属，防遗漏）

触发：审查报告 / 验收记录 / 架构决策 / 调试结论 等产出可执行结论的操作。纯研究、闲聊、一次性问答不触发。

**完成 = 三件事全做，缺任一算未完成：**

1. **写文档**：报告落盘成项目文件（`D:\workspace\projects\CardGame2\审查报告-<主题>-<日期>.md` 或 `验收记录-`），含位置/问题/原因/修复/验证五要素
2. **更看板**：发现进 `D:\workspace\Obsidian\CardGameGodot2\任务看板.md` 对应子区（按 P0/P1/P2/P3 分级 + `- [ ]` todo），frontmatter 计数实测核对后更新
3. **同步索引**：`CardGameGodot2 首页.md` 的 `上次会话` 字段 + `wiki/MOC - 开发时间线.md` 表格顶部追加一行

**执行机制**：

- 这类任务开头建 TodoWrite 时，**最后一条 todo 固定为「知识库同步：报告+看板+首页+MOC」**
- **写入前实测核对（强制）**：版本号读项目版本源（package.json/project.godot）、commit 数 `git rev-list --count`、defect 计数用 grep 实测，**不盲信看板已有记录**

### 规划工作流（ecc:blueprint）

大规模重构/优化任务（如全量 UI 的 .tscn 重构）可用 `ecc:blueprint` 组织工程路径与知识库回流。

用 `ecc:blueprint` 规划任务时，**必须遵循**知识库集成规则 `D:\workspace\Obsidian\.claude\rules\blueprint-kb-integration.md`：Research 先读本项目知识库 → Draft 把蓝图写入知识库 `系统文档/` → Review 发现回流知识库 → Register 更新首页/任务看板/MOC 时间线。

---

## 变更日志

| 日期 | 变更 |
|------|------|
| 2026-07-22 | 初版，基于通用模板 `C:\Users\wgt\ZCodeProject\templates\AGENTS-template.md` 重组；断开与 CLAUDE.md 的软链，AGENTS.md 独立自包含 |
| 2026-07-24 | 迁移阶段结束，进入 Godot 原生适配/优化阶段：重写「项目阶段」（原「项目铁律」）解除源码强制对齐，解禁设计类 skill，开发协议改为 DESIGN → CODE → VERIFY；红线与工程规范保留不变 |
| 2026-07-27 | 修订 `.tscn` 红线：结构性改动（节点/ext_resource/uid/unique_id/load_steps）仍禁外部 patch，**纯数值改动**（offset/size/position/scale/color 等）放开允许 Edit 改 + import/CI 兜底。依据：战役 HUD 补全时 4 节点 8 行 offset 替换 + CI 1732/1732 全绿实证风险可控；旧版铁律源于 ext_resource id/uid 错乱致引用断裂，对纯数值改动过严 |
| 2026-08-14 | 架构重构阶段二（目录与规范统一）：View 职责重划（battle panel 归 `scripts/view/battle/` + 3 通用展示工具下沉 `scripts/ui/`，治反向依赖）；删 ModuleRegistry/InstanceModule 死骨架；feature_catalog 并入 `scripts/data/`（`scripts/server/` 目录消失，顶层 6→5）；新增「tscn↔gd 绑定规范（一轨制）」节；仓库结构描述同步实况 |
