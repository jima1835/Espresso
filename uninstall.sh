#!/bin/bash
# NoSleep 卸载:停 app -> 删 app -> 删 sudoers 免密规则
# 注意:如果当前处于防休眠状态(SleepDisabled=1),请先恢复正常睡眠再卸载。
set -euo pipefail

SUDOERS=/etc/sudoers.d/pmset-nosleep

if pmset -g | grep -qE 'SleepDisabled\s+1'; then
    echo "警告:当前是防休眠状态,先帮你恢复正常睡眠 (sudo pmset -a disablesleep 0)"
    sudo /usr/bin/pmset -a disablesleep 0
fi

pkill -x NoSleep 2>/dev/null || true
rm -rf "$HOME/Applications/NoSleep.app"

if [ -f "$SUDOERS" ]; then
    osascript -e "do shell script \"/bin/rm $SUDOERS\" with prompt \"NoSleep 卸载:删除 sudoers 免密规则\" with administrator privileges"
    echo "已删除 $SUDOERS"
fi

echo "卸载完成。"
