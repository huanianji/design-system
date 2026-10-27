import {captureFullViewport} from './replay-controls.cua.mjs';
export async function replayCombined({tab,cdp,fs,root,part='all'}){
 const checks=[],traces=[],url='http://127.0.0.1:50106/foundation/web/fragments.html';
 const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
 const click=id=>tab.playwright.locator('#'+id).click(),key=k=>tab.pressKey(null,k);
 const person=id=>tab.playwright.locator(`[data-person="${id}"] .roster-select`).click();
 const asset=(id,title=false)=>tab.playwright.locator(`[data-asset="${id}"] ${title?'.asset-name':'img'}`).click();
 const text=async(id,value)=>{await click(id);await key('super+a');await tab.paste(null,value);if(!value)await key('Backspace');};
 const quick=async(selector,hold=0)=>{
  let point=await tab.playwright.evaluate(selector=>{const r=document.querySelector(selector).getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2,bottom:r.bottom,viewport:innerHeight};},selector);
  if(point.bottom>point.viewport-16){await cdp.send('Input.dispatchMouseEvent',{type:'mouseWheel',x:point.x,y:point.viewport-50,deltaX:0,deltaY:point.bottom-point.viewport+100});await pause(100);point=await tab.playwright.evaluate(selector=>{const r=document.querySelector(selector).getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};},selector);}
  await cdp.send('Input.dispatchMouseEvent',{type:'mouseMoved',x:point.x,y:point.y});await cdp.send('Input.dispatchMouseEvent',{type:'mousePressed',x:point.x,y:point.y,button:'left',clickCount:1});if(hold)await pause(hold);await cdp.send('Input.dispatchMouseEvent',{type:'mouseReleased',x:point.x,y:point.y,button:'left',clickCount:1});
 };
 const observe=()=>tab.playwright.evaluate(()=>{
  const $=id=>document.getElementById(id),state=JSON.parse(document.getElementById('combined-state').textContent),local=state.people[state.selected]||{},values=state.previews[state.asset]||{},focus=document.activeElement;
  return {view:state.view,mode:state.mode,enlarged:state.enlarged,reduced:state.reduced,selected:state.selected,visible:state.visible,checks:local.checks||[],note:local.note||'',saved:local.savedNote||'',status:local.noteStatus||'',message:$('note-message').textContent,busy:$('save-note').getAttribute('aria-busy')==='true',note_disabled:$('note').disabled,mic:local.mic??true,mic_label:$('microphone-label').textContent,open:state.noteOpen,asset:state.asset,category:state.category,zoom:values.zoom||0,opacity:values.opacity||0,reset_disabled:$('reset-preview').disabled,focus:focus.id||focus.closest('[data-asset]')?.dataset.asset||'',focus_visible:getComputedStyle(focus).outlineStyle!=='none',note_role:+getComputedStyle($('note')).fontSize.replace('px',''),save_focusable:$('save-note').tabIndex>=0&&!$('save-note').disabled,viewport:[innerWidth,innerHeight],fits:document.documentElement.scrollWidth<=innerWidth&&$('workspace').getBoundingClientRect().right<=innerWidth&&document.querySelector('.inspector').getBoundingClientRect().right<=innerWidth};
 });
 const record=async(id,actions)=>{await pause(id==='note-pending'?50:550);const observed=await observe(),screenshot='evidence/combined-'+id+'-web.jpg';await fs.writeFile(root+'/'+screenshot,await captureFullViewport(cdp,observed.viewport[0],observed.viewport[1]));checks.push({id,actions,observed,screenshot});};
 if(part!=='traces'){
  await tab.goto(url+'?combined-probe=checks');await tab.getAXState({emit:false});await tab.playwright.locator('#combined-state').waitFor({state:'attached'});
  await record('management-initial',[]);
  await click('microphone');await record('mic-off',['pointer:microphone']);
  await tab.playwright.locator('label.checkrow').nth(2).click();await record('task-toggle',['pointer:task2']);
  await click('note-toggle');await pause(500);await text('note','今晚先聊新歌。');await record('note-draft',['pointer:note-toggle','input:note']);
  await click('simulate-failure');await click('save-note');await record('note-pending',['pointer:simulate-failure','pointer:save-note']);
  await pause(300);await record('note-failure',['wait:result']);
  await click('simulate-failure');await click('save-note');await pause(750);await record('note-success',['pointer:allow-success','pointer:save-note']);
  await person('tangli');await record('switch-person',['pointer:tangli']);await person('linxi');await record('return-person',['pointer:linxi']);
  await text('note','尚未提交的草稿');await click('save-note');await person('tangli');await pause(750);await record('cancel-owner',['input:draft','pointer:save-note','pointer:tangli']);await person('linxi');await record('cancel-preserves-draft',['pointer:linxi']);
  await text('query','不存在的主播');await record('empty-results',['input:query-no-match']);await text('query','');await record('recover-results',['clear:query']);
  await click('mode');await record('dark-preserve',['pointer:mode']);await click('text-scale');await record('enlarged-preserve',['pointer:text-scale']);
  await click('creative-view');await record('creative-initial',['pointer:creative']);await asset('warmframe');await record('asset-image',['pointer:warmframe-image']);await asset('window',true);await record('asset-title',['pointer:window-title']);
  await click('zoom');await key('End');for(let i=0;i<20;i++)await key('Left');await click('opacity');await key('End');for(let i=0;i<35;i++)await key('Left');await record('preview-adjust',['key:zoom-120','key:opacity-65']);
  await asset('starlight');await asset('window');await record('preview-return',['pointer:starlight','pointer:window']);await click('reset-preview');await record('preview-reset',['pointer:reset-preview']);await tab.playwright.locator('[data-category="frame"]').click();await record('creative-category',['pointer:category-frame']);await click('mode');await record('creative-light',['pointer:mode']);
  await cdp.send('Emulation.setDeviceMetricsOverride',{width:800,height:720,deviceScaleFactor:1,mobile:false});await tab.getAXState({emit:false});await record('compact-125',['window:800x720']);
  await cdp.send('Emulation.setDeviceMetricsOverride',{width:1280,height:960,deviceScaleFactor:1,mobile:false});
 }
 if(part!=='checks')for(const id of ['bell-once','bell-repeat','bell-reduced','mic-off','mic-reverse','mic-keyboard','mic-theme','mic-reduce-mid','mic-hide','arrow-open','arrow-reverse','arrow-reduced','asset-switch','asset-reduced','save-busy','save-failure']){
  await tab.goto(url+'?combined-probe='+id);await tab.getAXState({emit:false});await tab.playwright.locator('#combined-probe-ready').waitFor({state:'attached'});
  if(id.startsWith('asset'))await click('creative-view');
  else if(id.startsWith('save')){await click('note-toggle');await pause(500);if(id==='save-failure')await click('simulate-failure');}
  if(id.endsWith('reduced'))await click('reduce');
  const target=id.startsWith('bell')?'attention-action':id.startsWith('mic')?'microphone':id.startsWith('arrow')?'note-toggle':'save-note';
  if(id==='mic-keyboard'){await click('microphone');await key('Tab');await key('shift+Tab');await pause(550);await key('space');}
  else if(id.startsWith('asset'))await quick('[data-asset=warmframe] img');
  else {
   await quick('#'+target,id.startsWith('save')?160:0);
  }
  if(['bell-repeat','mic-reverse','arrow-reverse'].includes(id)){await pause(120);await quick('#'+target);}
  else if(id==='mic-theme'){await pause(120);await quick('#mode');}
  else if(id==='mic-reduce-mid'){await pause(120);await quick('#reduce');}
  else if(id==='mic-hide'){await pause(120);await quick('#creative-view');await quick('#management-view');}
  await tab.playwright.locator('#combined-trace').waitFor({state:'attached'});
  const trace=await tab.playwright.evaluate(()=>JSON.parse(document.getElementById('combined-trace').textContent));traces.push(trace);
 }
 const {createHash}=await import('node:crypto'),sources={};
 const tree=await cdp.send('Page.getResourceTree',{}),runtime_sources={};
 for(const item of [tree.frameTree.frame,...tree.frameTree.resources]){
  const path=new URL(item.url).pathname;if(!path.startsWith('/foundation/')||! /\.(html|js|css)$/.test(path))continue;
  const name=path.slice('/foundation/'.length),resource=await cdp.send('Page.getResourceContent',{frameId:tree.frameTree.frame.id,url:item.url});
  runtime_sources[name]=createHash('sha256').update(resource.content).digest('hex');sources[name]=createHash('sha256').update(await fs.readFile(root+'/'+name)).digest('hex');
  if(runtime_sources[name]!==sources[name])throw Error('页面加载的代码过期：'+name);
 }
 sources['web/replay-combined.cua.mjs']=createHash('sha256').update(await fs.readFile(root+'/web/replay-combined.cua.mjs')).digest('hex');
 const result={platform:'web',source_stamp:await tab.playwright.locator('#source-status').innerText(),source_files:sources,runtime_sources,checks,traces,input_driver:'CUA pointer / native keys / paste; DOM read-only; rAF actual rendered properties'};
 const name='evidence/combined-web'+(part==='all'?'':'-'+part)+'.json';await fs.writeFile(root+'/'+name,JSON.stringify(result,null,2)+'\n');return {checks:checks.length,traces:traces.length};
}
