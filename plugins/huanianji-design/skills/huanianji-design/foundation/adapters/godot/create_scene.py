"""生成本实验的具体场景；运行时不拼装主要布局。"""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
glyph_offset = 0.0
if len(sys.argv)>1:
    glyph_offset = json.loads(Path(sys.argv[1]).read_text())['profiles']['baseline']['godot']['optical']['check_x']
has_theme = (ROOT/'generated/editor-theme.tres').is_file()
lines = ['[gd_scene load_steps=%d format=3]' % (8 if has_theme else 7),
'[ext_resource type="Script" path="res://adapters/godot/main.gd" id="1"]',
*(['[ext_resource type="Theme" path="res://generated/editor-theme.tres" id="2"]'] if has_theme else []),
'[ext_resource type="Texture2D" path="res://assets/icons/bell.svg" id="3"]',
'[ext_resource type="Script" path="res://adapters/godot/check_visual.gd" id="4"]',
'[ext_resource type="Texture2D" path="res://assets/icons/chevron.svg" id="5"]',
'[sub_resource type="ButtonGroup" id="TabGroup"]',
'[sub_resource type="StyleBoxLine" id="Divider"]',
'color = Color(0.55, 0.55, 0.6, 0.25)', 'thickness = 1']

def node(name, kind, parent=None, **props):
    where = '' if parent is None else f' parent="{parent}"'
    lines.append(f'\n[node name="{name}" type="{kind}"{where}]')
    lines.append('unique_name_in_owner = true')
    for key,value in props.items():
        lines.append(f'{key.replace("__", "/")} = {value}')
    return name if parent=='.' else (f'{parent}/{name}' if parent else '.')

def text(name, parent, content, role=None, **props):
    p={'layout_mode':2,'text':repr(content).replace("'",'"')}
    if role: p['theme_type_variation']=f'"{role}"'
    p.update(props)
    return node(name,'Label',parent,**p)

def button(name,parent,caption,role=None,**props):
    p={'layout_mode':2,'text':f'"{caption}"','custom_minimum_size':'Vector2(0, 38)'}
    if role: p['theme_type_variation']=f'"{role}"'
    p.update(props)
    return node(name,'Button',parent,**p)

node('UI','Control',layout_mode=3,anchors_preset=15,anchor_right=1.0,anchor_bottom=1.0,grow_horizontal=2,grow_vertical=2,theme='ExtResource("2")' if has_theme else 'null',script='ExtResource("1")')
node('Background','ColorRect','.',layout_mode=1,anchors_preset=15,anchor_right=1.0,anchor_bottom=1.0,mouse_filter=2,color='Color(0.95,0.95,0.96,1)')
shell=node('Shell','MarginContainer','.',layout_mode=1,anchors_preset=15,anchor_right=1.0,anchor_bottom=1.0,theme_override_constants__margin_left=40,theme_override_constants__margin_right=40,theme_override_constants__margin_top=20,theme_override_constants__margin_bottom=20)
stack=node('ShellStack','VBoxContainer',shell,layout_mode=2)
bar=node('Toolbar','HFlowContainer',stack,layout_mode=2)
text('LabTitle',bar,'Godot 原生 · 共同源','Muted',custom_minimum_size='Vector2(152,38)',vertical_alignment=1)
button('Reload',bar,'重新读取设计')
button('Mode',bar,'切换深色')
button('Accent',bar,'强调色：靛蓝')
button('TextScale',bar,'字号 125%')
button('Reduce',bar,'减少动态',toggle_mode='true')
# SCROLL_MODE_RESERVE=4：收展跨越可滚动阈值时，不让整个面板横移。
scroll=node('Scroll','ScrollContainer',stack,layout_mode=2,size_flags_vertical=3,horizontal_scroll_mode=0,vertical_scroll_mode=4)
center=node('CenterRow','HBoxContainer',scroll,layout_mode=2,size_flags_horizontal=3)
node('LeftSpace','Control',center,layout_mode=2,size_flags_horizontal=3,mouse_filter=2)
card=node('Card','PanelContainer',center,layout_mode=2,custom_minimum_size='Vector2(880,0)',size_flags_vertical=0)
body=node('Body','VBoxContainer',card,layout_mode=2)
head=node('Header','HBoxContainer',body,layout_mode=2)
titles=node('Titles','VBoxContainer',head,layout_mode=2,size_flags_horizontal=3,theme_override_constants__separation=4)
text('Title',titles,'开播准备','Heading',autowrap_mode=3)
text('Subtitle',titles,'把声音、画面和今晚的话题准备好','Muted',autowrap_mode=3)
bell=button('Bell',head,'',custom_minimum_size='Vector2(46,46)',tooltip_text='"提醒设置（本地演示）"',size_flags_vertical=4)
node('BellArt','TextureRect',bell,layout_mode=0,offset_left=10,offset_top=11,offset_right=34,offset_bottom=35,mouse_filter=2,texture='ExtResource("3")',expand_mode=1,self_modulate='Color(0.15,0.15,0.17,1)')
tabs=node('Tabs','PanelContainer',body,layout_mode=2,theme_type_variation='"TabsPanel"')
tr=node('TabsRoot','Control',tabs,layout_mode=2,custom_minimum_size='Vector2(0,42)')
node('Plate','Panel',tr,layout_mode=0,offset_right=260,offset_bottom=42,theme_type_variation='"SelectionPlate"',mouse_filter=2)
th=node('TabButtons','HBoxContainer',tr,layout_mode=1,anchors_preset=15,anchor_right=1.0,anchor_bottom=1.0,theme_override_constants__separation=4)
for i,label in enumerate(['开播前','直播中','结束后']):
    button('Tab'+str(i),th,label,'TabButton',toggle_mode='true',button_group='SubResource("TabGroup")',button_pressed='true' if i==0 else 'false',size_flags_horizontal=3)
topic=node('Topic','VBoxContainer',body,layout_mode=2,theme_override_constants__separation=8)
text('TopicLabel',topic,'今晚想聊什么？',autowrap_mode=3)
node('TopicInput','LineEdit',topic,layout_mode=2,custom_minimum_size='Vector2(0,44)',text='"一起聊聊最近的小确幸"',placeholder_text='"输入今晚的话题"',caret_blink='true')
check=node('ReadyCheck','CheckBox',body,layout_mode=2,custom_minimum_size='Vector2(0,48)',text='"麦克风与音量已确认"',button_pressed='true')
node('CheckArt','Control',check,layout_mode=0,offset_left=10,offset_top=10,offset_right=38,offset_bottom=38,mouse_filter=2,script='ExtResource("4")',glyph_offset_x=glyph_offset)
frame=node('Frame','PanelContainer',body,layout_mode=2,theme_type_variation='"FramePanel"')
fv=node('FrameBody','VBoxContainer',frame,layout_mode=2,theme_override_constants__separation=14)
fh=node('FrameHeader','HBoxContainer',fv,layout_mode=2)
text('FrameTitle',fh,'画面与布局',size_flags_horizontal=3)
expand=button('Expand',fh,'展开设置','ExpandButton',custom_minimum_size='Vector2(112,30)')
node('ExpandArt','TextureRect',expand,layout_mode=0,offset_left=86,offset_top=7,offset_right=102,offset_bottom=23,mouse_filter=2,texture='ExtResource("5")',expand_mode=1,self_modulate='Color(0.38,0.38,0.42,1)')
scene=node('Scene','PanelContainer',fv,layout_mode=2,theme_type_variation='"ScenePanel"',custom_minimum_size='Vector2(0,106)')
scene_row=node('SceneRow','HBoxContainer',scene,layout_mode=2,theme_override_constants__separation=12)
preview=node('Preview','PanelContainer',scene_row,layout_mode=2,theme_type_variation='"PreviewPanel"',size_flags_horizontal=3)
text('SceneLabel',preview,'主播画面',horizontal_alignment=1,vertical_alignment=1)
side=node('Side','VBoxContainer',scene_row,layout_mode=2,custom_minimum_size='Vector2(110,0)',theme_override_constants__separation=7)
for i in range(3): node('Side'+str(i),'Panel',side,layout_mode=2,custom_minimum_size='Vector2(0,16)',size_flags_vertical=3,theme_type_variation='"SidePanel"')
reveal=node('Reveal','Control',fv,layout_mode=2,clip_contents='true')
settings=node('Settings','VBoxContainer',reveal,layout_mode=0,anchor_right=1.0,offset_bottom=76,theme_override_constants__separation=8)
text('BrightnessLabel',settings,'参数调节  68%','Muted')
node('Brightness','HSlider',settings,layout_mode=2,custom_minimum_size='Vector2(0,34)',min_value=0.0,max_value=100.0,value=68.0,focus_mode=0)
actionhost=node('ActionHost','Control',body,layout_mode=2,custom_minimum_size='Vector2(0,52)')
button('Action',actionhost,'试试按钮回弹','Action',layout_mode=1,anchors_preset=15,anchor_right=1.0,anchor_bottom=1.0)
text('ActionNote',body,'按下，再松开，感受落稳。','Muted',horizontal_alignment=1)
states=node('States','HBoxContainer',body,layout_mode=2,theme_override_constants__separation=18)
text('SuccessState',states,'✓ 已准备','Success')
text('WarningState',states,'! 待确认','Warning')
text('ErrorState',states,'× 有问题','Error')
text('Numbers',states,'96.5% · 12:34','Muted',size_flags_horizontal=3,horizontal_alignment=2)
node('Divider','HSeparator',body,layout_mode=2,theme_override_styles__separator='SubResource("Divider")')
footer=node('Footer','HBoxContainer',body,layout_mode=2)
text('Signature',footer,'华年集出品','Muted',size_flags_horizontal=3)
text('FontSample',footer,'中文 Aa 123 · 🚀','Muted',horizontal_alignment=2)
node('RightSpace','Control',center,layout_mode=2,size_flags_horizontal=3,mouse_filter=2)
(ROOT/'sample/main.tscn').write_text('\n'.join(lines)+'\n',encoding='utf-8')
