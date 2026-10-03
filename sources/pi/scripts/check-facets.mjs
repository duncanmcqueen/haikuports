// Run from an installed output directory. Failure records the known limitation.
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const directory = mkdtempSync(join(tmpdir(), 'pi-facet-check-'));
try {
    writeFileSync(join(directory, 'entry.ts'), 'export const value: number = 42;\n');
    const { bundleFacets } = await import('@earendil-works/chord/bundler');
    const result = await bundleFacets({ plugin: { id: 'test' }, entries: { main: './entry.ts' }, workingDirectory: directory, outdir: './out' });
    const { readFileSync } = await import('node:fs');
    const { createRequire } = await import('node:module');
    const manifest = JSON.parse(readFileSync(result.manifestPath, 'utf8'));
    const require = createRequire(import.meta.url);
    const output = require(join(directory, 'out', manifest.entries.main.file));
    if (output.value !== 42) throw Error('Facet returned the wrong value');
    console.log('Simple Chord facet bundle passed. Complex facets still need separate tests.');
} catch (error) {
    console.error('Chord facet bundle is unavailable:', error);
    process.exitCode = 1;
} finally { rmSync(directory, { recursive: true, force: true }); }
