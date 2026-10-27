// 真实输入和视口条件由 CUA 驱动；字形测量由页面中的原生 FontFace / Canvas 产生。
export async function replayTypography({tab,viewport,fs,root,phase}) {
  const {createHash}=await import('node:crypto');
  const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
  const manifest=JSON.parse(await fs.readFile(root+'/generated/manifest.json','utf8'));
  const fixtureBytes=await fs.readFile(root+'/sample/typography.json');
  const contract=JSON.parse(await fs.readFile(root+'/sample/typography-review.json','utf8'));
  const bundle=JSON.parse(await fs.readFile(root+'/'+manifest.bundle+'/profiles.json','utf8'));
  const checks=[],cases=[];const check=(name,passed,detail)=>checks.push({name,passed,detail});
  await tab.reload();await tab.getAXState({emit:false});
  for(const scenario of contract.cases) {
    await viewport.set({width:scenario.context.viewport[0],height:scenario.context.viewport[1]});
    await tab.getAXState({emit:false});
    for(const action of scenario.actions) {
      const [kind,target,...rest]=action.split(':');
      if(kind==='text')await tab.playwright.locator('#draft').fill(rest.join(':'));
      else await tab.playwright.locator(target==='group'?'#groups button[data-group="'+rest[0]+'"]':'#'+target).click();
    }
    await tab.getAXState({emit:false});
    const key=[scenario.expect.group,scenario.context.theme,scenario.context.text_scale,scenario.expect.fallback,scenario.context.viewport[0]].join('/');
    await tab.playwright.locator('html[data-ready="true"][data-measured="'+key+'"]').waitFor({state:'attached'});
    const observed=JSON.parse(await tab.playwright.locator('#font-metrics').textContent());
    const raw=observed.raw;
    check(scenario.id+'/loaded',observed.primary_loaded&&raw.font_faces.some(f=>f.status==='loaded'),raw.font_faces);
    check(scenario.id+'/font-hash',raw.font_sha256===manifest.assets['assets/fonts/ResourceHanRoundedCN-VF.otf'],raw.font_sha256);
    check(scenario.id+'/weight-raster',raw.weight_rasters.regular!==raw.weight_rasters.heading,raw.weight_rasters);
    check(scenario.id+'/combining',raw.normalization_rasters.composed===raw.normalization_rasters.combining,raw.normalization_rasters);
    for(const item of raw.samples) {
      check(scenario.id+'/size/'+item.id,Math.abs(item.font_size-bundle.profiles.management.web.font[item.role]*scenario.context.text_scale)<.01,item.font_size);
      check(scenario.id+'/wrap/'+item.id,!item.horizontal_overflow,item.rect);
      check(scenario.id+'/line-height/'+item.id,item.line_height>=item.paint_height,{line:item.line_height,paint:item.paint_height});
    }
    for(const item of raw.fallback_rasters.filter(x=>x.text!=='別'))check(scenario.id+'/fallback-raster/'+item.text,item.normal===item.system&&item.normal!==item.boundary,item);
    // 只判可见字形及规范等价序列；具体字库来源不由 CSS 声明或像素差异推断。
    for(const item of raw.script_rasters)check(scenario.id+'/script-shaping/'+item.text,item.normal===item.decomposed&&item.normal!==item.boundary,item);
    if(observed.group==='mixed')check(scenario.id+'/tabular',Math.max(...raw.digit_widths)-Math.min(...raw.digit_widths)<.01,raw.digit_widths);
    check(scenario.id+'/input-size',Math.abs(raw.input_font_size-bundle.profiles.management.web.font.body*scenario.context.text_scale)<.01,raw.input_font_size);
    if(observed.group==='mixed')for(const item of raw.data_samples) {
      check(scenario.id+'/data-size/'+item.text,Math.abs(item.font_size-bundle.profiles.management.web.font.body*scenario.context.text_scale)<.01,item.font_size);
      check(scenario.id+'/data-weight/'+item.text,item.weight===bundle.profiles.management.web.font.regular_weight,item.weight);
    }
    const screenshot='evidence/typography-'+phase+'-web-'+scenario.id+'.jpg';
    await fs.writeFile(root+'/'+screenshot,await tab.getScreenshot({emit:false}));
    cases.push({id:scenario.id,actions:scenario.actions,context:{build_id:manifest.build_id,fixture:hash(fixtureBytes),viewport:raw.viewport,theme:raw.theme,text_scale:raw.text_scale},observed,screenshot});
  }
  const result={platform:'web',evidence_root:'..',input_driver:'CUA click/fill/viewport',implementation_sha256:hash(await fs.readFile(root+'/web/typography.js')),adapter_sha256:hash(await fs.readFile(root+'/web/replay-typography.cua.mjs')),cases,checks,failed:checks.filter(x=>!x.passed)};
  await fs.writeFile(root+'/evidence/typography-'+phase+'-web.json',JSON.stringify(result,null,2)+'\n');
  return {cases:cases.length,checks:checks.length,failed:result.failed.map(x=>x.name)};
}
