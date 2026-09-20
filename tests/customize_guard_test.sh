#!/bin/bash
# customize.py가 install 액션 없이(스크립트 미설치 상태) 실행되면 config.toml을 건드리지
# 않고 거부하는지 검증한다 — 회귀 대상: 설치 전 customize 실행 시 존재하지 않는
# agent_usage.py/tab_id.py를 가리키는 config.toml이 만들어지던 버그.
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/customize.py"
fail() { echo "FAIL: $1"; exit 1; }

# 1) 완전 미설치 — agent_usage.py, tab_id.py 둘 다 없음
DIR="$(mktemp -d)"
mkdir -p "$DIR/herdr"
printf '[ui]\ntab_bar_right = []\n' > "$DIR/herdr/config.toml"

set +e
out=$(HERDR_CONFIG_DIR="$DIR/herdr" python3 "$SCRIPT" 2>&1)
code=$?
set -e

[ "$code" -ne 0 ] || fail "install 전 실행인데도 성공 종료: $out"
echo "$out" | grep -q "run the install action first" || fail "안내 메시지 없음: got '$out'"
echo "$out" | grep -q "agent_usage.py" || fail "누락 목록에 agent_usage.py 없음: got '$out'"
echo "$out" | grep -q "tab_id.py" || fail "누락 목록에 tab_id.py 없음: got '$out'"
grep -q "tab_bar_right = \[\]" "$DIR/herdr/config.toml" || fail "config.toml이 변경됨(건드리면 안 됨)"
[ ! -f "$DIR/herdr/agent-usage/layout.toml" ] || fail "layout.toml이 생성됨(건드리면 안 됨)"
rm -rf "$DIR"

# 2) 부분 설치(stale) — agent_usage.py만 있고 tab_id.py가 없음. 회귀 대상: v0.3.0 이전에
#    install한 뒤 재설치 없이 herdr-tab-id를 켜면 존재하지 않는 파일을 가리키던 버그.
DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT
mkdir -p "$DIR/herdr/agent-usage"
printf '[ui]\ntab_bar_right = []\n' > "$DIR/herdr/config.toml"
touch "$DIR/herdr/agent-usage/agent_usage.py"

set +e
out=$(HERDR_CONFIG_DIR="$DIR/herdr" python3 "$SCRIPT" 2>&1)
code=$?
set -e

[ "$code" -ne 0 ] || fail "stale 설치(tab_id.py 없음)인데도 성공 종료: $out"
echo "$out" | grep -q "run the install action first" || fail "안내 메시지 없음: got '$out'"
echo "$out" | grep -q "tab_id.py" || fail "누락 목록에 tab_id.py 없음: got '$out'"
echo "$out" | grep -q "agent_usage.py" && fail "이미 있는 agent_usage.py까지 누락으로 보고함: got '$out'"
grep -q "tab_bar_right = \[\]" "$DIR/herdr/config.toml" || fail "config.toml이 변경됨(건드리면 안 됨)"
[ ! -f "$DIR/herdr/agent-usage/layout.toml" ] || fail "layout.toml이 생성됨(건드리면 안 됨)"

echo "PASS (2/2)"
