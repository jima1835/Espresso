#!/bin/bash
# Espresso 一键安装:编译 -> 装 app -> sudoers 免密规则 + CLI(合并为一次密码框)-> 启动
# UI(菜单栏 app)与 CLI(espresso 命令)都会安装,共用同一条免密规则。
# 幂等,重复运行安全。
set -euo pipefail
cd "$(dirname "$0")"

SUDOERS=/etc/sudoers.d/pmset-espresso
CLI_DEST=/usr/local/bin/espresso

# 1. 系统版本与编译环境
if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 15 ]; then
    echo "需要 macOS 15 (Sequoia) 及以上,当前是 $(sw_vers -productVersion)"
    exit 1
fi
if ! command -v swiftc >/dev/null; then
    echo "需要先安装 Xcode Command Line Tools,请运行: xcode-select --install"
    exit 1
fi

# 2. 编译 + 打包 + 签名 app
./build.sh

# 3. 收集需要管理员权限的动作,合并进一次系统密码框
ADMIN=()
TMP=""
if [ -f "$SUDOERS" ]; then
    echo "sudoers 免密规则已存在,跳过"
else
    TMP="$(mktemp -t pmset-espresso)"
    printf '%s ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0\n' \
        "$USER" > "$TMP"
    visudo -cf "$TMP" >/dev/null   # 语法校验不过就中止,绝不装坏 sudoers
    ADMIN+=("/usr/bin/install -o root -g wheel -m 0440 $TMP $SUDOERS")
fi
if cmp -s espresso "$CLI_DEST" 2>/dev/null; then
    echo "CLI 已是最新,跳过"
else
    # Apple Silicon 上 /usr/local/bin 可能不存在(Homebrew 在 /opt/homebrew),先建好
    ADMIN+=("/bin/mkdir -p /usr/local/bin")
    ADMIN+=("/usr/bin/install -o root -g wheel -m 0755 $PWD/espresso $CLI_DEST")
fi

if [ ${#ADMIN[@]} -gt 0 ]; then
    CMD=""
    for c in "${ADMIN[@]}"; do
        CMD="${CMD:+$CMD && }$c"
    done
    osascript -e "do shell script \"$CMD\" with prompt \"Espresso:授权一次,以后开关防休眠不再要密码\" with administrator privileges"
    [ -z "$TMP" ] || rm -f "$TMP"
fi

# 4. 启动 app
open "$HOME/Applications/Espresso.app"
echo
echo "安装完成:"
echo "  UI  - 菜单栏找咖啡杯图标,点大圆钮开关"
echo "  CLI - espresso on / off / toggle / status / for 2h"
