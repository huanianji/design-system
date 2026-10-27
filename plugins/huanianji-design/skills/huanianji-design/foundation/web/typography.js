import {createControls} from '../components/web/controls.js';
const $=id=>document.getElementById(id),root=new URL('../',import.meta.url),html=document.documentElement;
const state={group:'daily',mode:'light',enlarged:false,fallback:false,loaded:false};
let manifest,bundle,fixture,data,fontError=null,fontHash=null,measurementFrame;
const motion=createControls(()=>data?.motion,()=>matchMedia('(prefers-reduced-motion: reduce)').matches);
const digest=async bytes=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(v=>v.toString(16).padStart(2,'0')).join('');
async function fetchBytes(path){const r=await fetch(new URL(path,root),{cache:'no-store'});if(!r.ok)throw Error('字库读取失败（HTTP '+r.status+'）');return r.arrayBuffer();}
async function json(path){return JSON.parse(new TextDecoder().decode(await fetchBytes(path)));}
function render(){
  html.dataset.theme=state.mode;html.style.setProperty('--text-scale',state.enlarged?1.25:1);
  html.style.setProperty('--lab-font-family',(state.fallback||!state.loaded?'':'"Huanianji Typography",')+data.font.fallbacks.map(v=>v==='sans-serif'?v:JSON.stringify(v)).join(','));
  html.style.setProperty('--lab-data-font-family',state.fallback||!state.loaded?'Menlo,Consolas,"DejaVu Sans Mono","Liberation Mono",monospace':'inherit');
  $('mode').firstElementChild.textContent=state.mode==='light'?'切换深色':'切换浅色';$('scale').firstElementChild.textContent=state.enlarged?'字号 100%':'字号 125%';
  $('fallback').setAttribute('aria-pressed',String(state.fallback));
  $('font-status').textContent=fontError?'主字库未加载，当前显示系统回退。':!state.loaded?'主字库正在加载，当前临时显示系统字体。':state.fallback?'系统回退对照：字形可能随设备变化。':'主字库已加载：资源圆体 1.910，正文 400 / 标题 600。';
  for(const b of $('groups').querySelectorAll('button'))b.setAttribute('aria-pressed',String(b.dataset.group===state.group));
  for(const el of $('samples').children)el.hidden=el.dataset.group!==state.group;
  $('data-sample').hidden=state.group!=='mixed';
  html.dataset.group=state.group;html.dataset.fallback=String(state.fallback);html.dataset.primaryLoaded=String(state.loaded);
  scheduleMeasurement();
}
function scheduleMeasurement(){
  cancelAnimationFrame(measurementFrame);
  measurementFrame=requestAnimationFrame(async()=>{
    await document.fonts.ready;
    const canvas=document.createElement('canvas');canvas.width=480;canvas.height=100;const ctx=canvas.getContext('2d');
    const fallbackFamily=data.font.fallbacks.map(v=>v==='sans-serif'?v:JSON.stringify(v)).join(','),normalFamily='"Huanianji Typography",'+fallbackFamily;
    const raster=(text,weight=400,family=normalFamily)=>{ctx.clearRect(0,0,480,100);ctx.font=weight+' 32px '+family;ctx.fillStyle='#000';ctx.textBaseline='alphabetic';ctx.fillText(text,8,68);let hash=2166136261;for(const byte of ctx.getImageData(0,0,480,100).data)hash=Math.imul(hash^byte,16777619);return (hash>>>0).toString(16);};
    const samples=[...document.querySelectorAll('.type-case:not([hidden])')].map(el=>{const t=el.querySelector('.sample-text'),s=getComputedStyle(t),rect=t.getBoundingClientRect();ctx.font=s.fontWeight+' '+s.fontSize+' '+s.fontFamily;const paint=ctx.measureText(t.textContent);return {id:el.dataset.case,role:el.dataset.role,weight:+s.fontWeight,text:t.textContent,font_size:parseFloat(s.fontSize),font_family:s.fontFamily,line_height:parseFloat(s.lineHeight),rect:{x:rect.x,y:rect.y,width:rect.width,height:rect.height},paint_height:paint.actualBoundingBoxAscent+paint.actualBoundingBoxDescent,horizontal_overflow:t.scrollWidth>t.clientWidth+1};});
    const data_samples=[...document.querySelectorAll('.number-row>span:last-child')].map(el=>{const s=getComputedStyle(el);return {text:el.textContent,font_size:parseFloat(s.fontSize),weight:+s.fontWeight,font_family:s.fontFamily};});
    const input_style=getComputedStyle($('draft'));
    const fallback_rasters=['𠮷','𠮶','𡈽','𩸽','別','🚀','👩🏽‍💻'].map(text=>({text,normal:raster(text),system:raster(text,400,fallbackFamily),boundary:raster('𱻀')}));
    // 韩文可能由合成音节或 Jamo 序列排版；能显示不等于与纯系统路径采用同一字形。
    const script_rasters=['한','별'].map(text=>({text,normal:raster(text),decomposed:raster(text.normalize('NFD')),system:raster(text,400,fallbackFamily),boundary:raster('𱻀')}));
    const result={group:state.group,fallback:state.fallback,primary_loaded:state.loaded,draft:$('draft').value,samples:samples.map(({id,role,weight,text})=>({id,role,weight,text})),horizontal_overflow:document.documentElement.scrollWidth>document.documentElement.clientWidth+1,raw:{samples,data_samples,input_font_size:parseFloat(input_style.fontSize),viewport:[innerWidth,innerHeight],theme:state.mode,text_scale:state.enlarged?1.25:1,font_sha256:fontHash,font_status:$('font-status').textContent,font_error:fontError,font_faces:[...document.fonts].filter(f=>f.family.includes('Huanianji Typography')).map(f=>({family:f.family,status:f.status,weight:f.weight})),digit_widths:[...$('digits').children].map(n=>n.getBoundingClientRect().width),fallback_rasters,script_rasters,weight_rasters:{regular:raster('华年集 Aa 0123',400),heading:raster('华年集 Aa 0123',600)},normalization_rasters:{composed:raster('Café'),combining:raster('Café')}}};
    $('font-metrics').textContent=JSON.stringify(result);html.dataset.measured=[state.group,state.mode,state.enlarged?1.25:1,state.fallback,innerWidth].join('/');
  });
}
async function load(){
  manifest=await json('generated/manifest.json');bundle=await json(manifest.bundle+'/profiles.json');data=bundle.profiles.management.web;fixture=await json('sample/typography.json');
  const stylesReady=new Promise((resolve,reject)=>{$('tokens').onload=resolve;$('tokens').onerror=()=>reject(Error('共同字体样式不可读取'));});$('tokens').href=new URL(manifest.bundle+'/tokens.css',root);await stylesReady;$('source-status').textContent='Web · '+manifest.build_id.slice(0,8);
  for(const [id,label] of Object.entries(fixture.groups)){const b=document.createElement('button');b.dataset.group=id;b.innerHTML='<span class="surface"></span>';b.firstElementChild.textContent=label;b.addEventListener('click',()=>{state.group=id;render();});$('groups').append(b);}
  for(const c of fixture.cases){const el=document.createElement('section');el.className='type-case';el.dataset.case=c.id;el.dataset.group=c.group;el.dataset.role=c.role;const label=document.createElement('p');label.className='sample-caption';label.textContent=c.label;const text=document.createElement('p');text.className='sample-text';text.style.fontWeight=c.weight;text.textContent=c.text;el.append(label,text);if(c.note){const note=document.createElement('p');note.className='sample-note';note.textContent=c.note;el.append(note);}$('samples').append(el);}
  for(const digit of '0123456789'){const el=document.createElement('i');el.textContent=digit;$('digits').append(el);}
  $('draft').value=fixture.input;
  $('draft').addEventListener('input',scheduleMeasurement);window.addEventListener('resize',scheduleMeasurement);
  $('mode').addEventListener('click',()=>{state.mode=state.mode==='light'?'dark':'light';render();});$('scale').addEventListener('click',()=>{state.enlarged=!state.enlarged;render();});$('fallback').addEventListener('click',()=>{state.fallback=!state.fallback;render();});motion.bind(document.querySelectorAll('button'));
  try{
    const missing=new URLSearchParams(location.search).has('missing-font'),path=missing?'assets/fonts/typography-intentionally-missing.otf':data.font.file.replace(/^res:\/\//,'');
    const bytes=await fetchBytes(path);
    fontHash=await digest(bytes);if(fontHash!==manifest.assets[path])throw Error('字库内容与当前设计源不一致');
    const face=new FontFace('Huanianji Typography',bytes,{weight:'400 700',style:'normal'});await face.load();document.fonts.add(face);state.loaded=true;
  }catch(error){fontError=error.message;$('error').hidden=false;$('error').textContent=fontError;}
  render();await document.fonts.ready;html.dataset.ready='true';
}
window.typographyLab={getState:()=>({...state,fontError,build_id:manifest?.build_id,draft:$('draft').value}),getFixture:()=>fixture};
load().catch(error=>{$('error').hidden=false;$('error').textContent=error.message;});

window.addEventListener('pagehide',event=>{if(!event.persisted)motion.dispose();});
