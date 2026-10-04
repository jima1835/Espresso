#!/bin/bash
# Espresso 卸载:停 app -> 删 app -> 删 CLI 和 sudoers 免密规则
# 注意:如果当前处于防休眠状态(SleepDisabled=1),会先帮你恢复正常睡眠。
set -euo pipefail

SUDOERS=/etc/sudoers.d/pmset-espresso
CLI_DEST=/usr/local/bin/espresso
TIMER_LABEL=com.mrn3088.espresso.timer

# 取消定时会话:卸载并删除自动关闭的 LaunchAgent 和状态目录
launchctl bootout "gui/$(id -u)/$TIMER_LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$TIMER_LABEL.plist"
rm -rf "$HOME/Library/Application Support/Espresso"

if /usr/bin/pmset -g | grep -qE 'SleepDisabled[[:space:]]+1'; then
    echo "当前处于防休眠状态,先恢复正常睡眠 (sudo pmset -a disablesleep 0)"
    sudo /usr/bin/pmset -a disablesleep 0
fi

pkill -x Espresso 2>/dev/null || true
rm -rf "$HOME/Applications/Espresso.app"

ADMIN=""
[ ! -f "$CLI_DEST" ] || ADMIN="/bin/rm $CLI_DEST"
[ ! -f "$SUDOERS" ] || ADMIN="${ADMIN:+$ADMIN && }/bin/rm $SUDOERS"
if [ -n "$ADMIN" ]; then
    osascript -e "do shell script \"$ADMIN\" with prompt \"Espresso 卸载:删除 CLI 与 sudoers 免密规则\" with administrator privileges"
fi

echo "卸载完成。"
