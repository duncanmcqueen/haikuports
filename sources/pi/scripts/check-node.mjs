// Run with: node --expose-gc scripts/check-node.mjs
import assert from 'node:assert/strict';
import { Worker } from 'node:worker_threads';
import { DatabaseSync } from 'node:sqlite';
assert.equal(process.platform, 'haiku');
assert.equal(typeof globalThis.gc, 'function');
for (let i = 0; i < 20; i++) {
    const data = Array.from({ length: 10000 }, (_, n) => ({ n, text: `value-${n}` }));
    globalThis.gc();
    assert.equal(data[9999].n, 9999);
}
await Promise.all(Array.from({ length: 4 }, () => new Promise((resolve, reject) => {
    const worker = new Worker(`const { parentPort } = require('node:worker_threads');
for(let i=0;i<20;i++){ const data=Array.from({length:10000},(_,n)=>({n})); global.gc(); if(data[9999].n!==9999) throw Error('bad data'); }
parentPort.postMessage('ok');`, { eval: true });
    const timer = setTimeout(() => { worker.terminate(); reject(new Error('Worker timed out')); }, 60000);
    let received = false;
    worker.on('message', message => { assert.equal(message, 'ok'); received = true; });
    worker.on('error', error => { clearTimeout(timer); reject(error); });
    worker.on('exit', code => { clearTimeout(timer); code === 0 && received ? resolve() : reject(new Error(`Worker exited: ${code}`)); });
})));
const db = new DatabaseSync(':memory:');
assert.equal(db.prepare('SELECT 42 AS answer').get().answer, 42);
db.close();
console.log('Haiku Node GC, worker, and SQLite checks passed.');
