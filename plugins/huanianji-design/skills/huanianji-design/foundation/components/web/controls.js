// 公共行为不包含示例内容；参数由调用者提供的共同源读取。
export function scaleOf(element) { const value=getComputedStyle(element).transform; return value==='none'?1:new DOMMatrixReadOnly(value).a; }
export function bezier(t,points) { if(t<=0||t>=1)return t; let lo=0,hi=1;for(let i=0;i<18;i++){const a=(lo+hi)/2;const x=3*(1-a)**2*a*points[0]+3*(1-a)*a*a*points[2]+a**3;if(x<t)lo=a;else hi=a;}const a=(lo+hi)/2;return 3*(1-a)**2*a*points[1]+3*(1-a)*a*a*points[3]+a**3; }
export function sample(t,values,offsets) { for(let i=1;i<offsets.length;i++)if(t<=offsets[i])return values[i-1]+(values[i]-values[i-1])*(t-offsets[i-1])/(offsets[i]-offsets[i-1]);return values.at(-1); }

export function createControls(getMotion,getReduced=()=>false) {
  const motions=new Map(),buttons=new Map(),widgets=new Set(),events=new AbortController();
  let held=null,disposed=false,keyboard=true;
  // 浏览器可能在异步恢复焦点时沿用先前的键盘提示；按当前输入方式管理公共按钮的提示。
  function inputFocus(value){if(keyboard===value)return;keyboard=value;for(const element of buttons.keys())element.dataset.hjFocusInput=value?'keyboard':'pointer';}
  window.addEventListener('pointerdown',()=>inputFocus(false),{capture:true,signal:events.signal});
  window.addEventListener('keydown',()=>inputFocus(true),{capture:true,signal:events.signal});
  function stop(key) { motions.get(key)?.();motions.delete(key); }
  function frames(key,seconds,draw,finish=()=>{}) {
    stop(key);if(disposed)return;
    const start=performance.now();let frame;
    const cancel=()=>cancelAnimationFrame(frame);motions.set(key,cancel);
    const tick=now=>{if(motions.get(key)!==cancel)return;const p=Math.min(1,(now-start)/(seconds*1000));draw(p);if(p<1)frame=requestAnimationFrame(tick);else {motions.delete(key);finish();}};
    draw(0);frame=requestAnimationFrame(tick);
  }
  function animate(key,element,keys,options,finish=()=>{}) {
    stop(key);if(disposed)return;
    const animation=element.animate(keys,options),cancel=()=>animation.cancel();motions.set(key,cancel);
    animation.onfinish=()=>{if(motions.get(key)===cancel){motions.delete(key);finish();animation.cancel();}};
  }
  function button(element) {
    if(buttons.has(element))return buttons.get(element);
    const signal=new AbortController(),key={},surface=element.querySelector('.surface');
    element.dataset.hjFocusInput=keyboard?'keyboard':'pointer';
    let busy=false,disabled=element.disabled,destroyed=false,isDown=false;
    function reset(){isDown=false;stop(key);if(surface)surface.style.transform='none';}
    function press(down){
      const m=getMotion();if(!surface||!m||destroyed||(down&&element.disabled)||(!down&&!isDown))return;
      isDown=down;
      const from=scaleOf(surface);stop(key);
      if(getReduced()){reset();return;}
      const peak=element.getAttribute('role')==='tab'?m.tab_release_peak:m.release_peak;
      const values=down?[from,m.press_scale]:[from,peak,m.release_return,1],offsets=down?[0,1]:[0,...m.release_offsets,1];
      animate(key,surface,values.map((s,i)=>({transform:`scale(${s})`,offset:offsets[i]})),{duration:1000*(down?m.press_seconds:m.release_seconds),easing:`cubic-bezier(${(down?m.press_easing:m.release_easing).join(',')})`,fill:'both'},()=>surface.style.transform=down?`scale(${m.press_scale})`:'none');
    }
    // 处理中保留本次输入的释放反馈；显式不可用、隐藏及退出仍立即归稳。
    function sync(){element.disabled=disabled||busy;element.setAttribute('aria-busy',String(busy));if(disabled)reset();}
    const api={element,press,reset,get busy(){return busy;},setDisabled(value){disabled=!!value;sync();},setBusy(value){if(value&&isDown)press(false);busy=!!value;sync();},
      async run(task){if(element.disabled||destroyed)return;const restoreFocus=document.activeElement===element;api.setBusy(true);try{return await task(signal.signal);}finally{if(!destroyed){api.setBusy(false);if(restoreFocus&&document.activeElement===document.body&&!disabled)element.focus({preventScroll:true});}}},
      dispose(){if(destroyed)return;destroyed=true;signal.abort();disabledObserver.disconnect();reset();busy=false;element.disabled=disabled;element.setAttribute('aria-busy','false');delete element.dataset.hjFocusInput;buttons.delete(element);if(held===api)held=null;}
    };
    element.addEventListener('pointerdown',e=>{if(e.button===0&&!element.disabled){held=api;press(true);}},{signal:signal.signal});
    element.addEventListener('keydown',e=>{if((e.key===' '||e.key==='Enter')&&!e.repeat)press(true);},{signal:signal.signal});
    element.addEventListener('keyup',e=>{if(e.key===' '||e.key==='Enter')press(false);},{signal:signal.signal});
    element.addEventListener('blur',()=>{if(isDown)reset();if(held===api)held=null;},{signal:signal.signal});
    const disabledObserver=new MutationObserver(()=>{if(element.disabled&&(!busy||disabled))reset();});disabledObserver.observe(element,{attributes:true,attributeFilter:['disabled']});
    buttons.set(element,api);return api;
  }
  function bind(elements){for(const element of elements)button(element);}
  for(const type of ['pointerup','pointercancel'])window.addEventListener(type,()=>{held?.press(false);held=null;},{signal:events.signal});
  window.addEventListener('blur',()=>{held=null;for(const b of buttons.values())b.reset();},{signal:events.signal});
  function tabs({buttons:items,indicator=null,panels=[],selected=0,onChange=()=>{}}){
    const listeners=new AbortController(),key={};let index=selected,target='',dead=false;
    bind(items);
    function layout(animated=true,preserve=false){
      if(!indicator||!getMotion()||dead)return;
      indicator.hidden=index<0;if(index<0){stop(key);return;}
      const b=items[index],next=b.offsetLeft+'/'+b.offsetWidth;if(preserve&&target===next)return;target=next;
      const from=getComputedStyle(indicator).transform,width=getComputedStyle(indicator).width;stop(key);
      const transform=`translateX(${b.offsetLeft}px)`;indicator.style.transform=transform;indicator.style.width=b.offsetWidth+'px';
      if(animated&&!getReduced())animate(key,indicator,[{transform:from,width},{transform,width:b.offsetWidth+'px'}],{duration:getMotion().select_seconds*1000,easing:'cubic-bezier(0.215,0.61,0.355,1)'});
    }
    function select(next,{focus=false,animated=true,notify=true}={}){
      if(dead||!items[next]||items[next].disabled)return false;
      index=next;items.forEach((b,i)=>{b.setAttribute('role','tab');b.setAttribute('aria-selected',String(i===index));b.tabIndex=i===index?0:-1;if(panels[i]){const panel=panels[i];if(i!==index&&panel.contains(document.activeElement))focus=true;panel.hidden=i!==index;panel.setAttribute('role','tabpanel');if(!b.id)b.id='hj-tab-'+crypto.randomUUID();if(!panel.id)panel.id='hj-panel-'+crypto.randomUUID();b.setAttribute('aria-controls',panel.id);panel.setAttribute('aria-labelledby',b.id);}});
      if(focus)items[index].focus({preventScroll:true});layout(animated);if(notify)onChange(index);return true;
    }
    function clear(){index=-1;items.forEach(b=>{b.setAttribute('aria-selected','false');b.tabIndex=-1;});panels.forEach(panel=>panel.hidden=true);layout(false);onChange(-1);}
    items.forEach((b,i)=>{
      b.addEventListener('click',()=>select(i),{signal:listeners.signal});
      b.addEventListener('keydown',e=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;e.preventDefault();const enabled=items.map((b,n)=>b.disabled?-1:n).filter(n=>n>=0);if(!enabled.length)return;const at=enabled.indexOf(i),next=e.key==='Home'?enabled[0]:e.key==='End'?enabled.at(-1):enabled[(at+(e.key==='ArrowRight'?1:enabled.length-1))%enabled.length];select(next,{focus:true});},{signal:listeners.signal});
    });
    const api={element:items[0],select,layout,get selected(){return index;},get active(){return motions.has(key);},setDisabled(n,value){button(items[n]).setDisabled(value);if(value&&n===index){const next=items.findIndex(b=>!b.disabled);next>=0?select(next):clear();}else if(!value&&index<0)select(n);},settle:()=>layout(false),dispose(){dead=true;stop(key);listeners.abort();widgets.delete(api);}};
    items.forEach(b=>{b.setAttribute('role','tab');b.tabIndex=-1;b.setAttribute('aria-selected','false');});
    widgets.add(api);const first=items[selected]?.disabled?items.findIndex(b=>!b.disabled):selected;if(first<0)clear();else select(first,{animated:false,notify:false});return api;
  }
  function disclosure({trigger,region,content=region.firstElementChild,arrow=null,icon=null,open=false,onChange=()=>{}}){
    const listeners=new AbortController(),key={};let value=open,target=0,dead=false;
    region.style.overflow='hidden';if(!region.id)region.id='hj-reveal-'+crypto.randomUUID();trigger.setAttribute('aria-controls',region.id);button(trigger);
    function setOpen(next,animated=true){
      if(dead||!getMotion())return;
      if(!next&&region.contains(document.activeElement))trigger.focus({preventScroll:true});
      value=!!next;trigger.setAttribute('aria-expanded',String(value));region.inert=!value;
      const from=parseFloat(getComputedStyle(region).height)||0;target=value?content.scrollHeight:0;
      const matrix=arrow?new DOMMatrixReadOnly(getComputedStyle(arrow).transform):null,angle=matrix?Math.atan2(matrix.b,matrix.a)*180/Math.PI:0;
      stop(key);onChange(value);const settle=()=>{region.style.height=target+'px';if(icon)icon.follow(value?1:0);else if(arrow)arrow.style.transform=value?'rotate(180deg)':'none';};
      if(!animated||getReduced()){settle();return;}
      const m=getMotion(),bump=Math.min(m.expand_limit,Math.abs(target-from)*m.expand_ratio),heights=value?[from,target+bump,target-bump*m.expand_return_ratio,target]:[from,from+bump*m.collapse_lift_ratio,0],offsets=value?m.expand_offsets:m.collapse_offsets;
      frames(key,m.expand_seconds,p=>{if(icon)icon.follow((angle+((value?180:0)-angle)*(1-(1-p)**3))/180);else if(arrow)arrow.style.transform=`rotate(${angle+((value?180:0)-angle)*(1-(1-p)**3)}deg)`;for(let i=1;i<offsets.length;i++)if(p<=offsets[i]){const t=(p-offsets[i-1])/(offsets[i]-offsets[i-1]),w=value&&i===1?1-(1-t)**3:t*t*(3-2*t);region.style.height=Math.max(0,heights[i-1]+(heights[i]-heights[i-1])*w)+'px';break;}},settle);
    }
    const api={element:trigger,setOpen,get open(){return value;},get active(){return motions.has(key);},get target(){return target;},refresh(){if(value&&target!==content.scrollHeight)setOpen(value,false);},settle:()=>setOpen(value,false),dispose(){dead=true;stop(key);listeners.abort();widgets.delete(api);}};
    trigger.addEventListener('click',()=>{if(!trigger.disabled)setOpen(!value);},{signal:listeners.signal});
    region.addEventListener('keydown',event=>{if(value&&event.key==='Escape'&&!event.isComposing&&!event.defaultPrevented){event.preventDefault();setOpen(false);}},{signal:listeners.signal});
    widgets.add(api);return api;
  }
  function settle(){for(const b of buttons.values())b.reset();for(const widget of widgets)widget.settle();}
  function dispose(){if(disposed)return;for(const widget of [...widgets])widget.dispose();for(const b of [...buttons.values()])b.dispose();for(const key of [...motions.keys()])stop(key);events.abort();detached.disconnect();disposed=true;}
  // 动态列表移除节点时释放监听、动画和任务，不按 ID 推测动画归属。
  const detached=new MutationObserver(()=>{
    for(const widget of [...widgets]){if(!widget.element.isConnected)widget.dispose();else if(widget.active&&widget.element.closest('[hidden],[inert]'))widget.settle();}
    for(const [element,b] of buttons){if(!element.isConnected)b.dispose();else if(element.closest('[hidden],[inert]'))b.reset();}
  });
  detached.observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['hidden','inert']});
  return {motions,stop,frames,animate,button,bind,tabs,disclosure,settle,dispose};
}
