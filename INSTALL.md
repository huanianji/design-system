# AI 安装协议：华年集设计系统

本说明用于帮助具备终端／文件／网络能力的 AI 助手，将 `huanianji/design-system` 中的设计系统安装到 **Codex**。仓库地址：`https://github.com/huanianji/design-system`。

只有在用户要求安装或更新本插件时，才执行会写入插件配置的步骤；用户仅要求阅读或评估时，提供说明即可。安装范围为 Codex 插件与必要的本地来源登记，不包含业务项目改造、其他插件清理或账号配置迁移。

## 0. 读取使用许可

先读取同目录的 [LICENSE](LICENSE)。许可为 `LicenseRef-Huanianji-Restricted`：允许安装和非商业自用，转售、再分发或商用需另行书面授权，包括使用本系统开发商业产品或提供商业服务。不要将“公开仓库”“自用”或“AI 执行”自动解释为商业授权。

向用户简要说明这些限制。已有明确安装授权且用途属于许可范围时连续完成安装，无需逐步确认；已知用途超出范围时，先取得相应书面授权。用途会影响许可判断而尚不清楚时，只澄清这一点，不擅自声称获得商业授权。合法权利人对自有材料的权利，以及第三方字体各自许可，按 LICENSE 的对应条款处理。

## 1. 确认安装环境

识别当前操作系统，检查 `codex` 是否可执行，以及以下子命令是否存在：

```sh
codex plugin marketplace add --help
codex plugin add --help
```

若命令不支持插件，先报告实际版本／缺失能力，使用下方离线路径。不要把文件复制成功报告为插件已经启用，也不要擅自关闭客户端。

私有仓库需要目标电脑已有的 GitHub 访问权限。认证失败时说明失败位置，由用户在可信界面完成登录；不要索取、读取或在聊天中展示 token、cookie、密码。

## 2. 下载并安装

以下命令由 Codex 下载 Git 仓库、登记插件源并安装插件，无需手工填写路径：

```sh
codex plugin marketplace add https://github.com/huanianji/design-system.git --ref main --json
codex plugin add huanianji-design@huanianji-design --json
```

检查每一步的退出码与 JSON 结果。若插件源已经登记，先确认它指向 `huanianji/design-system`，再按更新流程刷新；不要覆盖同名但指向其他仓库的来源。

## 3. 验证结果

```sh
codex plugin marketplace list --json
codex plugin list --marketplace huanianji-design --available --json
```

从实际结果确认来源地址、插件 `huanianji-design` 的安装／启用状态和版本。仅出现在可用插件列表中，不等于已经安装；不能根据 HTTP 200、退出码或目录存在单独判断成功。

通过宿主返回的插件位置或资源清单定位这两个入口，不猜测其他电脑的缓存路径：

- `skills/huanianji-design/SKILL.md`：主设计工作流。
- `skills/huanianji-setup/SKILL.md`：当前电脑的环境准备。

主入口所在目录中运行环境探测：

```sh
python3 scripts/portable.py doctor
```

Windows 可用 `py -3 -X utf8 scripts/portable.py doctor`。脚本需要 Python 3.9+；Godot 示例另外需要目标电脑上的 Godot，引擎可通过 `--godot <实际可执行文件路径>` 指定。缺少引擎时，将 Godot 运行状态报告为待准备，不伪装成全部能力已就绪。

若当前会话没有重新加载插件，让用户打开新会话，并从插件选择器调用「华年集设计系统」。存在同名独立 Skill 时，明确使用 `huanianji-design:huanianji-design`；保留旧入口，除非用户另行要求处理。

## 4. 更新

```sh
codex plugin marketplace upgrade huanianji-design
codex plugin add huanianji-design@huanianji-design --json
```

再次核对插件状态与版本。不要覆盖项目设计档案、产品覆盖或业务代码。

## 无 CLI 时的离线路径

1. 下载仓库 ZIP：`https://github.com/huanianji/design-system/archive/refs/heads/main.zip`，或用现有 Git 工具克隆本仓库。
2. 完整解压，检查根目录 `README.md`、`install.py`、`.agents/plugins/marketplace.json` 与 `plugins/huanianji-design/plugin.json`，确认插件名一致。
3. 在解压根目录执行 `python3 install.py --dry-run`，核对目标位置；再执行 `python3 install.py`。Windows 分别使用 `py -3 -X utf8 install.py --dry-run` 和 `py -3 -X utf8 install.py`。
4. 安装器按 `package-files.json` 校验插件内容，复制实际文件并保留既有插件源备份。读取返回的 `marketplace` 与 `host_install_required`，不要固定假设个人插件源名称。
5. 没有可用 CLI 时，来源登记后仍需用户在 Codex 插件目录安装／启用并打开新会话。应明确报告“来源已登记，宿主启用待完成”。

安装器不包含内置账号或运行时引擎。不要转移旧电脑的 Codex 配置、凭据、缓存或符号链接。

## 完成报告

简短说明：仓库与来源、已安装版本、许可及用途限制、宿主实际状态、准备 Skill 是否可读、Python／Godot 条件，以及新会话调用方式。遇到失败时报告实际错误和已完成步骤，不重置用户配置、不把部分完成写成安装成功。
