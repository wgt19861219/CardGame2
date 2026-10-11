#!/usr/bin/env python3
"""ch203 换色 Boss 头像生成（2026-10-10）。

战斗 puppet（anim_frames sheet）已换色验收，但 Unit.Portrait 仍指模板原图——
UI 头像与战斗形象不一致。本工具从每对 sheet 像素学习 hue 分箱映射 LUT
（24 箱，箱间线性插值防色带），应用到模板头像 jpg，观感与战斗内一致。

为什么不用全局均匀 hue 旋转：sheet 换色是分色区的非均匀映射（如 LOA 金棕盔甲
→LichKing 冰蓝≈+160°，而蓝灰阴影区映射角不同），中位数旋转 +85° 套到金棕占比
更高的头像上会偏绿（2026-10-10 VisualCoding 样张验收实锤）；分箱 LUT 忠实复刻
各色区真实映射。

sat 全局 ×SAT_BOOST 补偿：换色平均降饱和 20-30%（VisualCoding 建议恢复量）。

离线渲染器方案（渲染 puppet 帧当头像）有裁剪错位缺陷未修——本方案直接替代关闭。

用法：python tools/recolor_lich_portraits.py
依赖：assets/anim_frames/<模板 Resource>/ 与 <Boss>/ 的 sheet.png（换色产物）；
     assets/ui/HERO/<模板 Portrait 名>.jpg（官方头像）。
输出：assets/ui/HERO/<Boss 名>.jpg（9 张，LadyVashj 除外——sheet 实测零换色，
     Portrait 保持指模板 Naga.jpg，不生成重复文件）。
"""
import colorsys
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAMES = os.path.join(ROOT, "assets", "anim_frames")
HERO_DIR = os.path.join(ROOT, "assets", "ui", "HERO")

# 与 expand_lich_data._LICH_BOSS_UNITS 同源：(tid, 模板tid, 新 Puppet 名)
_LICH_BOSS_UNITS = [
    (90001, 42, "LichKing"),
    (90002, 14, "Karathress"),
    (90003, 15, "Tidewalker"),
    (90004, 13, "LadyVashj"),
    (90005, 35, "RageWinter"),
    (90006, 6, "Anetheron"),
    (90007, 47, "Archimonde"),
    (90008, 37, "Sindragosa"),
    (90009, 7, "BloodQueen"),
]

HUE_BINS = 24            # hue 分箱数（15°/箱）
SAT_BOOST: float = 1.25  # 全局饱和补偿（换色降饱和 20-30% 的恢复量）
MIN_SAMPLE = 200         # 每箱最少样本（不足的箱就近合并到相邻有效箱）
SKIP_NOTE = "sheet 实测零换色（差<6），Portrait 保持模板值不生成"


def _load_rgb(path: str) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0


def _to_hsv(arr: np.ndarray) -> tuple:
    h = np.empty(arr.shape[:2], np.float32)
    s = np.empty(arr.shape[:2], np.float32)
    v = arr.max(axis=2)
    vmin = arr.min(axis=2)
    delta = v - vmin
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    with np.errstate(divide="ignore", invalid="ignore"):
        s = np.where(v > 0, delta / np.maximum(v, 1e-6), 0.0)
        h = np.where(delta <= 1e-6, 0.0,
                     np.where(v == r, ((g - b) / np.maximum(delta, 1e-6)) % 6.0,
                              np.where(v == g, (b - r) / np.maximum(delta, 1e-6) + 2.0,
                                       (r - g) / np.maximum(delta, 1e-6) + 4.0))) * (1.0 / 6.0)
    return h, s, v


def _from_hsv(h: np.ndarray, s: np.ndarray, v: np.ndarray) -> np.ndarray:
    i = (h * 6.0).astype(np.int32) % 6
    f = h * 6.0 - np.floor(h * 6.0)
    p = v * (1.0 - s)
    q = v * (1.0 - s * f)
    t = v * (1.0 - s * (1.0 - f))
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return np.dstack([r, g, b])


def learn_lut(tpl_rgb: np.ndarray, new_rgb: np.ndarray, alpha_mask: np.ndarray) -> dict:
    """从 sheet 像素对学 hue 分箱映射。返回 {bin: (dh_circ, sat_ratio, val_ratio)}。

    sr/vr 用箱内分布中心比（median(v1_bin)/median(v0_bin)）而非逐像素比值中位数：
    逐像素比值受亮度选择偏差污染（低亮样本被掩码排除后，亮部高光把比值中位数拉到
    ~2.0 的失真水平，2026-10-10 诊断实锤）；分布中心比抗噪且无选择偏差。vr 另加
    [0.6, 1.4] 钳制（换色不应翻倍/砍半亮度）。
    """
    h0, s0, v0 = _to_hsv(tpl_rgb)
    h1, s1, v1 = _to_hsv(new_rgb)
    sample = alpha_mask & (s0 > 0.08) & (v0 > 0.15)
    idx = (h0[sample] * HUE_BINS).astype(np.int32) % HUE_BINS
    dh = ((h1[sample] - h0[sample] + 0.5) % 1.0) - 0.5
    bins: dict = {}
    for b in range(HUE_BINS):
        m = idx == b
        if m.sum() < MIN_SAMPLE:
            continue
        # 圆周中位数：sin/cos 合成角
        ang = np.arctan2(np.median(np.sin(2 * np.pi * dh[m])), np.median(np.cos(2 * np.pi * dh[m])))
        sr = float(np.clip(np.median(s1[sample][m]) / max(np.median(s0[sample][m]), 1e-4), 0, 1.5))
        vr = float(np.clip(np.median(v1[sample][m]) / max(np.median(v0[sample][m]), 1e-4), 0.6, 1.4))
        bins[b] = (ang / (2 * np.pi), sr, vr)
    return bins


def _fill_gaps(bins: dict) -> np.ndarray:
    """稀疏箱插值补全 → 每箱 (dh, sr, vr) 数组（箱间线性插值防色带）。"""
    out = np.zeros((HUE_BINS, 3), np.float32)
    keys = sorted(bins)
    for b in range(HUE_BINS):
        if b in bins:
            out[b] = bins[b]
            continue
        prev_k = max([k for k in keys if k < b], default=keys[-1] - HUE_BINS if keys else 0)
        next_k = min([k for k in keys if k > b], default=keys[0] + HUE_BINS if keys else 0)
        pk, nk = prev_k % HUE_BINS, next_k % HUE_BINS
        span = (next_k - prev_k) % HUE_BINS or HUE_BINS
        w = ((b - prev_k) % HUE_BINS) / span
        dh = ((bins[nk][0] - bins[pk][0] + 0.5) % 1.0 - 0.5) * w + bins[pk][0]
        out[b] = (dh, bins[pk][1] + (bins[nk][1] - bins[pk][1]) * w,
                  bins[pk][2] + (bins[nk][2] - bins[pk][2]) * w)
    return out


def apply_lut_arr(img: Image.Image, lut: np.ndarray) -> Image.Image:
    arr = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0
    h, s, v = _to_hsv(arr)
    # 每像素按 hue 取箱（浮点箱号线性插值两端）
    pos = h * HUE_BINS
    b0 = np.floor(pos).astype(np.int32) % HUE_BINS
    b1 = (b0 + 1) % HUE_BINS
    w = (pos - np.floor(pos))[..., None]
    m = lut[b0] * (1 - w) + lut[b1] * w
    h2 = (h + m[..., 0]) % 1.0
    s2 = np.clip(s * m[..., 1] * SAT_BOOST, 0, 1)
    v2 = np.clip(v * m[..., 2], 0, 1)
    out = (_from_hsv(h2, s2, v2) * 255).astype(np.uint8)
    return Image.fromarray(out, "RGB")


def main() -> None:
    unit = json.load(open(os.path.join(ROOT, "resources", "data", "Unit.json"), encoding="utf-8"))
    puppet = json.load(open(os.path.join(ROOT, "resources", "data", "Puppet.json"), encoding="utf-8"))
    for tid, tpl_tid, name in _LICH_BOSS_UNITS:
        tpl_res = puppet[str(unit[str(tpl_tid)]["Puppet"])]["Resource"]
        tpl_sheet = os.path.join(FRAMES, tpl_res, "sheet.png")
        new_sheet = os.path.join(FRAMES, name, "sheet.png")
        tpl_hero = str(unit[str(tpl_tid)]["Portrait"]).split("/")[-1].replace(".jpg", "")
        src = os.path.join(HERO_DIR, tpl_hero + ".jpg")
        for p in (tpl_sheet, new_sheet, src):
            if not os.path.exists(p):
                print(f"[跳过] {name} 缺文件 {p}")
                break
        else:
            tpl_rgb = _load_rgb(tpl_sheet)
            new_rgb = _load_rgb(new_sheet)
            if tpl_rgb.shape != new_rgb.shape:
                print(f"[跳过] {name} sheet 尺寸不一致 {tpl_rgb.shape} vs {new_rgb.shape}")
                continue
            diff = float(np.abs(new_rgb - tpl_rgb).max(axis=2).mean())
            if diff < 0.02:
                print(f"[跳过] {name} <- {tpl_res}：{SKIP_NOTE}（平均差 {diff:.3f}）")
                continue
            alpha = np.asarray(Image.open(tpl_sheet).convert("RGBA"))[..., 3] > 64
            lut = _fill_gaps(learn_lut(tpl_rgb, new_rgb, alpha))
            out = apply_lut_arr(Image.open(src), lut)
            dest = os.path.join(HERO_DIR, name + ".jpg")
            out.save(dest, "JPEG", quality=92)
            print(f"[OK] {tpl_hero}.jpg -> {name}.jpg（LUT {HUE_BINS} 箱，源平均差 {diff:.3f}）")


if __name__ == "__main__":
    main()
