#!/usr/bin/env python3
"""ch203 冰封王座美术资产生成客户端 v2（ComfyUI Qwen-Image 2.1，2026-10-08 二轮）。

一轮教训（用户反馈）：生成的是人物立绘、无透明底、风格与项目不一致——项目副本
节点图标实为"地标场景图"（crusade_stage 系：椭圆岩座+地标+怪物局部元素，45°俯视
2.5D 厚涂无描边，透明底），主城建筑为 Q 版卡通建筑（eff_UI_Main_*）。

v2 改造：
  ① 节点图（9 张）→ 冰系地标主题（VisualCoding 风格锚报告），以 crusade_stage_1
     + crusade_stage_12 为风格参考图（TextEncodeQwenImage21.images 参考通道）；
  ② main_icon → Q 版冰封尖塔建筑（对齐主城建筑语言，纯 prompt——Exercise 图集系
     Spine 拆件平铺不宜做参考）；
  ③ 背景（3 张）→ 以 crusade_detail_bg1 为风格参考重生（卡通场景底图）；
  ④ 透明底：生成后经 ComfyUI RemoveBackground（RMBG 模型）去底（工具待装模型）。

用法：
  python tools/gen_lich_art.py v2            # v2 全量
  python tools/gen_lich_art.py v2 <name>     # 单件
输出：.lich_art_raw/<name>.png
"""
import json
import sys
import time
import urllib.request
import urllib.error
import os

BASE = "http://127.0.0.1:8188"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, ".lich_art_raw")
REF_DIR = os.path.join(ROOT, "assets", "ui", "alpha", "HVGA", "crusade")

UNET = "Qwen\\qwen_image_2.1_int8_convrot.safetensors"
CLIP = "qwen3vl_8b_int8_convrot.safetensors"
VAE = "qwen_image_2.1_vae_bf16.safetensors"
STEPS = 20
CFG = 4.5

# VisualCoding 风格锚（crusade_stage 系实测归纳）
STYLE_NODE = (
    "休闲手游UI图标，欧美中世纪奇幻卡通风格，卡通Q版地标，平涂色块上色表面干净平滑，"
    "无笔触纹理少细节堆砌，无外描边，同一材质分面明暗（亮面/中间调/暗面三阶），"
    "左上方主光源，暗部压深，岩石块面化处理，斜45度俯视2.5D等距视角，"
    "椭圆岛状岩石底座收底（占画面下方四分之一），底缘深色接触阴影，"
    "主体居中占比约七成，冷灰蓝冻土岩配冰晶青蓝点缀，单一地标场景，"
    "纯黑背景，无人物无文字无笔触"
)
STYLE_BUILDING = (
    "休闲手游UI图标，欧美中世纪奇幻卡通风格，Q版卡通功能建筑，矮胖比例宽底收窄，"
    "平涂色块上色表面干净平滑无笔触，无外描边，同一材质分面明暗三阶，"
    "左上方主光源，暖灰石色系主导，小面积主题色穹顶与银白饰件点缀，发光窗，"
    "斜45度俯视2.5D等距视角，纯黑背景，无文字无笔触"
)
STYLE_BG = (
    "手游UI贴图，欧美中世纪奇幻卡通风格，卡通Q版场景厚涂软渐变，无外描边，"
    "左上方主光源，暗部压深，斜45度俯视2.5D假透视，无人物无文字，横向宽幅场景"
)
NEGATIVE = (
    "人物，立绘，角色，人形生物，外描边，轮廓线，日式二次元，厚涂笔触，"
    "写实照片，UI按钮框，边框装饰，场景背景，白色背景，灰色背景，文字，水印，低质量，变形"
)

# 参考图：上传到 Comfy 后的注册名
REF_NODE = ["ref_stage1.png", "ref_stage12.png"]
REF_BG = ["ref_detailbg1.png"]

# (name, 尺寸, 主题提示词, kind[0=节点/1=建筑/2=背景])
JOBS = [
    ("node_50022", (1008, 896),
     "深海漩涡岩窟：椭圆冻土岩台上凹下深水漩涡坑，坑中伸出鲨鱼颚巨爪（怪物局部元素），青蓝水光", 0),
    ("node_50023", (1008, 896),
     "珊瑚贝壳祭坛：椭圆珊瑚岩台上巨大的张口巨贝壳，贝缘镶金饰，四周碎浪与漂浮冰晶", 0),
    ("node_50024", (1008, 896),
     "纳迦蛇神殿拱门：椭圆岩台上盘蛇纹石柱与黄金蛇饰拱门，蛇眼宝石发青光", 0),
    ("node_50025", (1008, 896),
     "冰封符文祭坛：椭圆冻土岩台上冰晶方尖碑，碑面缠绕发光冰霜符文，地面结霜龟裂", 0),
    ("node_50026", (1008, 896),
     "噩梦魔晶簇：椭圆岩台上黑紫色水晶簇，晶体中封着恶魔犄角剪影，紫雾缭绕", 0),
    ("node_50027", (1008, 896),
     "世界之树残根拱门：巨大古树残根弯成拱门，根系缠绕椭圆岩台，绿色余烬火点与顶部圣光", 0),
    ("node_50028", (1008, 896),
     "冰龙骨翼化石：冰崖岩台上巨龙骨翼从冰层中探出（怪物局部元素），骨翼覆霜，寒气弥漫", 0),
    ("node_50029", (1008, 896),
     "猩红冰晶王座：椭圆冰台上暗红水晶王座，血色雾气缠绕座脚，冰面倒映红光", 0),
    ("node_50030", (1008, 896),
     "冰封王座：冰晶尖塔阶梯之巅的蓝冰王座，王座符文自发光，寒冰棱柱环绕，至高威压", 0),
    ("main_icon", (1008, 1008),
     "Q版冰封尖塔建筑：矮胖三层冰晶圆塔，蓝色冰穹顶与银白尖顶饰件，塔身镶嵌发光冰符文，"
     "冰晶窗透冷蓝光，底缘积雪与冰棱，冰蓝旗帜", 1),
    ("bg_serpent", (1328, 576),
     "水下神殿场景：卡通化的珊瑚石柱群与蛇形雕像，青绿海水光柱，悬浮气泡，暖色宝光点缀", 2),
    ("bg_hyjal", (1328, 576),
     "世界之树战场场景：卡通化巨大古树与根系拱门，破损战旗与武器残骸，绿色余烬与远处圣光", 2),
    ("bg_icecrown", (1328, 576),
     "冰封要塞场景：卡通化冰晶尖塔群与冰封王座高台，蓝色寒雾与极光，漂浮碎冰", 2),
    # 标题横幅 v2（2026-10-08 三轮：一轮版紫底不透明，用户实机反馈边缘不透明）：
    # 纯黑底生成→去底，中央区域留空（TitleLabel 叠字），平涂风对齐节点图
    ("title_banner", (1344, 384),
     "游戏标题横幅装饰框：冰霜金属质感的横向绶带底板，两端冰晶兽首装饰与冰棱垂饰，"
     "银白与深蓝配色，中央区域平整留空无图案，横向对称构图", 0),
]


def post_json(path: str, payload: dict) -> dict:
    req = urllib.request.Request(
        BASE + path, data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get_json(path: str) -> dict:
    with urllib.request.urlopen(BASE + path, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def upload_ref(local_path: str, remote_name: str) -> None:
    """上传风格参考图到 ComfyUI input 目录（幂等，overwrite）。"""
    boundary = "----lichref"
    with open(local_path, "rb") as f:
        payload = f.read()
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="image"; filename="{remote_name}"\r\n'
        "Content-Type: image/png\r\n\r\n"
    ).encode("utf-8") + payload + f"\r\n--{boundary}--\r\n".encode("utf-8")
    req = urllib.request.Request(
        BASE + "/upload/image?overwrite=true", data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        json.loads(resp.read().decode("utf-8"))


def build_workflow(prompt_add: str, style: str, width: int, height: int, seed: int,
                   ref_names: list) -> dict:
    full = f"{style}。{prompt_add}"
    wf = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": UNET, "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": CLIP, "type": "qwen_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "4": {"class_type": "TextEncodeQwenImage21", "inputs": {
            "clip": ["2", 0], "prompt": full, "negative_prompt": NEGATIVE,
            "resolution": 1024, "images": []}},
        "5": {"class_type": "EmptySD3LatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
        "6": {"class_type": "KSampler", "inputs": {
            "model": ["1", 0], "positive": ["4", 0], "negative": ["4", 1],
            "latent_image": ["5", 0], "seed": seed, "steps": STEPS, "cfg": CFG,
            "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "7": {"class_type": "VAEDecode", "inputs": {"samples": ["6", 0], "vae": ["3", 0]}},
        "8": {"class_type": "SaveImage", "inputs": {"images": ["7", 0], "filename_prefix": "lich"}},
    }
    # 风格参考图通道（TextEncodeQwenImage21.images，VAE latents 拼进文本编码序列）
    for i, ref in enumerate(ref_names):
        node_id = str(10 + i)
        wf[node_id] = {"class_type": "LoadImage", "inputs": {"image": ref}}
        wf["4"]["inputs"]["images"].append([node_id, 0])
    if ref_names:
        wf["4"]["inputs"]["vae"] = ["3", 0]
    return wf


def download(url_path: str, dest: str) -> None:
    with urllib.request.urlopen(BASE + url_path, timeout=120) as resp:
        with open(dest, "wb") as f:
            f.write(resp.read())


def gen_one(name: str, size: tuple, prompt_add: str, kind: int, seed: int,
            refs_by_kind: dict) -> None:
    dest = os.path.join(OUT_DIR, f"{name}.png")
    if os.path.exists(dest):
        print(f"[{name}] 已存在，跳过", flush=True)
        return
    wf = build_workflow(prompt_add, [STYLE_NODE, STYLE_BUILDING, STYLE_BG][kind],
                        size[0], size[1], seed, refs_by_kind.get(kind, []))
    result = post_json("/prompt", {"prompt": wf})
    pid = result["prompt_id"]
    print(f"[{name}] 提交 {pid} ({size[0]}x{size[1]}, refs={len(refs_by_kind.get(kind, []))})", flush=True)
    t0 = time.time()
    while True:
        time.sleep(5)
        hist = get_json(f"/history/{pid}")
        if pid not in hist:
            if time.time() - t0 > 1200:
                raise TimeoutError(f"{name} 生成超时 20min")
            continue
        status = hist[pid].get("status", {})
        if status.get("status_str") == "error":
            msgs = status.get("messages", [])
            raise RuntimeError(f"{name} 生成失败: {json.dumps(msgs, ensure_ascii=False)[:400]}")
        outputs = hist[pid].get("outputs", {})
        for node_out in outputs.values():
            for img in node_out.get("images", []):
                if img.get("type") == "output":
                    download(f"/view?filename={urllib.request.quote(img['filename'])}"
                             f"&subfolder={urllib.request.quote(img.get('subfolder', ''))}"
                             f"&type=output", dest)
                    print(f"[{name}] 完成 {time.time()-t0:.0f}s -> {dest}", flush=True)
                    return
        if status.get("completed"):
            raise RuntimeError(f"{name} 无输出图: {json.dumps(status)[:200]}")


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    upload_ref(os.path.join(REF_DIR, "stage", "crusade_stage_1.png"), REF_NODE[0])
    upload_ref(os.path.join(REF_DIR, "stage", "crusade_stage_12.png"), REF_NODE[1])
    upload_ref(os.path.join(REF_DIR, "crusade_detail_bg1.png"), REF_BG[0])
    refs_by_kind = {0: REF_NODE, 2: REF_BG}
    only = sys.argv[2] if len(sys.argv) >= 3 and sys.argv[1] == "v2" else None
    jobs = [(n, s, p, k) for (n, s, p, k) in JOBS if only is None or n == only]
    seed_base = 20261009
    for i, (name, size, prompt_add, kind) in enumerate(jobs):
        gen_one(name, size, prompt_add, kind, seed_base + i, refs_by_kind)
    print(f"全部完成：{len(jobs)} 件 -> {OUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
