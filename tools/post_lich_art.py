#!/usr/bin/env python3
"""ch203 生图资产后处理 v2（黑底去底版，2026-10-08 二轮）。

v2 修正（用户反馈：一轮为人物立绘+无透明底+风格不一致）：
  ① 节点图（node_500xx）+ 主城建筑（main_icon）→ 生成时纯黑底 → 本脚本连通域去底
     （内部全不透明防暗部渗漏 + 边缘 2px 软过渡，VisualCoding 白底合成验证放行）；
  ② 背景图（bg_*）→ 满幅底图不去底，裁 2% 边（去 Comfy 噪点框）+ 缩放；
  ③ 节点图目标比例改为地标图标比例 1.12:1（对齐 crusade_stage 系 239×213），
     贴图 512×456（÷CS 显示 400×356，适配 BOSS_POS 段内布局不出屏）。

用法：python tools/post_lich_art.py
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, ".lich_art_raw")
OUT = os.path.join(ROOT, "assets", "ui", "lich")
EDGE_TRIM = 0.02       # 背景类四边各裁 2%
BG_THRESH = 14         # 近黑判定（RGB 最大通道 ≤ 阈值 = 候选背景）
SOFT_BAND = 2          # 背景边界软过渡带宽（px）
SOFT_RANGE = 60        # 过渡像素亮度→alpha 线性映射上限

BG_TARGET = (1456, 794)     # 段背景（显示 729×397 的 2x）
ICON_TARGET = (512, 512)    # 主城入口建筑（去底后中心缩放）
NODE_TARGET = (512, 456)    # 副本节点地标图标（1.12:1，显示 400×356）
TITLE_TARGET = (796, 184)   # 标题横幅（TitleBg rect 2x，不去底）

NODE_IDS = list(range(50022, 50031))


def cutout_black_bg(img: Image.Image) -> Image.Image:
    """纯黑底连通域去底：内部全不透明（防暗部渗漏），边缘 SOFT_BAND 像素软过渡。"""
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    dist = a.max(axis=2)
    bg_mask = dist <= BG_THRESH
    labels, _ = ndimage.label(bg_mask)
    edge = np.concatenate([labels[0, :], labels[-1, :], labels[:, 0], labels[:, -1]])
    edge_ids = np.unique(edge[edge > 0])
    bg = np.isin(labels, edge_ids) if edge_ids.size else np.zeros_like(bg_mask)

    alpha = np.where(bg, 0, 255).astype(np.uint8)
    bg_d = ndimage.binary_dilation(bg, iterations=SOFT_BAND)
    soft = bg_d & (~bg)
    alpha[soft] = np.clip(dist[soft] * 255 // SOFT_RANGE, 0, 255)

    rgba = np.dstack([np.asarray(img.convert("RGB")), alpha]).astype(np.uint8)
    out = Image.fromarray(rgba, "RGBA")
    # 裁剪到内容 bbox（去底后四周黑区剪掉）
    bbox = out.getchannel("A").getbbox()
    return out.crop(bbox) if bbox else out


def fit_size(img: Image.Image, target: tuple) -> Image.Image:
    """中心裁到目标比例后 Lanczos 缩放（RGBA 保 alpha，RGB 保 RGB）。"""
    tw, th = target
    src_ratio = img.width / img.height
    dst_ratio = tw / th
    if src_ratio > dst_ratio:
        new_w = int(img.height * dst_ratio)
        x0 = (img.width - new_w) // 2
        img = img.crop((x0, 0, x0 + new_w, img.height))
    else:
        new_h = int(img.width / dst_ratio)
        y0 = (img.height - new_h) // 2
        img = img.crop((0, y0, img.width, y0 + new_h))
    return img.resize((tw, th), Image.LANCZOS)


def trim_edge(img: Image.Image) -> Image.Image:
    """背景类裁 2% 边（去 Comfy 噪点框）。"""
    w, h = img.size
    dx, dy = int(w * EDGE_TRIM), int(h * EDGE_TRIM)
    return img.crop((dx, dy, w - dx, h - dy))


def process(src_name: str, out_name: str, target: tuple, cutout: bool) -> None:
    src = os.path.join(RAW, src_name + ".png")
    if not os.path.exists(src):
        print(f"[跳过] {src_name} 未生成")
        return
    img: Image.Image = Image.open(src)
    if cutout:
        img = cutout_black_bg(img)
    else:
        img = trim_edge(img.convert("RGB"))
    img = fit_size(img, target)
    dest = os.path.join(OUT, out_name + ".png")
    img.save(dest, "PNG")
    print(f"[OK] {src_name} -> {out_name}.png ({target[0]}x{target[1]}, cutout={cutout})")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    process("main_icon", "main_icon", ICON_TARGET, cutout=True)
    for sid in NODE_IDS:
        process(f"node_{sid}", f"boss_{sid}", NODE_TARGET, cutout=True)
    process("bg_serpent", "bg_serpent", BG_TARGET, cutout=False)
    process("bg_hyjal", "bg_hyjal", BG_TARGET, cutout=False)
    process("bg_icecrown", "bg_icecrown", BG_TARGET, cutout=False)
    # 标题横幅 v2：纯黑底生成→去底（一轮版紫底不透明，2026-10-08 三轮用户反馈修正）
    process("title_banner", "title_banner", TITLE_TARGET, cutout=True)


if __name__ == "__main__":
    main()
