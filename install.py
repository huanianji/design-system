#!/usr/bin/env python3
"""将自包含插件登记到当前电脑的个人插件源；不复制账号、缓存或凭据。"""
import argparse
import datetime
import hashlib
import json
import os
import shutil
import sys
import uuid
from pathlib import Path

PACKAGE = Path(__file__).resolve().parent
PLUGIN = PACKAGE/'plugins/huanianji-design'
NAME = 'huanianji-design'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name+'.pending-'+uuid.uuid4().hex)
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    os.replace(temporary, path)


def verify(root):
    receipt = read(root/'package-files.json')
    for path in root.rglob('*'):
        relative = path.relative_to(root)
        if path.is_symlink(): raise ValueError('插件包含符号链接：'+str(relative))
        if any(part in {'.godot','__pycache__'} for part in relative.parts):continue
        if path.is_file() and relative.as_posix() not in receipt['files'] and relative.as_posix()!='package-files.json':
            raise ValueError('插件包含未登记的文件：'+str(relative))
    for name, expected in receipt['files'].items():
        path = root/name
        if not path.resolve().is_relative_to(root.resolve()) or path.is_symlink() or not path.is_file():
            raise ValueError('包内文件缺失、链接或路径越界：'+name)
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError('包内文件校验失败：'+name)
    return hashlib.sha256((root/'package-files.json').read_bytes()).hexdigest()


def install(home, dry_run=False):
    home = home.expanduser().resolve()
    manifest = read(PLUGIN/'plugin.json')
    version = manifest['version']
    digest = verify(PLUGIN)
    relative = '.codex/plugins/huanianji-design/releases/'+version
    destination = home/relative
    if not destination.resolve().is_relative_to(home): raise ValueError('插件目标越出目标用户目录。')
    if destination.is_symlink(): raise ValueError('目标版本是链接，拒绝覆盖。')
    if destination.exists():
        if verify(destination) != digest: raise ValueError('相同版本已有不同内容；请核对版本，拒绝覆盖。')
    catalog_path = home/'.agents/plugins/marketplace.json'
    if catalog_path.is_symlink() or not catalog_path.resolve().is_relative_to(home):
        raise ValueError('个人插件源是链接或越出用户目录，请先核对。')
    catalog = read(catalog_path) if catalog_path.exists() else {
        'name':'huanianji-personal', 'interface':{'displayName':'华年集本地插件'}, 'plugins':[]}
    if not isinstance(catalog.get('plugins'),list) or not isinstance(catalog.get('name'),str):
        raise ValueError('现有个人插件源格式不正确，拒绝覆盖。')
    if not all(isinstance(item,dict) for item in catalog['plugins']):
        raise ValueError('个人插件源包含无效条目，拒绝覆盖。')
    original_catalog = catalog_path.read_bytes() if catalog_path.exists() else None
    entry = {'name':NAME,'source':{'source':'local','path':'./'+relative},
             'policy':{'installation':'AVAILABLE','authentication':'ON_INSTALL'},'category':'Productivity'}
    old = [x for x in catalog['plugins'] if x.get('name') == NAME]
    if len(old)>1: raise ValueError('个人插件源中存在重复的同名插件，请先核对。')
    if old:
        origin = old[0].get('source',{})
        origin_path = origin.get('path','') if isinstance(origin,dict) else origin
        if not isinstance(origin_path,str) or not origin_path.startswith('./.codex/plugins/huanianji-design/releases/'):
            raise ValueError('已有同名插件指向其他来源，拒绝替换。')
    result = {'registered':not dry_run,'dry_run':dry_run,'plugin':NAME,'version':version,
              'destination':str(destination),'catalog':str(catalog_path),'marketplace':catalog['name'],
              'host_install_required':True,
              'license':manifest['license'],'license_file':str(destination/'LICENSE'),
              'usage':'允许非商业自用；转售、再分发或商用需另行书面授权。',
              'next':'重启 Codex，在插件目录的个人／本地来源中安装「华年集设计系统」，然后开新会话使用。'}
    if dry_run: return result
    if not destination.exists():
        destination.parent.mkdir(parents=True, exist_ok=True)
        stage = destination.with_name(version+'.pending-'+uuid.uuid4().hex)
        shutil.copytree(PLUGIN,stage)
        verify(stage);stage.rename(destination)
    if old and old[0] == entry: return result
    current_catalog = catalog_path.read_bytes() if catalog_path.exists() else None
    if current_catalog != original_catalog: raise ValueError('安装期间个人插件源已被其他操作修改，请重试；未覆盖新内容。')
    catalog['plugins'] = [entry if x.get('name')==NAME else x for x in catalog['plugins']]
    if not old: catalog['plugins'].append(entry)
    if catalog_path.exists():
        backup = catalog_path.parent/'backups'/('marketplace-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:8]+'.json')
        backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(catalog_path,backup)
        result['backup'] = str(backup)
    write_json(catalog_path,catalog)
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home',type=Path,default=Path.home(),help='默认当前用户目录；隔离测试可指定专用空目录。')
    parser.add_argument('--dry-run',action='store_true')
    args=parser.parse_args()
    try:
        if sys.version_info<(3,9): raise ValueError('需要 Python 3.9 或更新版本。')
        print(json.dumps(install(args.home,args.dry_run),ensure_ascii=False,indent=2));return 0
    except (OSError,ValueError,KeyError,json.JSONDecodeError) as error:
        print(json.dumps({'error':str(error)},ensure_ascii=False),file=sys.stderr);return 1


if __name__=='__main__':
    raise SystemExit(main())
