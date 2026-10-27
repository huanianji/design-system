import {createControls} from '../components/web/controls.js';
const $=id=>document.getElementById(id),root=new URL('../',import.meta.url);
let data,controls,topControls,tabGroup,reveal,action,attempts=0,mounts=0,reduced=false,enlarged=false;
const enabled=id=>$(id).getAttribute('aria-pressed')==='true';
const manifest=await (await fetch(new URL('generated/manifest.json',root))).json();
const bundle=await (await fetch(new URL(manifest.bundle+'/profiles.json',root))).json();
data=bundle.profiles.management.web;
await new Promise((resolve,reject)=>{$('tokens').onload=resolve;$('tokens').onerror=reject;$('tokens').href=new URL(manifest.bundle+'/tokens.css',root);});
function mount(){
  controls?.dispose();mounts++;$('mount').dataset.mounts=mounts;$('mount').innerHTML=`<div class="lab-row"><button id="lab-action"><span class="surface">执行本地操作</span></button><button id="disabled-action" disabled><span class="surface">不可用操作</span></button></div><div class="lab-row"><button data-owner="first"><span class="surface">按钮一</span></button><button data-owner="second"><span class="surface">按钮二</span></button></div><div class="tabs"><div class="tab-row" role="tablist" aria-label="检查内容"><div class="plate" aria-hidden="true"></div><button id="lab-tab0"><span class="surface">概览</span></button><button id="lab-tab1"><span class="surface">草稿</span></button><button id="lab-tab2"><span class="surface">设置</span></button></div></div><section id="panel0" class="lab-panel"><p>概览内容</p><button id="lab-toggle"><span class="surface">局部设置 <svg class="chevron" style="width:16px" viewBox="0 0 16 16"><path d="m4 6 4 4 4-4"/></svg></span></button><div id="lab-region" class="lab-region"><div class="lab-inner"><label>局部草稿 <input id="local-draft" class="lab-input" value="保留这份草稿"></label></div></div></section><section id="panel1" class="lab-panel"><label>独立草稿 <input class="lab-input" id="tab-draft" value="切换后仍保留"></label></section><section id="panel2" class="lab-panel"><p>设置内容</p></section>`;
  controls=createControls(()=>data.motion,()=>reduced);controls.bind($('mount').querySelectorAll('button'));
  action=controls.button($('lab-action'));
  tabGroup=controls.tabs({buttons:[0,1,2].map(i=>$('lab-tab'+i)),indicator:$('mount').querySelector('.plate'),panels:[0,1,2].map(i=>$('panel'+i))});
  reveal=controls.disclosure({trigger:$('lab-toggle'),region:$('lab-region'),arrow:$('lab-toggle').querySelector('svg')});reveal.setOpen(false,false);
  for(let i=0;i<3;i++)tabGroup.setDisabled(i,enabled('disable-all')||(i===1&&enabled('disable-tab')));
  $('lab-action').addEventListener('click',async()=>{
    const current=action,fail=enabled('fail-next');const owner=mounts;attempts++;$('mount').dataset.attempts=attempts;$('result').textContent='处理中…';
    try{
      await current.run(signal=>new Promise((resolve,reject)=>{
        const aborted=()=>{clearTimeout(timer);reject(new DOMException('已取消','AbortError'));};
        const timer=setTimeout(()=>{signal.removeEventListener('abort',aborted);fail?reject(Error('本地模拟失败，可重试')):resolve();},650);
        signal.addEventListener('abort',aborted,{once:true});
      }));
      if(owner===mounts)$('result').textContent='本地操作完成';
    }catch(error){if(owner===mounts&&error.name!=='AbortError')$('result').textContent=error.message;}
  });
  $('result').textContent=mounts>1?'已重建，旧操作已取消':'尚未操作';
  document.documentElement.dataset.ready='true';
}
topControls=createControls(()=>data.motion,()=>reduced);topControls.bind(document.querySelectorAll('.toolbar button,#conditions button'));
$('mode').addEventListener('click',()=>{const dark=document.documentElement.dataset.theme!=='dark';document.documentElement.dataset.theme=dark?'dark':'light';$('mode').firstElementChild.textContent=dark?'切换浅色':'切换深色';});
$('reduce').addEventListener('click',()=>{reduced=!reduced;$('reduce').setAttribute('aria-pressed',String(reduced));controls.settle();topControls.settle();});
$('scale').addEventListener('click',()=>{enlarged=!enlarged;document.documentElement.style.setProperty('--text-scale',enlarged?1.25:1);$('scale').firstElementChild.textContent=enlarged?'字号 100%':'字号 125%';requestAnimationFrame(()=>{tabGroup.layout(false);reveal.refresh();});});
$('remount').addEventListener('click',mount);
for(const id of ['fail-next','disable-tab','disable-all'])$(id).addEventListener('click',()=>{
  $(id).setAttribute('aria-pressed',String(!enabled(id)));
  if(id!=='fail-next')for(let i=0;i<3;i++)tabGroup.setDisabled(i,enabled('disable-all')||(i===1&&enabled('disable-tab')));
});
window.addEventListener('resize',()=>{tabGroup.layout(false);reveal.refresh();});
window.addEventListener('pagehide',event=>{if(!event.persisted){controls.dispose();topControls.dispose();}});
$('source-status').textContent='Web · '+manifest.build_id.slice(0,8);mount();await document.fonts.ready;
