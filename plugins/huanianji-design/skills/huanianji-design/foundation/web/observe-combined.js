// 仅 ?combined-probe=场景 时加载；记录真实输入后的渲染属性，不驱动业务。
const scenario=new URLSearchParams(location.search).get('combined-probe');
const target=scenario.startsWith('bell')?'attention-action':scenario.startsWith('mic')?'microphone':scenario.startsWith('arrow')?'note-toggle':scenario.startsWith('asset')?null:'save-note';
let record,started;
const $=id=>document.getElementById(id);
function rotation(el){const m=new DOMMatrixReadOnly(getComputedStyle(el).transform);let angle=Math.atan2(m.b,m.a)*180/Math.PI;if(angle<-.001&&el.classList.contains('note-chevron'))angle+=360;return angle;}
function frame(){
 const transform=getComputedStyle($('microphone-icon')).transform,m=new DOMMatrixReadOnly(transform),surface=new DOMMatrixReadOnly(getComputedStyle($('save-note').firstElementChild).transform),rect=$('save-note').getBoundingClientRect(),state={reduced:document.getElementById('reduce').getAttribute('aria-pressed')==='true'};
 return {ms:performance.now()-started,bell:rotation($('reminder-icon')),mic:+$('microphone-icon').dataset.progress,mic_scale:Math.hypot(m.a,m.b),arrow:rotation(document.querySelector('.note-chevron')),height:$('note-region').getBoundingClientRect().height,target_height:$('note-region').firstElementChild.scrollHeight,asset:+getComputedStyle($('art')).opacity,save_scale:Math.hypot(surface.a,surface.b),busy:$('save-note').getAttribute('aria-busy')==='true',mic_enabled:$('microphone').getAttribute('aria-pressed')==='true',open:$('note-toggle').getAttribute('aria-expanded')==='true',mode:document.documentElement.dataset.theme,reduced:state.reduced,save_rect:[rect.x,rect.y,rect.width,rect.height]};
}
function tick(){record.frames.push(frame());if(performance.now()-started<1250)requestAnimationFrame(tick);else{const output=document.createElement('script');output.type='application/json';output.id='combined-trace';output.textContent=JSON.stringify(record);document.body.append(output);}}
for(const type of ['pointerdown','pointerup','keydown','keyup','click'])document.addEventListener(type,e=>{
 const button=e.target.closest('button');if(!button)return;
 const key=button.id||button.dataset.asset||'';
 if(!record&&(scenario==='mic-keyboard'?type==='keydown'&&e.key===' ':type==='pointerdown')&&(target?key===target:button.dataset.asset==='warmframe')){started=performance.now();record={id:scenario,frames:[],events:[]};requestAnimationFrame(tick);}
 if(record)record.events.push({type,key,ms:performance.now()-started});
},true);

const ready=document.createElement('span');ready.id='combined-probe-ready';ready.hidden=true;document.body.append(ready);

if(scenario==='checks'){
 const snapshot=document.createElement('script');snapshot.type='application/json';snapshot.id='combined-state';document.body.append(snapshot);
 function sync(){const value=JSON.stringify(window.themeFragments.getState());if(snapshot.textContent!==value)snapshot.textContent=value;requestAnimationFrame(sync);}sync();
}
