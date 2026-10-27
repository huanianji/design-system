// 当前素材案例的 CUA 输入适配器；通用差异判断在 scripts/compare_interactions.py。
export async function replayMediaReview({tab,fs,root,phase}) {
  const {createHash}=await import('node:crypto');
  const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
  const contract=JSON.parse(await fs.readFile(root+'/sample/media-review.json','utf8'));
  const manifest=JSON.parse(await fs.readFile(root+'/generated/manifest.json','utf8'));
  const probe=await fs.readFile(root+'/web/observe-media.js','utf8');
  const records=[];
  let mode=null;
  for(const scenario of contract.cases) {
    const targetMode=scenario.id.split('/')[0];
    if(mode!==targetMode) {
      await tab.reload();
      await tab.getAXState({emit:false});
      await tab.playwright.locator('#creative-view').click();
      await tab.getAXState({emit:false});
      if(targetMode==='dark') {
        await tab.playwright.locator('#mode').click();
        await tab.getAXState({emit:false});
      }
      mode=targetMode;
    }
    for(const action of scenario.actions) {
      const part=action.split(':');
      if(part[0]==='key')await tab.pressKey(null,part[1]==='Space'?'space':part[1]);
      else if(part[1]==='canvas')await tab.playwright.locator('#canvas').click();
      else await tab.playwright.locator('[data-asset="'+part[1]+'"] '+(part[2]==='image'?'img':'.asset-name')).click();
      await tab.getAXState({emit:false});
    }
    const snapshot=await tab.playwright.evaluate('('+probe+')()');
    if(!snapshot.stamp.includes(manifest.build_id.slice(0,8)))throw Error('版本未对齐');
    const screenshot='evidence/media-'+phase+'-web-'+scenario.id.replace('/','-')+'.jpg';
    await fs.writeFile(root+'/'+screenshot,await tab.getScreenshot({emit:false}));
    records.push({id:scenario.id,actions:scenario.actions,context:{build_id:manifest.build_id,fixture:manifest.inputs['sample/fragments.json'],viewport:snapshot.viewport,text_scale:snapshot.text_scale,theme:snapshot.theme,reduced:snapshot.reduced},observed:snapshot.observed,screenshot});
  }
  const record={platform:'web',evidence_root:'..',input_driver:'CUA locator.click and pressKey',implementation_sha256:hash(await fs.readFile(root+'/web/fragments.js')),adapter_sha256:hash(await fs.readFile(root+'/web/replay-media.cua.mjs')),probe_sha256:hash(probe),cases:records};
  await fs.writeFile(root+'/evidence/media-'+phase+'-web.json',JSON.stringify(record,null,2)+'\n');
  return {phase,cases:records.length};
}
