import fs from 'fs';
import { execSync } from 'node:child_process';
// One-shot retry queue for timeout/flaky IDs: node retry-queue.mjs provider:id [...]
// Same overshoot method as probe.mjs. Writes retry-queue.json. Never logs keys.
const outDir = 'F:/CD/Opencode/.opencode/tools/model-verify/output';
function getUserEnv(k){ try{ return execSync(`powershell -Command "[Environment]::GetEnvironmentVariable('${k}','User')"`,{encoding:'utf8'}).trim(); }catch{ return null; } }
const PROVIDERS = {
  hcnsec:   { base:'https://api.hcnsec.cn/v1', key: getUserEnv('HCNSEC_API_KEY') },
  aihubmix: { base:'https://aihubmix.com/v1',  key: getUserEnv('AIHUBMIX_API_KEY') },
};
const jobs = process.argv.slice(2);
if(!jobs.length){ console.log('usage: node retry-queue.mjs provider:id [...]'); process.exit(1); }
async function fetchJSON(url, opts){
  const r=await fetch(url, opts);
  const t=await r.text();
  try{ return {status:r.status, ok:r.ok, json:JSON.parse(t), text:t}; }catch{ return {status:r.status, ok:r.ok, text:t, json:null} }
}
const results=[];
for(const job of jobs){
  const ci = job.indexOf(':');
  const prov = job.slice(0,ci), id = job.slice(ci+1);
  const P = PROVIDERS[prov];
  const entry={ id, provider:prov, probe:{} };
  if(!P || !P.key){ entry.probe.error='no provider/key'; results.push(entry); continue; }
  try{
    const body={ model:id, messages:[{role:'user',content:'hi'}], max_tokens:2000000 };
    const res=await fetchJSON(P.base.replace(/\/$/,'')+'/chat/completions', {method:'POST', headers:{'Content-Type':'application/json', Authorization:`Bearer ${P.key}`}, body: JSON.stringify(body), signal:AbortSignal.timeout(25000)});
    entry.probe.status=res.status; entry.probe.ok=res.ok;
    if(res.ok){ entry.probe.usage=res.json.usage||null; entry.probe.model_returned=res.json.model||null; }
    else{ entry.probe.error=(res.json?JSON.stringify(res.json):res.text).slice(0,800); }
    console.log(prov+':'+id+' -> '+res.status+' '+(res.ok?'ok':entry.probe.error.slice(0,150)));
  }catch(e){ entry.probe.error=String(e.message||e).slice(0,300); console.log(prov+':'+id+' -> ERR '+entry.probe.error); }
  results.push(entry);
  await new Promise(r=>setTimeout(r,1500));
}
fs.writeFileSync(outDir+'/retry-queue.json', JSON.stringify(results,null,2));
console.log('wrote retry-queue.json entries='+results.length);
