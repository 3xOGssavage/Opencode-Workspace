import fs from 'fs';
import { execSync } from 'node:child_process';
const cfg = JSON.parse(fs.readFileSync('F:/CD/Opencode/opencode.json','utf8'));
function getUserEnv(k){ try{ return execSync(`powershell -Command "[Environment]::GetEnvironmentVariable('${k}','User')"`,{encoding:'utf8'}).trim(); }catch{ return null; } }
const ahKey = getUserEnv('AIHUBMIX_API_KEY');
console.log('ahKey', ahKey ? ahKey.slice(0,8)+'...'+ahKey.slice(-4) : 'missing');
const remaining = Object.keys(cfg.provider.aihubmix.models).slice(10);
console.log('remaining aihubmix:', remaining.length, remaining.slice(0,5).join(', '));
async function fetchJSON(url, opts){
  const r=await fetch(url, opts);
  const t=await r.text();
  try{ return {status:r.status, ok:r.ok, json:JSON.parse(t), text:t}; }catch{ return {status:r.status, ok:r.ok, text:t, json:null} }
}
for(const id of remaining){
  try{
    const body={ model:id, messages:[{role:'user',content:'hi'}], max_tokens:2000000 };
    const res=await fetchJSON('https://aihubmix.com/v1/chat/completions', {method:'POST', headers:{'Content-Type':'application/json', Authorization:`Bearer ${ahKey}`}, body:JSON.stringify(body), signal:AbortSignal.timeout(20000)});
    const msg = res.json? JSON.stringify(res.json).slice(0,500): res.text.slice(0,500);
    console.log(id+': '+res.status+' '+msg.slice(0,180).replace(/\n/g,' '));
  }catch(e){ console.log(id+': ERR '+e.message) }
  await new Promise(r=>setTimeout(r,700));
}
