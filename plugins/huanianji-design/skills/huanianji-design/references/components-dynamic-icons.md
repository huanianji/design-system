# 公共动态图标：提醒、麦克风状态与展开跟随

本批提供 Web / Godot 原生实现；本机验证状态和边界见[合批验收记录](packaged-status.md)。图形来自同一份SVG，不另做品牌Logo。具体参数沿用当前产品profile的motion；这不是所有产品冻结的图标样式或尺寸。

| 角色 | 触发与落点 | 动态归属 |
|---|---|---|
| bell 提醒 | 真实提醒动作成功接收输入时摆动一次，回到静态。重复触发从当前角度重启，禁止叠加多个时钟 | 图标拥有局部摆动；外层按钮保留公共按压，不随悬停或获焦自动播放 |
| microphone 状态 | 按实际enabled状态显示麦克风或静音斜线；文字与按下态同步表达，颜色只是辅助 | 图标拥有斜线显隐与局部弹性；中途反向从当前视觉值继续，不使用成功对勾 |
| direction 方向 | 展开为180°、收起为0°，实际展开状态决定方向 | 展开组件拥有唯一时钟，通过follow传入进度；图标不再另启动动画 |

Web：`foundation/components/web/dynamic-icon.js` 的 `dynamicIcon(element,{kind,getMotion,getReduced,enabled})`，同时加载同目录 `dynamic-icon.css`。API为`notify()`、`setEnabled(value,animated)`、`follow(progress)`、`settle()`、`dispose()`；只使用对应角色的方法。公共disclosure接收`icon`和真实`arrow`，测量当前角度后连续驱动。

Godot：`foundation/components/godot/dynamic_icon.gd` 的 `attach(control,role,parameters)`，载体使用TextureRect/Control，保持外层Button原生事件与公共`action_button.gd`。API为`notify()`、`set_enabled(value,animated)`、`follow(progress)`、`set_reduced(value)`、`settle()`；disclosure.icon引用该行为。图标以单调时钟读取实际经过时间；组件退出时结束帧驱动。主题改变只刷新颜色/参数；字体或容器重排才重新定位图形。

调用方负责真实状态、可达名称、必要的文字说明及产品语义；图标是装饰，没有自己的焦点或命中目标。铃铛读取optical.bell_x；其他图形依据自身视觉重心判断，不能统一照抄铃铛偏移。图形可运动，按钮命中范围保持稳定。

减少动态立即落在真实最终状态；隐藏、换记录和退出清理旧内容的运动。切主题保留同一内容的进行中动画。方向图标的隐藏清理由展开的最终状态收束，不把箭头方向单独复位成收起。

实际消费者是[管理/创作工作台](combined-workflows.md)。新增图标角色先确定含义、所有者、输入/状态分支和中断规则；当前三种用途的通过不自动覆盖其他图标、完整图标库或其他平台。

当前图标使用UI实际经过时间，不随Engine.time_scale调速；游戏暂停/时间缩放与不同处理模式的组合须在实际产品验证，本批只覆盖默认运行条件。
