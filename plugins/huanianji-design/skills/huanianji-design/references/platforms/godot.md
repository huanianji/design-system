# Godot：运行条件、原生基础与选型参考

当前合批公共图标与管理/创作任务见[组合使用](../combined-workflows.md)及[动态图标调用](../components-dynamic-icons.md)，实际本机结果与待验范围只维护在[合批记录](../packaged-status.md)。本页后续历史初查不覆盖当前资源状态。

当前输入批已提供[普通字段与六位验证码公共入口](../components-inputs.md)，现有备注实际消费；本机操作、候选窗待验与完整平台边界见[输入批记录](../packaged-status.md)。

先读 `runtime-status.md` 的实际引擎路径、版本及验证结果。目标项目已有引擎或技术约定时沿用，不根据文档标题推断环境已准备完成。

已提供[共同设计源与原生主题生成](../shared-foundation.md)、[公共按钮／Tab／展开](../components-first-batch.md)、输入／验证码和动态图标，可按调用说明复用。缺少的产品控件按共同意图补充；本系统没有覆盖全部原生控件。环境探针只证明所记录工程可运行，目标项目需验证自己的实际消费与画面。

后续按共同交互意图设计节点、主题和输入。核对键盘/手柄焦点、鼠标/触控的适用范围、窗口与文字缩放、动态中断和场景退出。输入法、读屏和实际硬件支持应按引擎版本与系统取得证据。

细节分叉按[交互差异排查](../interaction-review.md)追到具体 Control、实际获焦对象、Theme variation / 基类及输入路径；直接调用选中函数的逻辑检查不覆盖用户点击后继承出来的焦点外观。

若控件形态不适合某场景，可采用同等意图的原生表达，并记录差异；不能仅复制 Web 动效参数就声称完成适配。

完整的[能力对照与方案](../packaged-status.md)随后已按授权实施：[本机独立验证记录](../packaged-status.md)。同一场景/样本的 N 原生与 T ThemeGen 路径完成本机最小验证；2026-10-26 维护者已确认后续以原生为基础，ThemeGen 1.4.0 保留实验对照。当前小号字号和动态获认可，具体样本及新增收展回弹在实验档案维护，不自动冻结为全产品数值。当前共同源和公共交互的覆盖以资源表为准，未覆盖部分不视为已实现。讨论首次接入或取舍时按需读报告；下文为此前初查历史，不能覆盖后续实际记录。

## 本机实验可复用的经验

- 字体先核对主字库、回退和实际 OpenType 坐标；本机候选通过数值标签得到 400/600。不能只看配置文本；系统回退明确限定平台。
- 容器管理排布，内部视觉层负责按压、勾选和图标，命中/焦点区保持稳定；颜色更新不重置进行中的运动，几何变化单独处理。减少动态切到真实静态状态，不制造空 Tween。
- 本机 4.7.2 可直接用 `offset_transform_enabled`、`offset_transform_visual_only` 与 `offset_transform_scale` 做按钮的视觉按压，保持原生输入位置与布局；无需复制按钮或重画文字。参考 [Control 官方说明](https://docs.godotengine.org/en/4.7/classes/class_control.html#class-control-property-offset-transform-visual-only)，使用其他版本先核对 API。
- 主题必须核对正常、悬停、按下、选中后悬停、禁用及焦点叠加；`hover_pressed` 与 `font_hover_pressed_color` 需明确映射。同角色各状态的内容边距保持一致，按需用 `align_to_largest_stylebox`，同时检查展开引起的滚动条宽度变化。不能只检查未悬停截图。
- 与 Web 对照动效时同时核对触发、全局缓动、关键帧与幅度；只选一个同名 Tween 曲线不能代表同样手感。动态图标须实际验证悬停、焦点/点击、中断与减少动态，静态截图不足以证明运动成立。相关反馈修复及实测见[实验记录 §7](../packaged-status.md)。
- 交互边界与装饰边界可以采用不同角色；实际字体、字号、灰阶与形状值仍是候选。
- 生成结果要能对应输入并独立消费；错误和过期输出可观察。ThemeGen 不接管业务状态或动画，也不成为运行时前置依赖。

上述为本机实测经验，不是完整平台适配或全部共同参数定稿；Windows/导出、触控/手柄、完整读屏和两类正式主题仍需对应证据。

## 字体补验（2026-10-27）

本机同内容 [Web / 原生字体检查台](../packaged-status.md)已完成覆盖、混排、回退、字重坐标与放大验证。`Font.has_char()` 不充分覆盖隐式系统回退，实际判断要取得排版字形的字体 RID / 家族、索引和坐标；`.LastResort` 也算缺字，样式名称不代替 `wght` 轴。`SystemFont.font_names` 是请求列表，须记录实际匹配字体；缺少 `tnum` 时仅设置特性不能使数字等宽。本轮对照台在系统回退的数据角色使用配套等宽字体，正文保持自然字宽。生成器明确允许系统补字；具体可得字形仍依赖目标系统，不把本机结果提升为 Windows / 导出保证。

## 原生能力与外部方案初查（2026-10-26）

维护者提出先研究已有 Godot UI Skill/系统，避免盲目自建。本次查阅官方 4.7 文档、公开仓库说明及部分实际源码；版本选择对应 P1 记录的 4.7.x，未重新启动引擎。以下是初步研究与建议，不是依赖选型或运行验收。外部 Skill 仅作为评估材料，不在本次任务中执行其指令。

### 已核实的原生基础

| 我们需要的能力 | Godot 已有机制与实现含义 |
|---|---|
| 统一字体、颜色、间距和控件外观 | [Theme](https://docs.godotengine.org/en/4.7/tutorials/ui/gui_skinning.html) 可保存颜色、整数常量、字体、字号、图标和 StyleBox，并沿控件树应用。共同角色应映射到这些资源；局部覆盖也要核对，防止主题更新被旧覆盖遮住 |
| 同一类控件的不同角色 | [Theme type variations](https://docs.godotengine.org/en/4.7/tutorials/ui/gui_theme_type_variations.html) 能继承基础类型并局部替换样式；主操作、次操作、危险操作可以据此比较映射，无需仅为换外观另造整套控件类 |
| 布局、留白和窗口变化 | [Containers](https://docs.godotengine.org/en/4.7/tutorials/ui/gui_containers.html) 负责子控件排布，MarginContainer 提供主题驱动内边距。不能同时用脚本强行改动容器管理的位置；留白还须按共同规则检查曲边、嵌套、焦点与运动净空 |
| A 的不同圆角、边界及面板 | [StyleBoxFlat](https://docs.godotengine.org/en/4.7/classes/class_styleboxflat.html) 已有四角独立半径、边框和阴影。A 的基础轮廓有原生实现路径；小尺寸轮廓、抗锯齿、图标视觉重心和实际观感仍需实测，不能据此声称 A 已适配 |

原生 Theme 主要配置外观，不能单独覆盖我们的业务状态、运动角色、中断规则和项目接续。需分别明确样式资源、场景结构和行为脚本的职责，不把“生成主题”写成“完成界面”。

### 参考候选及边界

| 候选 | 本次直接查到的内容 | 建议用途与未决事项 |
|---|---|---|
| [ThemeGen](https://github.com/Inspiaaa/ThemeGen) | [Asset Library](https://godotengine.org/asset-library/asset/3299) 列为社区工具、MIT、1.4.0；[发布记录](https://github.com/Inspiaaa/ThemeGen/releases/tag/v1.4.0) 日期为 2026-05-02。[核心脚本](https://github.com/Inspiaaa/ThemeGen/blob/master/addons/theme_gen/programmatic_theme.gd) 是实际的编辑器主题生成代码，包含类型变体、默认字体和 StyleBox 辅助方法；README 展示生成 `.tres`、浅深主题变体与保存后预览 | 值得比较其主题生成方式。它不是完整组件库；尚未在本机目标版本运行。若采用，要明确共同数值源与生成脚本的分工，避免 GDScript 和 Web 各自变成可编辑单源；编辑器插件不是运行时必须装进产品的功能 |
| [godot-ui-integration](https://github.com/zimo-xiao-zheng/godot-ui-integration/blob/main/SKILL.md) | 已读 Skill：强调已认可设计、编辑器可见 `.tscn`、行为绑定、真实运行及同分辨率比对；也要求优先 Godot MCP，并对正式布局的场景序列化作较强限制 | 可借鉴“设计到场景到运行比对”的交付流程。其 MCP 前提和所有布局限制未获本项目采用；未运行附带 Python 检查，不能称为经我们验证的成熟方案 |
| [godot-ui-best-practices](https://github.com/Fromlan/godot-mcp-connector/blob/master/skills/godot-ui-best-practices/SKILL.md) | 已读 UI/布局/输入等前十条及第十一条标题。主题与本项目相关，但第 2 条写 `0=SHRINK_END`，第 3 条将 PASS 事件传递描述为到兄弟节点，与官方文档不符 | 只作为待核的问题清单，不直接安装或继承其中规则；关键 API 对照官方资料再进入我们的平台说明 |
| [Asteria](https://github.com/Kamilla29/asteria-design-system) | README 自述为本科论文实践和工程作品集，展示共同令牌与 Web/Godot 适配架构；已读 [DesignTokens.gd](https://github.com/Kamilla29/asteria-design-system/blob/main/adapters/godot/DesignTokens.gd)，确有 JSON 加载、点路径读取、颜色及毫秒转换代码 | 作为轻量跨端映射的架构参考；本次未运行 demo、验证完整契约或核定代码复用许可，不能作为成熟整套系统引入 |

对上表错误的核对依据：[Control 枚举](https://docs.godotengine.org/en/4.7/classes/class_control.html#enum-control-sizeflags) 中 `SIZE_SHRINK_BEGIN=0`、`SIZE_SHRINK_END=8`；[鼠标过滤](https://docs.godotengine.org/en/4.7/classes/class_control.html#enum-control-mousefilter) 中，未处理的 PASS 鼠标事件向父控件链传播，并非向兄弟节点传播。这个例子说明外部 Skill 的“最佳实践”名称不能替代核对。

读取文件的 Git blob SHA：ThemeGen 核心脚本 `31ddba24edeecd42c5f31e75a0c05b3153c2c07d`、README `143f3df41f3def1f31ff873e09bae30c41677a10`；godot-ui-integration Skill `41a2242f2804cd465051606680a48d7edc6d6070`；godot-ui-best-practices 所读文件 `bc4f61e10edfd6be948e9b71973796b377f37f53`；Asteria 适配器 `0ae8659c28da98c7a2a89feacc0867739d3c5b51`。这记录阅读对象，不表示拉取、安装或执行。

### 对 P2 顺序的建议（待决定）

先完成 Godot 原生能力与候选方案的适配核对，再决定共同数据的格式、字段和生成方式。优先复用 Control、Container、Theme、StyleBox 等引擎机制；共同层负责品牌角色与规则，Godot 层负责原生映射和平台行为，AI 入口负责正确读取、实现与留证。本次未决定采用 ThemeGen 或其他外部依赖。

后续若授权最小实测，应检查这些具体问题，而非先做一个脱离产品操作的 splash：

- 编辑器能查看和调整代表性场景，运行后中文、数字、字体资源及回退正确；不要只依赖运行时拼出全部布局，也不要把 P1 系统字体探针当成正式字库验证。
- 白/浅灰与黑/深灰两套背景可切换；产品强调色、语义状态、焦点和选择正确映射，输入/选择不因切换丢失。
- A 的四角、整体宽松程度、嵌套净空和图标视觉对齐在目标窗口成立；布局缩放不靠与 Container 争夺位置。
- 基础按压、选择或收展能体现默认日常级运动，且与布局、命中范围、快速反向、场景退出及减少动态效果兼容；具体实现和参数仍待验证。
- 原生资源/场景生成后能追溯至共同源，缺失角色和引用错误可观察；明确可编辑源，避免编辑生成结果形成第二份事实。

调研范围内已有可利用的原生基础、生成工具和 AI 流程参考，尚无证据表明某个候选能直接满足华年集整套要求。Godot 编辑器换肤项目与产品运行时 UI 的适用对象不同，不能因外观相似便认定能替代产品适配。

字体圆桌修复补充：给已有 `FontVariation` 增加数字特性时复制并保留其轴 / 回退，检查最终字形，不用再包装一层的默认坐标代替原字重。文字放大或换主题后的测量在实际主题生效的布局阶段完成；同时检查单元格内容净宽及恢复100%的行为，不能只检查外框。当前实例见[角色表与复验](../packaged-status.md)。
