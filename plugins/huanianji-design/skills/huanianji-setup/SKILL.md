---
name: huanianji-setup
description: 在新电脑安装华年集设计插件后，定位完整资源、检查 Python / Godot 条件并引导开始项目设计。
---

# 华年集插件准备

先读取 [使用许可](../../LICENSE)。允许安装与非商业自用；转售、再分发或商用需另行书面授权。AI 不能替用户扩大授权；合法权利人对自有材料的权利及第三方许可按全文处理。

以本文件所在目录为基准，主入口在 `../huanianji-design/SKILL.md`。先执行 `python ../huanianji-design/scripts/portable.py doctor`；Windows 可用 `py -3`，macOS / Linux 可用 `python3`。有明确 Godot 路径时传 `--godot`，不填源机器路径。

报告规则／Web 和 Godot 各自是否就绪，缺失环境保持待准备。用户已有目标项目时按主 Skill 的 context 命令定位档案；尚无目标时介绍“说需求 → 选择产品方向 → 原生实现 → 实际检查 → 写回档案”的用法。只有用户要求预览才通过 prepare 在新目录组装样例，不改现有产品。

如果有同名个人 Skill，说明需要在插件选择器明确使用本插件；保留原文件，不擅自删掉旧入口或改用户其他插件。
