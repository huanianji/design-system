# P3 首批公共实现：按钮、Tab 与局部展开

范围：P2 已认可的本机 Web / 原生 Godot 基准。主题色由产品选择，公共组件只读取颜色角色；不把管理靛蓝 / 创作青绿固定为产品默认。输入 / 验证码、动态图标完整组件、完整产品与其他目标系统继续按原路线推进。

2026-10-27用户修订：对勾只用于待办 / 核对条目。普通开关使用切换按钮，Web以原生button的 `aria-pressed`、Godot以 `Button.toggle_mode / button_pressed` 对应实际启用状态；当前检查台三个条件开关已按此修改。单次动作仍按实际处理 / 结果反馈，规则见[共同规则§3.9](common/华年集共同设计规则.md#39-交互状态外观与滚动边界)。

## 共同行为约定

| 交互 | 输入与状态 | 焦点与可达性 | 运动、打断与退出 |
|---|---|---|---|
| 按钮 | 原生鼠标 / 键盘激活；正常、禁用、处理中；重复触发在处理中被阻止。结果由真实调用方提供，失败后解除处理中供重试 | 禁用不接收激活或新焦点；处理中使用禁用，完成后若焦点没有被用户移往别处，恢复原入口。业务说明 / 结果由调用方呈现 | 只缩放视觉层，布局 / 命中 / 焦点框保持；各实例独立接续。离焦时若仍按住则复位，已释放的回弹可独立完成；禁用、隐藏、窗口失焦和退出落稳 / 清理 |
| Tab / 分段 | 点击、左右方向键、Home / End；跳过禁用项；选中与内容对应。动态禁用当前项时选下一可用项，全禁用时无选中，恢复可用后重新选中 | 单一 Tab 键入口，其余项通过方向键访问；可见焦点与选中分别表达；隐藏面板不保留内部焦点 | 指示底板沿轨道直接到当前目标；重复切换取消旧目标并从当前画面接续，不让旧结束回调复活旧选中。主题不重置选择；字号 / 尺寸变化重新排布；减少动态直接落稳 |
| 局部展开 | 同一入口切换，内容中 Escape 收起；保留草稿和独立禁用状态。程序也可调用公开接口改变开合状态 | 收起内容不再可聚焦或操作；焦点在内容内时先返回触发入口；Web关联 `aria-expanded/controls`，Godot使用原生控件和显式焦点目标 | 高度与箭头同一运动，保留已认可展开回弹与收起轻提；反向从当前值续接。换主题保留目标，减少动态归稳；内容尺寸变化刷新；换内容 / 移除 / 退出取消旧运动 |

焦点分两件事：逻辑焦点决定下一次键盘输入发给谁，可见提示说明键盘操作位置，均不等于选中 / 开启。公共按钮按当前输入方式显示提示：鼠标 / 触摸不残留键盘框，键盘导航 / 激活必须可见；处理中切换输入方式也以最新方式为准。完成 / 取消只在用户尚未移往另一控件时恢复逻辑焦点，不能把结果反馈伪装成选中态。

Godot由[input_focus.gd](../foundation/components/godot/input_focus.gd)在每个Viewport记录输入方式，只管理已绑定的公共按钮，`grab_focus(true)`保留逻辑焦点并隐藏提示；`has_focus()`包含隐藏焦点，`has_focus(true)`忽略隐藏焦点、用于判断可见提示。Web保留原生焦点，以公共按钮的`data-hj-focus-input`限制提示样式；同时覆盖鼠标场景的浏览器默认outline，文本输入提示不受影响。自定义按钮样式仍须遵守这一可见性约定。

精确参数仍从[共同源](../foundation/tokens/base.json)及产品覆盖读取。新内容或产品有额外动作时，先明确操作边界，再按[交互排查](interaction-review.md)验证；不把本组三个组件当完整目录。

2026-10-27提交反馈修正：在途阻止重复激活，但保留这次已经接受输入的释放回弹；`setBusy/begin`、配置刷新及调用方重复同步可用性不清理该反馈。显式`setDisabled(true)/set_disabled(true)`、取消、隐藏、窗口失焦和退出仍按各自语义归稳。Web `button.primary`现在提供与Godot `Action`对应的公共主操作变体，含字体强调、悬停、按下与继承的禁用态；产品覆盖背景时必须限定可用状态，避免无条件选择器抹掉状态样式。实际消费者中的校验/在途/键盘过程也须验证，见[过程门禁](packaged-status.md)。

## Web 公共入口

[controls.js](../foundation/components/web/controls.js) 和 [controls.css](../foundation/components/web/controls.css)。样式与生成的 `tokens.css` 一起引用，包含原生按钮与 Tabs 的共同默认；产品可在后面覆盖布局。基础样张的 `app.css` 已导入此样式，旧 `web/motion.js` 只保留导出转发。

```js
import {createControls} from './components/web/controls.js';
const ui = createControls(() => resolved.motion, () => reduced);
const action = ui.button(buttonElement); // 同一作用域重复取得仍是同一控制器
action.setDisabled(false);
buttonElement.addEventListener('click', async () => {
  try {
    await action.run(async signal => {
      const result = await performOperation({signal});
      if (!signal.aborted && isCurrentRecord()) showActualResult(result);
    });
  } catch (error) { if (isCurrentRecord()) showActualError(error); }
});
const tabs = ui.tabs({buttons, panels, indicator, onChange: showSelection});
tabs.setDisabled(1, true);
const local = ui.disclosure({trigger, region, content, arrow, onChange: showOpenLabel});
local.setOpen(false, false);
// 用户选择减少动态后调用 ui.settle()；数据/内容变更后 local.refresh()。
// 字号或尺寸改变后 tabs.layout(false)，退出该界面时 ui.dispose()。
```

`run` 不吞掉异常，不制造成功；调用方必须处理失败。`dispose` 中止组件所属的 AbortSignal、监听和动画；不响应取消的外部请求可能仍在执行，调用方不得把它的结果写回新业务对象。移除节点自动释放对应绑定；同一节点重建绑定前应释放旧作用域。保留浏览器返回缓存时不销毁该缓存内的作用域。

Tabs 传入非空、同一父层的按钮数组；需要内容切换时传入一一对应的 `panels`。标准结构为 `.tabs > .tab-row[role=tablist]`，其中放置可选 `.plate[aria-hidden=true]` 和带 `.surface` 的按钮；使用原生button，避免另造可点击div。底板可省略。`select(index, {focus, animated, notify})`、`layout(animated, preserve)` 和 `setDisabled(index, value)` 为公开入口；产品负责内容，组件负责选中、键盘和可达关系。全禁用时 `selected=-1`。两端Tab数组结构变化时销毁旧组再绑定；内容更新可保留现有面板，不复用过期的索引回调。

展开内容放入独立 `region` 的第一个子项或显式 `content`，高度由组件控制；不要再给 `region` 添加竞争的高度过渡。通过 `setOpen(value, animated)`、`refresh()`、`settle()` 和 `dispose()` 管理。外部通过 CSS 改变可见性但不使用 `hidden/inert` 时，应显式 `settle()` / `dispose()`，不宣称能自动识别任意 CSS 状态。

## Godot 公共入口

- [action_button.gd](../foundation/components/godot/action_button.gd)：`attach(button, motion)` 返回挂在按钮下的行为节点，同一按钮重复取得复用原节点；`set_disabled`、`set_reduced`、`reset`。原生按钮 / Theme 保留文字、状态外观、命中和焦点，反馈仅操作视觉偏移。旧适配器脚本只转发到此实现。
- [tab_group.gd](../foundation/components/godot/tab_group.gd)：新建后 `bind(buttons, motion, indicator, panels)`；`select`、`set_disabled`、`layout`、`set_reduced`，通过 `changed(index)` 更新业务状态。自动复用按钮反馈，并按Tab角色选择释放幅度，调用方无需另接回弹；未显式设variation的按钮使用共同 `TabButton` 外观，已有variation保留。非选中项使用点击焦点，选中项成为完整键盘入口；全禁用时 `selected=-1`。背景容器使用现有 `TabsPanel`，底板使用 `SelectionPlate`，不在样张另画一套选中态。
- [disclosure.gd](../foundation/components/godot/disclosure.gd)：新建后 `bind(trigger, region, content, motion, arrow, focus_targets)`；`set_open`、`refresh`、`settle`、`set_reduced`，用 `changed(open)` 更新文字和业务状态。明确传入应随展开参与焦点的字段，不自动把所有装饰节点变成焦点目标。

```gdscript
var behavior = Action.attach(button, roles.motion)
func execute() -> void:
    var owner = behavior # 捕获所属实例，不能在等待后转而读取新建的行为节点
    var token: int = owner.begin()
    if token == 0: return # 禁用或已有进行中操作
    var result: Dictionary = await actual_operation()
    if is_instance_valid(owner) and owner.is_inside_tree():
        owner.finish(token, result) # 过期 token 被拒绝；结果由调用方呈现
```

`begin/finish/cancel` 管理本控件状态；`completed(result)` 与 `cancelled` 供调用方接收，不连接服务也不替代业务请求的超时 / 失败 / 取消机制。原生不存在 Web Promise 的异常捕获模式，调用方以实际结果字典结束，并检查节点和业务对象是否仍有效。销毁所属节点时 Tween / 信号随树退出清理；移除后重建不可复用旧 token。

主题覆盖改变时更新各控制器 `config`；TabGroup会同步到组内按钮反馈。减少动态时调用 `set_reduced`，TabGroup覆盖底板和组内按钮；排布后调用 `layout` / `refresh`。字体、Theme 和适用引擎版本沿用[共同源说明](shared-foundation.md)，当前基于 Godot 4.7 的视觉偏移；未声明其他 Godot 版本或目标系统已验证。

## 实际消费与检查入口

| 消费者 | Web | Godot |
|---|---|---|
| 基础样张 | `foundation/web/index.html`：按钮、Tabs、设置展开 | `foundation/sample/main.tscn`：同三类 |
| 管理 / 创作片段 | `foundation/web/fragments.html`：按钮、备注展开 | `foundation/sample/fragments.tscn`：同两类；筛选保留原有精确反馈，不冒充完整内容Tab |
| 字体检查台 | `foundation/web/typography.html`：公共按钮反馈 | 既有字体台保持其专业检查职责 |
| 公共状态检查台 | `foundation/web/controls.html` | `foundation/sample/controls.tscn` |

检查台的650ms任务和失败结果均明确标为本地模拟，只验证组件状态与生命周期，不代表 API 接入。测试与画面、源码摘要、故障和边界统一见[P3首批验收记录](packaged-status.md)。
