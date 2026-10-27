import {createControls,scaleOf,bezier,sample} from '../components/web/controls.js';
import {inputField} from '../components/web/inputs.js';
import {dynamicIcon} from '../components/web/dynamic-icon.js';

const $=id=>document.getElementById(id),root=new URL('../',import.meta.url),html=document.documentElement;
const state={view:'management',mode:'light',enlarged:false,reduced:matchMedia('(prefers-reduced-motion: reduce)').matches,query:'',status:'all',selected:null,noteOpen:false,category:'all',asset:null,failNext:false};
let manifest,bundle,fixture,data,noteTarget=0,pendingNote=null;
const people=new Map(),previews=new Map(),boundChecks=new WeakSet();
const motion=createControls(()=>data?.motion,()=>state.reduced);
const reminderIcon=dynamicIcon($('reminder-icon'),{kind:'bell',getMotion:()=>data?.motion,getReduced:()=>state.reduced});
const microphoneIcon=dynamicIcon($('microphone-icon'),{kind:'microphone',getMotion:()=>data?.motion,getReduced:()=>state.reduced});
const directionIcon=dynamicIcon(document.querySelector('.note-chevron'),{kind:'direction',getMotion:()=>data?.motion,getReduced:()=>state.reduced});
const saveControl=motion.button($('save-note'));
const noteField=inputField($('note'),{message:$('note-message'),onChange:value=>{if(!state.selected)return;const local=people.get(state.selected);local.note=value;local.noteStatus='idle';local.noteMessage=value===local.savedNote?'与已保存内容一致。':'尚有未保存的修改。';showNoteStatus();}});
function showNoteStatus(){if(!state.selected)return;const local=people.get(state.selected);noteField.setStatus(local.noteStatus,local.noteMessage);}
function cancelNote(){
  if(!pendingNote)return;const task=pendingNote;pendingNote=null;clearTimeout(task.timer);task.resolve(false);
  const local=people.get(task.owner);local.noteStatus='idle';local.noteMessage='保存已取消，草稿已保留。';saveControl.setBusy(false);saveControl.reset();noteField.setDisabled(!state.noteOpen);showNoteStatus();
}
async function saveNote(){
  if(!state.selected||noteField.composing||saveControl.busy)return;
  const local=people.get(state.selected);if(!local.note.trim()){local.noteStatus='error';local.noteMessage='请先写一条开播备注。';showNoteStatus();$('note').focus();return;}
  const task={owner:state.selected,value:local.note,failed:state.failNext};pendingNote=task;
  local.noteStatus='pending';local.noteMessage='正在保存到当前窗口…';noteField.setDisabled(true);showNoteStatus();
  await saveControl.run(async()=>{
    const completed=await new Promise(resolve=>{task.resolve=resolve;task.timer=setTimeout(()=>resolve(true),650);});
    if(!completed||pendingNote!==task)return;pendingNote=null;
    local.noteStatus=task.failed?'error':'success';local.noteMessage=task.failed?'保存失败，备注已保留，可重试。':'已保存到当前窗口。';if(!task.failed)local.savedNote=task.value;
    noteField.setDisabled(!state.noteOpen);showNoteStatus();
  });
}
$('save-note').addEventListener('click',saveNote);
$('simulate-failure').addEventListener('click',()=>{state.failNext=!state.failNext;$('simulate-failure').setAttribute('aria-pressed',String(state.failNext));});
$('microphone').addEventListener('click',()=>{if(!state.selected)return;const local=people.get(state.selected);local.mic=!local.mic;$('microphone').setAttribute('aria-pressed',String(local.mic));$('microphone-label').textContent=local.mic?'麦克风开启':'麦克风静音';microphoneIcon.setEnabled(local.mic);});
const digest=async buffer=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',buffer))].map(v=>v.toString(16).padStart(2,'0')).join('');
async function bytes(path){const r=await fetch(new URL(path,root),{cache:'no-store'});if(!r.ok)throw Error('文件不可用：'+path);return r.arrayBuffer();}
async function json(path){return JSON.parse(new TextDecoder().decode(await bytes(path)));}
function fail(error){$('workspace').hidden=true;$('design-error').hidden=false;$('design-error').textContent=error.message+'。重新生成后点击“重新读取设计”。';}
async function verify(record,all=false){await Promise.all(Object.entries({...record.inputs,...record.outputs,...(all?record.assets:{})}).map(async([file,hash])=>{if(await digest(await bytes(file))!==hash)throw Error('设计源或生成物已变化：'+file);}));}
function node(tag,className,text){const n=document.createElement(tag);if(className)n.className=className;if(text!==undefined)n.textContent=text;return n;}
function button(text,id,role=''){const b=node('button');if(id)b.id=id;if(role)b.setAttribute('role',role);b.append(node('span','surface',text));motion.bind([b]);return b;}
function filteredPeople(){const q=state.query.trim().toLocaleLowerCase();return fixture.streamers.filter(p=>(state.status==='all'||p.status===state.status)&&(!q||(p.name+' '+p.topic+' '+p.slot).toLocaleLowerCase().includes(q)));}
function statusLabel(status){const def=fixture.statuses[status],n=node('span','status-label',def.label);n.dataset.role=def.role;return n;}
function renderRoster(){
  const list=filteredPeople(),previous=state.selected;
  if(!list.some(p=>p.id===state.selected)){cancelNote();state.selected=list[0]?.id??null;}
  $('roster-body').replaceChildren();
  for(const p of list){
    const tr=node('tr',p.id===state.selected?'selected':'');tr.dataset.person=p.id;
    const name=node('td'),select=node('button','roster-select');select.setAttribute('aria-label','查看'+p.name+'的准备详情');select.setAttribute('aria-pressed',String(p.id===state.selected));
    select.append(node('span','name',p.name),node('span','topic-summary',p.topic));select.addEventListener('click',()=>selectPerson(p.id));name.append(select);
    const slot=node('td','slot',p.slot),status=node('td');status.append(statusLabel(p.status));
    const ready=node('td','ready-cell',people.get(p.id).checks.filter(Boolean).length+' / '+fixture.tasks.length);
    tr.append(name,slot,status,ready);tr.addEventListener('click',event=>{if(!event.target.closest('button')){selectPerson(p.id);select.focus();}});$('roster-body').append(tr);
  }
  $('roster-empty').hidden=list.length>0;$('result-count').textContent='显示 '+list.length+' 位';
  for(const b of $('status-filters').querySelectorAll('button'))b.setAttribute('aria-pressed',String(b.dataset.status===state.status));
  if(previous!==state.selected||!$('detail-name').textContent)renderDetail();
}
function settleDetail(){motion.stop('detail');$('detail-content').style.transform='none';$('detail-content').style.opacity=1;}
function selectPerson(id){
  if(state.selected===id)return;
  const el=$('detail-content'),running=motion.motions.has('detail'),from=running?scaleOf(el):data.motion.detail_start_scale,alpha=running?+getComputedStyle(el).opacity:.6;
  motion.stop('detail');cancelNote();state.selected=id;renderRoster();renderDetail();document.querySelector(`[data-person="${CSS.escape(id)}"] .roster-select`)?.focus({preventScroll:true});
  if(state.reduced){settleDetail();return;}
  const m=data.motion,values=[from,m.detail_peak_scale,m.detail_return_scale,1],offsets=[0,...m.release_offsets,1];
  motion.frames('detail',m.release_seconds,p=>{const scale=sample(bezier(p,m.release_easing),values,offsets),y=m.detail_distance*(1-scale)/(1-m.detail_start_scale);el.style.transform=`translateY(${y}px) scale(${scale})`;el.style.opacity=alpha+(1-alpha)*(1-(1-p)**3);},settleDetail);
}
function animateCheck(input,art){
  if(boundChecks.has(input))return;boundChecks.add(input);
  input.addEventListener('change',()=>{
    const record=people.get(state.selected);record.checks[+input.dataset.task]=input.checked;
    $('ready-count').textContent=record.checks.filter(Boolean).length+' / '+fixture.tasks.length+' 已确认';renderRoster();
    const line=art.querySelector('path'),m=data.motion,key='check-'+input.id,from=scaleOf(art),offset=parseFloat(getComputedStyle(line).strokeDashoffset),target=input.checked?0:1;
    motion.stop(key);motion.stop(key+'-line');
    if(state.reduced){art.style.transform='none';line.style.strokeDashoffset=target;return;}
    motion.frames(key,m.check_press_seconds+m.check_release_seconds,p=>{const t=p*(m.check_press_seconds+m.check_release_seconds);let s;if(t<m.check_press_seconds)s=from+(m.check_press_scale-from)*(1-(1-t/m.check_press_seconds)**3);else{const q=(t-m.check_press_seconds)/m.check_release_seconds;const back=1+2.70158*(q-1)**3+1.70158*(q-1)**2;s=m.check_press_scale+(1-m.check_press_scale)*back;}art.style.transform=`scale(${s})`;},()=>art.style.transform='none');
    motion.frames(key+'-line',m.check_draw_seconds,p=>line.style.strokeDashoffset=offset+(target-offset)*(1-(1-p)**3));
  });
}
function renderDetail(){
  // 筛选 / 重新读取也会更换详情；旧对象的进入运动不能继续驱动新内容。
  settleDetail();
  const person=fixture.streamers.find(p=>p.id===state.selected);$('detail-content').hidden=!person;$('detail-empty').hidden=!!person;if(!person){settleDetail();return;}
  const local=people.get(person.id);$('detail-name').textContent=person.name;$('detail-slot').textContent=person.slot;$('detail-topic').textContent=person.topic;
  const status=fixture.statuses[person.status];$('detail-status').textContent=status.label;$('detail-status').dataset.role=status.role;
  $('ready-count').textContent=local.checks.filter(Boolean).length+' / '+fixture.tasks.length+' 已确认';$('detail-checks').replaceChildren();
  fixture.tasks.forEach((text,i)=>{const row=node('label','checkrow'),input=node('input');input.type='checkbox';input.id='task-'+i;input.dataset.task=i;input.checked=local.checks[i];const art=node('span','check-art');art.setAttribute('aria-hidden','true');art.innerHTML='<svg viewBox="0 0 28 28"><path d="M7 14 12 19 22 8" pathLength="1"/></svg>';art.querySelector('path').style.strokeDashoffset=input.checked?0:1;row.append(input,art,node('span','',text));$('detail-checks').append(row);animateCheck(input,art);});
  $('note').value=local.note;showNoteStatus();$('microphone').setAttribute('aria-pressed',String(local.mic));$('microphone-label').textContent=local.mic?'麦克风开启':'麦克风静音';microphoneIcon.setEnabled(local.mic,false);toggleNote(state.noteOpen,false);
}
const noteDisclosure=motion.disclosure({trigger:$('note-toggle'),region:$('note-region'),arrow:document.querySelector('.note-chevron'),icon:directionIcon,onChange:open=>{state.noteOpen=open;$('note-toggle').querySelector('.surface>span').textContent=open?'收起开播备注':'展开开播备注';$('note').disabled=!open||!!pendingNote;$('save-note').tabIndex=open?0:-1;}});
function toggleNote(open,animated=true){noteDisclosure.setOpen(open,animated);noteTarget=noteDisclosure.target;}
function renderAssets(){
  motion.stop('asset-change');
  const assets=fixture.assets.filter(a=>state.category==='all'||a.category===state.category);if(!assets.some(a=>a.id===state.asset))state.asset=assets[0]?.id??null;
  $('asset-strip').replaceChildren();
  for(const asset of assets){const b=button('',null);b.className='asset-choice';b.dataset.asset=asset.id;b.setAttribute('aria-label','选择'+asset.name);b.setAttribute('aria-pressed',String(asset.id===state.asset));const surface=b.firstElementChild,img=node('img');img.src=new URL(asset.file,root);img.alt='';surface.replaceChildren(img,node('span','asset-name',asset.name));b.addEventListener('click',()=>selectAsset(asset.id));$('asset-strip').append(b);}
  for(const b of $('category-filters').querySelectorAll('button'))b.setAttribute('aria-pressed',String(b.dataset.category===state.category));renderPreview();
}
function selectAsset(id){if(id===state.asset)return;motion.stop('asset-change');state.asset=id;renderAssets();document.querySelector(`[data-asset="${CSS.escape(id)}"]`)?.focus({preventScroll:true});const art=$('art'),opacity=previews.get(id).opacity/100;if(!state.reduced)motion.frames('asset-change',data.motion.select_seconds,p=>{art.style.opacity=opacity*(1-(1-p)**3);},()=>art.style.opacity=opacity);}
function renderPreview(){
  const asset=fixture.assets.find(a=>a.id===state.asset);if(!asset)return;const values=previews.get(asset.id);
  $('art').src=new URL(asset.file,root);$('art').alt=asset.name;$('canvas').setAttribute('aria-label',asset.name+'，缩放 '+values.zoom+'%，透明度 '+values.opacity+'%');
  $('art').style.transform=`scale(${values.zoom/100})`;$('art').style.opacity=values.opacity/100;
  $('asset-title').textContent=asset.name;$('inspector-name').textContent=asset.name;$('asset-description').textContent=asset.description;
  $('zoom').value=values.zoom;$('opacity').value=values.opacity;$('zoom-value').value=values.zoom+'%';$('opacity-value').value=values.opacity+'%';
  $('reset-preview').disabled=values.zoom===fixture.preview.zoom_default&&values.opacity===fixture.preview.opacity_default;$('preview-status').textContent=$('reset-preview').disabled?'默认预览':'当前素材的预览已调整';
}
function apply(){
  data=bundle.profiles[state.view].web;html.dataset.profile=state.view;html.dataset.theme=state.mode;html.style.setProperty('--text-scale',state.enlarged?1.25:1);
  $('management').hidden=state.view!=='management';$('creative').hidden=state.view!=='creative';$('management-view').setAttribute('aria-pressed',String(state.view==='management'));$('creative-view').setAttribute('aria-pressed',String(state.view==='creative'));
  $('mode').firstElementChild.textContent=state.mode==='light'?'切换深色':'切换浅色';$('text-scale').firstElementChild.textContent=state.enlarged?'字号 100%':'字号 125%';$('reduce').setAttribute('aria-pressed',String(state.reduced));
  if(state.noteOpen&&state.view==='management')requestAnimationFrame(()=>{if(noteTarget!==$('note-region').firstElementChild.scrollHeight)toggleNote(true,false);});
}
async function change(key,value){try{await verify(manifest);if(key==='view'){cancelNote();reminderIcon.settle();microphoneIcon.settle();motion.stop('asset-change');renderPreview();}if(key==='view'&&$(state.view).contains(document.activeElement))$(value+'-view').focus();state[key]=value;apply();}catch(error){fail(error);}}
for(const view of ['management','creative'])$(view+'-view').addEventListener('click',()=>change('view',view));
$('mode').addEventListener('click',()=>change('mode',state.mode==='light'?'dark':'light'));$('text-scale').addEventListener('click',()=>change('enlarged',!state.enlarged));
$('query').addEventListener('input',()=>{state.query=$('query').value;renderRoster();});$('attention-action').addEventListener('click',()=>{reminderIcon.notify();state.status='attention';state.query='';$('query').value='';renderRoster();});
for(const key of ['zoom','opacity'])$(key).addEventListener('input',()=>{motion.stop('asset-change');previews.get(state.asset)[key]=+$(key).value;renderPreview();});
$('reset-preview').addEventListener('click',()=>{motion.stop('asset-change');previews.set(state.asset,{zoom:fixture.preview.zoom_default,opacity:fixture.preview.opacity_default});renderPreview();});
$('reduce').addEventListener('click',()=>{state.reduced=!state.reduced;reminderIcon.settle();microphoneIcon.settle();for(const key of [...motion.motions.keys()])motion.stop(key);settleDetail();for(const el of document.querySelectorAll('button .surface,.check-art'))el.style.transform='none';for(const input of $('detail-checks').querySelectorAll('input'))input.nextElementSibling.querySelector('path').style.strokeDashoffset=input.checked?0:1;apply();motion.settle();toggleNote(state.noteOpen,false);renderPreview();});
motion.bind([...document.querySelectorAll('button')]);
async function load(){
  try{
    cancelNote();reminderIcon.settle();microphoneIcon.settle();
    const next=await json('generated/manifest.json');await verify(next,true);const fresh=await json(next.bundle+'/profiles.json');if(!fresh.fragments)throw Error('缺少两类片段内容，请重新生成');
    const href=new URL(next.bundle+'/tokens.css',root).href,link=$('tokens');if(link.href!==href){const ready=new Promise((resolve,reject)=>{link.onload=resolve;link.onerror=()=>reject(Error('样式无法读取'));});link.href=href;await ready;}
    manifest=next;bundle=fresh;fixture=fresh.fragments;
    for(const p of fixture.streamers)if(!people.has(p.id))people.set(p.id,{checks:[...p.checks],note:p.note,savedNote:p.note,noteStatus:'idle',noteMessage:'',mic:true});for(const a of fixture.assets)if(!previews.has(a.id))previews.set(a.id,{zoom:fixture.preview.zoom_default,opacity:fixture.preview.opacity_default});
    $('status-filters').replaceChildren();for(const [id,label] of [['all','全部'],['attention','待确认'],['live','直播中'],['scheduled','待开播']]){const count=id==='all'?fixture.streamers.length:fixture.streamers.filter(p=>p.status===id).length,b=button(label+' '+count);b.dataset.status=id;b.setAttribute('aria-pressed',String(state.status===id));b.addEventListener('click',()=>{state.status=id;renderRoster();});$('status-filters').append(b);}
    $('category-filters').replaceChildren();for(const [id,label] of [['all','全部'],['opening','开场'],['frame','边框'],['scene','场景']]){const b=button(label);b.dataset.category=id;b.setAttribute('aria-pressed',String(state.category===id));b.addEventListener('click',()=>{state.category=id;renderAssets();});$('category-filters').append(b);}
    $('zoom').min=fixture.preview.zoom_min;$('zoom').max=fixture.preview.zoom_max;$('disclaimer').textContent=fixture.disclaimer;apply();renderRoster();renderAssets();$('design-error').hidden=true;$('workspace').hidden=false;$('source-status').textContent='Web · '+manifest.build_id.slice(0,8);await document.fonts.load(`${data.font.regular_weight} ${data.font.body}px "${data.font.family}"`,'今晚的开播安排');
  }catch(error){fail(error);}
}
$('reload').addEventListener('click',load);window.addEventListener('resize',()=>{if(data&&state.noteOpen)toggleNote(true,false);});
window.themeFragments={getState:()=>({...state,people:Object.fromEntries(people),previews:Object.fromEntries(previews),visible:fixture?filteredPeople().map(p=>p.id):[],build_id:manifest?.build_id,stale:!$('design-error').hidden})};
window.addEventListener('pagehide',event=>{if(!event.persisted){cancelNote();noteField.dispose();reminderIcon.dispose();microphoneIcon.dispose();directionIcon.dispose();motion.dispose();}});
await load();
if(new URLSearchParams(location.search).has('combined-probe'))await import('./observe-combined.js');
