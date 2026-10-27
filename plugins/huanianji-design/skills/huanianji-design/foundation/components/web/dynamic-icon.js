import {createControls,sample,bezier,scaleOf} from './controls.js';
const icons=new WeakMap();

// 装饰只跟随动作/状态，焦点、命中和可达名称继续属于外层真实控件。
export function dynamicIcon(element,{kind,getMotion,getReduced=()=>false,enabled=true}){
  if(icons.has(element))return icons.get(element);
  if(!['bell','microphone','direction'].includes(kind))throw Error('未知动态图标角色：'+kind);
  const motion=createControls(getMotion,getReduced),key={},glyph=document.createElement('span');
  let active=!!enabled,progress=active?0:1,dead=false,angle=0;
  element.classList.add('hj-icon');element.dataset.kind=kind;element.setAttribute('aria-hidden','true');
  glyph.className='hj-icon-glyph';element.append(glyph);
  element.style.setProperty('--hj-glyph',`url("${new URL('../../assets/icons/'+({bell:'bell',microphone:'mic',direction:'chevron'}[kind])+'.svg',import.meta.url)}")`);
  let mark;
  if(kind==='microphone'){mark=document.createElement('span');mark.className='hj-icon-mark';element.append(mark);element.style.setProperty('--hj-mark',`url("${new URL('../../assets/icons/slash.svg',import.meta.url)}")`);}
  function drawState(){if(mark)mark.style.opacity=progress;element.dataset.enabled=String(active);element.dataset.progress=String(progress);}
  function settle(){motion.stop(key);angle=0;element.style.transform=kind==='direction'?`rotate(${progress*180}deg)`:'none';if(kind==='microphone')progress=active?0:1;drawState();}
  function notify(){
    if(dead||kind!=='bell')return;motion.stop(key);if(getReduced()){settle();return;}
    const m=getMotion(),values=[angle,...m.bell_degrees],offsets=values.map((_,i)=>i/(values.length-1));
    motion.frames(key,m.bell_seconds,p=>{for(let i=1;i<offsets.length;i++)if(p<=offsets[i]){const q=(p-offsets[i-1])/(offsets[i]-offsets[i-1]);angle=values[i-1]+(values[i]-values[i-1])*q*q*(3-2*q);break;}element.style.transform=`rotate(${angle}deg)`;},settle);
  }
  function setEnabled(value,animated=true){
    value=!!value;if(dead||kind!=='microphone')return;if(value===active&&animated)return;
    active=value;const from=progress,scale=scaleOf(element);motion.stop(key);drawState();
    if(!animated||getReduced()){settle();return;}
    const m=getMotion(),target=active?0:1;
    motion.frames(key,m.release_seconds,p=>{progress=from+(target-from)*(1-(1-p)**3);drawState();const s=sample(bezier(p,m.release_easing),[scale,m.tab_release_peak,m.release_return,1],[0,...m.release_offsets,1]);element.style.transform=`scale(${s})`;},settle);
  }
  // 方向动画的时钟归展开控件所有，避免箭头和容器各自启动一个 Tween。
  function follow(value){if(dead||kind!=='direction')return;progress=value;drawState();element.style.transform=`rotate(${progress*180}deg)`;}
  const observer=new MutationObserver(()=>{if(!element.isConnected)api.dispose();else if(element.closest('[hidden],[inert]'))settle();});
  const api={element,notify,setEnabled,follow,settle,get enabled(){return active;},get active(){return motion.motions.has(key);},dispose(){if(dead)return;settle();dead=true;observer.disconnect();motion.dispose();icons.delete(element);}};
  observer.observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['hidden','inert']});
  icons.set(element,api);settle();return api;
}
