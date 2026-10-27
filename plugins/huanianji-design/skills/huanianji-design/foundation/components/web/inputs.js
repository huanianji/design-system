import {createControls} from './controls.js';
const boundFields=new WeakMap(),boundOtps=new WeakMap();

export function digits(text){return [...text].map(c=>c>='０'&&c<='９'?String(c.charCodeAt(0)-0xff10):c).join('').replace(/[^0-9]/g,'');}

// 保留原生编辑、撤销、选区和输入法；状态与说明不改写正在输入的内容。
export function inputField(element,{message=null,onChange=()=>{}}={}) {
  if(boundFields.has(element))return boundFields.get(element);
  const events=new AbortController();let composing=false,status='idle';
  element.classList.add('hj-input');element.dataset.hjInput='field';
  if(message){if(!message.id)message.id=(element.id||'hj-input-'+crypto.randomUUID())+'-message';element.setAttribute('aria-describedby',[element.getAttribute('aria-describedby'),message.id].filter(Boolean).join(' '));message.setAttribute('aria-live','polite');}
  function setStatus(next='idle',text=''){status=next;element.dataset.inputStatus=next;element.setAttribute('aria-invalid',String(next==='error'));if(message){message.textContent=text;message.dataset.status=next;}}
  element.addEventListener('compositionstart',()=>composing=true,{signal:events.signal});
  element.addEventListener('compositionend',()=>{composing=false;setStatus();onChange(element.value);},{signal:events.signal});
  element.addEventListener('input',()=>{if(!composing){setStatus();onChange(element.value);}},{signal:events.signal});
  const api={element,get composing(){return composing;},get status(){return status;},setStatus,setDisabled(value){element.disabled=!!value;},setReadOnly(value){element.readOnly=!!value;},dispose(){events.abort();boundFields.delete(element);}};
  boundFields.set(element,api);return api;
}

export function otpInput(root,{length=6,getMotion,getReduced=()=>false,onChange=()=>{},message=null}={}) {
  if(boundOtps.has(root))return boundOtps.get(root);
  if(!Number.isInteger(length)||length<1)throw new Error('验证码位数必须为正整数');
  const events=new AbortController(),motion=createControls(getMotion,getReduced),fields=[],labels=[],slots=Array(length).fill('');
  let status='idle',blocked=false,readOnly=false,dead=false,focused=-1;
  root.classList.add('hj-otp');root.setAttribute('role','group');root.setAttribute('aria-label',root.getAttribute('aria-label')||length+'位验证码');root.style.setProperty('--otp-length',length);
  const plate=document.createElement('span');plate.className='hj-otp-focus';plate.setAttribute('aria-hidden','true');root.append(plate);
  const focus=index=>{fields[index].focus({preventScroll:true});fields[index].select();};
  function layout(animated=true){
    motion.stop(plate);plate.hidden=focused<0||blocked;if(plate.hidden)return;
    const b=fields[focused].parentElement,from=getComputedStyle(plate).transform;
    plate.style.width=b.offsetWidth+'px';plate.style.height=b.offsetHeight+'px';plate.style.transform=`translateX(${b.offsetLeft}px)`;
    if(animated&&!getReduced())motion.animate(plate,plate,[{transform:from},{transform:plate.style.transform}],{duration:getMotion().select_seconds*1000,easing:'cubic-bezier(.215,.61,.355,1)'});
  }
  function setStatus(next='idle',text=''){
    status=next;root.dataset.inputStatus=next;motion.stop(root);root.style.transform='none';
    for(const field of fields)field.setAttribute('aria-invalid',String(next==='error'));
    if(message){message.textContent=text;message.dataset.status=next;}
    if(next==='error'&&!getReduced())motion.animate(root,root,[0,-1,1,-.5,.5,0].map(x=>({transform:`translateX(${x*getMotion().input_error_distance}px)`})),{duration:getMotion().release_seconds*1000,easing:'ease-out'});
  }
  function render(previous){
    slots.forEach((digit,i)=>{fields[i].value=digit;labels[i].textContent=digit;motion.stop(labels[i]);if(previous&&digit&&previous[i]!==digit&&!getReduced())motion.animate(labels[i],labels[i],[{transform:`translateY(${-getMotion().input_enter_ratio*100}%)`,opacity:0},{transform:'translateY(8%)',opacity:1},{transform:'none',opacity:1}],{duration:getMotion().release_seconds*1000,easing:'cubic-bezier(.2,.75,.3,1)'});});
  }
  function change(index,text){
    if(blocked||readOnly||dead)return;
    const previous=[...slots],value=digits(text);
    if(!text)slots[index]='';else if(value){[...value.slice(0,length-index)].forEach((c,n)=>slots[index+n]=c);} // 粘贴只覆盖涉及的位，保留前导零及其余内容。
    render(previous);setStatus();if(value)focus(Math.min(length-1,index+value.length));onChange([...slots]);
  }
  for(let i=0;i<length;i++){
    const box=document.createElement('div');box.className='hj-otp-slot';
    const field=document.createElement('input');field.type='text';field.inputMode='numeric';field.autocomplete=i===0?'one-time-code':'off';field.setAttribute('aria-label',`验证码第 ${i+1} 位`);field.dataset.index=i;field.spellcheck=false;
    if(message){if(!message.id)message.id=(root.id||'hj-otp-'+crypto.randomUUID())+'-message';field.setAttribute('aria-describedby',message.id);message.setAttribute('aria-live','polite');}
    const label=document.createElement('span');label.className='hj-otp-digit';label.setAttribute('aria-hidden','true');box.append(field,label);root.append(box);fields.push(field);labels.push(label);
    let composing=false;
    field.addEventListener('focus',()=>{focused=i;field.select();layout();},{signal:events.signal});
    field.addEventListener('click',()=>field.select(),{signal:events.signal});
    field.addEventListener('compositionstart',()=>{composing=true;box.classList.add('composing');},{signal:events.signal});
    field.addEventListener('compositionend',()=>{composing=false;box.classList.remove('composing');change(i,field.value);},{signal:events.signal});
    field.addEventListener('input',event=>{if(!composing&&!event.isComposing)change(i,field.value);},{signal:events.signal});
    field.addEventListener('paste',event=>{if(blocked||readOnly)return;event.preventDefault();change(i,event.clipboardData.getData('text'));},{signal:events.signal});
    field.addEventListener('keydown',event=>{
      if(composing||event.isComposing||blocked)return;
      if(['ArrowLeft','ArrowRight','Home','End'].includes(event.key)){event.preventDefault();focus(event.key==='Home'?0:event.key==='End'?length-1:Math.max(0,Math.min(length-1,i+(event.key==='ArrowLeft'?-1:1))));}
      if(readOnly)return;
      if(event.key==='Backspace'){event.preventDefault();if(slots[i])change(i,'');else focus(Math.max(0,i-1));}
      if(event.key==='Delete'){event.preventDefault();change(i,'');}
    },{signal:events.signal});
  }
  root.addEventListener('focusout',event=>{if(!root.contains(event.relatedTarget)){focused=-1;layout(false);}},{signal:events.signal});
  const observer=new ResizeObserver(()=>layout(false));observer.observe(root);
  const api={fields,get slots(){return [...slots];},get value(){return slots.join('');},get complete(){return slots.every(Boolean);},get status(){return status;},setStatus,focus,
    setDisabled(value){blocked=!!value;for(const f of fields)f.disabled=blocked;if(blocked)api.settle();else layout(false);},setReadOnly(value){readOnly=!!value;for(const f of fields)f.readOnly=readOnly;},
    clear(){api.settle();slots.fill('');render();setStatus();onChange([...slots]);},settle(){for(const key of [...motion.motions.keys()])motion.stop(key);for(const label of labels){label.style.transform='none';label.style.opacity=1;}root.style.transform='none';layout(false);},
    dispose(){dead=true;events.abort();observer.disconnect();motion.dispose();root.replaceChildren();boundOtps.delete(root);}
  };
  boundOtps.set(root,api);setStatus();layout(false);return api;
}
