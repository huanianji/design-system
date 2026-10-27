# 管理 / 创作工作台与 AI 实际消费

用途：把P3公共交互用于P4完整小任务，供新界面复用和同条件对照。已有管理/创作片段在原位置升级，不复制更精致的展示专用实现。

Web入口：`foundation/web/fragments.html`。Godot入口：`foundation/sample/fragments.tscn`。两端同名「华年集 · 管理与创作工作台」，默认管理、浅色、小号、日常动态、林汐；交付时核对实际窗口，不能误开输入检查台。两端窗口状态各自保留，不是跨端实时同步系统。

| 场景 | 可完成的任务 | 状态和责任 |
|---|---|---|
| 管理工作台 | 搜索/筛选主播→查看准备事项→麦克风状态切换→展开备注→编辑/保存/失败重试→换人返回 | 每位主播分别保留checks、note草稿、savedNote、noteStatus/message及mic。编辑不冒充保存；在途换人/换界面/重新读取会取消旧提交、保留草稿，旧结果不得覆盖新对象 |
| 创作工作台 | 分类/选择素材→实际画布预览→调整缩放和透明度→切换素材返回→重置当前预览 | 每份素材分别保留预览参数；切换只对作品做短暂进入，棋盘/参数不跟着闪。调参/重置结束旧切换动画，减少动态直接落稳 |

准备事项属于待办，保留勾选；麦克风是普通开关，使用按下态、图标和文字表示当前状态。麦克风不连接设备；备注仅保存当前窗口的内存状态；全部数据来自`sample/fragments.json`，不是共华年或米鹿工坊正式业务。真实服务/持久化接入时必须验证相应路径。

## AI 从入口到实际修改

1. 在Skill源目录用 `python3 scripts/kit.py context --project <foundation或实际产品绝对路径>` 定位已存在档案；读取当前决定与本次相关资源。`context`不负责自动选择组件。
2. 新产品先走方向方法；已有产品沿用档案。当前两类布局、密度、字号和A来自已认可基准，强调色不承担家族识别验收。
3. 按所需交互读取公共实现。按钮/Tab/展开见`components-first-batch.md`；普通输入/验证码见`components-inputs.md`；图标见`components-dynamic-icons.md`。共同参数见`shared-foundation.md`。不复制片段里的业务数据或演示失败开关到真实产品。
4. Web组织层在`foundation/web/fragments.js`，布局在同名HTML/CSS；Godot组织层在`foundation/adapters/godot/fragments.gd`，场景由`create_fragments.py`生成。改布局源而非手改生成场景；只改行为不需要虚构新的token构建。
5. 验证当前消费者的真实操作和动态中间过程，核对实际资源摘要；保存适用范围、失败与平台例外。当前合批约定和证据在`validation/phase3/combined/`，记录见[合批验收](packaged-status.md)。
6. 更新当前项目单源与资源状态，留下能直接继续的下一步。本轮是同一主会话沿Skill定位资产后实现任务；不能写成P5独立新项目或新会话通过。

六类偏好的日常导航为`foundation/web/showcase.html`：按钮/Tab/展开→controls；输入/验证码→inputs；图标与组合→fragments；字体→typography。每项给出对应Godot场景和公共源路径。现有组件不足时按共同规则和平台能力补齐所需控件，按实际职责检查，不以完成全组件库作为开始产品的前提。
