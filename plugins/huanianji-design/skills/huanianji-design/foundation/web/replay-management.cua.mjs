// 当前管理场景的输入映射；比较逻辑复用通用脚本。
export async function replayManagementReview({tab,fs,root,phase}) {
  const {createHash}=await import('node:crypto');
  const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
  const contract=JSON.parse(await fs.readFile(root+'/sample/management-review.json','utf8'));
  const manifest=JSON.parse(await fs.readFile(root+'/generated/manifest.json','utf8'));
  const probe=await fs.readFile(root+'/web/observe-management.js','utf8');
  await tab.reload();
  await tab.getAXState({emit:false});
  const records=[];
  for(const scenario of contract.cases) {
    for(const action of scenario.actions) {
      const [kind,target,...rest]=action.split(':');
      if(kind==='key')await tab.pressKey(null,target==='Space'?'space':target==='ShiftTab'?'shift+Tab':target);
      else if(kind==='text')await tab.playwright.locator('#'+target).fill(rest.join(':'));
      else {
        const selector=target==='person'?'[data-person="'+rest[0]+'"] .roster-select':
          target==='filter'?'[data-status="'+rest[0]+'"]':target==='task'?'#task-'+rest[0]:'#'+target;
        await tab.playwright.locator(selector).click();
      }
    }
    await tab.getAXState({emit:false});
    // 本批记录落稳态；中途采样另存，不能把工具调用耗时当作动画已结束。
    if(scenario.expect.detail_visible)await tab.playwright.locator('#detail-content:not([style]), #detail-content[style*="transform: none"]').waitFor({state:'visible'});
    const height=scenario.expect.note_open?await tab.playwright.evaluate(()=>document.querySelector('#note-region>div').scrollHeight):0;
    await tab.playwright.locator('#note-region[style*="height: '+height+'px"]').waitFor({state:'attached'});
    const snapshot=await tab.playwright.evaluate('('+probe+')()');
    if(!snapshot.stamp.includes(manifest.build_id.slice(0,8)))throw Error('版本未对齐');
    const screenshot='evidence/management-'+phase+'-web-'+scenario.id+'.jpg';
    await fs.writeFile(root+'/'+screenshot,await tab.getScreenshot({emit:false}));
    records.push({id:scenario.id,actions:scenario.actions,context:{build_id:manifest.build_id,fixture:manifest.inputs['sample/fragments.json'],viewport:snapshot.viewport,text_scale:snapshot.text_scale,theme:snapshot.theme,reduced:snapshot.reduced},observed:snapshot.observed,screenshot});
  }
  await fs.writeFile(root+'/evidence/management-'+phase+'-web.json',JSON.stringify({platform:'web',evidence_root:'..',input_driver:'CUA click/fill/pressKey',implementation_sha256:hash(await fs.readFile(root+'/web/fragments.js')),adapter_sha256:hash(await fs.readFile(root+'/web/replay-management.cua.mjs')),probe_sha256:hash(probe),cases:records},null,2)+'\n');
  return {phase,cases:records.length};
}
