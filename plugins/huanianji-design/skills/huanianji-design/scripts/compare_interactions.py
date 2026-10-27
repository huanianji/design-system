#!/usr/bin/env python3
"""比较任意界面的行为约定与两端实测快照；不控制 UI，也不代替画面审阅。"""
import argparse
import json
from pathlib import Path


def compare(contract, observations):
    findings = []
    expected_cases = {case['id']: case for case in contract['cases']}
    if len(expected_cases) != len(contract['cases']):
        raise ValueError('行为约定的检查点 id 重复')
    platforms = list(observations)
    if len(platforms) < 2:
        raise ValueError('配对检查至少需要两个平台的实际记录')
    indexed = {platform: {case['id']: case for case in record['cases']} for platform, record in observations.items()}
    for platform, record in observations.items():
        if len(indexed[platform]) != len(record['cases']):
            raise ValueError('平台检查点 id 重复：'+platform)
    for case_id, case in expected_cases.items():
        present = {}
        for platform in platforms:
            measured = indexed[platform].get(case_id)
            if measured is None:
                findings.append(dict(case=case_id, platform=platform, kind='unobserved', field=None, reason='缺少实际操作记录'))
                continue
            present[platform] = measured
            for field, expected in {**contract.get('context', {}), **case.get('context', {})}.items():
                if field not in measured.get('context', {}) or measured['context'][field] != expected:
                    findings.append(dict(case=case_id, platform=platform, kind='setup', field=field, expected=expected, actual=measured.get('context', {}).get(field)))
            if measured.get('actions') != case['actions']:
                findings.append(dict(case=case_id, platform=platform, kind='input-path', field='actions', expected=case['actions'], actual=measured.get('actions')))
            for field, expected in {**contract.get('expect', {}), **case.get('expect', {})}.items():
                actual = measured.get('observed', {}).get(field)
                if field not in measured.get('observed', {}) or actual != expected:
                    findings.append(dict(case=case_id, platform=platform, kind='contract', field=field, layer=contract.get('layers', {}).get(field, '待定位'), expected=expected, actual=actual, evidence=measured.get('screenshot')))
        if len(present) != len(platforms):
            continue
        reference = present[platforms[0]]
        for platform in platforms[1:]:
            measured = present[platform]
            different_context = [key for key in contract['context_keys'] if key not in reference.get('context', {}) or key not in measured.get('context', {}) or reference['context'][key] != measured['context'][key]]
            if different_context:
                findings.append(dict(case=case_id, platform=platform, kind='not-comparable', field=different_context, reason='版本、内容、窗口或输入条件未对齐'))
                continue
            for field in contract.get('equal_fields', []):
                left = reference.get('observed', {}).get(field)
                right = measured.get('observed', {}).get(field)
                if field not in reference.get('observed', {}) or field not in measured.get('observed', {}) or left != right:
                    findings.append(dict(case=case_id, platform=platform, kind='platform-difference', field=field, layer=contract.get('layers', {}).get(field, '待定位'), reference=left, actual=right, evidence=[reference.get('screenshot'), measured.get('screenshot')]))
    return dict(scope=contract['scope'], platforms=platforms, cases=len(expected_cases), findings=findings, passed=not findings,
                boundary='只判断已声明且已采集的事实；截图、运动画面和未建模细节仍需实际审阅。')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--contract', type=Path, required=True)
    parser.add_argument('--observations', type=Path, nargs='+', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    contract = json.loads(args.contract.read_text())
    records = [json.loads(path.read_text()) for path in args.observations]
    if len({r['platform'] for r in records}) != len(records):
        raise ValueError('平台记录重复')
    result = compare(contract, {r['platform']: r for r in records})
    for path, record in zip(args.observations, records):
        base = (path.parent/record.get('evidence_root', '.')).resolve()
        for case in record['cases']:
            screenshot = case.get('screenshot')
            if not screenshot or not (base/screenshot).is_file():
                result['findings'].append(dict(case=case['id'], platform=record['platform'], kind='missing-evidence', field='screenshot', actual=screenshot))
    result['passed'] = not result['findings']
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(dict(passed=result['passed'], cases=result['cases'], findings=len(result['findings'])), ensure_ascii=False))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
