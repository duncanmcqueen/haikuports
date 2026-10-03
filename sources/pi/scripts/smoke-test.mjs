import assert from 'node:assert/strict';
import { existsSync, readFileSync, mkdtempSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { execFileSync, spawn } from 'node:child_process';
import { join, resolve } from 'node:path';

const output = process.cwd();
const root = resolve('node_modules/@earendil-works/pi-coding-agent');
const p = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));
const temporary = mkdtempSync(join(tmpdir(), 'pi-consumer-check-'));
const sdkFile = join(output, `.pi-sdk-check-${process.pid}.mjs`);
const env = { PATH: process.env.PATH, HOME: temporary, PI_CODING_AGENT_DIR: join(temporary, 'agent'), PI_OFFLINE: '1', PI_TELEMETRY: '0' };
try {
    mkdirSync(env.PI_CODING_AGENT_DIR);
    assert.equal(execFileSync(process.execPath, [join(root, p.bin.pi), '--version'], { cwd: temporary, env, encoding: 'utf8', timeout: 60000 }).trim(), p.version);
    assert.ok(existsSync(join(root, p.exports['./rpc-entry'].import)), 'RPC entry is missing');
    writeFileSync(sdkFile, `import assert from 'node:assert/strict';
import { createAgentSession, SessionManager } from '@earendil-works/pi-coding-agent';
assert.equal(typeof createAgentSession, 'function');
assert.equal(typeof SessionManager.inMemory, 'function');
for (const suffix of ['/client', '/experimental/plugin']) {
    assert.throws(() => import.meta.resolve('@earendil-works/pi-coding-agent' + suffix));
}
`);
    execFileSync(process.execPath, [sdkFile], { cwd: temporary, env, encoding: 'utf8', timeout: 60000 });
    const marker = join(temporary, 'loaded');
    mkdirSync(join(env.PI_CODING_AGENT_DIR, 'extensions'));
    writeFileSync(join(env.PI_CODING_AGENT_DIR, 'extensions', 'check.ts'), `import { writeFileSync } from 'node:fs';
import { SessionManager, type ExtensionAPI } from '@earendil-works/pi-coding-agent';
export default function(pi: ExtensionAPI): void {
    if (typeof SessionManager.inMemory !== 'function') throw new Error('Extension package import failed');
    pi.registerCommand('haiku-check', { description: 'Test extension', handler: async () => {} });
    writeFileSync(${JSON.stringify(marker)}, 'loaded');
}`);
    execFileSync(process.execPath, [join(root, p.bin.pi), '--list-models'], { cwd: temporary, env, encoding: 'utf8', timeout: 60000 });
    assert.ok(existsSync(marker), 'The TypeScript extension did not load');
    await new Promise((resolve, reject) => {
        const child = spawn(process.execPath, [join(root, p.exports['./rpc-entry'].import), '--no-session'], { cwd: temporary, env, stdio: ['pipe', 'pipe', 'pipe'] });
        let pending = '';
        let errors = '';
        let complete = false;
        const stop = error => {
            if (complete) return;
            complete = true;
            clearTimeout(timer);
            child.kill('SIGTERM');
            error ? reject(error) : resolve();
        };
        const timer = setTimeout(() => stop(new Error(`RPC timed out: ${errors}`)), 60000);
        child.on('error', stop);
        child.on('exit', code => { if (!complete) stop(new Error(`RPC exited ${code}: ${errors}`)); });
        child.stderr.on('data', data => { errors += data; });
        child.stdout.on('data', data => {
            pending += data;
            let newline;
            while ((newline = pending.indexOf('\n')) >= 0) {
                const line = pending.slice(0, newline);
                pending = pending.slice(newline + 1);
                let response;
                try { response = JSON.parse(line); } catch { continue; }
                if (response.id !== 'haiku-check') continue;
                if (response.success !== true) stop(new Error(`RPC failed: ${line}`));
                else stop();
            }
        });
        child.stdin.on('error', error => { if (!complete) stop(error); });
        child.stdin.write(JSON.stringify({ id: 'haiku-check', type: 'get_state' }) + '\n');
    });
} finally {
    rmSync(sdkFile, { force: true });
    rmSync(temporary, { recursive: true, force: true });
}
console.log('Installed CLI, SDK, RPC request, and TypeScript extension checks passed.');
