#!/usr/bin/env python3
"""插件运行探测和独立预览准备；只依赖 Python 标准库。"""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def godot_path(explicit=None):
    if explicit:
        candidate = Path(explicit).expanduser()
        if candidate.is_dir() and candidate.suffix == '.app':
            candidate = candidate / 'Contents/MacOS/Godot'
        if not candidate.is_file():
            raise ValueError('指定的 Godot 可执行文件不存在。')
        return str(candidate.resolve())
    for name in ('godot', 'godot4', 'Godot'):
        candidate = shutil.which(name)
        if candidate:
            return candidate
    candidate = Path('/Applications/Godot.app/Contents/MacOS/Godot')
    return str(candidate) if candidate.is_file() else None


def doctor(explicit=None):
    engine = godot_path(explicit)
    result = {'python': sys.version.split()[0], 'system_root': str(ROOT),
              'rules': (ROOT/'references/common/华年集共同设计规则.md').is_file(),
              'font': (ROOT/'foundation/assets/fonts/ResourceHanRoundedCN-VF.otf').is_file(),
              'web': 'ready', 'godot': {'state': 'missing', 'hint': '安装 Godot 4.7.2，或通过 --godot 指定该电脑上的可执行文件。'}}
    if engine:
        version = subprocess.run([engine, '--version'], capture_output=True, text=True, timeout=30, check=True)
        result['godot'] = {'state': 'found', 'path': engine, 'version': version.stdout.strip()}
    result['ok'] = result['rules'] and result['font'] and sys.version_info >= (3, 9)
    return result


def copy_tree(source, target):
    shutil.copytree(source, target, ignore=shutil.ignore_patterns('.godot', '__pycache__', '*.pyc', 'evidence'))


def prepare(case, target):
    target = target.expanduser().absolute()
    if target.exists() or target.is_symlink():
        raise ValueError('预览目标必须是尚不存在的新目录，避免覆盖项目内容。')
    target.parent.mkdir(parents=True, exist_ok=True)
    if case == 'foundation':
        copy_tree(ROOT/'foundation', target)
    else:
        copy_tree(ROOT/'examples/lumina-workspace', target)
        (target/'components').mkdir(exist_ok=True)
        copy_tree(ROOT/'foundation/components/godot', target/'components/godot')
        (target/'fonts').mkdir(exist_ok=True)
        for name in ('ResourceHanRoundedCN-VF.otf', 'OFL.txt', 'SOURCE.json'):
            shutil.copy2(ROOT/'foundation/assets/fonts'/name, target/'fonts'/name)
    (target/'evidence').mkdir(exist_ok=True)
    return {'prepared': str(target), 'case': case, 'source': str(ROOT), 'formal_product_modified': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    probe = sub.add_parser('doctor'); probe.add_argument('--godot')
    probe.add_argument('--require-godot', action='store_true')
    ready = sub.add_parser('prepare'); ready.add_argument('--case', choices=['foundation', 'lumina'], required=True)
    ready.add_argument('--target', type=Path, required=True)
    sample = sub.add_parser('sample'); sample.add_argument('--case', choices=['foundation', 'lumina'], default='foundation')
    sample.add_argument('--godot'); sample.add_argument('--scene', choices=['main','fragments','controls','inputs','typography'], default='fragments')
    sample.add_argument('--target', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'doctor':
            result = doctor(args.godot)
            if args.require_godot and result['godot']['state'] == 'missing': result['ok'] = False
        elif args.command == 'prepare': result = prepare(args.case, args.target)
        else:
            engine = godot_path(args.godot)
            if not engine: raise ValueError('尚未发现 Godot；请用 --godot 指定目标电脑上的引擎。')
            target = args.target or Path(tempfile.mkdtemp(prefix='huanianji-preview-'))/'project'
            result = prepare(args.case, target)
            subprocess.run([engine,'--headless','--editor','--path',result['prepared'],'--import','--quit'], check=True)
            command = [engine,'--path',result['prepared']]
            if args.case == 'foundation': command.append('res://sample/'+args.scene+'.tscn')
            process = subprocess.Popen(command)
            result['pid'] = process.pid
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result.get('ok', True) else 1
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(json.dumps({'error': str(error)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
