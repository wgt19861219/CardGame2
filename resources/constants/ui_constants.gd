class_name UIConstants
extends Resource

## UI 设计系统常量（受控偏离：源无集中系统，本项目新建）。
## 间距系统：4 的倍数（4/8/16/24/32），对齐主流 8pt grid 但保留 4 细粒度。
## 配色：从现有 217 处 add_theme_*_override 归纳的常用色。

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
