# NoSleep

[English](#english) | [中文](#中文)

---

## 中文

macOS 菜单栏小工具:一键开关「防休眠」,**不用输密码**。

本质是 `pmset -a disablesleep 0/1` 的图形开关(等效于合盖也不睡),UI 参考 Warp (1.1.1.1):菜单栏一个咖啡杯,点开一个大圆钮,橙色发光 = 防休眠中,灰色 = 正常睡眠。

- 实心咖啡杯 / 橙色按钮:防休眠开启(`SleepDisabled = 1`,合盖也不睡)
- 空心咖啡杯 / 灰色按钮:正常睡眠模式

### 要求

- macOS 13+(Apple Silicon / Intel 均可)
- Xcode Command Line Tools(没有的话 `xcode-select --install`)

### 安装

```bash
git clone https://github.com/mrn3088/NoSleep.git
cd NoSleep
./install.sh
```

安装过程会弹一次系统密码框(唯一一次):往 `/etc/sudoers.d/pmset-nosleep` 写入一条免密规则,**只放行这两条精确命令**,其他 sudo 命令照常要密码:

```
<你的用户名> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
```

之后点菜单栏咖啡杯即可随意切换,永不输密码。终端里 `sudo pmset -a disablesleep 1` 同样免密。

### 卸载

```bash
./uninstall.sh
```

会停掉 app、删除 `~/Applications/NoSleep.app` 和 sudoers 规则;如果卸载时正处于防休眠状态,会先帮你恢复正常睡眠。

### 为什么不用 Amphetamine / caffeinate?

App Store 沙盒 app 调不了 `pmset`;`caffeinate` 类方案只防**闲置**休眠,合盖照样睡。本工具用的是系统级 `disablesleep`,合盖也不睡,代价是修改该设置必须 root —— 所以用了一条最小权限的 sudoers 免密规则解决。

### 常用命令

```bash
pmset -g | grep -i sleepdisabled   # 查看当前状态
./build.sh                          # 改完代码重新编译安装
```

### 项目结构

| 文件 | 说明 |
| --- | --- |
| `NoSleepApp.swift` | 全部 app 代码(SwiftUI `MenuBarExtra`,约 130 行) |
| `build.sh` | 编译 + 打包 + ad-hoc 签名到 `~/Applications/NoSleep.app` |
| `install.sh` / `uninstall.sh` | 一键安装 / 卸载(含 sudoers 规则) |
| `make_icon.swift` | 图标生成器,改动后重新生成 `AppIcon.icns` |
| `Info.plist` | bundle 配置(`LSUIElement`,无 Dock 图标) |

> 提醒:防休眠开启时合盖也不会睡,放包里前记得点回灰色,以免耗电发热。

---

## English

A macOS menu bar utility: toggle "no-sleep" with one click — **no password prompts**.

It is essentially a GUI switch for `pmset -a disablesleep 0/1` (the machine stays awake even with the lid closed). The UI is inspired by Warp (1.1.1.1): a coffee cup in the menu bar opens a panel with one big round button — glowing orange = no-sleep is on, gray = normal sleep.

- Solid cup / orange button: no-sleep ON (`SleepDisabled = 1`, lid-close won't sleep)
- Hollow cup / gray button: normal sleep mode

### Requirements

- macOS 13+ (Apple Silicon or Intel)
- Xcode Command Line Tools (run `xcode-select --install` if missing)

### Install

```bash
git clone https://github.com/mrn3088/NoSleep.git
cd NoSleep
./install.sh
```

During installation, a system password prompt appears **once and only once**: it writes a sudoers rule to `/etc/sudoers.d/pmset-nosleep` that **only whitelists these two exact commands** — every other `sudo` command still requires a password:

```
<your-username> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
```

After that, click the coffee cup in the menu bar to toggle at will — no password ever. `sudo pmset -a disablesleep 1` in a terminal is passwordless too.

### Uninstall

```bash
./uninstall.sh
```

Stops the app, removes `~/Applications/NoSleep.app` and the sudoers rule. If no-sleep is active at uninstall time, normal sleep is restored first.

### Why not Amphetamine / caffeinate?

Sandboxed App Store apps cannot run `pmset`, and `caffeinate`-style solutions only prevent **idle** sleep — closing the lid still sleeps. This tool uses the system-level `disablesleep` setting (lid-close included), which requires root to modify — hence the single least-privilege sudoers rule.

### Handy commands

```bash
pmset -g | grep -i sleepdisabled   # check current state
./build.sh                          # rebuild & reinstall after editing the code
```

### Project layout

| File | Purpose |
| --- | --- |
| `NoSleepApp.swift` | The entire app (SwiftUI `MenuBarExtra`, ~130 lines) |
| `build.sh` | Compile + bundle + ad-hoc sign into `~/Applications/NoSleep.app` |
| `install.sh` / `uninstall.sh` | One-step install / uninstall (including the sudoers rule) |
| `make_icon.swift` | Icon generator; rerun to regenerate `AppIcon.icns` |
| `Info.plist` | Bundle config (`LSUIElement`, no Dock icon) |

> Heads-up: with no-sleep on, the Mac stays awake even with the lid closed — switch back to gray before tossing it in a bag, or it will burn battery and heat up.
