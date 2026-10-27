() => {
  const $=id=>document.getElementById(id),visible=!$('detail-content').hidden;
  const selected=document.querySelector('#roster-body tr.selected');
  const focus=document.activeElement;
  const rows=[...document.querySelectorAll('#roster-body tr')].map(row=>({
    id:row.dataset.person,name:row.querySelector('.name').textContent,
    topic:row.querySelector('.topic-summary').textContent,slot:row.querySelector('.slot').textContent,
    status:row.querySelector('.status-label').textContent,ready:row.querySelector('.ready-cell').textContent
  }));
  const transform=getComputedStyle($('detail-content')).transform;
  return {
    stamp:$('source-status').textContent,viewport:[window.innerWidth,window.innerHeight],
    text_scale:getComputedStyle(document.documentElement).getPropertyValue('--text-scale')*1,
    theme:document.documentElement.dataset.theme,reduced:$('reduce').getAttribute('aria-pressed')==='true',
    observed:{rows,selected:selected?.dataset.person??null,result_count:$('result-count').textContent,
      detail_visible:visible,empty_visible:!$('roster-empty').hidden,
      detail:visible?{name:$('detail-name').textContent,slot:$('detail-slot').textContent,
        topic:$('detail-topic').textContent,labels:[...document.querySelectorAll('.detail-facts dt')].map(n=>n.textContent),status:$('detail-status').textContent}:null,
      checks:visible?[...document.querySelectorAll('#detail-checks input')].map(n=>n.checked):[],
      note:visible?$('note').value:null,note_open:visible&&$('note-toggle').getAttribute('aria-expanded')==='true',
      note_focusable:visible&&!$('note').disabled&&!$('note-region').inert,
      detail_settled:transform==='none'||transform==='matrix(1, 0, 0, 1, 0, 0)',
      focus:focus?.id||null,focus_visible:focus?focus.matches(':focus-visible'):false,
      raw:{detail_transform:transform,detail_opacity:getComputedStyle($('detail-content')).opacity,
        arrow_transform:getComputedStyle(document.querySelector('.note-chevron')).transform,
        note_height:$('note-region').getBoundingClientRect().height,focus_tag:focus?.tagName}
    }
  };
}
