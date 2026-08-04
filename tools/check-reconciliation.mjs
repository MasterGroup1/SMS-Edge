#!/usr/bin/env node
/**
 * Reconciliation guard.
 *
 * Alex's rule: "If it doesn't sum up to the summary, the data is not correct."
 *
 * This asserts the dashboard has exactly ONE source of truth for every number:
 * the raw `campaigns` rows. Any pre-aggregated array baked in alongside them is
 * a second source that silently goes stale the moment the campaign data is
 * refreshed — which is exactly what happened when the 200-row snapshot was
 * replaced with the full historical export and the summary arrays were left
 * behind, making every Countries/Brands/List total read ~8x too low.
 *
 * Run: npm test
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const file = path.join(root, 'index.html');
const src = fs.readFileSync(file, 'utf8');

let failures = 0;
const pass = (m) => console.log(`  [32m✓[0m ${m}`);
const fail = (m, detail) => {
  failures++;
  console.log(`  [31m✗ ${m}[0m`);
  if (detail) String(detail).split('\n').forEach((l) => console.log(`      ${l}`));
};

function extractArray(name) {
  const m = src.match(new RegExp(`^const ${name} = (\\[.*\\]);\\s*(?://.*)?$`, 'm'));
  return m ? JSON.parse(m[1]) : null;
}

console.log('\nReconciliation guard — index.html\n');

// ── 1. No pre-aggregated arrays may be baked in alongside `campaigns` ────────
console.log('Single source of truth:');
const FORBIDDEN = ['countries', 'brands', 'lists', 'combos'];
for (const name of FORBIDDEN) {
  const arr = extractArray(name);
  if (arr) {
    fail(
      `\`const ${name}\` is a baked pre-aggregated array (${arr.length} rows)`,
      'It duplicates numbers derived from `campaigns` and cannot be kept in sync.\n' +
        'Derive it at runtime in recomputeAggregates() instead.'
    );
  } else {
    pass(`no baked \`${name}\` array`);
  }
}

// ── 2. Render functions must not overwrite recomputed aggregates ────────────
console.log('\nRender functions honour recomputeAggregates():');
const OVERWRITES = [
  [/filteredCountries\s*=\s*countries\s*;/, 'filteredCountries = countries'],
  [/filteredBrands\s*=\s*brands\s*;/, 'filteredBrands = brands'],
  [/filteredLists\s*=\s*lists\s*;/, 'filteredLists = lists'],
];
for (const [re, label] of OVERWRITES) {
  const m = src.match(re);
  if (m) {
    const line = src.slice(0, m.index).split('\n').length;
    fail(`\`${label}\` at index.html:${line}`, 'Discards the recomputed aggregate and renders stale baked data.');
  } else {
    pass(`no \`${label}\` overwrite`);
  }
}

// ── 3. Aggregates derived from campaigns must reconcile with the raw rows ───
console.log('\nSummaries reconcile with campaign detail:');
const campaigns = extractArray('campaigns');
if (!campaigns) {
  fail('could not extract `campaigns` from index.html');
} else {
  pass(`campaigns dataset present (${campaigns.length} rows)`);

  const FIELDS = ['sent', 'clicks', 'leads', 'sales', 'cost'];
  const sum = (rows, f) => rows.reduce((s, r) => s + (Number(r[f]) || 0), 0);
  const near = (a, b) => Math.abs(a - b) < 0.01;

  // Grouping by a key must preserve every field total across rows that carry
  // that key. If it doesn't, the grouping is dropping or double-counting rows.
  const checkGrouping = (label, keyFn) => {
    const withKey = campaigns.filter((c) => keyFn(c));
    const groups = {};
    for (const c of withKey) {
      const g = (groups[keyFn(c)] ??= { camps: 0 });
      g.camps += 1;
      for (const f of FIELDS) g[f] = (g[f] || 0) + (Number(c[f]) || 0);
    }
    const rows = Object.values(groups);
    const bad = [];
    if (sum(rows, 'camps') !== withKey.length) {
      bad.push(`camps: grouped=${sum(rows, 'camps')} vs rows=${withKey.length}`);
    }
    for (const f of FIELDS) {
      if (!near(sum(rows, f), sum(withKey, f))) {
        bad.push(`${f}: grouped=${sum(rows, f).toFixed(2)} vs rows=${sum(withKey, f).toFixed(2)}`);
      }
    }
    if (bad.length) fail(`${label} grouping does not reconcile`, bad.join('\n'));
    else pass(`${label} grouping reconciles (${rows.length} groups, ${withKey.length} rows)`);
  };

  checkGrouping('country', (c) => c.country);
  checkGrouping('brand', (c) => c.brand);

  const totals = FIELDS.map((f) => `${f}=${sum(campaigns, f).toLocaleString('en-US', { maximumFractionDigits: 2 })}`);
  console.log(`\n  Dataset totals: ${campaigns.length} campaigns, ${totals.join(', ')}`);
}

// ── 4. Every Supabase write must check its error ────────────────────────────
// The client returns { error } rather than throwing, so an unchecked write
// silently discards data: the UI updates and nothing persists.
console.log('\nSupabase writes are error-checked:');
{
  const WRITES = /sb\s*\.from\([^)]*\)\s*\.\s*(upsert|insert|update|delete)\b/g;
  const unchecked = [];
  for (const m of src.matchAll(WRITES)) {
    // Walk back over whitespace/await to see how the statement begins.
    const before = src.slice(Math.max(0, m.index - 240), m.index);
    const wrapped = /dbWrite\(\s*(['"`])[\s\S]*?\1\s*,\s*$/.test(before);
    const destructured = /const\s*\{[^}]*error[^}]*\}\s*=\s*await\s*$/.test(before);
    if (!wrapped && !destructured) {
      unchecked.push({ line: src.slice(0, m.index).split('\n').length, op: m[0].replace(/\s+/g, '') });
    }
  }
  if (unchecked.length) {
    fail(
      `${unchecked.length} Supabase write(s) ignore the returned error`,
      unchecked.map((u) => `index.html:${u.line}  ${u.op}`).join('\n') +
        '\nWrap in dbWrite(label, query) or destructure { error } and handle it.'
    );
  } else {
    pass('all Supabase writes are wrapped or error-checked');
  }
}

console.log(
  failures === 0
    ? '\n[32mAll reconciliation checks passed.[0m\n'
    : `\n[31m${failures} reconciliation check(s) failed.[0m\n`
);
process.exit(failures === 0 ? 0 : 1);
