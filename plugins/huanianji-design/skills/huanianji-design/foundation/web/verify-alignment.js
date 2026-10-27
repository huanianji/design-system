async () => {
  const $=id=>document.getElementById(id),wait=ms=>new Promise(r=>setTimeout(r,ms)),checks=[];
  const check=(name,passed,detail=null)=>checks.push({name,passed,detail});
  const select=id=>document.querySelector(`[data-person="${id}"] .roster-select`).click();
  const visual=()=>{const c=getComputedStyle($('detail-content')),m=new DOMMatrixReadOnly(c.transform);return {scale:m.a,y:m.f,opacity:+c.opacity};};
  const settled=()=>{const v=visual();return Math.abs(v.scale-1)<.0001&&Math.abs(v.y)<.01&&v.opacity===1;};
  await document.fonts.ready;
  const row=document.querySelector('tr.selected'),first=row.firstElementChild,last=row.lastElementChild;
  check('rounded_row_without_vertical_bar',getComputedStyle(first).boxShadow==='none'&&parseFloat(getComputedStyle(first).borderTopLeftRadius)>0&&parseFloat(getComputedStyle(last).borderTopRightRadius)>0);
  const heads=[...document.querySelectorAll('thead th')],cells=[...row.children];
  check('selection_background_keeps_four_aligned_columns',heads.length===4&&cells.length===4&&heads.every((h,i)=>Math.abs(h.getBoundingClientRect().x-cells[i].getBoundingClientRect().x)<.1));
  const layout=$('roster-body').getBoundingClientRect().toJSON();select('tangli');const from=visual(),time=performance.now();let peak=1,minimumY=0,stable=true;
  while(performance.now()-time<550){const v=visual();peak=Math.max(peak,v.scale);minimumY=Math.min(minimumY,v.y);const r=$('roster-body').getBoundingClientRect();stable=stable&&Math.abs(r.x-layout.x)<.1&&Math.abs(r.width-layout.width)<.1;await new Promise(requestAnimationFrame);}
  check('detail_selection_has_visible_rebound',from.scale<.98&&peak>1.01&&minimumY< -3&&$('detail-name').textContent==='棠梨',{start:from.scale,peak,minimumY});
  check('detail_motion_keeps_roster_layout',stable);check('detail_motion_settles',settled());
  select('qianyu');await wait(80);const previous=visual();select('xiaocheng');const next=visual();
  check('rapid_selection_continues_current_visual_state',Math.abs(previous.scale-next.scale)<.0001&&Math.abs(previous.y-next.y)<.01);
  await wait(100);$('mode').click();await wait(550);
  check('rapid_selection_and_theme_keep_latest_detail',$('detail-name').textContent==='小澄'&&settled());
  select('linxi');await wait(60);$('reduce').click();check('reduce_during_detail_motion_settles',settled());
  select('tangli');check('reduced_selection_is_immediate',$('detail-name').textContent==='棠梨'&&settled());
  $('reduce').click();$('mode').click();await wait(500);select('linxi');await wait(500);
  const audit={roster:[...document.querySelectorAll('#roster-body tr')].map(r=>({id:r.dataset.person,name:r.querySelector('.name').textContent,topic:r.querySelector('.topic-summary').textContent,slot:r.children[1].textContent,status:r.children[2].textContent,ready:r.children[3].textContent})),detail_topic:$('detail-topic').textContent,list_height:$('roster-body').getBoundingClientRect().height,filter_labels:[...$('status-filters').children].map(b=>b.textContent)};
  return {build_id:window.themeFragments.getState().build_id,checks,failed:checks.filter(c=>!c.passed),audit};
}
