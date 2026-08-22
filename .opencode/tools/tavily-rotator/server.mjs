#!/usr/bin/env node
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

const NAME = 'tavily-mcp-rotator';
const VERSION = '1.0.0';
const API = 'https://api.tavily.com';
const COOLDOWN_MS = 24 * 60 * 60 * 1000;
const TIMEOUTS = { search: 60000, extract: 90000, crawl: 180000, map: 120000, usage: 15000 };
const DEPTHS = ['basic', 'advanced', 'fast', 'ultra-fast'];

function log(...a) {
  process.stderr.write(`[tavily-rotator] ${a.join(' ')}\n`);
}

const suf = (k) => k.slice(-6);

function workspaceRoot() {
  return path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
}

function statePath() {
  return process.env.TAVILY_STATE_PATH || path.join(workspaceRoot(), '.opencode', 'tavily-state.json');
}

let state = { idx: 0, cooldowns: {}, dead: {} };

try {
  const raw = JSON.parse(fs.readFileSync(statePath(), 'utf8'));
  state.idx = Number.isInteger(raw.idx) ? raw.idx : 0;
  state.cooldowns = raw.cooldowns && typeof raw.cooldowns === 'object' ? raw.cooldowns : {};
  state.dead = raw.dead && typeof raw.dead === 'object' ? raw.dead : {};
} catch {
  /* fresh start */
}

function saveState() {
  try {
    fs.writeFileSync(statePath(), JSON.stringify(state));
  } catch (e) {
    log(`WARN cannot persist state: ${e.message}`);
  }
}

function pool() {
  const keys = [];
  for (let i = 1; i <= 20; i++) {
    const k = process.env[`TAVILY_API_KEY_${i}`];
    if (k && !keys.includes(k.trim())) keys.push(k.trim());
  }
  return keys;
}

async function apiCall(key, method, endpointPath, body, timeoutMs) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const opts = { method, headers: { Authorization: `Bearer ${key}` }, signal: ctrl.signal };
    if (body !== undefined) {
      opts.headers['Content-Type'] = 'application/json';
      opts.body = JSON.stringify(body);
    }
    const res = await fetch(`${API}${endpointPath}`, opts);
    const text = await res.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = { raw: text };
    }
    return { status: res.status, ok: res.ok, data };
  } catch (e) {
    return { status: 0, ok: false, data: null, netError: e.message };
  } finally {
    clearTimeout(t);
  }
}

async function usageProbe(key) {
  const r = await apiCall(key, 'GET', '/usage', undefined, TIMEOUTS.usage);
  if (!r.ok || !r.data) return null;
  const ku = r.data.key || {};
  const acc = r.data.account || {};
  const usage =
    typeof ku.usage === 'number'
      ? ku.usage
      : typeof acc.plan_usage === 'number'
        ? acc.plan_usage
        : null;
  const limit =
    typeof ku.limit === 'number'
      ? ku.limit
      : typeof acc.plan_limit === 'number'
        ? acc.plan_limit
        : null;
  const plan = acc.current_plan || 'unknown';
  return { usage, limit, plan };
}

function keyStatus(k) {
  const now = Date.now();
  const s = suf(k);
  if (state.dead[s]) return `DEAD (${state.dead[s]})`;
  const cd = state.cooldowns[s];
  if (cd && cd > now) {
    const h = Math.ceil((cd - now) / 3600000);
    return `COOLDOWN (~${h}h left, quota reset pending)`;
  }
  return 'available';
}

async function runWithFailover(toolName, endpointPath, body, timeoutMs) {
  const keys = pool();
  if (!keys.length) throw new Error('No TAVILY_API_KEY_N environment variables found.');
  const order = [];
  for (let n = 0; n < keys.length; n++) order.push(keys[(state.idx + n) % keys.length]);
  const eligible = order.filter((k) => keyStatus(k) === 'available');
  if (!eligible.length) {
    const table = keys.map((k, i) => `  KEY_${i + 1} ...${suf(k)}: ${keyStatus(k)}`).join('\n');
    throw new Error(`All Tavily keys are dead or cooling down:\n${table}\nDelete .opencode/tavily-state.json to force re-probing.`);
  }

  for (const key of eligible) {
    const pos = keys.indexOf(key);
    log(`${toolName}: trying ...${suf(key)} -> POST ${endpointPath}`);
    let r = await apiCall(key, 'POST', endpointPath, body, timeoutMs);

    if (r.status >= 500 || r.netError) {
      log(`${toolName}: ...${suf(key)} transient failure (${r.netError || r.status}); retrying once`);
      r = await apiCall(key, 'POST', endpointPath, body, timeoutMs);
    }

    if (r.ok) {
      state.idx = (pos + 1) % keys.length;
      saveState();
      log(`${toolName}: success via ...${suf(key)}`);
      return { data: r.data, usedKey: suf(key) };
    }

    if (r.status === 401) {
      state.dead[suf(key)] = `deactivated/invalid (HTTP 401 at ${new Date().toISOString()})`;
      saveState();
      log(`${toolName}: ...${suf(key)} marked DEAD (401); rotating`);
      continue;
    }

    if (r.status === 429 || r.status === 432) {
      const u = await usageProbe(key).catch(() => null);
      const reset = u && u.limit != null && u.usage != null && u.usage < u.limit;
      log(`${toolName}: ...${suf(key)} quota block (${r.status}); usage probe: ${u ? `${u.usage}/${u.limit ?? 'unlimited'} plan=${u.plan}` : 'unreachable'}; reset=${reset}`);
      if (reset) {
        const r2 = await apiCall(key, 'POST', endpointPath, body, timeoutMs);
        if (r2.ok) {
          state.idx = (pos + 1) % keys.length;
          saveState();
          log(`${toolName}: quota cleared mid-call; success via ...${suf(key)}`);
          return { data: r2.data, usedKey: suf(key) };
        }
      }
      state.cooldowns[suf(key)] = Date.now() + COOLDOWN_MS;
      saveState();
      continue;
    }

    if (r.status >= 400) {
      const detail = (r.data && (r.data.detail?.error || r.data.detail)) || `HTTP ${r.status}`;
      throw new Error(`Tavily rejected the request (HTTP ${r.status}): ${typeof detail === 'string' ? detail : JSON.stringify(detail)}. Not rotating - this is a request problem, not a key problem.`);
    }
  }

  const table = keys.map((k, i) => `  KEY_${i + 1} ...${suf(k)}: ${keyStatus(k)}`).join('\n');
  throw new Error(`All eligible Tavily keys failed during this call:\n${table}`);
}

function defaultDepth(explicit) {
  if (explicit) return explicit;
  const env = (process.env.TAVILY_DEFAULT_DEPTH || '').toLowerCase();
  return DEPTHS.includes(env) ? env : 'basic';
}

const strArr = (v) => (Array.isArray(v) ? v.filter((x) => typeof x === 'string') : undefined);

function buildSearchBody(a) {
  const body = {
    query: a.query,
    search_depth: defaultDepth(typeof a.search_depth === 'string' ? a.search_depth.toLowerCase() : undefined),
    topic: a.topic || 'general',
  };
  if (a.max_results !== undefined) body.max_results = Math.max(0, Math.min(20, Number(a.max_results)));
  if (a.time_range) body.time_range = a.time_range;
  if (a.days) body.days = Number(a.days);
  if (a.start_date) body.start_date = a.start_date;
  if (a.end_date) body.end_date = a.end_date;
  if (a.country) body.country = a.country;
  if (a.include_domains) body.include_domains = strArr(a.include_domains);
  if (a.exclude_domains) body.exclude_domains = strArr(a.exclude_domains);
  if (typeof a.auto_parameters === 'boolean') body.auto_parameters = a.auto_parameters;
  if (a.chunks_per_source) body.chunks_per_source = Math.max(1, Math.min(3, Number(a.chunks_per_source)));
  if (a.include_answer !== undefined) body.include_answer = !!a.include_answer;
  if (a.include_raw_content !== undefined) body.include_raw_content = !!a.include_raw_content;
  if (a.include_images !== undefined) body.include_images = !!a.include_images;
  if (a.include_image_descriptions !== undefined) body.include_image_descriptions = !!a.include_image_descriptions;
  return body;
}

function formatSearch(d) {
  const out = [];
  if (d.answer) out.push(`Answer:\n\n${d.answer}\n`);
  if (Array.isArray(d.images) && d.images.length) {
    out.push('Images:');
    for (const im of d.images) out.push(`- ${typeof im === 'string' ? im : im.url}${im.description ? ` (${im.description})` : ''}`);
    out.push('');
  }
  out.push('Results:');
  (d.results || []).forEach((r, i) => {
    out.push(`\n${i + 1}. Title: ${r.title || '(untitled)'}`);
    out.push(`   URL: ${r.url}`);
    out.push(`   Content: ${r.content || ''}`);
    if (r.raw_content) out.push(`   Raw Content: ${r.raw_content}`);
  });
  if (d.response_time !== undefined) out.push(`\n(response_time: ${d.response_time}s)`);
  return out.join('\n');
}

const boolSchema = { type: 'boolean' };

const TOOLS = [
  {
    name: 'tavily-search',
    description:
      'A real-time web search engine with advanced filtering, returning ranked results with cleaned content. Supports general and news topics. Advanced depth costs 2 credits; use sparingly.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'The search query' },
        search_depth: { type: 'string', enum: DEPTHS, description: 'Defaults to basic unless overridden.' },
        topic: { type: 'string', enum: ['general', 'news'] },
        max_results: { type: 'number', minimum: 0, maximum: 20 },
        time_range: { type: 'string', enum: ['day', 'week', 'month', 'year'] },
        days: { type: 'number', description: 'News topic only: days back from current date' },
        start_date: { type: 'string', description: 'YYYY-MM-DD' },
        end_date: { type: 'string', description: 'YYYY-MM-DD' },
        country: { type: 'string' },
        include_domains: { type: 'array', items: { type: 'string' } },
        exclude_domains: { type: 'array', items: { type: 'string' } },
        chunks_per_source: { type: 'number', minimum: 1, maximum: 3 },
        include_answer: boolSchema,
        include_raw_content: boolSchema,
        include_images: boolSchema,
        include_image_descriptions: boolSchema,
        auto_parameters: boolSchema,
      },
      required: ['query'],
    },
    run: async (a) => {
      const { data } = await runWithFailover('search', '/search', buildSearchBody(a), TIMEOUTS.search);
      return formatSearch(data);
    },
  },
  {
    name: 'tavily-extract',
    description: 'Extract clean, structured raw content from one or more web page URLs.',
    inputSchema: {
      type: 'object',
      properties: {
        urls: { type: 'array', items: { type: 'string' }, minItems: 1, maxItems: 20, description: 'URLs to extract from' },
        query: { type: 'string', description: 'Reranks extracted chunks by relevance to this query' },
        chunks_per_source: { type: 'number', minimum: 1, maximum: 3 },
        extract_depth: { type: 'string', enum: ['basic', 'advanced'] },
        format: { type: 'string', enum: ['markdown', 'text'] },
        include_images: boolSchema,
        include_image_descriptions: boolSchema,
        include_favicon: boolSchema,
      },
      required: ['urls'],
    },
    run: async (a) => {
      const body = { urls: strArr(a.urls) };
      if (a.query) body.query = a.query;
      if (a.chunks_per_source) body.chunks_per_source = Math.max(1, Math.min(3, Number(a.chunks_per_source)));
      if (a.extract_depth) body.extract_depth = a.extract_depth;
      if (a.format) body.format = a.format;
      if (a.include_images !== undefined) body.include_images = !!a.include_images;
      if (a.include_image_descriptions !== undefined) body.include_image_descriptions = !!a.include_image_descriptions;
      if (a.include_favicon !== undefined) body.include_favicon = !!a.include_favicon;
      const { data } = await runWithFailover('extract', '/extract', body, TIMEOUTS.extract);
      return JSON.stringify(data, null, 2);
    },
  },
  {
    name: 'tavily-crawl',
    description: 'Crawl a website starting from a URL, extracting content across pages with configurable depth and breadth.',
    inputSchema: {
      type: 'object',
      properties: {
        url: { type: 'string', description: 'Root URL to begin the crawl' },
        instructions: { type: 'string' },
        query: { type: 'string' },
        max_depth: { type: 'number', minimum: 1 },
        max_breadth: { type: 'number', minimum: 1 },
        limit: { type: 'number', minimum: 1 },
        select_paths: { type: 'array', items: { type: 'string' } },
        select_domains: { type: 'array', items: { type: 'string' } },
        allow_external: boolSchema,
        categories: { type: 'array', items: { type: 'string' } },
        extract_depth: { type: 'string', enum: ['basic', 'advanced'] },
        format: { type: 'string', enum: ['markdown', 'text'] },
        include_favicon: boolSchema,
      },
      required: ['url'],
    },
    run: async (a) => {
      const body = { url: a.url };
      for (const f of ['instructions', 'query', 'max_depth', 'max_breadth', 'limit', 'select_paths', 'select_domains', 'allow_external', 'categories', 'extract_depth', 'format', 'include_favicon']) {
        if (a[f] !== undefined) body[f] = a[f];
      }
      const { data } = await runWithFailover('crawl', '/crawl', body, TIMEOUTS.crawl);
      return JSON.stringify(data, null, 2);
    },
  },
  {
    name: 'tavily-map',
    description: "Map a website's structure, returning the list of URLs discovered starting from a root URL.",
    inputSchema: {
      type: 'object',
      properties: {
        url: { type: 'string', description: 'Root URL to begin mapping' },
        instructions: { type: 'string' },
        query: { type: 'string' },
        max_depth: { type: 'number', minimum: 1 },
        max_breadth: { type: 'number', minimum: 1 },
        limit: { type: 'number', minimum: 1 },
        select_paths: { type: 'array', items: { type: 'string' } },
        select_domains: { type: 'array', items: { type: 'string' } },
        allow_external: boolSchema,
        categories: { type: 'array', items: { type: 'string' } },
      },
      required: ['url'],
    },
    run: async (a) => {
      const body = { url: a.url };
      for (const f of ['instructions', 'query', 'max_depth', 'max_breadth', 'limit', 'select_paths', 'select_domains', 'allow_external', 'categories']) {
        if (a[f] !== undefined) body[f] = a[f];
      }
      const { data } = await runWithFailover('map', '/map', body, TIMEOUTS.map);
      return JSON.stringify(data, null, 2);
    },
  },
  {
    name: 'tavily-usage',
    description: 'Show credit usage, plan, and rotation status for every configured Tavily key. Free health check - never spends credits or rotates.',
    inputSchema: { type: 'object', properties: {} },
    run: async () => {
      const keys = pool();
      if (!keys.length) throw new Error('No TAVILY_API_KEY_N environment variables found.');
      const rows = await Promise.all(
        keys.map(async (k, i) => {
          const u = await usageProbe(k).catch(() => null);
          return `KEY_${i + 1} ...${suf(k)} | ${u ? `${u.plan} | ${u.usage ?? '?'}/${u.limit ?? 'unlimited'} credits` : 'UNREACHABLE'} | ${keyStatus(k)}`;
        })
      );
      return ['Tavily key pool:', ...rows].join('\n');
    },
  },
];

function send(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

function reply(id, result) {
  send({ jsonrpc: '2.0', id, result });
}

function replyError(id, code, message) {
  send({ jsonrpc: '2.0', id, error: { code, message } });
}

async function handleMessage(msg) {
  if (msg.id === undefined || msg.id === null) return;

  if (msg.method === 'initialize') {
    reply(msg.id, {
      protocolVersion: (msg.params && msg.params.protocolVersion) || '2024-11-05',
      capabilities: { tools: { listChanged: false } },
      serverInfo: { name: NAME, version: VERSION },
    });
    return;
  }
  if (msg.method === 'ping') {
    reply(msg.id, {});
    return;
  }
  if (msg.method === 'tools/list') {
    reply(msg.id, { tools: TOOLS.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })) });
    return;
  }
  if (msg.method === 'tools/call') {
    const { name, arguments: args = {} } = msg.params || {};
    const tool = TOOLS.find((t) => t.name === name);
    if (!tool) {
      reply(msg.id, { content: [{ type: 'text', text: `Error: unknown tool "${name}"` }], isError: true });
      return;
    }
    try {
      const text = await tool.run(args);
      reply(msg.id, { content: [{ type: 'text', text }] });
    } catch (e) {
      log(`tool ${name} failed: ${e.message}`);
      reply(msg.id, { content: [{ type: 'text', text: `Error: ${e.message}` }], isError: true });
    }
    return;
  }
  replyError(msg.id, -32601, `Method not found: ${msg.method}`);
}

log(`${NAME} v${VERSION} starting; pool=${pool().length} keys; state=${statePath()}`);

const rl = createInterface({ input: process.stdin, terminal: false });
let queue = Promise.resolve();
rl.on('line', (line) => {
  if (!line.trim()) return;
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return;
  }
  queue = queue
    .then(() => handleMessage(msg))
    .catch((e) => {
      log(`handler crash: ${e.message}`);
      if (msg && msg.id !== undefined) replyError(msg.id, -32603, 'Internal error');
    });
});

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => process.exit(0));
}
