import fs from 'fs';
import { execSync } from 'node:child_process';
// Probes aihubmix models AFTER the first 10 (probe.mjs covers slice(0,10)).
// Writes structured JSON (aihubmix-probe-rest.json). Never logs key material.
// Quota guard: 3 consecutive quota/rate errors aborts the run, partial results kept.
const outDir = 'F:/CD/Opencode/.opencode/tools/model-verify/output';
function getUserEnv(k){ try{ return execSync(`powershell -Command "[Environment]::GetEnvironmentVariable('${k}','User')"`,{encoding:'utf8'}).trim(); }catch{ return null; } }
const ahKey = getUserEnv('AIHUBMIX_API_KEY');
if(!ahKey){ console.log('AIHUBMIX_API_KEY missing - abort'); process.exit(1); }
const cfg = JSON.parse(fs.readFileSync('F:/CD/Opencode/opencode.json','utf8'));
const ids = Object.keys(cfg.provider.aihubmix.models).slice(10);
console.log('probing remaining aihubmix:', ids.length);
async function fetchJSON(url, opts){
  const r=await fetch(url, opts);
  const t=await r.text();
  try{ return {status:r.status, ok:r.ok, json:JSON.parse(t), text:t}; }catch{ return {status:r.status, ok:r.ok, text:t, json:null} }
}
const results=[];
let quotaHits=0;
for(const id of ids){
  const entry={ id, probe:{} };
  try{
    const body={ model:id, messages:[{role:'user',content:'hi'}], max_tokens:2000000 };
    const res=await fetchJSON('https://aihubmix.com/v1/chat/completions', {method:'POST', headers:{'Content-Type':'application/json', Authorization:`Bearer ${ahKey}`}, body: JSON.stringify(body), signal:AbortSignal.timeout(20000)});
    entry.probe.status=res.status; entry.probe.ok=res.ok;
    const errText = res.ok ? '' : (res.json?JSON.stringify(res.json):res.text);
    if(res.ok){ entry.probe.usage=res.json.usage||null; entry.probe.model_returned=res.json.model||null; }
    else{
      entry.probe.error=errText.slice(0,800);
      const m=entry.probe.error.match(/max_tokens[^0-9]*([0-9]{3,7})/i)||entry.probe.error.match(/\[1,([0-9]{3,7})\]/);
      if(m) entry.probe.inferred_limit=m[1];
      if(res.status===429 || /quota|rate limit|too many requests/i.test(errText)){ quotaHits++; }
      else { quotaHits=0; }
    }
    console.log(id+': '+res.status+' '+(res.ok?'ok':entry.probe.error.slice(0,120)));
  }catch(e){ entry.probe.error=String(e.message||e).slice(0,300); console.log(id+': ERR '+entry.probe.error); }
  results.push(entry);
  if(quotaHits>=3){ console.log('QUOTA GUARD: 3 consecutive quota errors - stopping, partial results kept'); break; }
  await new Promise(r=>setTimeout(r,2000));
}
fs.writeFileSync(outDir+'/aihubmix-probe-rest.json', JSON.stringify(results,null,2));
console.log('wrote aihubmix-probe-rest.json entries='+results.length);
