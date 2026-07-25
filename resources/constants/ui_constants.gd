class_name UIConstants
extends Resource

## UI 设计系统常量（受控偏离：源无集中系统，本项目新建）。
## 间距系统：4 的倍数（4/8/16/24/32），对齐主流 8pt grid 但保留 4 细粒度。
## 配色与字号档位：从 642 处 add_theme_*/theme_override_* 归纳（轮 0 落地）。
## 三条主题化路径：① Theme 变体（默认）② UIConstants 受控 token（一次性色）③ 按钮工厂（cap_insets 动态）。
## 详见 设计-add_theme系统化-2026-07-25.md。

# ── 间距系统（4 的倍数）──
const SPACING_XS: int = 4
const SPACING_SM: int = 8
const SPACING_MD: int = 16
const SPACING_LG: int = 24
const SPACING_XL: int = 32

# ── 网格间距（替代 add_theme_constant_override h/v_separation 散落值）──
const GRID_H_SEP: int = 8
const GRID_V_SEP: int = 8

# ── 配色（从 override 归纳，RGB 0-1 归一化）──
const COLOR_TITLE_GOLD: Color = Color(0.906, 0.808, 0.075)   # 源 ccc3(231,206,19) 标题金
const COLOR_TEXT_DEFAULT: Color = Color(1.0, 1.0, 1.0)        # 白
const COLOR_TEXT_SHADOW: Color = Color(0.0, 0.0, 0.0)         # 描边黑
const OUTLINE_SIZE_DEFAULT: int = 3                            # 描边粗细

# ── add_theme 系统化 token（轮 0 落地，源值见 设计-add_theme系统化-2026-07-25.md）──
# Rank 7 档（源 scripts/systems/readhero_handbook.gd:23-29）
const COLOR_RANK_WHITE: Color = Color(254.0 / 255.0, 251.0 / 255.0, 241.0 / 255.0)
const COLOR_RANK_YELLOW: Color = Color(248.0 / 255.0, 255.0 / 255.0, 62.0 / 255.0)
const COLOR_RANK_BLUE: Color = Color(96.0 / 255.0, 172.0 / 255.0, 243.0 / 255.0)
const COLOR_RANK_PURPLE: Color = Color(1.0, 128.0 / 255.0, 1.0)
const COLOR_RANK_ORANGE: Color = Color(1.0, 152.0 / 255.0, 72.0 / 255.0)
const COLOR_RANK_RED: Color = Color(1.0, 60.0 / 255.0, 60.0 / 255.0)
const COLOR_RANK_DEFAULT: Color = Color(1.0, 1.0, 1.0)  # 未匹配稀有度兜底色（rank < 1）

# Tab 3 档（源 scripts/ui/battle_prepare_panel.gd:32-34）
const COLOR_TAB_SELECTED: Color = Color(230.0 / 255.0, 190.0 / 255.0, 76.0 / 255.0)
const COLOR_TAB_UNSELECTED: Color = Color(196.0 / 255.0, 187.0 / 255.0, 170.0 / 255.0)
const COLOR_TAB_SHADOW: Color = Color(42.0 / 255.0, 31.0 / 255.0, 22.0 / 255.0)

# 按钮标签 + 数量（BTN_LABEL 散落 10 文件如 equipboard_ofbuy_panel.gd:42 + midas_panel.gd:25；AMOUNT 源 equipboard_ofbuy_panel.gd:46）
const COLOR_BTN_LABEL: Color = Color(234.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)
const COLOR_AMOUNT: Color = Color(155.0 / 255.0, 41.0 / 255.0, 14.0 / 255.0)  # 数量数值文字色（深褐红）

# 字号 / 描边 / 阴影档位（摸底众数：.gd add_theme_font_size 50 处 + .tscn theme_override_font_sizes 177 处归纳）
const FONT_SIZE_SMALL: int = 14
const FONT_SIZE_TITLE: int = 20
const FONT_SIZE_AMOUNT: int = 18
const OUTLINE_SIZE_THIN: int = 1
const OUTLINE_SIZE_BTN: int = 2
const SHADOW_OFFSET_X: int = 0
const SHADOW_OFFSET_Y: int = 2
