#!/usr/bin/env python3
"""从共同源生成 Web 与 Godot 原生资源；只使用 Python 标准库。"""
import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parent
FONT_SIZES = ('body', 'small', 'title', 'section')
COLORS = ('page', 'paper', 'soft', 'ink', 'muted', 'line', 'control_line', 'success', 'warning', 'error')
ACCENT_COLORS = ('accent', 'wash', 'action', 'action_ink')
MOTION_NUMBERS = ('press_scale','press_seconds','release_peak','release_return','release_seconds','select_seconds','expand_seconds','bell_seconds','tab_release_peak','check_press_scale','check_press_seconds','check_release_seconds','check_draw_seconds','expand_limit','expand_ratio','collapse_lift_ratio','expand_return_ratio','detail_start_scale','detail_peak_scale','detail_return_scale','detail_distance','input_enter_ratio','input_error_distance')


def read(path):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError) as e:
        raise ValueError(f'无法读取 {path.name}：{e}') from e


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def number(value, where, positive=True):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or (positive and value <= 0):
        raise ValueError(f'无效数值：{where}')


def color(value, where):
    if not isinstance(value, str) or not re.fullmatch(r'#[0-9a-fA-F]{6}', value):
        raise ValueError(f'缺失或无效颜色：{where}')


def validate(data, root):
    if type(data['format_version']) is not int or data['format_version'] != 1:
        raise ValueError('不支持的 format_version')
    for key in FONT_SIZES + ('regular_weight', 'heading_weight'):
        number(data['font'][key], f'font.{key}')
    if not isinstance(data['font']['family'],str) or not data['font']['family'].strip():raise ValueError('字族别名不能为空')
    number(data['platforms']['web']['line_height'], 'platforms.web.line_height')
    font = (root/data['font']['file']).resolve()
    if not font.is_relative_to(root.resolve()) or not font.is_file():
        raise ValueError('字体文件不存在或越出工程目录')
    for group in ('space', 'shape', 'motion', 'optical', 'light', 'dark', 'accents', 'platforms'):
        if not isinstance(data[group], dict):
            raise ValueError(f'缺失角色组：{group}')
    for key in ('page_large','page_small','panel','frame','scene','group','tight','code_cell','code_gap'):
        number(data['space'][key], f'space.{key}')
    for key in ('panel','frame','button','small','micro','check'):
        values = data['shape'][key]
        if not isinstance(values,list) or len(values)!=4:
            raise ValueError(f'圆角须按左上、右上、右下、左下给四个值：{key}')
        for value in values:
            number(value, f'shape.{key}', positive=False)
            if value<0: raise ValueError(f'圆角不能为负数：{key}')
    for key in ('bell_x','check_x'): number(data['optical'][key], 'optical.'+key, positive=False)
    for mode in ('light','dark'):
        for key in COLORS: color(data[mode].get(key), f'{mode}.{key}')
    for accent, modes in data['accents'].items():
        for mode in ('light','dark'):
            for key in ACCENT_COLORS: color(modes[mode].get(key), f'accents.{accent}.{mode}.{key}')
    for key in MOTION_NUMBERS: number(data['motion'][key], f'motion.{key}')
    if not 0<data['motion']['input_enter_ratio']<=1: raise ValueError('输入进入距离比例必须位于0—1')
    if not 0<data['motion']['detail_start_scale']<data['motion']['detail_return_scale']<1<data['motion']['detail_peak_scale']:
        raise ValueError('详情切换须先缩入、回弹，再落稳')
    for key,count in [('press_easing',4),('release_easing',4),('release_offsets',2),('bell_degrees',4),('expand_offsets',4),('collapse_offsets',3)]:
        values=data['motion'][key]
        if not isinstance(values,list) or len(values)!=count: raise ValueError(f'无效运动数组：motion.{key}')
        for value in values: number(value, f'motion.{key}', positive=False)
        if key.endswith('offsets') and (values!=sorted(values) or len(set(values))!=len(values) or values[0]<0 or values[-1]>1):
            raise ValueError(f'运动时间节点必须递增且位于 0—1：{key}')
    for platform in ('web','godot'):
        mapping=data['platforms'][platform]
        for key in ('font_scale','space_scale'): number(mapping[key], f'platforms.{platform}.{key}')
        if not isinstance(mapping['fallbacks'],list) or not all(isinstance(v,str) for v in mapping['fallbacks']):
            raise ValueError(f'无效字体回退：{platform}')


def merge(target, overrides, trail=''):
    for key,value in overrides.items():
        path=f'{trail}.{key}' if trail else key
        if key not in target: raise ValueError(f'未知覆盖字段：{path}')
        if isinstance(value,dict) and isinstance(target[key],dict): merge(target[key],value,path)
        elif isinstance(target[key],dict): raise ValueError(f'覆盖类型不匹配：{path}')
        else: target[key]=copy.deepcopy(value)


def sources(root):
    names=['tokens/base.json','sample/content.json','sample/fragments.json','build.py','adapters/godot/generate.gd','adapters/godot/style_contract.gd','adapters/godot/create_scene.py','adapters/godot/create_fragments.py']
    names += [str(p.relative_to(root)) for p in sorted((root/'products').glob('*.json'))]
    return {name:digest(root/name) for name in names}


def resolve(root):
    base=read(root/'tokens/base.json')
    validate(base,root)
    profiles={}
    for path in sorted((root/'products').glob('*.json')):
        profile=read(path)
        if set(profile)-{'id','label','accent','overrides'}: raise ValueError(f'产品配置有未知字段：{path.name}')
        if not re.fullmatch('[a-z][a-z0-9-]*',profile['id']) or profile['id'] in profiles: raise ValueError('产品 id 无效或重复')
        data=copy.deepcopy(base)
        overrides=profile.get('overrides',{})
        if set(overrides)-{'font','space','shape','motion','optical'}: raise ValueError('产品覆盖范围仅含字体角色数值、间距、形状、运动与视觉偏移；基础背景和状态含义引用共同源')
        if set(overrides.get('font',{}))-set(FONT_SIZES+('regular_weight','heading_weight')): raise ValueError('产品不能在此入口覆盖共同字族/字库路径')
        merge(data,overrides)
        accent=profile['accent']
        if isinstance(accent,dict):
            accent_key=profile['id'];data['accents'][accent_key]=accent
        else: accent_key=accent
        if accent_key not in data['accents']: raise ValueError(f'未知强调色：{accent_key}')
        validate(data,root)
        mapped={}
        for platform in ('web','godot'):
            item=copy.deepcopy(data);mapping=data['platforms'][platform]
            for key in FONT_SIZES: item['font'][key]=int(math.floor(item['font'][key]*mapping['font_scale']+0.5))
            item['font']['file']='res://'+data['font']['file']
            item['font']['fallbacks']=mapping['fallbacks']
            if platform=='web': item['font']['line_height']=mapping['line_height']
            for key in item['space']: item['space'][key]=int(math.floor(item['space'][key]*mapping['space_scale']+0.5))
            for key in item['shape']: item['shape'][key]=[int(math.floor(v*mapping['space_scale']+0.5)) for v in item['shape'][key]]
            for key in item['optical']: item['optical'][key]*=mapping['space_scale']
            for key in ['detail_distance','input_error_distance']: item['motion'][key]*=mapping['space_scale']
            item['palette']={mode:{**item[mode],**item['accents'][accent_key][mode]} for mode in ('light','dark')}
            mapped[platform]=item
        profiles[profile['id']]={'id':profile['id'],'label':profile['label'],'accent':accent_key,**mapped}
    if 'baseline' not in profiles: raise ValueError('必须保留 baseline 配置')
    return {'format_version':1,'profiles':profiles,'content':read(root/'sample/content.json'),'fragments':validate_fragments(root)}


def validate_fragments(root):
    data=read(root/'sample/fragments.json')
    if len(data['tasks'])!=3 or not data['streamers'] or not data['assets']:raise ValueError('片段需要三项准备事项、主播和素材样本')
    ids=[p['id'] for p in data['streamers']]
    if len(ids)!=len(set(ids)):raise ValueError('主播样本 id 重复')
    for person in data['streamers']:
        if person['status'] not in data['statuses'] or len(person['checks'])!=3 or not all(type(c) is bool for c in person['checks']):raise ValueError('主播状态或准备事项无效')
    ids=[a['id'] for a in data['assets']]
    if len(ids)!=len(set(ids)):raise ValueError('素材 id 重复')
    for asset in data['assets']:
        path=(root/asset['file']).resolve()
        if not path.is_relative_to(root.resolve()) or not path.is_file() or path.suffix!='.svg':raise ValueError('演示素材缺失或越界')
    for key in ['zoom_min','zoom_max','zoom_default','opacity_default']:number(data['preview'][key],key)
    if not 0<data['preview']['zoom_min']<=data['preview']['zoom_default']<=data['preview']['zoom_max']<=140:raise ValueError('预览缩放范围无效')
    return data


def css(bundle):
    font=next(iter(bundle['profiles'].values()))['web']['font']
    font_url='../../../'+font['file'].removeprefix('res://')
    family=json.dumps(font['family'],ensure_ascii=False)
    out=['/* 自动生成：修改 tokens/base.json 或 products/*.json 后重新 build。 */',
         '@font-face{font-family:'+family+';font-weight:400 700;font-style:normal;font-display:swap;src:url('+json.dumps(font_url)+') format("opentype");}']
    for name,profile in bundle['profiles'].items():
        data=profile['web'];fields={}
        for key in FONT_SIZES: fields[f'font-{key}']=f'{data["font"][key]}px'
        fields['font-family']=family+','+','.join(json.dumps(v) if v!='sans-serif' else v for v in data['font']['fallbacks'])
        fields.update({'font-weight':str(data['font']['regular_weight']),'heading-weight':str(data['font']['heading_weight']),'line-height':str(data['font']['line_height'])})
        for key,value in data['space'].items():fields[f'space-{key.replace("_","-")}']=f'{value}px'
        for key,value in data['shape'].items():fields[f'radius-{key}']=' '.join(f'{v}px' for v in value)
        for key,value in data['optical'].items(): fields['optical-'+key.replace('_','-')]=f'{value}px'
        for key,value in data['motion'].items():
            if key.endswith('_seconds'):fields[f'motion-{key[:-8].replace("_","-")}']=f'{value*1000:g}ms'
        prefix=f':root[data-profile="{name}"]'
        out.append(prefix+'{'+''.join(f'--hj-{k}:{v};' for k,v in fields.items())+'}')
        for mode,palette in data['palette'].items():
            out.append(prefix+f'[data-theme="{mode}"]'+'{color-scheme:'+mode+';'+''.join(f'--hj-{k.replace("_","-")}:{v};' for k,v in palette.items())+'}')
    return '\n'.join(out)+'\n'


def find_engine(root, supplied):
    if supplied:
        path=Path(supplied).expanduser().resolve()
        if path.is_file(): return str(path)
        raise ValueError('--godot 指定的引擎不存在')
    found=shutil.which('godot') or shutil.which('Godot')
    if found:return found
    for parent in root.parents:
        candidate=parent/'.tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot'
        if candidate.is_file():return str(candidate)
    raise ValueError('未找到 Godot，请按目标机器实际路径传入 --godot')


def write_json(path,data):
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


def check(root):
    manifest=read(root/'generated/manifest.json')
    if sources(root)!=manifest['inputs']: raise ValueError('共同源或映射已改变，生成物过期；请重新 build')
    for name,expected in manifest['assets'].items():
        if digest(root/name)!=expected:raise ValueError(f'资源与记录不符：{name}')
    for name,expected in manifest['outputs'].items():
        if not (root/name).is_file() or digest(root/name)!=expected:raise ValueError(f'生成物缺失或被手改：{name}')
    return {'ok':True,'build_id':manifest['build_id'],'profiles':manifest['profiles']}


def build(root, engine):
    # 先校验全部配置，再产生文件；失败时 manifest 保持原来成功版本。
    bundle=resolve(root);inputs=sources(root)
    assets={str(p.relative_to(root)):digest(p) for p in (root/'assets').rglob('*') if p.is_file() and p.suffix in {'.otf','.svg','.txt','.json'}}
    build_id=hashlib.sha256(json.dumps({'inputs':inputs,'assets':assets},sort_keys=True).encode()).hexdigest()[:20]
    destination=root/'generated/builds'/build_id
    if destination.exists():
        # 相同源重新生成时保留旧产物，另建可追溯批次，不覆盖已经被界面引用的文件。
        destination=destination.with_name(build_id+'-'+uuid.uuid4().hex[:8])
    destination.mkdir(parents=True)
    write_json(destination/'profiles.json',bundle)
    (destination/'tokens.css').write_text(css(bundle),encoding='utf-8')
    subprocess.run([sys.executable,str(root/'adapters/godot/create_scene.py')],check=True,capture_output=True,text=True)
    subprocess.run([sys.executable,str(root/'adapters/godot/create_fragments.py')],check=True,capture_output=True,text=True)
    logs=[]
    for args in [
        [engine,'--headless','--editor','--path',str(root),'--import','--quit'],
        [engine,'--headless','--path',str(root),'--script','adapters/godot/generate.gd','--',f'--bundle={destination / "profiles.json"}',f'--output={destination / "themes"}']]:
        result=subprocess.run(args,text=True,capture_output=True,timeout=120)
        logs.append(result.stdout+result.stderr)
        if result.returncode or re.search(r'(^|\n)(SCRIPT ERROR|ERROR|WARNING):',logs[-1]):
            (destination/'generation.log').write_text('\n'.join(logs),encoding='utf-8')
            raise ValueError(f'Godot 生成失败，原 manifest 未变；见 {destination / "generation.log"}')
    (destination/'generation.log').write_text('\n'.join(logs),encoding='utf-8')
    expected={f'{name}_{mode}.tres' for name in bundle['profiles'] for mode in ('light','dark')}
    if {p.name for p in (destination/'themes').glob('*.tres')}!=expected:raise ValueError('Godot 输出主题不完整，未发布 manifest')
    if sources(root)!=inputs:raise ValueError('构建期间共同源发生变化，未发布 manifest，请重试')
    outputs={str(p.relative_to(root)):digest(p) for p in destination.rglob('*') if p.is_file() and p.name!='generation.log'}
    manifest={'format_version':1,'build_id':destination.name,'bundle':str(destination.relative_to(root)),'profiles':list(bundle['profiles']),'inputs':inputs,'assets':assets,'outputs':outputs,'default_profile':'baseline'}
    # 编辑器预览使用稳定引用；运行时从 manifest 读取不可变主题文件。
    editor=root/'generated/editor-theme.tres'
    shutil.copyfile(destination/'themes/baseline_light.tres',editor)
    outputs[str(editor.relative_to(root))]=digest(editor)
    subprocess.run([sys.executable,str(root/'adapters/godot/create_scene.py'),str(destination/'profiles.json')],check=True,capture_output=True,text=True)
    subprocess.run([sys.executable,str(root/'adapters/godot/create_fragments.py'),str(destination/'profiles.json')],check=True,capture_output=True,text=True)
    pending=root/('generated/manifest.pending-'+uuid.uuid4().hex+'.json');write_json(pending,manifest)
    os.replace(pending,root/'generated/manifest.json')
    return check(root)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['build','check'])
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--godot',help='本机 Godot 可执行文件，未提供时按 PATH 或本工作区工具目录查找')
    args=parser.parse_args();root=args.root.expanduser().resolve()
    try:
        result=build(root,find_engine(root,args.godot)) if args.command=='build' else check(root)
        print(json.dumps(result,ensure_ascii=False,indent=2));return 0
    except (OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError) as error:
        print(json.dumps({'ok':False,'error':str(error)},ensure_ascii=False),file=sys.stderr);return 2


if __name__=='__main__':raise SystemExit(main())
