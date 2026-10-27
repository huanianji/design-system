export async function captureFullViewport(cdp,width=1280,height=960) {
  const result=await cdp.send('Page.captureScreenshot',{format:'jpeg',quality:90,captureBeyondViewport:true,clip:{x:0,y:0,width,height,scale:1}});
  return Buffer.from(result.data,'base64');
}

export async function replayControls({tab,fs,root,capture=()=>tab.getScreenshot({emit:false}),captureDriver='CUA tab screenshot',reload=()=>tab.reload(),cdp=null}) {
  const checks=[];const {createHash}=await import('node:crypto');
  const click=id=>tab.playwright.locator('#'+id).click();
  const key=(id,value)=>tab.playwright.locator('#'+id).press(value);
  const observe=()=>tab.playwright.evaluate(()=>{
    const $=id=>document.getElementById(id),surface=$('lab-action').querySelector('.surface');
    return {focus_owner_visible:getComputedStyle(document.activeElement).outlineStyle!=='none',managed_focus:$('lab-action').hasAttribute('data-hj-focus-input'),logical_focus:document.activeElement===$('lab-action'),browser_focus_visible:$('lab-action').matches(':focus-visible'),focus_visible:document.activeElement===$('lab-action')&&getComputedStyle($('lab-action')).outlineStyle!=='none',settings_are_state_buttons:['fail-next','disable-tab','disable-all'].every(id=>$(id).tagName==='BUTTON'&&$(id).hasAttribute('aria-pressed'))&&document.querySelectorAll('input[type=checkbox]').length===0,settings:['fail-next','disable-tab','disable-all'].map(id=>$(id).getAttribute('aria-pressed')==='true'),viewport:[innerWidth,innerHeight],source_stamp:$('source-status').textContent,attempts:+$('mount').dataset.attempts||0,mounts:+$('mount').dataset.mounts,busy:$('lab-action').getAttribute('aria-busy')==='true',disabled:$('lab-action').disabled,result:$('result').textContent,tab:([0,1,2].find(i=>$('lab-tab'+i).getAttribute('aria-selected')==='true')??-1),open:$('lab-toggle').getAttribute('aria-expanded')==='true',height:+getComputedStyle($('lab-region')).height.replace('px',''),target:$('lab-region').firstElementChild.scrollHeight,draft:$('local-draft').value,focus:document.activeElement.id,mode:document.documentElement.dataset.theme,reduced:$('reduce').getAttribute('aria-pressed')==='true',action_scale:getComputedStyle(surface).transform,keyboard_stops:[0,1,2].map(i=>$('lab-tab'+i).tabIndex===0&&!$('lab-tab'+i).disabled),tab_stops:[0,1,2].map(i=>$('lab-tab'+i).tabIndex),hidden_panels:[0,1,2].map(i=>$('panel'+i).hidden),inert:$('lab-region').hasAttribute('inert')};
  });
  const record=async(id,passed,observed,actions)=>{const screenshot='evidence/controls-'+id+'-web.jpg';await fs.writeFile(root+'/'+screenshot,await capture());checks.push({id,passed,observed,actions,screenshot});};
  await reload();await tab.getAXState({emit:false});
  await click('lab-action');await tab.playwright.locator('#lab-action').click({force:true});
  let s=await observe();await record('busy-blocks-repeat',s.busy&&s.disabled&&s.attempts===1&&s.result==='处理中…',s,['pointer:action','pointer:action-during-busy']);
  await tab.playwright.getByText('本地操作完成',{exact:true}).waitFor({state:'visible'});
  s=await observe();await record('action-completes',!s.busy&&!s.disabled&&s.result==='本地操作完成'&&!s.focus_visible,s,['wait:local-result']);
  await tab.playwright.locator('#disabled-action').click({force:true});s=await observe();await record('disabled-blocks-activation',s.result==='本地操作完成'&&!s.busy,s,['pointer:disabled-action']);
  await click('fail-next');await click('lab-action');await tab.playwright.getByText('本地模拟失败，可重试',{exact:true}).waitFor({state:'visible'});
  s=await observe();await record('failure-unlocks-retry',!s.busy&&!s.disabled&&s.result==='本地模拟失败，可重试'&&!s.focus_visible,s,['pointer:fail-next','pointer:action','wait:local-result']);
  await click('fail-next');await key('lab-action','Space');await tab.playwright.getByText('本地操作完成',{exact:true}).waitFor({state:'visible'});
  s=await observe();await record('keyboard-retry',s.attempts===3&&s.result==='本地操作完成'&&s.focus_visible,s,['condition:action-focus','key:Space','wait:local-result']);
  await click('lab-tab1');await key('lab-tab1','Home');await click('disable-tab');await click('lab-tab0');await key('lab-tab0','ArrowRight');
  s=await observe();await record('tabs-skip-disabled',s.tab===2&&s.focus==='lab-tab2'&&s.hidden_panels.join(',')==='true,true,false',s,['pointer:tab1','key:Home','pointer:disable-tab','pointer:tab0','key:ArrowRight']);
  await key('lab-tab2','Home');await key('lab-tab0','Tab');s=await observe();await record('tabs-single-stop',s.focus==='lab-toggle'&&s.tab_stops.join(',')==='0,-1,-1',s,['key:Home','key:Tab']);
  await key('lab-toggle','Space');await tab.playwright.locator('#lab-region:not([style*="height: 0px"])').waitFor({state:'attached'});const opening=await observe();await click('lab-toggle');s=await observe();await record('disclosure-reverses',!s.open&&opening.height>0&&s.height>0,s,['key:Space','pointer:toggle']);
  await click('mode');await tab.getAXState({emit:false});await tab.playwright.locator('#lab-region[style*="height: 0px"]').waitFor({state:'attached'});
  s=await observe();await record('theme-during-collapse',s.mode==='dark'&&!s.open&&s.height===0,s,['pointer:mode','wait:settled']);
  await click('lab-toggle');await click('reduce');s=await observe();await record('reduce-settles-disclosure',s.reduced&&s.open&&s.height===s.target,s,['pointer:toggle','pointer:reduce']);
  await click('local-draft');await key('local-draft','Escape');s=await observe();await record('collapse-restores-focus',s.focus==='lab-toggle'&&s.draft==='保留这份草稿'&&s.inert,s,['pointer:local-draft','key:Escape']);
  await click('lab-action');await click('remount');await new Promise(resolve=>setTimeout(resolve,750));await tab.getAXState({emit:false});s=await observe();await record('unmount-cancels-old-result',!s.busy&&s.mounts===2&&s.result==='已重建，旧操作已取消',s,['pointer:action','pointer:remount','wait:old-result-window']);
  await click('lab-action');await tab.playwright.getByText('本地操作完成',{exact:true}).waitFor({state:'visible'});s=await observe();await record('remount-no-duplicate-handlers',!s.busy&&s.attempts===5&&s.result==='本地操作完成',s,['pointer:action','wait:local-result']);
  await click('disable-all');s=await observe();await record('tabs-all-disabled',s.tab===-1&&s.hidden_panels.every(Boolean),s,['pointer:disable-all']);
  await click('disable-all');s=await observe();await record('tabs-reenable',s.tab===0&&!s.hidden_panels[0]&&s.keyboard_stops.join(',')==='true,false,false',s,['pointer:enable-tabs']);
  await click('reduce');const points=await tab.playwright.evaluate(()=>[...document.querySelectorAll('[data-owner]')].map(b=>{const r=b.getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2];}));const start=Date.now();
  if(cdp){for(const [x,y] of points){await cdp.send('Input.dispatchMouseEvent',{type:'mouseMoved',x,y});await cdp.send('Input.dispatchMouseEvent',{type:'mousePressed',x,y,button:'left',clickCount:1});await cdp.send('Input.dispatchMouseEvent',{type:'mouseReleased',x,y,button:'left',clickCount:1});}}
  else {await tab.playwright.locator('[data-owner="first"]').click();await tab.playwright.locator('[data-owner="second"]').click();}
  const parallel=await tab.playwright.evaluate(()=>({first:getComputedStyle(document.querySelector('[data-owner="first"] .surface')).transform,second:getComputedStyle(document.querySelector('[data-owner="second"] .surface')).transform}));
  s=await observe();s.parallel_press=parallel.first!=='none'&&parallel.second!=='none';s.press_samples=parallel;s.sample_window_ms=Date.now()-start;await record('independent-button-feedback',s.parallel_press,s,['pointer:restore-motion','pointer:button-one','pointer:button-two']);
  const sources={};for(const name of ['components/web/controls.js','components/web/controls.css','web/controls-lab.js','web/app.css'])sources[name]=createHash('sha256').update(await fs.readFile(root+'/'+name)).digest('hex');
  const result={source_files:sources,adapter_sha256:createHash('sha256').update(await fs.readFile(root+'/web/replay-controls.cua.mjs')).digest('hex'),capture_driver:captureDriver,platform:'web',input_driver:'CUA pointer/keyboard and read-only DOM observation; sequential CDP mouse events for feedback sampling when supplied',checks,failed:checks.filter(c=>!c.passed)};
  await fs.writeFile(root+'/evidence/controls-web.json',JSON.stringify(result,null,2)+'\n');return {checks:checks.length,failed:result.failed};
}
