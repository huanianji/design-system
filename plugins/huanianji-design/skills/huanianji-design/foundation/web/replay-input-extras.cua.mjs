import {captureFullViewport} from './replay-controls.cua.mjs';

export async function inputExtras({tab,cdp,fs,root,composition=false}){
  const checks=[];
  const record=async(id,passed,observed,actions)=>{const screenshot='evidence/input-extra-'+id+'-web.jpg';await fs.writeFile(root+'/'+screenshot,await captureFullViewport(cdp));checks.push({id,passed,observed,actions,screenshot});};
  await cdp.send('Emulation.setDeviceMetricsOverride',{width:1280,height:960,deviceScaleFactor:1,mobile:false});
  await cdp.send('Page.reload',{ignoreCache:true});await tab.getAXState({emit:false});
  let s;
  if(composition){
  await tab.playwright.locator('#save-note').click();
  await cdp.send('Input.imeSetComposition',{text:'今晚',selectionStart:2,selectionEnd:2});
  s=await tab.playwright.evaluate(()=>({status:document.getElementById('note').dataset.inputStatus,message:document.getElementById('note-message').textContent,busy:document.getElementById('save-note').getAttribute('aria-busy')}));
  await record('note-composition',s.status==='error'&&s.busy==='false',s,['pointer:save-empty-note','ime:preedit']);
  await cdp.send('Input.insertText',{text:'今晚新歌'});await tab.getAXState({emit:false});
  s=await tab.playwright.evaluate(()=>({status:document.getElementById('note').dataset.inputStatus,value:document.getElementById('note').value}));
  await record('note-composition-commit',s.status==='idle'&&s.value==='今晚新歌',s,['ime:commit']);
  await tab.playwright.locator('#otp input').nth(0).click();
  await cdp.send('Input.imeSetComposition',{text:'９',selectionStart:1,selectionEnd:1});
  s=await tab.playwright.evaluate(()=>({composing:document.querySelector('.hj-otp-slot').classList.contains('composing'),overlay:getComputedStyle(document.querySelector('.hj-otp-digit')).visibility}));
  await record('otp-composition',s.composing&&s.overlay==='hidden',s,['pointer:digit0','ime:preedit-fullwidth']);
  await cdp.send('Input.insertText',{text:'９'});await tab.getAXState({emit:false});
  s=await tab.playwright.evaluate(()=>({composing:document.querySelector('.hj-otp-slot').classList.contains('composing'),focus:document.activeElement.dataset.index}));
  await record('otp-composition-commit',!s.composing&&s.focus==='1',s,['ime:commit-fullwidth']);
  }else {await tab.playwright.locator('#note').click();await tab.paste(null,'今晚新歌');}
  await tab.playwright.locator('#save-note').click();await tab.playwright.locator('#mode').click();await tab.playwright.getByText('本地模拟保存完成。',{exact:true}).waitFor({state:'visible'});
  s=await tab.playwright.evaluate(()=>({mode:document.documentElement.dataset.theme,value:document.getElementById('note').value,message:document.getElementById('note-message').textContent}));
  await record('pending-theme',s.mode==='dark'&&s.value==='今晚新歌',s,['pointer:save-note','pointer:mode-during-busy','wait:result']);
  await tab.playwright.locator('#otp input').nth(0).click();await tab.paste(null,'123456');await tab.playwright.locator('#verify').click();await cdp.send('Page.reload',{ignoreCache:true});await tab.getAXState({emit:false});
  s=await tab.playwright.evaluate(()=>({message:document.getElementById('otp-message').textContent,busy:document.getElementById('verify').getAttribute('aria-busy')}));
  await record('reload-cancels',s.message===''&&s.busy==='false',s,['paste:123456','pointer:verify','reload:during-busy']);
  const result={platform:'web',not_run:composition?[]:[{scope:'native browser composition injection',reason:'IAB CDP does not support Input.imeSetComposition; no synthetic DOM events substituted'}],input_driver:'CUA pointer, paste, theme and reload; composition only when supported',checks,failed:checks.filter(c=>!c.passed)};
  await fs.writeFile(root+'/evidence/input-extras-web.json',JSON.stringify(result,null,2)+'\n');return {checks:checks.length,failed:result.failed};
}

export async function inputConsumption({tab,cdp,fs,root}){
  const checks=[];
  const record=async(id,test,actions)=>{const observed=await tab.playwright.evaluate(()=>({note:document.getElementById('note').value,bound:document.getElementById('note').dataset.hjInput==='field',open:document.getElementById('note-toggle').getAttribute('aria-expanded')==='true',mode:document.documentElement.dataset.theme,focus:document.activeElement.id,font:getComputedStyle(document.getElementById('note')).fontSize})),screenshot='evidence/input-consumption-'+id+'-web.jpg';await fs.writeFile(root+'/'+screenshot,await captureFullViewport(cdp));checks.push({id,passed:test(observed),observed,actions,screenshot});};
  await tab.goto('http://127.0.0.1:50106/foundation/web/fragments.html');await cdp.send('Page.reload',{ignoreCache:true});await tab.getAXState({emit:false});
  await tab.playwright.locator('#note-toggle').click();await tab.playwright.locator('#note').click();await tab.playwright.locator('#note').press('Meta+a');await tab.paste(null,'复用输入：今晚先聊新歌');
  await record('note-actual-consumer',s=>s.bound&&s.note==='复用输入：今晚先聊新歌'&&s.font==='14px',['pointer:expand-note','input:chinese-note']);
  await tab.playwright.locator('#note').press('Escape');await record('note-escape-focus',s=>!s.open&&s.focus==='note-toggle',['key:Escape']);
  await tab.playwright.locator('#mode').click();await tab.playwright.locator('#note-toggle').click();await record('note-theme-preserves',s=>s.mode==='dark'&&s.note==='复用输入：今晚先聊新歌',['pointer:mode','pointer:expand-note']);
  await tab.playwright.locator('#note').click();await tab.playwright.locator('#note').press('Tab');await record('note-tab-exits',s=>s.focus!=='note'&&!s.note.includes('\t'),['pointer:note','key:Tab']);
  const result={platform:'web',checks,failed:checks.filter(c=>!c.passed)};await fs.writeFile(root+'/evidence/input-consumption-web.json',JSON.stringify(result,null,2)+'\n');return {checks:checks.length,failed:result.failed};
}
