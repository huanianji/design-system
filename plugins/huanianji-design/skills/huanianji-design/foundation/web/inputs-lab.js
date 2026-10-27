import {createControls} from '../components/web/controls.js';
import {inputField,otpInput} from '../components/web/inputs.js';
const $=id=>document.getElementById(id),root=new URL('../',import.meta.url);
let reduced=matchMedia('(prefers-reduced-motion: reduce)').matches,enlarged=false,disabled=false,readonly=false,failed=false,noteBusy=false,otpBusy=false;
const manifest=await (await fetch(new URL('generated/manifest.json',root),{cache:'no-store'})).json();
const bundle=await (await fetch(new URL(manifest.bundle+'/profiles.json',root))).json(),data=bundle.profiles.management.web;
await new Promise((resolve,reject)=>{$('tokens').onload=resolve;$('tokens').onerror=reject;$('tokens').href=new URL(manifest.bundle+'/tokens.css',root);});
const ui=createControls(()=>data.motion,()=>reduced);ui.bind(document.querySelectorAll('button'));
const note=inputField($('note'),{message:$('note-message')});
const otp=otpInput($('otp'),{message:$('otp-message'),getMotion:()=>data.motion,getReduced:()=>reduced});
function availability(){note.setDisabled(disabled||noteBusy);note.setReadOnly(readonly);otp.setDisabled(disabled||otpBusy);otp.setReadOnly(readonly);ui.button($('save-note')).setDisabled(disabled||readonly);ui.button($('verify')).setDisabled(disabled||readonly);ui.button($('clear')).setDisabled(disabled||readonly||otpBusy);}
function toggle(id,callback){$(id).addEventListener('click',()=>{const value=$(id).getAttribute('aria-pressed')!=='true';$(id).setAttribute('aria-pressed',String(value));callback(value);});}
toggle('disabled',value=>{disabled=value;availability();});toggle('readonly',value=>{readonly=value;availability();});toggle('fail-next',value=>failed=value);
toggle('reduce',value=>{reduced=value;ui.settle();otp.settle();});$('reduce').setAttribute('aria-pressed',String(reduced));
$('mode').addEventListener('click',()=>{const dark=document.documentElement.dataset.theme!=='dark';document.documentElement.dataset.theme=dark?'dark':'light';$('mode').firstElementChild.textContent=dark?'切换浅色':'切换深色';});
$('scale').addEventListener('click',()=>{enlarged=!enlarged;document.documentElement.style.setProperty('--text-scale',enlarged?1.25:1);$('scale').firstElementChild.textContent=enlarged?'字号 100%':'字号 125%';otp.settle();});
const wait=signal=>new Promise(resolve=>{const timer=setTimeout(resolve,650);signal.addEventListener('abort',()=>{clearTimeout(timer);resolve();},{once:true});});
$('save-note').addEventListener('click',async()=>{
  if(note.composing)return;
  if(!$('note').value.trim()){note.setStatus('error','请先写一条开播备注。');$('note').focus();return;}
  const shouldFail=failed;
  await ui.button($('save-note')).run(async signal=>{noteBusy=true;availability();note.setStatus('pending','正在本地模拟保存…');await wait(signal);if(!signal.aborted)note.setStatus(shouldFail?'error':'success',shouldFail?'本地模拟保存失败，输入已保留，可重试。':'本地模拟保存完成。');noteBusy=false;availability();});
});
$('verify').addEventListener('click',async()=>{
  if(!otp.complete){otp.setStatus('error','请补齐六位验证码。');otp.focus(otp.slots.findIndex(s=>!s));return;}
  const value=otp.value,shouldFail=failed;
  await ui.button($('verify')).run(async signal=>{otpBusy=true;availability();otp.setStatus('pending','正在本地模拟验证…');await wait(signal);if(!signal.aborted){const ok=!shouldFail&&value==='123456';otp.setStatus(ok?'success':'error',ok?'本地模拟验证通过。':shouldFail?'本地模拟请求失败，验证码已保留，可重试。':'验证码不匹配，请更正后重试。');}otpBusy=false;availability();});
});
$('clear').addEventListener('click',()=>{otp.clear();otp.focus(0);});
$('source-status').textContent='Web · '+manifest.build_id.slice(0,8);availability();
window.addEventListener('pagehide',event=>{if(!event.persisted){note.dispose();otp.dispose();ui.dispose();}});
// 只有显式开发采集地址才挂只读的逐帧观察，不进入产品交互。
if(new URLSearchParams(location.search).has('motion-probe'))await import('./observe-button-motion.js');
