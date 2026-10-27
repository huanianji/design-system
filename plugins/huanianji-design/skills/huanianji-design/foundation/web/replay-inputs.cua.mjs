import {captureFullViewport} from './replay-controls.cua.mjs';

export async function replayInputs({tab,cdp,fs,root}){
  const checks=[],noteText='今晚聊新歌\n保留中文和空格';
  const click=id=>tab.playwright.locator('#'+id).click(),field=i=>tab.playwright.locator('#otp input').nth(i),key=k=>tab.pressKey(null,k);
  const paste=async(i,text)=>{await field(i).click();await tab.paste(null,text);};
  const observe=()=>tab.playwright.evaluate(()=>{
    const note=document.getElementById('note'),otp=document.getElementById('otp'),items=[...otp.querySelectorAll('input')],active=document.activeElement;
    return {code_gap:+getComputedStyle(otp).gap.replace('px',''),cell_height:items[0].getBoundingClientRect().height,viewport:[innerWidth,innerHeight],note:note.value,note_status:note.dataset.inputStatus,note_message:document.getElementById('note-message').textContent,note_editable:!note.disabled&&!note.readOnly,note_busy:document.getElementById('save-note').getAttribute('aria-busy')==='true',slots:items.map(i=>i.value),filled:items.map(i=>!!i.value),otp_status:otp.dataset.inputStatus,otp_message:document.getElementById('otp-message').textContent,otp_busy:document.getElementById('verify').getAttribute('aria-busy')==='true',focused_digit:items.indexOf(active),focus:active.id,mode:document.documentElement.dataset.theme,enlarged:document.documentElement.style.getPropertyValue('--text-scale')==='1.25',reduced:document.getElementById('reduce').getAttribute('aria-pressed')==='true',note_bound:note.dataset.hjInput==='field',digit_transforms:[...otp.querySelectorAll('.hj-otp-digit')].map(e=>getComputedStyle(e).transform),digit_opacities:[...otp.querySelectorAll('.hj-otp-digit')].map(e=>getComputedStyle(e).opacity),otp_transform:getComputedStyle(otp).transform};
  });
  const record=async(id,test,actions)=>{const observed=await observe(),screenshot='evidence/inputs-'+id+'-web.jpg';await fs.writeFile(root+'/'+screenshot,await captureFullViewport(cdp));checks.push({id,passed:test(observed),observed,actions,screenshot});};
  await cdp.send('Page.reload',{ignoreCache:true});await tab.getAXState({emit:false});
  await click('save-note');await record('note-required',s=>s.note_status==='error'&&s.focus==='note',['pointer:save-empty-note']);
  await tab.paste(null,noteText);await key('Tab');await record('note-edit-and-tab',s=>s.note===noteText&&s.note_status==='idle'&&s.focus==='save-note',['input:chinese-multiline','key:Tab']);
  await click('fail-next');await click('save-note');await tab.playwright.getByText('本地模拟保存失败，输入已保留，可重试。',{exact:true}).waitFor({state:'visible'});
  await record('note-failure-preserves',s=>s.note_status==='error'&&s.note===noteText&&s.note_editable,['pointer:fail-next','pointer:save-note','wait:result']);
  await click('fail-next');await click('save-note');await tab.playwright.getByText('本地模拟保存完成。',{exact:true}).waitFor({state:'visible'});await record('note-retry',s=>s.note_status==='success',['pointer:allow-success','pointer:save-note','wait:result']);
  await click('readonly');await tab.playwright.locator('#note').click();await key('Backspace');await record('readonly-preserves',s=>!s.note_editable&&s.note===noteText&&s.focus==='note',['pointer:readonly','pointer:note','key:Backspace']);
  await click('readonly');await click('disabled');await tab.playwright.locator('#note').click({force:true});await record('disabled-skips-input',s=>!s.note_editable&&s.focus!=='note',['pointer:editable','pointer:disabled','pointer:note']);
  await click('disabled');await click('clear');for(const c of '123')await key(c);await record('otp-sequential',s=>s.focused_digit===3&&s.filled.slice(0,3).every(Boolean)&&!s.filled[3],['pointer:enable','pointer:clear','input:123']);
  await click('clear');await paste(0,'０１２３４５');await record('otp-paste-leading-zero',s=>s.slots.slice(1).join('')==='12345'&&s.focused_digit===5,['pointer:clear','paste:fullwidth-012345']);
  await paste(2,'98');await record('otp-partial-paste',s=>s.slots.slice(1).join('')==='19845'&&s.focused_digit===4,['pointer:digit2','paste:98']);
  await key('Backspace');await key('Backspace');await record('otp-backspace',s=>s.slots.slice(1).join(',')==='1,9,8,,5'&&s.focused_digit===3,['key:Backspace','key:Backspace']);
  for(const k of ['Home','End','ArrowLeft','Delete'])await key(k);await record('otp-navigation-delete',s=>s.focused_digit===4&&!s.filled[4],['key:Home','key:End','key:ArrowLeft','key:Delete']);
  await click('verify');await record('otp-incomplete',s=>s.otp_status==='error'&&s.focused_digit===4,['pointer:verify-incomplete']);
  await click('clear');await paste(0,'654321');await click('verify');await tab.playwright.getByText('验证码不匹配，请更正后重试。',{exact:true}).waitFor({state:'visible'});await record('otp-mismatch',s=>s.otp_status==='error'&&s.slots.slice(1).join('')==='54321',['pointer:clear','paste:654321','pointer:verify','wait:result']);
  await paste(0,'123456');await click('fail-next');await click('verify');await tab.playwright.getByText('本地模拟请求失败，验证码已保留，可重试。',{exact:true}).waitFor({state:'visible'});await record('otp-request-failure',s=>s.otp_status==='error'&&s.slots.slice(1).join('')==='23456',['paste:123456','pointer:fail-next','pointer:verify','wait:result']);
  await click('fail-next');await click('verify');await tab.playwright.getByText('本地模拟验证通过。',{exact:true}).waitFor({state:'visible'});await record('otp-retry-success',s=>s.otp_status==='success'&&!s.otp_busy,['pointer:allow-success','pointer:verify','wait:result']);
  await click('mode');await click('scale');await record('theme-scale-preserve',s=>s.mode==='dark'&&s.enlarged&&s.slots.slice(1).join('')==='23456'&&s.note===noteText,['pointer:mode','pointer:scale']);
  await click('clear');await paste(0,'12');await click('reduce');await record('reduce-settles',s=>s.reduced&&s.slots[1]==='2'&&s.digit_transforms.every(t=>t==='none')&&s.digit_opacities.every(a=>a==='1')&&s.otp_transform==='none',['pointer:clear','paste:12','pointer:reduce']);
  await cdp.send('Emulation.setDeviceMetricsOverride',{width:800,height:720,deviceScaleFactor:1,mobile:false});await tab.getAXState({emit:false});
  const fits=await tab.playwright.evaluate(()=>document.querySelector('.card').getBoundingClientRect().right<=780&&document.getElementById('otp').getBoundingClientRect().right<=780&&document.documentElement.scrollWidth<=innerWidth);await record('compact-125',s=>fits,['window:800x720']);
  const {createHash}=await import('node:crypto'),sources={};for(const name of ['components/web/inputs.js','components/web/inputs.css','web/inputs-lab.js','web/inputs.html','web/replay-inputs.cua.mjs'])sources[name]=createHash('sha256').update(await fs.readFile(root+'/'+name)).digest('hex');
  const tree=await cdp.send('Page.getResourceTree',{}),runtime_sources={};
  for(const name of ['components/web/inputs.js','components/web/inputs.css','web/inputs-lab.js']){
    const resource=await cdp.send('Page.getResourceContent',{frameId:tree.frameTree.frame.id,url:'http://127.0.0.1:50106/foundation/'+name});
    runtime_sources[name]=createHash('sha256').update(resource.content).digest('hex');
    if(runtime_sources[name]!==sources[name])throw new Error('当前预览仍使用旧源码：'+name);
  }
  const result={runtime_sources,platform:'web',source_files:sources,input_driver:'CUA pointer, keys and clipboard paste; DOM is read-only',observation_boundary:'浏览器自动脱敏首位验证码值；保留脱敏原始观察，以其余位、焦点、实际结果及截图核对，不推回隐藏值。',checks,failed:checks.filter(c=>!c.passed)};
  await fs.writeFile(root+'/evidence/inputs-web.json',JSON.stringify(result,null,2)+'\n');return {checks:checks.length,failed:result.failed};
}
