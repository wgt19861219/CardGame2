#!/usr/bin/env bash
# 本地 CI 门禁：① Python 门禁（分层 + lint）② Godot headless 导入 ③ GUT 单测
# 用法：bash tools/ci/check.sh   任一步失败即非零退出
# 环境变量可覆盖：PYTHON=  GODOT=
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PYTHON="${PYTHON:-python}"
GODOT="${GODOT:-D:/godot/Godot_v4.7-stable_win64_console.exe}"
export PYTHONUTF8=1  # 让 Python 门禁的中文输出在 Windows 终端正常显示

echo "=== 1/3 分层 + Lint 门禁（Python）==="
"$PYTHON" "$ROOT/tools/ci/check_all.py" "$ROOT"

echo "=== 2/3 Headless 导入（class_name 注册前提，首次/资源变动后必需）==="
"$GODOT" --headless --import --path "$ROOT"

echo "=== 3/3 GUT 单测（headless）==="
GUT_OUTPUT="$("$GODOT" --headless --path "$ROOT" -s res://addons/gut/gut_cmdln.gd -gexit 2>&1)" || {
	echo "$GUT_OUTPUT"
	echo "❌ GUT 单测失败（非零退出）"
	exit 1
}
echo "$GUT_OUTPUT"

# ⚠️ 血泪守护，不可删（P0×2，GUT 测试审查 2026-07-08 确认当前 1048 合规全靠这两条守住）。
# 删掉 = 测试脚本解析失败被静默跳过 / failing 测试被漏报，CI 假绿。
# 堵静默跳过口子：tests/ 下若有脚本解析失败或被 GUT 忽略，门禁必须失败。
# 否则协程缺 await 等解析错误会让测试文件被静默丢弃，CI 仍报绿。
if printf '%s' "$GUT_OUTPUT" | grep -E 'Failed to load script "res://tests/|Ignoring script res://tests/' >/dev/null; then
	echo "❌ 检测到 tests/ 下测试脚本被静默跳过（解析失败或未继承 GutTest），门禁失败"
	exit 1
fi

# ⚠️ 血泪守护，不可删（GUT -gexit 对 failing 退出码不可靠，曾 1 failing 但门禁绿）。
# failing 检测：GUT -gexit 对 failing 退出码不可靠（可能 0），靠 grep 兜底。
if printf '%s' "$GUT_OUTPUT" | grep -E 'Failing Tests[[:space:]]+[1-9]' >/dev/null; then
	echo "❌ GUT 有 failing 测试，门禁失败"
	exit 1
fi

# P1-2（GUT 审查 2026-07-10）：passing-count 下限，防 test_ 改名等方法被 GUT 静默丢失
# （extends GutTest 但 0 个 test_ 方法 GUT 不告警；上面 grep 防 load 失败，此条防
# "load 成功但方法没被收集"致测试数下降）。加测试后调高 GUT_MIN_TESTS（当前基线 1161）。
# env 覆盖便于验证断言生效：GUT_MIN_TESTS=2000 bash check.sh 应 fail。
GUT_MIN_TESTS=${GUT_MIN_TESTS:-1161}
gut_tests=$(awk '/^Tests[[:space:]]+/{print $2; exit}' <<<"$GUT_OUTPUT")   # here-string：避 printf|awk 管道 SIGPIPE（awk exit 致 printf broken pipe，pipefail 放大为 141）
if [ -z "$gut_tests" ]; then
	echo "❌ 无法从 GUT 输出解析 Tests 计数（输出格式变？），门禁失败"
	exit 1
fi
if [ "$gut_tests" -lt "$GUT_MIN_TESTS" ]; then
	echo "❌ GUT 测试数 $gut_tests < 下限 $GUT_MIN_TESTS（疑似测试静默丢失，如 test_ 改名），门禁失败"
	exit 1
fi

echo "✅ 全部门禁通过"
