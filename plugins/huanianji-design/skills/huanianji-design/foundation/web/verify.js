async () => {
  const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
  for(let i=0;i<50&&!window.foundation?.getState().build_id;i++)await wait(100);
  await document.fonts.ready;
  const checks=[]; const check=(name,passed,detail=null)=>checks.push({name,passed,detail});
  const $=id=>document.getElementById(id); const state=()=>window.foundation.getState();
  const expectedBody=+(new URL(location.href).searchParams.get('body')||17);
  check('shared_source_loaded',!$('sample').hidden&&!state().stale,state().build_id);
  check('generated_font_size_consumed',parseFloat(getComputedStyle(document.body).fontSize)===expectedBody,getComputedStyle(document.body).fontSize);
  check('font_file_loaded',[...document.fonts].some(f=>f.family==='Huanianji UI'&&f.status==='loaded')&&document.fonts.check(`${expectedBody}px "Huanianji UI"`,'开播准备'),[...document.fonts].map(f=>({family:f.family,status:f.status})));
  $('topic').value='跨端共同源，保留草稿';$('topic').dispatchEvent(new Event('input',{bubbles:true}));$('topic').focus();
  $('check').click();$('tab2').click();$('expand').click();await wait(550);
  $('parameter').value=42;$('parameter').dispatchEvent(new Event('input',{bubbles:true}));
  $('mode').click();await wait(600);$('profile').click();await wait(600);
  const s=state();check('theme_preserves_input_selection_and_expansion',s.text==='跨端共同源，保留草稿'&&!s.checked&&s.selected===2&&s.expanded&&s.parameter===42,s);
  check('theme_preserves_focus',document.activeElement===$('topic'));
  check('product_profile_is_active',document.documentElement.dataset.profile==='jade-demo'&&getComputedStyle(document.body).getPropertyValue('--hj-accent').trim()==='#a4e1cc');
  $('action').dispatchEvent(new PointerEvent('pointerdown',{button:0,bubbles:true}));await wait(130);
  const surface=$('action').querySelector('.surface'),down=new DOMMatrixReadOnly(getComputedStyle(surface).transform).a;
  window.dispatchEvent(new PointerEvent('pointerup',{button:0,bubbles:true}));
  const start=performance.now();let peak=1,minAfter=1;const bounds=$('action').getBoundingClientRect();let stable=true;
  while(performance.now()-start<520){const scale=new DOMMatrixReadOnly(getComputedStyle(surface).transform).a;peak=Math.max(peak,scale);if(performance.now()-start>90)minAfter=Math.min(minAfter,scale);const rect=$('action').getBoundingClientRect();stable=stable&&Math.abs(rect.x-bounds.x)<.1&&Math.abs(rect.width-bounds.width)<.1;await new Promise(requestAnimationFrame);}
  check('rebound_and_stable_hit_area',down<.96&&peak>1.04&&minAfter<.995&&stable,{down,peak,minAfter});
  $('action').click();check('activation_once',state().clicks===1);
  $('expand').click();await wait(500);$('expand').click();await wait(80);
  const height=parseFloat(getComputedStyle($('reveal')).height);$('expand').click();const after=parseFloat(getComputedStyle($('reveal')).height);
  check('disclosure_reversal_continuous',Math.abs(height-after)<1,{height,after});
  $('reduce').click();await wait(30);check('reduced_motion_settles',state().reduced&&parseFloat(getComputedStyle($('reveal')).height)===0&&getComputedStyle(document.querySelector('.optical svg')).transform==='none');
  $('reduce').click();$('mode').click();await wait(500);$('profile').click();await wait(500);
  const result={url:location.href,build_id:state().build_id,checks,failed:checks.filter(c=>!c.passed),state:state()};return result;
}
