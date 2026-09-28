# CardGame2 — Godot 卡牌手游模板

> 一个用 **Godot 4.7** 从零复刻的完整商业级卡牌手游（单机版），致敬《刀塔传奇》（现名《小冰冰传奇》）——我氪金的第一款手游。
> 如果你正想用 Godot 做一款卡牌/养成类游戏，希望它可以作为你的**工程模板**——三层架构、CI 门禁、2800+ 单元测试、完整的卡牌玩法系统，拿来即用。

## 这个项目是什么

本项目是一个非官方的个人学习项目，致敬《刀塔传奇》（Lilith 出品，后更名《小冰冰传奇》）——那款曾让我天天蹲体力、抽卡抽到上头的手游。我把它的玩法系统完整迁移到 Godot 4.7 并做了原生适配与工程化重建：数据表 64 张、71 个功能域、75 个英雄战斗 hook 脚本、800×480 横屏复古手游形态。它不是 demo，是一个**玩法闭环完整、工程实践成型**的可运行游戏，同时也是一份"Godot 怎么做中大型手游项目"的参考答案。

## 🎬 游戏演示

主城与战斗实机演示（27 秒，Godot 4.7 实录）：

![游戏演示：主城与战斗](.github/demo_gameplay.mp4)

## 作为模板，你能从中拿到什么

- **三层架构**：`scenes/`（View 纯 UI）+ `scripts/systems/`（Logic 纯业务、可 headless 单测）+ `scripts/data/`（PlayerData / SaveManager / ConfigManager），依赖方向由 CI 检查器强制
- **本地 CI 门禁**：分层检查 + lint（禁魔法数字/单文件行数上限）+ headless import + GUT 全量单测，一条命令 `bash tools/ci/check.sh`
- **2800+ 单元测试**：buff/技能效果全枚举覆盖、存档原子写 + 坏档备份回归、经济入账边界、UI 静态结构守卫
- **完整玩法系统**：回合制自动战斗（75 个英雄 hook 脚本 / buff / 投射物 / 战斗统计）、抽卡、装备合成进阶、任务成就、竞技场、远征、试炼副本、公会（入会/膜拜/公会商店）、签到、邮件、图鉴、i18n、多档位存档
- **UI 两件套范式**：静态 `*_content.tscn`（无脚本）+ `*_panel.gd`（业务/信号/fill），Theme variation 优先，所见即所得调布局
- **Spine 骨骼动画**：JSON 解析器方案 + 蒙皮网格（MeshInstance2D 顶点蒙皮）实现

## 技术栈

| 项 | 值 |
|---|---|
| 引擎 | Godot 4.7（gl_compatibility 渲染器） |
| 语言 | GDScript（strict 类型，全参数/返回值注解） |
| 分辨率 | 800×480 横屏（aspect=ignore，复刻源实机 EXACT_FIT） |
| 测试 | GUT 9.6.0（267 脚本 / 2819 用例 / 2817 通过） |
| 数据 | 105 张 JSON 配置表驱动（Unit / Skill / Buff / Equip / Shop…） |

## 仓库结构

```
scenes/        View 资产层（content 底板 / 行模板 / 战斗场景 / 入口场景）
scripts/
  systems/     Logic 层（battle 战斗域 + 经济/任务/公会/竞技场等 20+ 管理器）
  data/        Data 层（PlayerData / SaveManager / ConfigManager / feature_catalog）
  ui/          View 层（功能 panel + 跨域通用展示工具）
  view/battle/ 战斗 View 子域（场景 / actor / HUD / 战前布阵）
tests/         GUT 单元测试（test_ 前缀，2800+ 用例）
resources/     数据表 JSON / 主题 / 常量
tools/ci/      本地门禁脚本
assets/        美术 / 音频 / Spine 动画数据
```

## 快速开始

1. 安装 [Godot 4.7](https://godotengine.org/download)（标准版即可）
2. 克隆本仓库，用 Godot 编辑器打开 `project.godot`
3. 首次打开等 import 完成，按 **F5** 运行

跑测试（可选）：

```bash
godot --headless --import
godot --headless -s res://addons/gut/gut_cmdln.gd -gexit
```

跑完整门禁（分层 + lint + import + 单测）：

```bash
bash tools/ci/check.sh
```

## 说明

- 本项目为**非官方**个人学习与研究项目，与 Lilith Games / 《刀塔传奇》《小冰冰传奇》官方无关；游戏内美术/音频资产版权归原权利方所有，请勿用于商业发行
- 存档为本地多档位（原子写 + 损坏备份），无联网/账号依赖

## 🙏 赞赏支持

这个项目从一个 Axmol/Lua 商业手游逐文件迁移到 Godot 原生实现，前后经过数百轮开发/审查/实机验收迭代，也烧掉了相当可观的 AI token。如果它帮到了你，欢迎请我喝杯咖啡——你的支持是我持续维护和补充文档的动力：

| 支付宝 | 微信 |
|:---:|:---:|
| ![支付宝](.github/sponsor/alipay.jpg) | ![微信](.github/sponsor/wechat_pay.jpg) |

感谢每一位支持者！⭐ 如果这个模板对你有帮助，也欢迎给仓库点个 Star。
