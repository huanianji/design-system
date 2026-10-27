# 当前电脑的运行条件

先执行 `python scripts/portable.py doctor`。需要实际 Godot 验证时加 `--require-godot --godot <目标电脑引擎路径>`。不要读取源机器固定路径或把旧验收视为当前电脑通过。

规则与档案工具需要 Python 3.9+。Web 示例使用本机静态 HTTP 服务。Godot 基线使用 4.7.2；其他版本先核对 API 与真实输入再采用。引擎、浏览器、Codex 由目标电脑提供，插件不携带账户、API Key、系统安装包或缓存。
