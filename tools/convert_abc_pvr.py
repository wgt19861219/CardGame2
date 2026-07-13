#!/usr/bin/env python3
"""批量转换 .abc zip 内的 sheet.pvr → sheet.png（RGBA4444 解码）。

.abc 是 cocos2d CCAnimation zip，内含 cha(关键帧)+plist(图集)+sheet.pvr(纹理)。
PVR 格式是 cocos2d PVR v2（headerLength=52, flags 低字节=format code），
实际数据是 RGBA4444（16bpp uncompressed，非 PVRTC 压缩）。

本脚本：
1. 遍历 assets/anim_frames/**/*.abc
2. 读 zip 内 sheet.pvr，解析 header 得 width/height
3. 用 Pillow frombytes RGBA;4B 解码为 PNG
4. 重新打包 .abc：cha + plist + sheet.png（替换 sheet.pvr）

用法：python tools/convert_abc_pvr.py [--check]（--check 只报告不写）
"""
from __future__ import annotations

import os
import struct
import sys
import zipfile
import io
from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM_DIR = os.path.join(PROJECT_ROOT, "assets", "anim_frames")


def parse_pvr_header(data: bytes) -> tuple[int, int, str] | None:
	"""解析 PVR v2 header，返 (width, height, format_name) 或 None。"""
	if len(data) < 52:
		return None
	header_len = struct.unpack('<I', data[0:4])[0]
	if header_len != 52:
		return None
	height = struct.unpack('<I', data[4:8])[0]
	width = struct.unpack('<I', data[8:12])[0]
	flags = struct.unpack('<I', data[16:20])[0]
	bpp = struct.unpack('<I', data[24:28])[0]
	magic = data[44:48]
	if magic != b'PVR!':
		return None
	fmt_code = flags & 0xFF
	# 实测 flags=0x8010 → fmt_code=0x10 标为 PVRTC2，但 bpp=16 + 数据量=width*height*2
	# 实际是 RGBA4444 uncompressed（cocos2d PVR v2 的 format code 不可靠，按 bpp 判）
	if bpp == 16:
		return (width, height, "RGBA4444")
	elif bpp == 32:
		return (width, height, "RGBA8888")
	elif bpp == 8:
		return (width, height, "A8")
	return (width, height, f"unknown_bpp{bpp}")


def decode_pvr_to_png(pvr_data: bytes) -> bytes | None:
	"""PVR v2 数据解码为 PNG bytes。"""
	parsed = parse_pvr_header(pvr_data)
	if parsed is None:
		return None
	width, height, fmt = parsed
	raw = pvr_data[52:]
	expected = width * height * (4 if "8888" in fmt else 2 if "4444" in fmt else 1)
	if len(raw) < expected:
		print(f"  ❌ 数据不足: {len(raw)} < {expected} ({fmt})")
		return None
	try:
		if fmt == "RGBA4444":
			img = Image.frombytes('RGBA', (width, height), raw, 'raw', 'RGBA;4B')
		elif fmt == "RGBA8888":
			img = Image.frombytes('RGBA', (width, height), raw)
		elif fmt == "A8":
			img = Image.frombytes('L', (width, height), raw)
		else:
			return None
		buf = io.BytesIO()
		img.save(buf, format='PNG')
		return buf.getvalue()
	except Exception as e:
		print(f"  ❌ 解码失败: {e}")
		return None


def convert_abc(abc_path: str, check_only: bool = False) -> bool:
	"""转换单个 .abc：sheet.pvr → sheet.png 重新打包。"""
	try:
		z = zipfile.ZipFile(abc_path, 'r')
		names = z.namelist()
		if 'sheet.pvr' not in names:
			return False   # 无 pvr，可能已转换或无纹理
		if 'sheet.png' in names:
			return False   # 已有 png，跳过
		pvr_data = z.read('sheet.pvr')
		png_data = decode_pvr_to_png(pvr_data)
		if png_data is None:
			return False
		if check_only:
			parsed = parse_pvr_header(pvr_data)
			print(f"  {os.path.basename(abc_path)}: {parsed[0]}x{parsed[1]} {parsed[2]} → PNG {len(png_data)} bytes")
			return True
		# 重新打包：保留 cha + plist，替换 sheet.pvr → sheet.png
		new_entries = []
		for name in names:
			if name == 'sheet.pvr':
				new_entries.append(('sheet.png', png_data))
			else:
				new_entries.append((name, z.read(name)))
		z.close()
		# 写临时文件再替换（原子写）
		tmp_path = abc_path + '.tmp'
		with zipfile.ZipFile(tmp_path, 'w', zipfile.ZIP_DEFLATED) as znew:
			for name, data in new_entries:
				znew.writestr(name, data)
		os.replace(tmp_path, abc_path)
		return True
	except Exception as e:
		print(f"  ❌ {abc_path}: {e}")
		return False


def main() -> int:
	check_only = '--check' in sys.argv
	abc_files = []
	for root, _dirs, files in os.walk(ANIM_DIR):
		for f in files:
			if f.endswith('.abc'):
				abc_files.append(os.path.join(root, f))
	print(f"找到 {len(abc_files)} 个 .abc 文件")
	converted = 0
	skipped = 0
	for abc in abc_files:
		result = convert_abc(abc, check_only)
		if result:
			converted += 1
		else:
			skipped += 1
	mode = "检查" if check_only else "转换"
	print(f"\n{mode}完成: {converted} 转换, {skipped} 跳过（已转换或无 pvr）")
	return 0


if __name__ == "__main__":
	sys.exit(main())
