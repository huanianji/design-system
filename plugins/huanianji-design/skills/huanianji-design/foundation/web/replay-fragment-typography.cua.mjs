// 检查同一片段的实际角色和文字净空；不通过页面内部状态函数代替操作。
export async function replayFragmentTypography({tab,viewport,fs,root,phase}) {
  const {createHash}=await import('node:crypto');
  const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
  const manifest=JSON.parse(await fs.readFile(root+'/generated/manifest.json','utf8'));
  const bundle=JSON.parse(await fs.readFile(root+'/'+manifest.bundle+'/profiles.json','utf8'));
  const cases=[],checks=[];
  const check=(name,passed,detail)=>checks.push({name,passed,detail});
  const scenarios=[
    ['management-light',1280,960,'management','light',1,[]],
    ['management-dark',1280,960,'management','dark',1,['mode']],
    ['management-compact-125',800,720,'management','dark',1.25,['text-scale']],
    ['management-reset-100',800,720,'management','dark',1,['text-scale']],
    ['creative-light',1280,960,'creative','light',1,['creative-view','mode']],
    ['creative-compact-dark-125',800,720,'creative','dark',1.25,['mode','text-scale']],
    ['creative-compact-light-125',800,720,'creative','light',1.25,['mode']],
    ['creative-reset-100',1280,960,'creative','light',1,['text-scale']],
    ['management-narrow-125',390,844,'management','light',1.25,['management-view','text-scale']]
  ];
  await tab.reload();await tab.getAXState({emit:false});
  for(const [id,width,height,view,mode,factor,actions] of scenarios) {
    await viewport.set({width,height});
    for(const action of actions)await tab.playwright.locator('#'+action).click();
    await tab.getAXState({emit:false});
    const raw=await tab.playwright.evaluate(()=>{
      const visible=el=>el.getBoundingClientRect().height>0;
      const groups=[
        ['title','#management-title,#creative-title'],
        ['section','.workspace h2'],['strong_body','.workspace h3'],
        ['small','.filter-group button .surface,.content-label,th'],
        ['body','.slot,#roster-body .status-label,.ready-cell,.asset-name']
      ];
      const metrics=groups.flatMap(([role,selector])=>[...document.querySelectorAll(selector)].filter(visible).map(el=>{const s=getComputedStyle(el);return {role,text:el.textContent.trim(),size:+s.fontSize.replace("px",""),weight:+s.fontWeight};}));
      const cells=[...document.querySelectorAll('.slot,.ready-cell,#roster-body td:has(.status-label)')].filter(visible).map(el=>{
        return {text:el.textContent.trim(),scroll_width:el.scrollWidth,client_width:el.clientWidth};
      });
      return {view:document.getElementById('management').hidden?'creative':'management',mode:document.documentElement.dataset.theme,factor:+document.documentElement.style.getPropertyValue('--text-scale')||1,viewport:[innerWidth,innerHeight],metrics,cells,horizontal_overflow:document.documentElement.scrollWidth>document.documentElement.clientWidth+1};
    });
    const font=bundle.profiles[view].web.font;
    check(id+'/conditions',raw.view===view&&raw.mode===mode&&raw.factor===factor&&raw.viewport[0]===width,raw);
    check(id+'/horizontal',!raw.horizontal_overflow,raw.viewport);
    for(const item of raw.metrics) {
      const role=item.role==='strong_body'?'body':item.role;
      const weight=['title','section','strong_body'].includes(item.role)?font.heading_weight:font.regular_weight;
      check(id+'/role/'+item.text,Math.abs(item.size-font[role]*factor)<.01&&item.weight===weight,item);
    }
    for(const cell of raw.cells)check(id+'/complete/'+cell.text,cell.scroll_width<=cell.client_width+1,cell);
    const screenshot='evidence/typography-'+phase+'-fragments-web-'+id+'.jpg';
    await fs.writeFile(root+'/'+screenshot,await tab.getScreenshot({emit:false}));
    cases.push({id,actions,context:{build_id:manifest.build_id,viewport:raw.viewport,theme:mode,text_scale:factor},observed:raw,screenshot});
  }
  const result={platform:'web',input_driver:'CUA click and viewport',implementation_sha256:hash(await fs.readFile(root+'/web/fragments.css')),adapter_sha256:hash(await fs.readFile(root+'/web/replay-fragment-typography.cua.mjs')),cases,checks,failed:checks.filter(x=>!x.passed)};
  await fs.writeFile(root+'/evidence/typography-'+phase+'-fragments-web.json',JSON.stringify(result,null,2)+'\n');
  return {cases:cases.length,checks:checks.length,failed:result.failed.map(x=>x.name)};
}
