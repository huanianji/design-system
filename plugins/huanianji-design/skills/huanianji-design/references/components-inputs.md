# P3 普通输入与验证码公共实现

2026-10-27。本批继承已认可的字体角色、A、留白、中性浅深与日常运动。普通输入保留原生编辑；验证码是独立模式，不替所有输入规定六格外观。演示结果明确为本地模拟，不接短信或身份服务。当前运行证据与未覆盖项见[本批验证](packaged-status.md)。

提交按钮的消费端过程已补[强制门禁](packaged-status.md)：普通字段/验证码的功能结果通过，不代表校验拒绝、进入在途及主操作变体的运动通过。复用公共按钮的业务调用中，阻断重复操作与本次释放反馈分别处理；样张主按钮使用公共primary/Action状态，不能局部无条件背景覆盖禁用态。

新增数值只维护在`foundation/tokens/base.json`：`space.code_cell`、`space.code_gap`、`motion.input_enter_ratio`、`motion.input_error_distance`。产品可按现有覆盖机制调整，运行原build后两端读取；时间沿用select/release角色。平台仍分别实现编辑和渲染，不意味着改一份行为代码会自动改另一端。

## 操作与状态约定

- 普通输入的文字、选区和光标不跟着回弹。焦点边界保持清楚，边框变化不挤动文字或命中区；字号由消费位置的角色决定，公共样式不覆盖已有小号备注。
- 正常、只读、禁用、处理中、错误与结果分别表达。只读保留聚焦、选择和复制；禁用跳过键盘输入。失败保留内容，并用关联文字说明恢复方式，修改后撤销过期错误。公共层不判断业务成功。
- 组合输入期间不在公共层截获编辑和确认键。Web等组合结束再向调用方发送提交的编辑内容；Godot保留原生TextEdit/LineEdit与输入法。表单多行输入的Tab用于离开字段；编辑器型缩进输入不属于本模式。输入法候选窗的实际系统行为仍须目标机验证。
- 验证码按字符串处理，保留前导零；全角数字转半角，非数字不进入槽位。输入或粘贴从当前位覆盖，超出末尾部分舍弃，其余位保留；点击已有位后选中该位，下一次输入替换它。
- Backspace先清当前位；空位再次Backspace返回上一位，不连带删除上一位。Delete清当前位；左右/Home/End移动；Tab/Shift+Tab按原生字段顺序访问六位和后续操作。每位有明确名称，整组有说明及错误关联。
- 数字进入与焦点迁移分别处理。连续输入取消旧目标、从当前画面接续；减少动态、清空、禁用与退出清理各自的运动，内容状态不依赖动画结束。错误只提供局部反馈，验证结果来自调用方，不用对勾表示普通开启。

## Web

加载[inputs.css](../foundation/components/web/inputs.css)，与生成的tokens及公共按钮样式一起使用；产品角色样式可覆盖它。实现为[inputs.js](../foundation/components/web/inputs.js)。

```js
import {inputField, otpInput} from './components/web/inputs.js';
const note = inputField(textarea, {message: hint, onChange: saveLocalDraft});
note.setStatus('error', '请补充备注。');
note.setReadOnly(true); // 可聚焦、选择、复制
note.setDisabled(true);
const otp = otpInput(container, {message: codeHint,
  getMotion: () => roles.motion, getReduced: () => reduced,
  onChange: slots => updateLocalCode(slots)});
if (otp.complete) startActualVerification(otp.value);
otp.setStatus('error', '验证码不匹配，请更正。');
otp.settle(); // 减少动态、显式隐藏或尺寸处理时
// 退出所属界面：note.dispose(); otp.dispose();
```

普通字段支持原生input/textarea，不接管光标、选区、撤销与粘贴。关联说明须传入独立message元素。重复绑定同一元素返回既有控制器；重新配置回调/说明前先dispose。验证码内部为原生text输入，不用number输入；数字视觉层为装饰，组合输入时让原生预编辑内容显示。`clear`、`focus(index)`、`setDisabled`、`setReadOnly`为公开入口。两端当前验收模式为六位，Web的其他length未纳入本批验收。

公共字段不提交请求。调用方负责校验、pending、按钮防重复、结果与取消；示例使用[首批公共按钮](components-first-batch.md)的run，业务请求仍须处理真实失败、过期与所属对象变化。

## Godot

[input_field.gd](../foundation/components/godot/input_field.gd)挂在原生TextEdit/LineEdit下；[otp_input.gd](../foundation/components/godot/otp_input.gd)组合六个原生LineEdit及独立装饰层。

```gdscript
var field = InputField.attach(note_edit, palette, hint_label)
field.changed.connect(save_local_draft)
field.set_status("error", "请补充备注。")
field.set_read_only(true)
field.set_disabled(true)
field.refresh(new_palette) # 换Theme后；角色与字号沿用控件Theme
var code = Otp.new()
parent.add_child(code)
code.bind(roles, palette, code_hint)
code.changed.connect(update_local_code)
if code.complete(): start_actual_verification(code.value())
code.set_status("error", "验证码不匹配，请更正。")
code.set_reduced(reduced)
code.refresh(roles, new_palette)
```

普通字段attach幂等，提示颜色随palette刷新，read_only与normal保持同一内容边距。验证码focus(index)、clear、set_disabled、set_read_only、set_reduced为公开入口；当前原生实现固定六位。调用方负责尺寸/所属场景、实际校验和请求；节点退出时其Tween随所属节点停止，旧请求仍须检查实例及业务对象有效性。

## 实际消费与证据

- 现有管理片段：Web `web/fragments.html` 的开播备注、Godot `sample/fragments.tscn` 的Note。通过公共编辑事件写回各主播的本地草稿，继续复用首批局部展开；未接后端保存。
- 独立检查台：Web `web/inputs.html` 对应Godot `sample/inputs.tscn`。同时展示普通输入和独立验证码，支持浅深、125%、减少动态、禁用、只读与模拟请求失败。
- 本机运行、同路径配对、实际画面、保留失败及输入法/读屏/自动填充边界统一见[验收记录](packaged-status.md)。未完成的动态图标和P3整体验收继续保留。
