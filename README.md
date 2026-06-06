# MagiskModuleFactory
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

一键生成 Magisk 模块的 Shell 脚本
**许可证**: GNU General Public License v3.0

---

## 功能列表

| 序号 | 功能 | 说明 |
|:----:|------|------|
| 1 | 普通应用转系统应用模块 | 将第三方应用固化到 `/system/app` |
| 2 | 生成修改 `/system` 模块 | 替换 `/system` 分区下的任意文件 |
| 3 | 生成修改 `/vendor` 模块 | 替换 `/vendor` 分区下的任意文件 |
| 4 | 生成修改系统属性模块 | 支持多行输入，批量修改系统属性 |
| 5 | 开机动画模块 | 支持 MP4 转动画 / 直接使用 bootanimation.zip |
| 6 | 生成修改机型模块 | 修改品牌、制造商、型号 |
| 7 | 自定义 hosts 文件模块 | 支持本地文件/网络下载/手动输入 |
| 8 | 开机自启脚本模块 | 生成 `post-fs-data.sh` 或 `service.sh` |
| 9 | 隐藏 Magisk 模块 | 删除目标模块的 `module.prop` 实现隐藏 |

---

## 快速开始

### 方法一：一键安装运行（推荐）

```bash
curl -sS https://raw.githubusercontent.com/zlkypx/MagiskModuleFactory/main/setup.sh | bash
```

---

依赖说明
必要 pm, zip, unzip 
MP4转开机动画 ffmpeg, ffprobe 
网络下载 curl
克隆仓库 git

---

使用示例

功能4：修改系统属性

```
请输入要修改的系统属性，格式：属性名=数值
每行一个属性，输入空行结束
示例:
  ro.debuggable=1
  persist.sys.usb.config=mtp,adb
开始输入:
ro.debuggable=1
persist.sys.usb.config=mtp,adb
ro.screen.low_brightness=1

已创建 system.prop 文件，包含以下属性:
----------------------------------------
ro.debuggable=1
persist.sys.usb.config=mtp,adb
ro.screen.low_brightness=1
----------------------------------------
```

功能5：开机动画

· 选项1：输入 MP4 文件路径，自动提取帧生成动画包
· 选项2：直接使用现成的 bootanimation.zip

---

输出文件

所有生成的模块保存在当前目录，命名格式：MagiskModuleFactory_功能名_时间戳.zip

功能 输出文件名示例
应用转系统 MagiskModuleFactory_app2system_20260607_143052.zip
修改属性 MagiskModuleFactory_prop_20260607_143052.zip
开机动画 MagiskModuleFactory_bootanimation_20260607_143052.zip
隐藏模块 MagiskModuleFactory_hidehelper_20260607_143052.zip

---

支持的环境

· Magisk及其分支
· KernelSU及其分支
· APatch及其分支

脚本会自动检测并使用对应的安装命令。

---

注意事项

1. 需要 root 权限：大多数功能需要 root 才能正常工作
2. 部分功能需要额外依赖：如 ffmpeg、curl/wget
3. 模块刷入后可能需要重启：部分修改需要重启才能生效
4. 建议备份：修改系统文件前建议做好备份

---

常见问题

Q: 脚本运行提示 "未找到可用的模块安装方法"

A: 请确保已安装 Magisk / KernelSU / APatch 之一，并且已正确 root。

Q: MP4 转动画失败

A: 请检查是否已安装 ffmpeg，以及 MP4 文件是否损坏。

Q: 模块刷入后没有效果

A: 尝试重启设备。部分修改（如系统属性）需要重启才能生效。

---

许可证

GNU General Public License v3.0

Copyright © 2026 github.com/zlkypx

本程序为自由软件，您可以遵照 GPL-3.0 许可证的条款重新分发和修改它。
该程序在希望它有用的情况下分发，但没有任何担保，甚至没有适销性或特定用途适用性的暗示担保。

---

更新日志

版本 日期 更新内容
1.0 2026-06-07 初始发布，包含9项功能
