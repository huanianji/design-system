import {captureFullViewport} from './replay-controls.cua.mjs';
export async function replayCombinedExtras({tab,cdp,fs,root}){
 const checks=[],click=id=>tab.playwright.locator('#'+id).click(),key=k=>tab.pressKey(null,k),pause=ms=>new Promise(r=>setTimeout(r,ms));
 const text=async value=>{await click('note');await key('super+a');if(value)await tab.paste(null,value);else await key('Backspace');};
 const record=async(id,actions)=>{await pause(550);const observed=await tab.playwright.evaluate(()=>{
  const state=JSON.parse(document.getElementById('combined-state').textContent),local=state.people[state.selected],focus=document.activeElement;
  return {selected:state.selected,note:local.note,saved:local.savedNote,status:local.noteStatus,message:document.getElementById('note-message').textContent,mic:local.mic,open:state.noteOpen,busy:document.getElementById('save-note').getAttribute('aria-busy')==='true',focus:focus.id,focus_visible:getComputedStyle(focus).outlineStyle!=='none'||(focus.id==='note'&&getComputedStyle(focus).boxShadow!=='none'),fits:document.documentElement.scrollWidth<=innerWidth};
 });const screenshot='evidence/combined-'+id+'-web.jpg';await fs.writeFile(root+'/'+screenshot,await captureFullViewport(cdp));checks.push({id,actions,observed,screenshot});};
 await tab.goto('http://127.0.0.1:50106/foundation/web/fragments.html?combined-probe=checks');await tab.getAXState({emit:false});await tab.playwright.locator('#combined-state').waitFor({state:'attached'});
 await click('note-toggle');await pause(500);await text('');await click('save-note');await record('empty-save',['input:empty-note','pointer:save']);
 await key('Escape');await record('escape-focus',['key:Escape']);
 await click('microphone');await key('Tab');await key('shift+Tab');await key('space');await record('keyboard-mic-focus',['pointer:microphone','key:Tab','key:ShiftTab','key:Space']);
 await click('note-toggle');await pause(500);await text('跨界面草稿');await click('save-note');await click('creative-view');await pause(750);await click('management-view');await record('view-cancel',['input:draft','pointer:save','pointer:creative','pointer:management']);
 await text('重新读取时保留草稿');await click('save-note');await click('reload');await pause(750);await record('reload-cancel',['input:draft','pointer:save','pointer:reload']);
 await text('较长备注包含中文、English和1234567890。'.repeat(8));await record('long-note-wrap',['input:long-note']);
 const {createHash}=await import('node:crypto'),source_files={};for(const p of ['web/fragments.js','components/web/controls.js','components/web/dynamic-icon.js','web/replay-combined-extras.cua.mjs'])source_files[p]=createHash('sha256').update(await fs.readFile(root+'/'+p)).digest('hex');
 await fs.writeFile(root+'/evidence/combined-extras-web.json',JSON.stringify({platform:'web',source_files,checks},null,2)+'\n');return checks.map(c=>({id:c.id,focus:c.observed.focus,status:c.observed.status}));
}
