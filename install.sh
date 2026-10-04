#!/bin/bash
# NoSleep 一键安装:编译 -> 装到 ~/Applications -> 配置 sudoers 免密 -> 启动
# 幂等,重复运行安全。
set -euo pipefail
cd "$(dirname "$0")"

SUDOERS=/etc/sudoers.d/pmset-nosleep

# 1. 编译环境
if ! command -v swiftc >/dev/null; then
    echo "需要先安装 Xcode Command Line Tools,请运行: xcode-select --install"
    exit 1
fi

# 2. 编译 + 打包 + 签名
./build.sh

# 3. sudoers 免密规则(只放行两条 pmset 命令;仅此一步需要输一次密码)
if [ -f "$SUDOERS" ]; then
    echo "sudoers 规则已存在,跳过(如需重建请先运行 uninstall.sh)"
else
    TMP="$(mktemp -t pmset-nosleep)"
    printf '%s ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0\n' \
        "$USER" > "$TMP"
    visudo -cf "$TMP" >/dev/null   # 语法校验不过就中止,绝不装坏 sudoers
    osascript -e "do shell script \"/usr/bin/install -o root -g wheel -m 0440 $TMP $SUDOERS\" with prompt \"NoSleep:授权一次,以后开关防休眠不再要密码\" with administrator privileges"
    rm -f "$TMP"
    echo "免密规则已写入 $SUDOERS"
fi

# 4. 启动
open "$HOME/Applications/NoSleep.app"
echo
echo "安装完成:菜单栏找咖啡杯图标,点大圆钮即可开关防休眠。"
