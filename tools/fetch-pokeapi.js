#!/usr/bin/env node
// Fetch the raw pokeapi CSVs (data/v2/csv) at one upstream commit into source/pokeapi/csv/.
// Every file is checked against the git blob hash GitHub lists for that commit, so the copy is byte-exact.
// Also writes source/pokeapi/README.md (the provenance "PIN" note) and source/.gdignore (Godot skips source/).
//
// Usage: node tools/fetch-pokeapi.js <commit id>
// Re-pinning is the same command with a new commit id; files gone upstream are removed and listed.
// Decision: docs/decisions/2026-11-15-pokeapi-source.md

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const UPSTREAM_REPO = 'PokeAPI/pokeapi';
const UPSTREAM_FOLDER = 'data/v2/csv';
const REPO_ROOT = path.resolve(__dirname, '..');
const SOURCE_FOLDER = path.join(REPO_ROOT, 'source');
const PIN_FOLDER = path.join(SOURCE_FOLDER, 'pokeapi');
const CSV_FOLDER = path.join(PIN_FOLDER, 'csv');
const PARALLEL_DOWNLOADS = 8;
const DOWNLOAD_ATTEMPTS = 3;

const requestHeaders = { 'User-Agent': 'PokeTactics-fetch-pokeapi', Accept: 'application/vnd.github+json' };
if (process.env.GITHUB_TOKEN) requestHeaders.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;

async function fetchJson(url) {
  const response = await fetch(url, { headers: requestHeaders });
  if (!response.ok) throw new Error(`GET ${url} failed: ${response.status} ${await response.text()}`);
  return response.json();
}

async function fetchBytes(url) {
  let lastError;
  for (let attempt = 1; attempt <= DOWNLOAD_ATTEMPTS; attempt++) {
    try {
      const response = await fetch(url, { headers: { 'User-Agent': requestHeaders['User-Agent'] } });
      if (!response.ok) throw new Error(`GET ${url} failed: ${response.status}`);
      return Buffer.from(await response.arrayBuffer());
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError;
}

// Same hash git uses for a file's content, which is what GitHub's listing reports as "sha".
function gitBlobHash(contentBytes) {
  const header = Buffer.from(`blob ${contentBytes.length}\0`);
  return crypto.createHash('sha1').update(header).update(contentBytes).digest('hex');
}

async function main() {
  const requestedCommit = process.argv[2];
  if (!requestedCommit) {
    console.error('Usage: node tools/fetch-pokeapi.js <commit id>');
    process.exit(1);
  }

  const commitInfo = await fetchJson(`https://api.github.com/repos/${UPSTREAM_REPO}/commits/${requestedCommit}`);
  const commitId = commitInfo.sha;
  const commitDate = commitInfo.commit.committer.date;
  console.log(`Commit ${commitId} (${commitDate})`);

  const listing = await fetchJson(
    `https://api.github.com/repos/${UPSTREAM_REPO}/contents/${UPSTREAM_FOLDER}?ref=${commitId}`,
  );
  const upstreamCsvFiles = listing.filter((entry) => entry.type === 'file' && entry.name.endsWith('.csv'));
  if (upstreamCsvFiles.length === 0) throw new Error('Upstream listing has no CSV files');
  console.log(`${upstreamCsvFiles.length} CSV files listed upstream`);

  fs.mkdirSync(CSV_FOLDER, { recursive: true });

  const pendingFiles = [...upstreamCsvFiles];
  const hashMismatches = [];
  let downloadedCount = 0;
  async function downloadWorker() {
    while (pendingFiles.length > 0) {
      const entry = pendingFiles.shift();
      const rawUrl = `https://raw.githubusercontent.com/${UPSTREAM_REPO}/${commitId}/${UPSTREAM_FOLDER}/${entry.name}`;
      const contentBytes = await fetchBytes(rawUrl);
      if (gitBlobHash(contentBytes) !== entry.sha) {
        hashMismatches.push(entry.name);
        continue;
      }
      fs.writeFileSync(path.join(CSV_FOLDER, entry.name), contentBytes);
      downloadedCount++;
    }
  }
  await Promise.all(Array.from({ length: PARALLEL_DOWNLOADS }, downloadWorker));
  if (hashMismatches.length > 0) {
    throw new Error(`Hash mismatch, not written: ${hashMismatches.join(', ')}`);
  }
  console.log(`${downloadedCount} files downloaded and verified`);

  const upstreamNames = new Set(upstreamCsvFiles.map((entry) => entry.name));
  const removedNames = fs.readdirSync(CSV_FOLDER).filter((name) => !upstreamNames.has(name));
  for (const name of removedNames) fs.unlinkSync(path.join(CSV_FOLDER, name));
  if (removedNames.length > 0) console.log(`Removed (gone upstream): ${removedNames.join(', ')}`);

  const fetchDate = new Date().toISOString().slice(0, 10);
  const provenanceNote = [
    '# source/pokeapi (raw pokeapi data, do not edit by hand)',
    '',
    `Raw CSVs from ${UPSTREAM_FOLDER} of https://github.com/${UPSTREAM_REPO}, copied byte-exact.`,
    '',
    '| | |',
    '|---|---|',
    `| Commit | ${commitId} |`,
    `| Commit date | ${commitDate.slice(0, 10)} |`,
    `| Fetched | ${fetchDate} |`,
    `| Files | ${upstreamCsvFiles.length} CSVs in csv/ |`,
    '',
    'License: PokeAPI is BSD-licensed (see the upstream LICENSE.md). Pokemon and Pokemon character names are',
    'trademarks of Nintendo. Credited in CREDITS.md.',
    '',
    `Re-pin (on purpose, as its own issue): \`node tools/fetch-pokeapi.js <commit id>\`.`,
    'Decision: docs/decisions/2026-11-15-pokeapi-source.md',
    '',
  ].join('\n');
  fs.writeFileSync(path.join(PIN_FOLDER, 'README.md'), provenanceNote);
  fs.writeFileSync(path.join(SOURCE_FOLDER, '.gdignore'), '');
  console.log('Wrote source/pokeapi/README.md and source/.gdignore');
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
