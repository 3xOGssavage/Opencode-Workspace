#!/usr/bin/env node
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));

function log(...a) {
  process.stderr.write(`[tavily-router] ${a.join(' ')}\n`);
}

function collectKeys(env) {
  const seen = new Set();
  const keys = [];
  for (let i = 1; i <= 20; i++) {
    const v = (env[`TAVILY_API_KEY_${i}`] || '').trim();
    if (v && !seen.has(v)) {
      seen.add(v);
      keys.push(v);
    }
  }
  const p = (env.TAVILY_API_KEY || '').trim();
  if (p && !seen.has(p)) keys.push(p);
  return keys;
}

export { collectKeys };

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const keys = collectKeys(process.env);

  if (keys.length === 0) {
    log('No Tavily API key found. Set TAVILY_API_KEY (single key) or TAVILY_API_KEY_1..N (multiple keys).');
    process.exit(1);
  }

  let child;
  if (keys.length === 1) {
    log(`1 distinct key detected (...${keys[0].slice(-6)}) -> official tavily-mcp (depth defaulted to basic)`);
    // ponytail: cmd /c on win32 because npx is a .cmd shim; Node EINVALs .cmd without shell since CVE-2024-27980
    child =
      process.platform === 'win32'
        ? spawn('cmd', ['/c', 'npx', '-y', 'tavily-mcp@latest'], {
            stdio: [process.stdin, process.stdout, process.stderr],
            env: { ...process.env, TAVILY_API_KEY: keys[0], DEFAULT_PARAMETERS: '{"search_depth":"basic"}' },
          })
        : spawn('npx', ['-y', 'tavily-mcp@latest'], {
            stdio: [process.stdin, process.stdout, process.stderr],
            env: { ...process.env, TAVILY_API_KEY: keys[0], DEFAULT_PARAMETERS: '{"search_depth":"basic"}' },
          });
  } else {
    log(`${keys.length} distinct keys detected -> multi-key rotator`);
    child = spawn(process.execPath, [path.join(here, 'server.mjs')], {
      stdio: [process.stdin, process.stdout, process.stderr],
    });
  }

  child.on('error', (e) => {
    log(`engine failed to start: ${e.message}`);
    process.exit(1);
  });

  child.on('exit', (code, signal) => process.exit(code === null ? (signal ? 1 : 0) : code));

  for (const sig of ['SIGINT', 'SIGTERM']) {
    process.on(sig, () => {
      try {
        child.kill();
      } catch {}
      process.exit(0);
    });
  }

  process.on('exit', () => {
    try {
      child.kill();
    } catch {}
  });
}
