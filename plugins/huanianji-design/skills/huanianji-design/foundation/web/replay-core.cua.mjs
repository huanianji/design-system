export async function replayCore({tab,viewport,fs,root}) {
  const checks=[],samples=[];
  const read=()=>tab.playwright.evaluate(()=>{
    const $=id=>document.getElementById(id),surface=$('action').querySelector('.surface'),m=getComputedStyle(surface).transform,r=$('action').getBoundingClientRect();
    return {scale:m==='none'?1:+m.split('(')[1].split(',')[0],rect:[r.x,r.y,r.width,r.height],note:$('action-note').textContent,selected:[0,1,2].find(i=>$('tab'+i).getAttribute('aria-selected')==='true'),focus:document.activeElement.id,expanded:$('expand').getAttribute('aria-expanded')==='true',height:+getComputedStyle($('reveal')).height.replace('px',''),target:document.querySelector('.settings').scrollHeight,inert:$('reveal').hasAttribute('inert'),mode:document.documentElement.dataset.theme,text:$('topic').value,body_size:+getComputedStyle(document.body).fontSize.replace('px',''),right:document.querySelector('.card').getBoundingClientRect().right,viewport:[innerWidth,innerHeight],overflow:document.documentElement.scrollWidth>document.documentElement.clientWidth};
  });
  const point=id=>tab.playwright.evaluate(id=>{const r=document.getElementById(id).getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2];},id);
  const check=(name,passed,detail)=>checks.push({name,passed,detail});
  await viewport.set({width:1280,height:960});
  try {
    await tab.reload();await tab.playwright.getByText('Web · 2aef6572',{exact:true}).waitFor({state:'visible'});await tab.getAXState({emit:false});
    await fs.writeFile(root+'/evidence/controls-core-light-web.jpg',await tab.getScreenshot({emit:false}));
    const before=await read(),position=await point('action');await tab.click(position,{durationMs:160});
    const start=Date.now();while(Date.now()-start<520){samples.push({ms:Date.now()-start,...await read()});}
    const peak=Math.max(...samples.map(s=>s.scale)),low=Math.min(...samples.map(s=>s.scale));
    check('daily-feedback-and-stable-hit',low<.97&&peak>1.04&&samples.every(s=>s.rect.every((x,i)=>Math.abs(x-before.rect[i])<.1)),{low,peak,samples:samples.length});
    check('pointer-activates-once',(await read()).note==='已体验 1 次 · 本地演示',await read());
    await tab.click(await point('tab2'));await tab.click(await point('tab0'));await tab.playwright.locator('#tab0').press('ArrowRight');
    let s=await read();check('rapid-tabs-and-keyboard',s.selected===1&&s.focus==='tab1',s);
    await tab.playwright.locator('#topic').fill('共同实现保留草稿');
    await tab.click(await point('expand'));await tab.getAXState({emit:false});const opened=await read();
    await tab.click(await point('expand'));await tab.click(await point('mode'));await tab.getAXState({emit:false});
    await tab.playwright.locator('#reveal[style*="height: 0px"]').waitFor({state:'attached'});
    s=await read();check('reverse-and-theme-preserve-target',opened.height>0&&!s.expanded&&s.height===0&&s.inert&&s.mode==='dark'&&s.text==='共同实现保留草稿',s);
    await tab.click(await point('expand'));await tab.click(await point('reduce'));await tab.getAXState({emit:false});
    s=await read();check('reduce-settles-current-target',s.expanded&&Math.abs(s.height-s.target)<1,s);
    await fs.writeFile(root+'/evidence/controls-core-dark-web.jpg',await tab.getScreenshot({emit:false}));
    await viewport.set({width:800,height:720});await tab.playwright.locator('#text-scale').click();await tab.getAXState({emit:false});
    s=await read();check('compact-125-keeps-content',s.body_size===21.25&&s.right<=800&&!s.overflow&&s.text==='共同实现保留草稿',s);
    await fs.writeFile(root+'/evidence/controls-core-compact-web.jpg',await tab.getScreenshot({emit:false}));
    const result={input_driver:'CUA pointer with held click / keyboard / DOM observation',checks,samples,failed:checks.filter(c=>!c.passed)};
    await fs.writeFile(root+'/evidence/controls-core-web.json',JSON.stringify(result,null,2)+'\n');return {checks:checks.length,failed:result.failed};
  } finally {await viewport.reset();}
}
