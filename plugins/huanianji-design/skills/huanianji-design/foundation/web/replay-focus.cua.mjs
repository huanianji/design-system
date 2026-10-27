import {captureFullViewport} from './replay-controls.cua.mjs';

export async function replayFocus({tab,cdp,fs,root}) {
  const checks=[];
  const observe=()=>tab.playwright.evaluate(()=>{
    const action=document.getElementById('lab-action'),owner=document.activeElement;
    return {viewport:[innerWidth,innerHeight],logical_focus:owner===action,browser_focus_visible:action.matches(':focus-visible'),focus_visible:owner===action&&getComputedStyle(action).outlineStyle!=='none',focus:owner.id||owner.dataset.owner||owner.tagName,focus_owner_visible:getComputedStyle(owner).outlineStyle!=='none',action_selected:action.getAttribute('aria-pressed')==='true',busy:action.getAttribute('aria-busy')==='true',result:document.getElementById('result').textContent};
  });
  const record=async(id,test,actions)=>{
    const observed=await observe(),screenshot='evidence/focus-after-'+id+'-web.jpg';
    await fs.writeFile(root+'/'+screenshot,await captureFullViewport(cdp));
    checks.push({id,passed:test(observed),observed,actions,screenshot});
  };
  const action=tab.playwright.locator('#lab-action');
  const wait=()=>tab.playwright.getByText('本地模拟失败，可重试',{exact:true}).waitFor({state:'visible'});
  await cdp.send('Page.reload',{ignoreCache:true});await tab.getAXState({emit:false});
  await tab.playwright.locator('#fail-next').click();await action.click();await wait();
  await record('pointer-failure',s=>s.logical_focus&&!s.focus_visible&&!s.action_selected,['pointer:fail-next','pointer:action','wait:result']);
  const peer=tab.playwright.locator('[data-owner="first"]');await peer.click();
  await record('pointer-peer',s=>s.focus==='first'&&!s.focus_owner_visible,['pointer:button-one']);
  await peer.press('Shift+Tab');await action.press('Space');await wait();
  await record('keyboard-failure',s=>s.logical_focus&&s.focus_visible,['key:Shift+Tab','key:Space','wait:result']);
  await action.press('Space');await tab.playwright.getByRole('heading',{name:'公共交互检查台',exact:true}).click();await wait();
  await record('keyboard-then-pointer',s=>s.logical_focus&&!s.focus_visible,['key:Space','pointer:heading-during-busy','wait:result']);
  await action.click();await tab.pressKey(null,'Tab');await wait();
  await record('pending-navigation',s=>!s.logical_focus&&s.focus!==''&&s.focus_owner_visible,['pointer:action','key:Tab-during-busy','wait:result']);
  const {createHash}=await import('node:crypto');const sources={};
  for(const name of ['components/web/controls.js','components/web/controls.css','web/controls-lab.js','web/replay-focus.cua.mjs'])sources[name]=createHash('sha256').update(await fs.readFile(root+'/'+name)).digest('hex');
  const tree=await cdp.send('Page.getResourceTree',{}),runtime_sources={};
  for(const name of ['components/web/controls.js','components/web/controls.css']){
    const resource=await cdp.send('Page.getResourceContent',{frameId:tree.frameTree.frame.id,url:'http://127.0.0.1:50106/foundation/'+name});
    runtime_sources[name]=createHash('sha256').update(resource.content).digest('hex');
    if(runtime_sources[name]!==sources[name])throw new Error('当前页面仍在使用旧源码：'+name);
  }
  const result={runtime_sources,platform:'web',source_files:sources,input_driver:'CUA pointer/keyboard; read-only DOM focus observation',checks,failed:checks.filter(c=>!c.passed)};
  await fs.writeFile(root+'/evidence/focus-after-web.json',JSON.stringify(result,null,2)+'\n');
  return {checks:checks.length,failed:result.failed};
}
