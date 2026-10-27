// 开发采集入口：读取真实事件、逐帧渲染和状态；不调用组件动作或业务函数。
const traces=[];
const active=new Map();
const output=document.createElement('script');output.type='application/json';output.id='button-motion-traces';document.body.append(output);
function snapshot(button){
  const surface=button.querySelector('.surface'),style=getComputedStyle(surface),m=style.transform;
  return {scale:m==='none'?1:new DOMMatrixReadOnly(m).a,disabled:button.disabled,busy:button.getAttribute('aria-busy')==='true',background:style.backgroundColor,foreground:style.color,rect:[button.getBoundingClientRect().x,button.getBoundingClientRect().y,button.offsetWidth,button.offsetHeight]};
}
function publish(){output.textContent=JSON.stringify(traces.filter(record=>record.complete));}
function sample(record){
  const ms=performance.now()-record.start;
  record.frames.push({ms,...snapshot(record.button)});
  if(ms<1050)requestAnimationFrame(()=>sample(record));
  else{active.delete(record.button);record.complete=true;delete record.button;publish();}
}
for(const type of ['pointerdown','pointerup','click','keydown','keyup','focus','blur'])document.addEventListener(type,event=>{
  const button=event.target.closest?.('button[data-hj-focus-input]');if(!button)return;
  const key=event.key||'';
  if((type==='pointerdown'||type==='keydown'&&[' ','Enter'].includes(key))&&!button.disabled&&!active.has(button)){
    const record={id:button.id,input:type==='pointerdown'?'pointer':key===' '?'Space':'Enter',start:performance.now(),events:[],frames:[],complete:false,button};active.set(button,record);traces.push(record);requestAnimationFrame(()=>sample(record));
  }
  if(active.has(button)){
    const record=active.get(button);record.events.push({type,key,ms:performance.now()-record.start,...snapshot(button)});
    // JSON不能承载DOM引用；采样完成前只发布轻量进度。
  }
},true);
publish();
