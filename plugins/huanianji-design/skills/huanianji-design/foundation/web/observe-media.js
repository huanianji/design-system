() => {
  const cards=[...document.querySelectorAll('.asset-choice')],focus=document.activeElement,card=focus?.closest('.asset-choice');
  const visible=!!card&&focus.matches(':focus-visible')&&getComputedStyle(focus).outlineStyle!=='none'&&+getComputedStyle(focus).outlineWidth.replace('px','')>0;
  const region=card?(focus===card?'whole_item':'inner_label'):null;
  return {
    observed:{
      selected:document.querySelector('.asset-choice[aria-pressed="true"]')?.dataset.asset,
      visible_focus_item:visible?card.dataset.asset:null,
      visible_focus_region:visible?region:null,
      focus_visible:visible,
      inner_action_controls:cards.reduce((n,c)=>n+c.querySelectorAll('button,a[href],input,select,textarea,[tabindex]').length,0),
      extra_inner_indicator:visible&&region!=='whole_item',
      raw:{focus_tag:focus?.tagName,actual_focus_item:card?.dataset.asset??null,actual_focus_region:region}
    },
    viewport:[window.innerWidth,window.innerHeight],theme:document.documentElement.dataset.theme,
    stamp:document.getElementById('source-status').textContent,
    text_scale:getComputedStyle(document.body).fontSize.replace('px','')/17,
    reduced:document.getElementById('reduce').getAttribute('aria-pressed')==='true'
  };
}
