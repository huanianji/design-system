import {createControls,scaleOf,bezier,sample} from "../components/web/controls.js";
const $ = id => document.getElementById(id);
const root = new URL('../', import.meta.url);
const ui = document.documentElement;
const state = {profile:'baseline',mode:'light',selected:0,expanded:false,checked:true,text:null,parameter:68,clicks:0,enlarged:false,reduced:matchMedia('(prefers-reduced-motion: reduce)').matches};
let manifest, bundle, data, expandTarget=0;
const motionLayer=createControls(()=>data?.motion,()=>state.reduced);
const {motions,stop,frames,animate}=motionLayer;
const surfaces = [...document.querySelectorAll('button .surface')];
const hash = async bytes => [...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(x=>x.toString(16).padStart(2,'0')).join('');
async function bytes(name) { const response=await fetch(new URL(name,root),{cache:'no-store'}); if(!response.ok)throw Error(`文件不可用：${name}`); return response.arrayBuffer(); }
async function json(name) { return JSON.parse(new TextDecoder().decode(await bytes(name))); }
function fail(error) { $('design-error').textContent=error.message+'。请让 AI 重新运行 build.py build，再点击“重新读取设计”。'; $('design-error').hidden=false; $('sample').hidden=true; $('source-status').textContent='设计资源未就绪'; }
async function verify(record, all=false) {
  const expected={...record.inputs,...record.outputs,...(all?record.assets:{})};
  await Promise.all(Object.entries(expected).map(async([name,value])=>{if(await hash(await bytes(name))!==value)throw Error(`共同源或生成物已变化：${name}`);}));
}
motionLayer.bind(surfaces.map(s=>s.parentElement));
const tabs=motionLayer.tabs({buttons:[0,1,2].map(i=>$('tab'+i)),indicator:document.querySelector('.plate'),onChange:index=>state.selected=index});
const disclosure=motionLayer.disclosure({trigger:$('expand'),region:$('reveal'),content:document.querySelector('.settings'),arrow:document.querySelector('.chevron'),onChange:value=>{state.expanded=value;document.querySelector('#expand .caption').textContent=value?'收起设置':'展开设置';$('parameter').disabled=!value;}});
function plate(animated=true,preserve=false){tabs.layout(animated,preserve);}
function select(index){tabs.select(index);}
function expanded(value,animated=true){disclosure.setOpen(value,animated);expandTarget=disclosure.target;}
function bell() {
  if(!data||state.reduced)return;const element=document.querySelector('.optical svg'),m=data.motion;
  const matrix=new DOMMatrixReadOnly(getComputedStyle(element).transform);const from=Math.atan2(matrix.b,matrix.a)*180/Math.PI;
  frames('bell',m.bell_seconds,p=>element.style.transform=`rotate(${sample(bezier(p,m.press_easing),[from,...m.bell_degrees],[0,.25,.5,.75,1])}deg)`,()=>element.style.transform='none');
}
$('bell').addEventListener('pointerenter',bell);$('bell').addEventListener('focus',()=>{if(!$('bell').matches(':hover'))bell();});$('bell').addEventListener('click',bell);
$('check').addEventListener('change',()=>{
  state.checked=$('check').checked;const element=document.querySelector('.check-art'),line=element.querySelector('path'),m=data.motion;
  const from=scaleOf(element);stop('check');stop('check-line');
  if(state.reduced){element.style.transform='none';line.style.strokeDashoffset=state.checked?'0':'1';return;}
  frames('check',m.check_press_seconds+m.check_release_seconds,p=>{
    const seconds=p*(m.check_press_seconds+m.check_release_seconds);
    let value;
    if(seconds<m.check_press_seconds)value=from+(m.check_press_scale-from)*(1-(1-seconds/m.check_press_seconds)**3);
    else {const q=(seconds-m.check_press_seconds)/m.check_release_seconds;const back=1+2.70158*(q-1)**3+1.70158*(q-1)**2;value=m.check_press_scale+(1-m.check_press_scale)*back;}
    element.style.transform=`scale(${value})`;
  },()=>element.style.transform='none');
  const progress=parseFloat(getComputedStyle(line).strokeDashoffset),target=state.checked?0:1;
  frames('check-line',m.check_draw_seconds,p=>line.style.strokeDashoffset=String(progress+(target-progress)*(1-(1-p)**3)));
});
function reduced(value) {
  state.reduced=value;$('reduce').setAttribute('aria-pressed',String(value));
  for(const key of [...motions.keys()])stop(key);
  for(const surface of surfaces)surface.style.transform='none';
  document.querySelector('.optical svg').style.transform='none';document.querySelector('.check-art').style.transform='none';document.querySelector('.check-art path').style.strokeDashoffset=state.checked?'0':'1';
  motionLayer.settle();plate(false);expanded(state.expanded,false);
}
$('reduce').addEventListener('click',()=>reduced(!state.reduced));
$('action').addEventListener('click',()=>{$('action-note').textContent=`已体验 ${++state.clicks} 次 · 本地演示`;});
$('topic').addEventListener('input',()=>state.text=$('topic').value);
$('parameter').addEventListener('input',()=>{state.parameter=+$('parameter').value;$('parameter-value').value=state.parameter+'%';});
function apply() {
  data=bundle.profiles[state.profile].web;
  ui.dataset.profile=state.profile;ui.dataset.theme=state.mode;ui.style.setProperty('--text-scale',state.enlarged?1.25:1);
  $('mode').querySelector('.surface').textContent=state.mode==='light'?'切换深色':'切换浅色';
  $('profile').querySelector('.surface').textContent='主题：'+bundle.profiles[state.profile].label;
  $('text-scale').querySelector('.surface').textContent=state.enlarged?'字号 100%':'字号 125%';
  $('reduce').setAttribute('aria-pressed',String(state.reduced));
}
async function change(key,value) { try{await verify(manifest);state[key]=value;apply();requestAnimationFrame(()=>{plate(false,true);if(state.expanded&&expandTarget!==document.querySelector('.settings').scrollHeight)expanded(true);});}catch(error){fail(error);} }
$('mode').addEventListener('click',()=>change('mode',state.mode==='light'?'dark':'light'));
$('profile').addEventListener('click',()=>{const names=['baseline','jade-demo'];change('profile',names[(names.indexOf(state.profile)+1)%names.length]);});
$('text-scale').addEventListener('click',()=>change('enlarged',!state.enlarged));
async function load() {
  try {
    const next=await json('generated/manifest.json');await verify(next,true);
    const nextBundle=await json(next.bundle+'/profiles.json');
    const link=$('tokens'),href=new URL(next.bundle+'/tokens.css',root).href;
    if(link.href!==href) {
      const ready=new Promise((resolve,reject)=>{link.onload=resolve;link.onerror=()=>reject(Error('共同样式无法加载'));});
      link.href=href;await ready;
    }
    manifest=next;bundle=nextBundle;if(!bundle.profiles[state.profile])state.profile='baseline';apply();
    for(const element of document.querySelectorAll('[data-copy]'))element.textContent=bundle.content[element.dataset.copy];
    if(state.text===null){$('topic').value=bundle.content.TopicInput;state.text=$('topic').value;}
    if(state.clicks)$('action-note').textContent=`已体验 ${state.clicks} 次 · 本地演示`;
    $('design-error').hidden=true;$('sample').hidden=false;
    $('source-status').textContent='Web · '+manifest.build_id.slice(0,8);
    await document.fonts.load(`${data.font.regular_weight} ${data.font.body}px "${data.font.family}"`,bundle.content.Title);
    document.querySelector('.check-art path').style.strokeDashoffset=state.checked?'0':'1';
    motionLayer.settle();plate(false);expanded(state.expanded,false);
  }catch(error){fail(error);}
}
$('reload').addEventListener('click',load);
window.addEventListener('resize',()=>{if(data){plate(false);if(state.expanded)expanded(true,false);}});
window.foundation={getState:()=>({...state,build_id:manifest?.build_id,font_body:data?.font.body,stale:!$('design-error').hidden})};
window.addEventListener('pagehide',event=>{if(!event.persisted)motionLayer.dispose();});
await load();
