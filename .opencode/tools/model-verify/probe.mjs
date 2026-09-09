import fs from 'node:fs';
import path from 'node:path';

const outDir = 'F:/CD/Opencode/.opencode/tools/model-verify/output';
fs.mkdirSync(outDir, { recursive: true });

const cfg = JSON.parse(fs.readFileSync('F:/CD/Opencode/opencode.json', 'utf8'));
const cacheRaw = fs.readFileSync(process.env.USERPROFILE + '/.cache/opencode/models.json', 'utf8');
const cache = JSON.parse(cacheRaw);
const auth = JSON.parse(fs.readFileSync('C:/Users/user/.local/share/opencode/auth.json','utf8'));

function getKey(name){
  if(auth[name]?.key) return auth[name].key;
  if(auth[name]?.apiKey) return auth[name].apiKey;
  const env = process.env[name.toUpperCase().replace(/-/g,'_')+'_API_KEY'] || process.env[name.toUpperCase()+'_API_KEY'];
  if(env) return env;
  // fallback to User env
  try{
    const v = process.env[name+'_API_KEY'];
    if(v) return v;
  }catch{}
  return null;
}

async function fetchJSON(url, opts={}){
  const r = await fetch(url, opts);
  const t = await r.text();
  try{ return { status:r.status, ok:r.ok, json:JSON.parse(t), text:t }; }catch{ return { status:r.status, ok:r.ok, text:t, json:null } }
}

// Secret hygiene: strip pagination cursors before writing evidence files.
// nextPageToken-style values are high-entropy opaque strings that trip secret
// scanners (generic-api-key rule) without being credentials. Exact-key match
// only: never touches real fields. Extension point if new cursor key names
// appear in future API responses (add them to the condition below).
function scrubCursors(o){
  if(Array.isArray(o)){ for(const v of o) scrubCursors(v); return o; }
  if(o && typeof o==='object'){
    for(const k of Object.keys(o)){
      if(k==='nextPageToken'){ delete o[k]; }
      else scrubCursors(o[k]);
    }
  }
  return o;
}

async function probeProvider(name, baseURL, key, modelIds){
  console.log(`\n=== PROBE ${name} base=${baseURL} models=${modelIds.length} ===`);
  const results=[];
  // 1. list models
  let liveList=null;
  try{
    const listUrl = baseURL.replace(/\/$/,'') + '/models';
    const headers={};
    if(key) headers.Authorization=`Bearer ${key}`;
    const res = await fetchJSON(listUrl, { headers, signal: AbortSignal.timeout(15000) });
    if(res.ok && res.json){
      liveList = res.json.data ? res.json.data.map(m=>typeof m==='string'?m:(m.id||m.name)) : (res.json.models? res.json.models.map(m=>m.name): []);
      console.log(` live list ok: ${liveList.length} ids`);
      fs.writeFileSync(path.join(outDir, `${name}-live-models.json`), JSON.stringify(scrubCursors(res.json),null,2));
    } else {
      console.log(` list failed status=${res.status} ${res.text.slice(0,300)}`);
    }
  }catch(e){ console.log(` list error ${e.message}`); }

  for(const id of modelIds){
    const entry={ id, configured: cfg.provider[name]?.models?.[id] || null, cache: cache[name]?.models?.[id] || null, live: liveList? liveList.includes(id) : null, probe:{} };
    // try output limit disclosure
    try{
      const body={ model:id, messages:[{role:'user',content:'hi'}], max_tokens: 2000000 };
      const headers={'Content-Type':'application/json'};
      if(key) headers.Authorization=`Bearer ${key}`;
      const res = await fetchJSON(baseURL.replace(/\/$/,'') + '/chat/completions', { method:'POST', headers, body: JSON.stringify(body), signal: AbortSignal.timeout(20000) });
      // capture error message which often contains limit
      entry.probe.status=res.status;
      entry.probe.ok=res.ok;
      if(!res.ok){
        const msg = res.json ? JSON.stringify(res.json).slice(0,800) : res.text.slice(0,800);
        entry.probe.error=msg;
        // try extract output limit numbers
        const m = msg.match(/max_tokens[^0-9]*([0-9]{3,7})/i) || msg.match(/output[^0-9]*([0-9]{3,7})/i) || msg.match(/([0-9]{4,7})\s*tokens/i);
        if(m) entry.probe.inferred_limit=m[1];
      } else {
        // success -> we got a generation, check usage if available (not billed much)
        entry.probe.usage=res.json.usage || null;
        entry.probe.model_returned=res.json.model || null;
      }
    }catch(e){ entry.probe.error=e.message; }
    console.log(` ${id}: live=${entry.live} status=${entry.probe.status} ${entry.probe.error? entry.probe.error.slice(0,120):'ok'}`);
    results.push(entry);
    await new Promise(r=>setTimeout(r, 800)); // rate limit
  }
  fs.writeFileSync(path.join(outDir, `${name}-probe.json`), JSON.stringify(results,null,2));
  return results;
}

async function probeGoogle(){
  console.log(`\n=== PROBE google (native ListModels) ===`);
  const key = auth.google?.key || process.env.GEMINI_API_KEY;
  const res = await fetchJSON(`https://generativelanguage.googleapis.com/v1beta/models?key=${key}`);
  if(!res.ok){ console.log(` google list failed ${res.status} ${res.text.slice(0,400)}`); return; }
  fs.writeFileSync(path.join(outDir, `google-live-models.json`), JSON.stringify(scrubCursors(res.json),null,2));
  const models=res.json.models.slice(0,50);
  console.log(` google live ${models.length} models`);
  // find our configured gemini models? none in opencode.json provider google? google provider not in opencode.json but via auth
  const geminiLite = models.find(m=>m.name==='models/gemini-3.5-flash-lite');
  if(!geminiLite) console.log(' gemini-3.5-flash-lite not found (maybe versioned name)');
  // dump limits
  for(const m of models.slice(0,5)){
    console.log(` ${m.name} in:${m.inputTokenLimit} out:${m.outputTokenLimit}`);
  }
  // compare with cache
  const cacheGoogle=cache.google?.models;
  let mism=0;
  for(const id of Object.keys(cacheGoogle||{})){
    const c=cacheGoogle[id];
    const live=models.find(m=>m.name===`models/${id}` || m.name===`models/${id.replace(/-preview$/, '')}`);
    // just count
  }
}

async function probeOllama(){
  const key = auth['ollama-cloud']?.key;
  const base='https://ollama.com/v1';
  console.log(`\n=== PROBE ollama-cloud ${base} ===`);
  try{
    const list = await fetchJSON(`${base}/models`, { headers:{ Authorization:`Bearer ${key}` }, signal: AbortSignal.timeout(15000) });
    console.log(` ollama list status ${list.status} ${list.text?.slice(0,400)}`);
    if(list.json) fs.writeFileSync(path.join(outDir,'ollama-live-models.json'), JSON.stringify(scrubCursors(list.json),null,2));
  }catch(e){ console.log(` ollama list err ${e.message}`); }
  // try chat with correct model id from cache
  const cacheModels=Object.keys(cache['ollama-cloud']?.models || {}).slice(0,3);
  for(const id of cacheModels){
    try{
      const body={ model:id, messages:[{role:'user',content:'hi'}], max_tokens:5 };
      const res=await fetchJSON(`${base}/chat/completions`, { method:'POST', headers:{'Content-Type':'application/json', Authorization:`Bearer ${key}`}, body: JSON.stringify(body), signal: AbortSignal.timeout(15000)});
      console.log(` ${id} chat status=${res.status} ${res.ok?'ok':res.text.slice(0,200)}`);
    }catch(e){ console.log(` ${id} err ${e.message}`);}
    await new Promise(r=>setTimeout(r,500));
  }
}

async function probeNvidia(){
  const key = auth.nvidia?.key;
  const base='https://integrate.api.nvidia.com/v1';
  console.log(`\n=== PROBE nvidia ${base} ===`);
  const list=await fetchJSON(`${base}/models`, { headers:{ Authorization:`Bearer ${key}` }, signal: AbortSignal.timeout(15000)});
  console.log(` nvidia list ${list.status} count ${list.json?.data?.length}`);
  if(list.json) fs.writeFileSync(path.join(outDir,'nvidia-live-models.json'), JSON.stringify(scrubCursors(list.json),null,2));
  // probe one model output limit
  const testId='meta/llama-3.3-70b-instruct';
  try{
    const body={ model:testId, messages:[{role:'user',content:'hi'}], max_tokens:2000000 };
    const res=await fetchJSON(`${base}/chat/completions`, { method:'POST', headers:{'Content-Type':'application/json', Authorization:`Bearer ${key}`}, body: JSON.stringify(body), signal: AbortSignal.timeout(15000)});
    console.log(` nvidia ${testId} status=${res.status} ${res.text.slice(0,400)}`);
  }catch(e){ console.log(` nvidia probe err ${e.message}`);}
}

async function probeOpencodeGo(){
  const key = auth['opencode-go']?.key;
  const base='https://opencode.ai/zen/go/v1';
  console.log(`\n=== PROBE opencode-go ${base} ===`);
  try{
    const list=await fetchJSON(`${base}/models`, { headers:{ Authorization:`Bearer ${key}`}, signal: AbortSignal.timeout(15000)});
    console.log(` opencode-go list ${list.status} ${list.text.slice(0,600)}`);
    if(list.json) fs.writeFileSync(path.join(outDir,'opencode-go-live-models.json'), JSON.stringify(scrubCursors(list.json),null,2));
  }catch(e){ console.log(` opencode-go err ${e.message}`);}
  // also cache says opencode-go has 28 models, try chat
  const testId='glm-5.2';
  try{
    const body={ model:testId, messages:[{role:'user',content:'hi'}], max_tokens:5 };
    const res=await fetchJSON(`${base}/chat/completions`, { method:'POST', headers:{'Content-Type':'application/json', Authorization:`Bearer ${key}`}, body: JSON.stringify(body), signal: AbortSignal.timeout(15000)});
    console.log(` opencode-go ${testId} status=${res.status} ${res.text.slice(0,400)}`);
  }catch(e){ console.log(` opencode-go chat err ${e.message}`);}
}

(async()=>{
  const execSync = (await import('node:child_process')).execSync;
  const getUserEnv = (k)=>{ try{ return execSync(`powershell -Command "[Environment]::GetEnvironmentVariable('${k}','User')"`,{encoding:'utf8'}).trim(); }catch{ return null; } };
  const hKey = process.env.HCNSEC_API_KEY || auth['hcnsec']?.key || getUserEnv('HCNSEC_API_KEY');
  const trKey = getUserEnv('TOKENROUTER_API_KEY') || process.env.TOKENROUTER_API_KEY;
  const ahKey = getUserEnv('AIHUBMIX_API_KEY') || process.env.AIHUBMIX_API_KEY;

  // probe each
  const hcnsecModels = Object.keys(cfg.provider.hcnsec.models);
  const ahModels = Object.keys(cfg.provider.aihubmix.models);
  const trModels = cfg.provider.tokenrouter ? Object.keys(cfg.provider.tokenrouter.models) : [];

  await probeProvider('hcnsec','https://api.hcnsec.cn/v1', hKey, hcnsecModels);
  if (trModels.length) await probeProvider('tokenrouter','https://api.tokenrouter.com/v1', trKey, trModels);
  else console.log('\n=== SKIP tokenrouter (not in config) ===');
  await probeProvider('aihubmix','https://aihubmix.com/v1', ahKey, ahModels.slice(0,10)); // sample 10 to save time/cost
  await probeGoogle();
  await probeNvidia();
  await probeOllama();
  await probeOpencodeGo();
  console.log('\n=== DONE ===');
})();
