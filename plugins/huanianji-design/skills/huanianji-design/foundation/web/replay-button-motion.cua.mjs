import {captureFullViewport} from './replay-controls.cua.mjs';

export async function replayButtonMotion({tab,cdp,fs,root,phase}){
  const records=[];
  for(const kind of ['note','code'])for(const scenario of ['invalid','busy','keyboard','enter','reduced']){
    await cdp.send('Page.reload',{ignoreCache:true});await tab.getAXState({emit:false});
    if(scenario!=='invalid'){
      if(kind==='note'){await tab.playwright.locator('#note').click();await tab.paste(null,'真实按压过程');}
      else {await tab.playwright.locator('#otp input').nth(0).click();await tab.paste(null,'123456');}
    }
    if(scenario==='reduced')await tab.playwright.locator('#reduce').click();
    const id=kind==='note'?'save-note':'verify';
    if(scenario==='keyboard'||scenario==='enter'){
      await tab.pressKey(null,'Tab');
      await tab.pressKey(null,scenario==='enter'?'Return':'space',{durationMs:160});
    }else{
      const point=await tab.playwright.evaluate(id=>{const r=document.getElementById(id).getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};},id);
      await cdp.send('Input.dispatchMouseEvent',{type:'mouseMoved',...point});
      await cdp.send('Input.dispatchMouseEvent',{type:'mousePressed',...point,button:'left',clickCount:1});
      await new Promise(resolve=>setTimeout(resolve,160));
      await cdp.send('Input.dispatchMouseEvent',{type:'mouseReleased',...point,button:'left',clickCount:1});
    }
    await tab.playwright.locator('#button-motion-traces').waitFor({state:'attached'});
    let raw=[];const started=Date.now();
    while(Date.now()-started<2200){raw=await tab.playwright.evaluate(()=>JSON.parse(document.getElementById('button-motion-traces').textContent));if(raw.some(r=>r.id===id))break;await new Promise(resolve=>setTimeout(resolve,80));}
    const record=raw.find(r=>r.id===id);if(!record)throw new Error('未取得真实按钮过程：'+kind+'-'+scenario);
    const release=record.events.find(e=>scenario==='enter'?e.type==='click':e.type==='pointerup'||e.type==='keyup');
    record.release_ms=release?.ms??0;record.button_id=record.id;record.id=kind+'-'+scenario;
    record.screenshot='evidence/action-motion-'+phase+'-'+record.id+'-web.jpg';await fs.writeFile(root+'/'+record.screenshot,await captureFullViewport(cdp));records.push(record);
  }
  const {createHash}=await import('node:crypto'),sources={};for(const name of ['components/web/controls.js','components/web/controls.css','web/inputs.html','web/inputs-lab.js','web/observe-button-motion.js','web/replay-button-motion.cua.mjs'])sources[name]=createHash('sha256').update(await fs.readFile(root+'/'+name)).digest('hex');
  const tree=await cdp.send('Page.getResourceTree',{}),runtime_sources={};
  for(const item of [tree.frameTree.frame,...tree.frameTree.resources]){
    const url=new URL(item.url);if(!url.pathname.startsWith('/foundation/')||! /\.(js|css|html)$/.test(url.pathname))continue;
    const name=url.pathname.slice('/foundation/'.length),resource=await cdp.send('Page.getResourceContent',{frameId:tree.frameTree.frame.id,url:item.url});
    runtime_sources[name]=createHash('sha256').update(resource.content).digest('hex');
    sources[name]=createHash('sha256').update(await fs.readFile(root+'/'+name)).digest('hex');
    if(runtime_sources[name]!==sources[name])throw new Error('页面仍加载旧资源：'+name);
  }
  const source_stamp=await tab.playwright.locator('#source-status').innerText();
  const result={source_stamp,runtime_sources,platform:'web',source_files:sources,input_driver:'CUA current-tab CDP native pointer/Space 160ms hold; requestAnimationFrame sample',records};await fs.writeFile(root+'/evidence/action-motion-'+phase+'-web.json',JSON.stringify(result,null,2)+'\n');return {records:records.length};
}
