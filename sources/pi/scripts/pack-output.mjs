import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { basename, join, resolve } from 'node:path';
import { readFileSync, readdirSync, writeFileSync, mkdirSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const [output, mode, modelDirectory, patchFile] = process.argv.slice(2);
const out = resolve(output);
const { packReleasePackages } = await import(pathToFileURL(resolve('scripts/coding-agent-consumer.mjs')));
const directories = ['chord', 'telemetry', 'codemode', 'mcp', 'ai', 'durable', 'tui', 'agent', 'protocol', 'client', 'server', 'coding-agent'];
// Read names from the manifests. Do not duplicate the upstream name table.
const packages = directories.map(d => {
    const directory = `packages/${d}`;
    const path = join(directory, 'package.json');
    const manifest = JSON.parse(readFileSync(path, 'utf8'));
    // Published packages must not advertise omitted source files.
    const clean = value => {
        if (typeof value !== 'object' || value === null) return value;
        return Object.fromEntries(Object.entries(value).filter(([key]) => key !== 'source').map(([key, child]) => [key, clean(child)]));
    };
    if (manifest.exports) manifest.exports = clean(manifest.exports);
    if (d === 'coding-agent') {
        delete manifest.exports['./client'];
        delete manifest.exports['./experimental/plugin'];
    }
    writeFileSync(path, JSON.stringify(manifest, null, '\t') + '\n');
    return { directory, name: manifest.name, manifest };
});
const tarballs = packReleasePackages(packages, join(out, 'tarballs'));
const installer = JSON.parse(readFileSync('packages/coding-agent/install-lock/package.json', 'utf8'));
const overrides = { ...installer.overrides, ...Object.fromEntries([...tarballs].map(([name, file]) => [name, `file:./tarballs/${basename(file)}`])) };
const manifest = { name: installer.name, version: installer.version, private: true, dependencies: { '@earendil-works/pi-coding-agent': overrides['@earendil-works/pi-coding-agent'] }, overrides };
writeFileSync(join(out, 'package.json'), JSON.stringify(manifest, null, 2) + '\n');
// Preserve the pinned production graph. Substitute only the workspace artifacts.
const lock = JSON.parse(readFileSync('packages/coding-agent/install-lock/package-lock.json', 'utf8'));
lock.packages[''].dependencies = manifest.dependencies;
for (const [path, entry] of Object.entries(lock.packages)) {
    for (const pkg of packages) {
        if (!path.endsWith(`node_modules/${pkg.name}`)) continue;
        const file = tarballs.get(pkg.name);
        entry.resolved = `file:tarballs/${basename(file)}`;
        entry.integrity = 'sha512-' + createHash('sha512').update(readFileSync(file)).digest('base64');
        if (pkg.manifest.bin) entry.bin = pkg.manifest.bin;
    }
}
writeFileSync(join(out, 'package-lock.json'), JSON.stringify(lock, null, 2) + '\n');
const hash = file => createHash('sha256').update(readFileSync(file)).digest('hex');
const modelArchive = readdirSync(modelDirectory).find(n => n.endsWith('.tgz'));
writeFileSync(join(out, 'UPSTREAM-LICENSE.txt'), readFileSync('LICENSE'));
mkdirSync(join(out, 'model-data'));
for (const name of readdirSync('packages/ai/src/providers/data')) {
    const data = readFileSync(join('packages/ai/src/providers/data', name));
    writeFileSync(join(out, 'model-data', name), data);
}
writeFileSync(join(out, 'build-info.json'), JSON.stringify({
    piCommit: execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
    portPatchSha256: hash(patchFile),
    mode, node: process.version, npm: execFileSync('npm', ['--version'], { encoding: 'utf8' }).trim(),
    typescript: JSON.parse(readFileSync('node_modules/typescript/package.json', 'utf8')).version,
    modelPackage: `@earendil-works/pi-ai@${JSON.parse(readFileSync('packages/ai/package.json', 'utf8')).version}`,
    modelArchiveSha256: hash(join(modelDirectory, modelArchive)),
    modelFiles: Object.fromEntries(readdirSync('packages/ai/src/providers/data').map(n => [n, hash(join('packages/ai/src/providers/data', n))])),
    runtimeLockSha256: hash(join(out, 'package-lock.json')),
    tarballs: Object.fromEntries([...tarballs].map(([name, file]) => [name, hash(file)])),
}, null, 2) + '\n');
