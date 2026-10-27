# 共同设计源与 Web / Godot 消费

当前输入批（2026-10-27）：普通字段与六位验证码已提供[公共入口](components-inputs.md)，现有开播备注实际复用。输入四项新参数在同一base.json维护，构建`c4f173becaa03a6fb0f3`，本机证据与待验系统输入法见[输入批记录](packaged-status.md)。

首批实现记录（2026-10-27）：P3首批按钮、Tab与局部展开已提供[公共入口与状态约定](components-first-batch.md)，基础样张与主题片段真实复用，[实际验证](packaged-status.md)单独记录。仅抽离公共实现，P2数值与令牌构建保持；当前消费端版本须同时看源码摘要。完整六类组件仍未完成。

状态：2026-10-27 [P2 本机样本验收通过](packaged-status.md)，当前构建 `2aef65724968bcedff08`。维护者认可管理 / 创作整体调性及家族关系，并明确主题色不纳入考虑；靛蓝 / 青绿保持示例候选，产品可另选。中性浅深背景、状态语义和可读性要求不变。最新八幅同条件画面、已确认基准、剩余缺口及P3进入建议以该记录为准。规则仍以[共同规则](common/华年集共同设计规则.md)为准；完整综合主题、正式组件包、目标系统及P5新会话终验保留后续范围。

## 改在哪里

| 位置（相对 Skill 根目录） | 编辑责任 |
|---|---|
| `foundation/tokens/base.json` | 唯一共同数值源：字体角色、颜色角色、A 圆角、间距、视觉偏移、日常运动及平台换算。初始值继承已认可样本，可验证后修订 |
| `foundation/products/*.json` | 产品主题：id、名称、强调色引用/浅深色组，以及需要覆盖的字体角色数值、间距、形状、运动或视觉偏移。未知字段会报错；不能在此改共同字库路径或基础背景角色 |
| `foundation/sample/fragments.json`、`assets/demo/*.svg` | 两类片段共用的固定演示内容、分类及素材。任务状态在各窗口本地保留；不接真实主播或素材服务 |
| `foundation/components/web/`、`foundation/components/godot/` | 公共按钮 / Tab / 局部展开 / 普通输入 / 验证码；消费共同运动数据，各平台分别实现，调用方不复制第二套行为 |
| `foundation/adapters/godot/`、`foundation/web/` | 平台排布、业务与公共组件消费；专业内容 / 尚未抽离交互仍保留此处，不冒称完整公共组件 |
| `foundation/generated/manifest.json`、`generated/builds/` | 生成结果。禁止手改，修改源后重新生成；旧批次保留，运行时按 manifest 选择版本 |
| `foundation/PROJECT-DESIGN.md` | 本样张的选择、验证与边界。采用到产品时，在产品自己的设计档案记录 profile 和差异 |

`format_version: 1` 是本系统当前可运行的内部格式，不宣称兼容外部令牌标准。当前字库为资源圆体 1.910 完整 CN VF 候选，许可与来源见 `foundation/assets/fonts/`；Web 和 Godot 实际读取同一字库文件，400/600 已检查。完整字库用于本机基准，Web 分片、远端首屏与打包优化尚未验收。本机覆盖、实际回退、125% 与字体检查台入口见[字体验证](packaged-status.md)；主字库基本区有 16 字缺映射，不能宣称全覆盖。

## 共同与平台的换算

- `font.body/small/title/section` 是角色基准；各平台乘以 `platforms.<平台>.font_scale` 后取整。初始基准为 17/14/28/19，125% 是样张可用的放大选项，不是另一套可编辑字号表。
- `space` 与 `shape` 通过平台 `space_scale` 映射；圆角按左上、右上、右下、左下保存。视觉偏移允许负值，调整的是图形，不改变命中区域；`optical.bell_x` 校正铃铛，`optical.check_x` 校正勾号，两端均消费同一源。
- `light/dark` 为两套共同中性背景与状态角色；`accents` 为可引用的强调色候选。产品也可在 `accent` 中提供完整 `light/dark` 四角色组（`accent/wash/action/action_ink`），保留产品调性。
- 运动时长源使用秒，Web 动画换算毫秒，Godot Tween 使用秒；曲线、关键帧和角色数值共用，分别实现中断、焦点和减少动态。当前公共实现包含按压、Tab、输入/验证码、动态图标和收展；勾选只用于待办。实际消费者、调用入口及待验范围见资源状态与组件说明。
- Web 行高在 `platforms.web.line_height` 中调整；Godot 此版沿用原生字形行高。字体回退按平台配置，Windows/其他系统的实际支持须在目标机器验证。

当前 `baseline` 与 `jade-demo` 用于验证产品覆盖机制，不代表已经交付管理型/创作型两套完整主题。不同产品通过自己的 profile 和布局形成调性，不必复刻样张。

`management` 与 `creative` 承载本次两类片段：前者靛蓝、组间距 14，后者青绿、组间距 20；共同字族、字号、A、背景和日常回弹保持。数字是当前已检查样张的候选值，不是所有产品的固定范围。名单/树表、创作画布和连续调参按平台任务实现；具体例外见[片段记录](packaged-status.md)。

## 文字使用位置与角色

共同数值表不替代控件角色映射。当前管理 / 创作片段的姓名、时段、状态、准备数、筛选、小标题、素材名称和说明采用[明确映射](packaged-status.md)。原生 `Body / StrongBody / SmallButton / SmallTabButton` 复用既有四个字号及 400/600，没有新增另一份字号数值源。新产品先根据任务确定信息主次，再在产品档案中记录对应关系和平台例外；不能仅因 Web 元素或 Godot 控件默认不同而接受层级分叉。

## AI 更新流程

在 Skill 根目录运行：

```sh
python3 foundation/build.py build
python3 foundation/build.py check
```

`build` 在本机 PATH 或工作区工具目录寻找 Godot；目标机器不同或找不到时，按实际运行条件传入 `--godot <可执行文件路径>`。只需 Python 标准库与 Godot 原生能力，不依赖 ThemeGen 或新增前端包。

一条 build 会验证源、固定片段内容及素材路径，合并产品覆盖，生成 Web CSS/运行数据和原生主题（当前四 profile × 浅深，共八个），同时生成基础场景与片段场景，最后发布 manifest。缺失角色、错误配置或引擎失败时，保留上次成功 manifest；失败日志留在对应构建批次。`check` 还会核对源、资产和生成结果摘要，发现手改、缺失及过期版本。

样张重新打开或点击「重新读取设计」后生效。**当前是“改一处 → 生成 → 两端重新读取”，没有保存文件即热更新的后台监听。** AI 应把生成与刷新一起完成，不让维护者分别维护两份参数。

- Web：从 `foundation` 或其父目录启动仅本机静态服务，打开 `web/`；例如在 Skill 根目录运行 `python3 -m http.server 0 --bind 127.0.0.1`，打开输出端口下的 `/foundation/web/`。
- Godot：使用实际引擎运行 `--path foundation`，或在编辑器打开 `foundation/project.godot`。编辑器初始主题是生成的 `editor-theme.tres`，运行时消费 manifest 所选主题。
- 两类片段：Web 打开 `/foundation/web/fragments.html`；Godot 运行 `<Godot 可执行文件> --path foundation res://sample/fragments.tscn`。基础入口继续保留。都提供方向、浅深、字号放大、减少动态和重新读取；窗口关闭/页面刷新后演示操作重置，没有持久保存。
- 字体检查台：Web `/foundation/web/typography.html` 对应 Godot `--path foundation res://sample/typography.tscn`；读取 `sample/typography.json`，不是管理 / 创作片段。实际操作与复验流程见[字体记录](packaged-status.md)。
- 新产品：先读取产品档案与共同规则，声明 profile，再生成。已有项目尚未采用时，不直接替换原有主题/组件；实际接入和兼容性按该项目范围验证。

独立复制消费时，保留 `foundation` 的源、适配器、样张及字体许可；无需复制 `.godot` 缓存和历史 `evidence`。在新位置重新 build，重新登记目标平台的引擎路径与验证范围。这里的文件复制/参数验证不替代 P5 独立新会话终验。

实测证据、失败与验收范围见[共同基础样张记录](packaged-status.md)。

新增片段的八种呈现、交互、窄窗口及回归证据见[主题片段验证](packaged-status.md)。本机样张检查不能代替产品采用和跨会话新项目终验。
