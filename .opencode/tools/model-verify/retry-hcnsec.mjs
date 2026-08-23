import { execSync } from 'node:child_process';
function getUserEnv(k){ return execSync(`powershell -Command "[Environment]::GetEnvironmentVariable('${k}','User')"`,{encoding:'utf8'}).trim(); }
const hKey=getUserEnv('HCNSEC_API_KEY');
async function probe(id){
  const body={model:id, messages:[{role:'user',content:'hi'}], max_tokens:2000000};
  try{
    const r=await fetch('https://api.hcnsec.cn/v1/chat/completions',{method:'POST', headers:{'Content-Type':'application/json', Authorization:`Bearer ${hKey}`}, body:JSON.stringify(body), signal:AbortSignal.timeout(30000)});
    const t=await r.text();
    console.log(id+': '+r.status+' '+t.slice(0,400).replace(/\n/g,' '));
  }catch(e){ console.log(id+': ERR '+e.message); }
}
await probe('Kimi-K2.6');
await new Promise(r=>setTimeout(r,1200));
await probe('DeepSeek-V4-Flash');
await new Promise(r=>setTimeout(r,1200));
await probe('auto');
await new Promise(r=>setTimeout(r,1200));
await probe('MiniMax-M3');
await probe('glm-4.7');
