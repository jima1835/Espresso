#!/bin/bash
# espresso CLI 的轻量测试:时长解析 / 格式化 / 供电解析(纯函数,不碰 pmset、sudo、launchd)
# 运行: ./tests/test_espresso.sh
set -uo pipefail
cd "$(dirname "$0")/.."

# shellcheck source=../espresso
source ./espresso
set +e

PASS=0 FAIL=0
check() {   # check <描述> <期望> <实际>
    if [ "$2" = "$3" ]; then PASS=$((PASS + 1))
    else FAIL=$((FAIL + 1)); printf 'FAIL: %s — expected [%s], got [%s]\n' "$1" "$2" "$3"; fi
}

# 合法时长 -> 分钟
for case in 1m:1 90m:90 1h:60 2h:120 8h:480 1h30m:90 08h:480 0h5m:5 168h:10080 10080m:10080; do
    check "parse ${case%%:*}" "${case##*:}" "$(parse_duration "${case%%:*}")"
done

# 非法时长 -> 返回 1 且无输出
for bad in "" 0 0m 0h 0h0m -1h -30m 90 1.5h 1d 1s h m 1hm 1m1h " 1h" "1h " 1H abc 169h 10081m 999999h; do
    out="$(parse_duration "$bad")"; rc=$?
    check "reject '$bad' (rc)" 1 "$rc"
    check "reject '$bad' (no output)" "" "$out"
done

for case in 1:1m 45:45m 60:1h 90:1h\ 30m 720:12h; do
    check "fmt ${case%%:*}" "${case#*:}" "$(fmt_minutes "${case%%:*}")"
done

check "power AC" AC "$(printf "Now drawing from 'AC Power'\n -InternalBattery-0\n" | parse_power_source)"
check "power battery" Battery "$(printf "Now drawing from 'Battery Power'\n -InternalBattery-0\n" | parse_power_source)"
check "power unknown" Unknown "$(printf "" | parse_power_source)"

# 跨天的时间带星期
check "clock today" "$(date +%H:%M)" "$(fmt_clock "$(date +%s)")"
check "clock other day" "$(date -r $(( $(date +%s) + 172800 )) '+%a %H:%M')" "$(fmt_clock $(( $(date +%s) + 172800 )))"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
