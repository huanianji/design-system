import {captureFullViewport} from './replay-controls.cua.mjs';
export async function replayCombinedLayout({tab,cdp,fs,root}){
 const checks=[],pause=ms=>new Promise(r=>setTimeout(r,ms));
 await cdp.send('Emulation.setDeviceMetricsOverride',{width:1280,height:960,deviceScaleFactor:1,mobile:false});await tab.goto('http://127.0.0.1:50106/foundation/web/fragments.html');await cdp.send('Page.reload',{ignoreCache:true});await tab.getAXState({emit:false});await tab.playwright.locator('#creative-view').click();
 const record=async id=>{await pause(400);const observed=await tab.playwright.evaluate(()=>{
  const strip=document.getElementById('asset-strip'),title=document.querySelector('.library-heading h3'),first=document.querySelector('#category-filters button'),canvas=document.getElementById('canvas');
  return {viewport:[innerWidth,innerHeight],enlarged:document.documentElement.style.getPropertyValue('--text-scale')==='1.25',cards:[...strip.querySelectorAll('button')].map(b=>({id:b.dataset.asset,width:b.getBoundingClientRect().width,height:b.getBoundingClientRect().height,centered:getComputedStyle(b.querySelector('.asset-name')).justifyContent==='center',label_height:b.querySelector('.asset-name').getBoundingClientRect().height})),filter_gap:first.getBoundingClientRect().left-title.getBoundingClientRect().right,all_selected:first.getAttribute('aria-pressed')==='true',canvas_clip:getComputedStyle(canvas).overflow==='hidden'&&getComputedStyle(canvas).borderTopLeftRadius==='0px',fits:document.documentElement.scrollWidth<=innerWidth};
 });
 // 点击已选项以走真实滚动定位，不改变素材；标题仍属于整项选择。
 await tab.playwright.locator('[data-asset=starlight] .asset-name').click();await tab.getAXState({emit:false});
 const screenshot='evidence/combined-layout-'+id+'-web.jpg';await fs.writeFile(root+'/'+screenshot,await captureFullViewport(cdp,observed.viewport[0],observed.viewport[1]));checks.push({id,observed,screenshot});};
 await record('wide');await tab.playwright.locator('#text-scale').click();await record('wide-125');await cdp.send('Emulation.setDeviceMetricsOverride',{width:800,height:720,deviceScaleFactor:1,mobile:false});await tab.getAXState({emit:false});await record('compact-125');
 const {createHash}=await import('node:crypto'),source_files={};for(const name of ['web/fragments.css','web/fragments.js','web/replay-combined-layout.cua.mjs'])source_files[name]=createHash('sha256').update(await fs.readFile(root+'/'+name)).digest('hex');
 await fs.writeFile(root+'/evidence/combined-layout-web.json',JSON.stringify({platform:'web',source_files,checks},null,2)+'\n');return checks.map(c=>({id:c.id,cards:c.observed.cards}));
}
