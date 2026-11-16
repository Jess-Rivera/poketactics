#!/usr/bin/env node
// Fetch Pokemon sprites from PMDCollab/SpriteCollab at one commit into source/spritecollab/ (same folder layout).
// These are the raw sheets; Godot never sees them. tools/pack_sprites.py packs them into assets/pokemon/.
// Which sets: every species' normal set, the mainline forms (2026-11-15-variant-scope), and the shiny of each.
// Which files: AnimData.xml, credits.txt, and the Anim, Offsets and Shadow sheets of the agreed animations
// (2026-11-15-animation-set). Every file is checked against the git blob hash in GitHub's listing.
// Also writes source/spritecollab/README.md (provenance note), CREDITS.md (artists per sprite set) and the license copy.
//
// Also keeps tracker.json (SpriteCollab's names for every folder), byte-exact, so tools/export_pack.py can match
// units to sprite sets.
//
// Portraits: the same sets' portrait/ folders (every emotion, flipped ^ and Special ones included, plus credits.txt)
// go byte-exact into source/spritecollab-portrait/, with their own README.md and CREDITS.md (#16).
//
// Usage: node tools/fetch-spritecollab.js <commit id> [--tracker-only] [--portraits-only]
//   --tracker-only refreshes just tracker.json at that commit, without re-fetching any sprite.
//   --portraits-only skips the sprite pass and fetches only the portraits.
// Needs a GitHub token for about 1,000 listing calls: GITHUB_TOKEN, or a logged-in gh CLI.
// Decision: docs/decisions/2026-11-15-sprite-sources.md

const childProcess = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Readable } = require('node:stream');
const { pipeline } = require('node:stream/promises');

const UPSTREAM_REPO = 'PMDCollab/SpriteCollab';
const REPO_ROOT = path.resolve(__dirname, '..');
const SPRITE_FOLDER = path.join(REPO_ROOT, 'source', 'spritecollab');
const PORTRAIT_FOLDER = path.join(REPO_ROOT, 'source', 'spritecollab-portrait');
const PARALLEL_LISTINGS = 8;

// SpriteCollab form names that are mainline forms we use; '' is the species' normal form.
const MAINLINE_FORM_NAMES = new Set([
  'Alola', 'Galar', 'Hisui', 'Paldea', 'Mega', 'Mega_X', 'Mega_Y', 'Mega_Z', 'Gigantamax', 'Primal',
]);
const SHINY_FOLDER = '0001';
const NORMAL_FORM_FOLDER = '0000';

// docs/discussion-outputs/sprites-primer.md, animation set table (core plus tactics extras).
const AGREED_ANIMATIONS = new Set([
  'Idle', 'Walk', 'Rotate', 'Attack', 'Swing', 'Double', 'Shoot', 'Charge', 'Hop', 'Hurt', 'Sleep',
  'Hover', 'Float', 'FlapAround',
  'Faint', 'Fainted',
  'Cringe', 'Pain', 'LostBalance', 'Trip', 'Tumble', 'TumbleBack', 'HitGround', 'Injured',
  'Withdraw',
  'EventSleep', 'Wake', 'Laying',
  'Strike', 'QuickStrike', 'MultiStrike', 'Slam', 'Bite', 'MultiScratch', 'Punch', 'Kick', 'Jab', 'Stomp',
  'Scratch', 'Slice', 'Chop', 'Uppercut', 'Slap', 'Lick', 'TailWhip',
  'SpAttack', 'Emit', 'Shock', 'Gas', 'Roar', 'Ricochet', 'Rumble', 'Swell', 'Shake',
  'LeapForth', 'Jump', 'DigIn', 'DigOut', 'Sink',
]);
const SHEET_KINDS = ['Anim', 'Offsets', 'Shadow'];
const METADATA_FILES = new Set(['AnimData.xml', 'credits.txt']);

function githubToken() {
  if (process.env.GITHUB_TOKEN) return process.env.GITHUB_TOKEN;
  try {
    return childProcess.execFileSync('gh', ['auth', 'token'], { encoding: 'utf8' }).trim();
  } catch {
    throw new Error('No GitHub token: set GITHUB_TOKEN or log in with gh');
  }
}

const apiHeaders = {
  'User-Agent': 'PokeTactics-fetch-spritecollab',
  Accept: 'application/vnd.github+json',
  Authorization: `Bearer ${githubToken()}`,
};

async function fetchJson(url) {
  for (let attempt = 1; ; attempt++) {
    const response = await fetch(url, { headers: apiHeaders });
    if (response.ok) return response.json();
    if (attempt >= 3) throw new Error(`GET ${url} failed: ${response.status}`);
    await new Promise((resolve) => setTimeout(resolve, 2000 * attempt));
  }
}

async function fetchRawText(commitId, repoPath) {
  const response = await fetch(`https://raw.githubusercontent.com/${UPSTREAM_REPO}/${commitId}/${repoPath}`);
  if (!response.ok) throw new Error(`GET ${repoPath} failed: ${response.status}`);
  return response.text();
}

function gitBlobHash(contentBytes) {
  const header = Buffer.from(`blob ${contentBytes.length}\0`);
  return crypto.createHash('sha1').update(header).update(contentBytes).digest('hex');
}

function isWantedFileName(fileName) {
  if (METADATA_FILES.has(fileName)) return true;
  const sheetMatch = /^(.+)-(Anim|Offsets|Shadow)\.png$/.exec(fileName);
  return Boolean(sheetMatch && AGREED_ANIMATIONS.has(sheetMatch[1]) && SHEET_KINDS.includes(sheetMatch[2]));
}

// Returns [{ folder: '0037/0001', label: 'Vulpix Alola' }, ...] for every set we want, shinies included.
function wantedSpriteSets(tracker) {
  const sets = [];
  for (const [dexFolder, species] of Object.entries(tracker)) {
    if (dexFolder === '0000') continue; // placeholder entry, not a Pokemon
    const subgroups = species.subgroups || {};
    sets.push({ folder: dexFolder, label: species.name });
    if (subgroups[NORMAL_FORM_FOLDER]?.subgroups?.[SHINY_FOLDER]) {
      sets.push({ folder: `${dexFolder}/${NORMAL_FORM_FOLDER}/${SHINY_FOLDER}`, label: `${species.name} Shiny` });
    }
    for (const [formFolder, form] of Object.entries(subgroups)) {
      if (formFolder === NORMAL_FORM_FOLDER || !MAINLINE_FORM_NAMES.has(form.name)) continue;
      sets.push({ folder: `${dexFolder}/${formFolder}`, label: `${species.name} ${form.name}` });
      if (form.subgroups?.[SHINY_FOLDER]) {
        sets.push({
          folder: `${dexFolder}/${formFolder}/${SHINY_FOLDER}`,
          label: `${species.name} ${form.name} Shiny`,
        });
      }
    }
  }
  return sets;
}

// Lists every file under <tree root>/<dex folder> (root 'sprite' or 'portrait') with its blob hash; one API call
// per dex folder.
async function listUpstreamFiles(commitId, treeRoot) {
  const topTree = await fetchJson(`https://api.github.com/repos/${UPSTREAM_REPO}/git/trees/${commitId}:${treeRoot}`);
  const dexFolders = topTree.tree.filter((entry) => entry.type === 'tree');
  const fileHashByPath = new Map();
  const pending = [...dexFolders];
  async function listingWorker() {
    while (pending.length > 0) {
      const dexFolder = pending.shift();
      const subtree = await fetchJson(
        `https://api.github.com/repos/${UPSTREAM_REPO}/git/trees/${dexFolder.sha}?recursive=1`,
      );
      if (subtree.truncated) throw new Error(`Listing truncated for ${dexFolder.path}`);
      for (const entry of subtree.tree) {
        if (entry.type === 'blob') fileHashByPath.set(`${dexFolder.path}/${entry.path}`, entry.sha);
      }
    }
  }
  await Promise.all(Array.from({ length: PARALLEL_LISTINGS }, listingWorker));
  return fileHashByPath;
}

async function downloadArchive(commitId, archivePath) {
  if (fs.existsSync(archivePath)) {
    console.log(`Reusing downloaded archive ${archivePath}`);
    return;
  }
  const url = `https://codeload.github.com/${UPSTREAM_REPO}/tar.gz/${commitId}`;
  console.log(`Downloading ${url} (whole repo at this commit, can take a while)`);
  const response = await fetch(url, { headers: { 'User-Agent': apiHeaders['User-Agent'] } });
  if (!response.ok) throw new Error(`Archive download failed: ${response.status}`);
  const partialPath = `${archivePath}.partial`;
  await pipeline(Readable.fromWeb(response.body), fs.createWriteStream(partialPath));
  fs.renameSync(partialPath, archivePath);
}

function parseCreditNames(creditNamesText) {
  const nameById = new Map();
  for (const line of creditNamesText.split(/\r?\n/).slice(1)) {
    const [name, creditId, contact] = line.split('\t');
    if (creditId) nameById.set(creditId, { name, contact: contact && contact.startsWith('http') ? contact : '' });
  }
  return nameById;
}

// credits.txt lines: date, credit id, CUR or OLD, note, animations. Returns the distinct credited names.
function creditedNames(creditsText, nameById) {
  const names = new Set();
  for (const line of creditsText.split(/\r?\n/)) {
    const creditId = line.split('\t')[1];
    if (!creditId) continue;
    names.add(nameById.get(creditId)?.name || creditId);
  }
  return [...names];
}

// Extracts the wanted files of one tree root ('sprite' or 'portrait') from the archive, checks each against its
// upstream blob hash, writes it under destinationFolder and returns the set of local paths written.
function extractVerified(context, treeRoot, wantedFiles, destinationFolder) {
  const { workFolder, archivePath, archiveRoot } = context;
  const extractFolder = path.join(workFolder, `extract-${treeRoot}`);
  fs.rmSync(extractFolder, { recursive: true, force: true });
  fs.mkdirSync(extractFolder, { recursive: true });
  const memberListPath = path.join(workFolder, `members-${treeRoot}.txt`);
  fs.writeFileSync(memberListPath, wantedFiles.map((file) => `${archiveRoot}/${treeRoot}/${file.filePath}`).join('\n'));
  console.log(`Extracting the wanted ${treeRoot} files`);
  // Relative paths from inside the work folder: GNU tar reads "C:\..." as a remote host name.
  childProcess.execFileSync(
    'tar',
    ['-xzf', path.basename(archivePath), '-C', path.basename(extractFolder), '-T', path.basename(memberListPath)],
    { stdio: 'inherit', cwd: workFolder },
  );

  const hashMismatches = [];
  const wantedLocalPaths = new Set();
  for (const { filePath, blobHash } of wantedFiles) {
    const extractedBytes = fs.readFileSync(path.join(extractFolder, archiveRoot, treeRoot, filePath));
    if (gitBlobHash(extractedBytes) !== blobHash) {
      hashMismatches.push(filePath);
      continue;
    }
    const destination = path.join(destinationFolder, filePath);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, extractedBytes);
    wantedLocalPaths.add(path.normalize(destination));
  }
  if (hashMismatches.length > 0) throw new Error(`Hash mismatch: ${hashMismatches.slice(0, 20).join(', ')}`);
  console.log(`${wantedFiles.length} ${treeRoot} files verified and written`);
  return wantedLocalPaths;
}

// Removes files from an earlier pin that are no longer wanted (only file types this script writes).
function sweepUnwanted(rootFolder, wantedLocalPaths, generatedTopFiles) {
  let removedCount = 0;
  function sweep(folder) {
    for (const entry of fs.readdirSync(folder, { withFileTypes: true })) {
      const entryPath = path.join(folder, entry.name);
      if (entry.isDirectory()) {
        sweep(entryPath);
        if (fs.readdirSync(entryPath).length === 0) fs.rmdirSync(entryPath);
      } else if (folder === rootFolder && generatedTopFiles.has(entry.name)) {
        continue;
      } else if (/\.(png|xml|txt)$/.test(entry.name) && !wantedLocalPaths.has(path.normalize(entryPath))) {
        fs.unlinkSync(entryPath);
        removedCount++;
      }
    }
  }
  sweep(rootFolder);
  if (removedCount > 0) console.log(`Removed ${removedCount} files no longer wanted`);
}

// The artist list and the per-set table, from each present set's credits.txt.
function creditSections(rootFolder, presentSets, nameById, setHeading) {
  const sortedSets = [...presentSets].sort((first, second) => first.folder.localeCompare(second.folder));
  const creditedIds = new Set();
  const creditLines = sortedSets.map((set) => {
    const creditsPath = path.join(rootFolder, set.folder, 'credits.txt');
    const creditsText = fs.existsSync(creditsPath) ? fs.readFileSync(creditsPath, 'utf8') : '';
    for (const line of creditsText.split(/\r?\n/)) if (line.split('\t')[1]) creditedIds.add(line.split('\t')[1]);
    return `| ${set.folder} | ${set.label} | ${creditedNames(creditsText, nameById).join(', ')} |`;
  });
  const artistLines = [...creditedIds]
    .map((creditId) => nameById.get(creditId) || { name: creditId, contact: '' })
    .sort((first, second) => first.name.localeCompare(second.name))
    .map((artist) => `- ${artist.name}${artist.contact ? ` (${artist.contact})` : ''}`);
  return [
    `## Artists (${artistLines.length})`,
    '',
    ...artistLines,
    '',
    `## Per ${setHeading.toLowerCase()} (${creditLines.length})`,
    '',
    `| Folder | ${setHeading} | Credited |`,
    '|---|---|---|',
    ...creditLines,
    '',
  ];
}

async function spritePass(context) {
  const { commitId, commitDate, tracker, nameById, licenseText } = context;
  console.log('Listing upstream sprite files');
  const fileHashByPath = await listUpstreamFiles(commitId, 'sprite');
  const allSets = wantedSpriteSets(tracker);
  const presentSets = allSets.filter((set) => fileHashByPath.has(`${set.folder}/AnimData.xml`));
  const missingSets = allSets.filter((set) => !fileHashByPath.has(`${set.folder}/AnimData.xml`));
  const presentFolders = new Set(presentSets.map((set) => set.folder));

  const wantedFiles = [];
  for (const [filePath, blobHash] of fileHashByPath) {
    const slash = filePath.lastIndexOf('/');
    if (presentFolders.has(filePath.slice(0, slash)) && isWantedFileName(filePath.slice(slash + 1))) {
      wantedFiles.push({ filePath, blobHash });
    }
  }
  console.log(`${presentSets.length} sprite sets with sprites, ${missingSets.length} without, ${wantedFiles.length} files`);

  const wantedLocalPaths = extractVerified(context, 'sprite', wantedFiles, SPRITE_FOLDER);
  sweepUnwanted(
    SPRITE_FOLDER,
    wantedLocalPaths,
    new Set(['README.md', 'CREDITS.md', 'LICENSE-SpriteCollab.md', 'tracker.json']),
  );

  fs.writeFileSync(
    path.join(SPRITE_FOLDER, 'CREDITS.md'),
    [
      '# Sprite credits (generated by tools/fetch-spritecollab.js, do not edit by hand)',
      '',
      `Sprites from [SpriteCollab](https://github.com/${UPSTREAM_REPO}) at commit ${commitId},`,
      'licensed CC BY-NC 4.0 (LICENSE-SpriteCollab.md). CHUNSOFT marks sprites from the original Pokemon Mystery',
      'Dungeon games by Spike Chunsoft.',
      '',
      ...creditSections(SPRITE_FOLDER, presentSets, nameById, 'Sprite set'),
    ].join('\n'),
  );
  fs.writeFileSync(path.join(SPRITE_FOLDER, 'LICENSE-SpriteCollab.md'), licenseText);
  fs.writeFileSync(
    path.join(SPRITE_FOLDER, 'README.md'),
    [
      '# source/spritecollab (raw SpriteCollab sprites, do not edit by hand)',
      '',
      `Copied byte-exact from sprite/ of https://github.com/${UPSTREAM_REPO}, same folder layout`,
      '(dex number, then form, then 0001 for shiny; tracker.json upstream names every folder).',
      '',
      '| | |',
      '|---|---|',
      `| Commit | ${commitId} |`,
      `| Commit date | ${commitDate.slice(0, 10)} |`,
      `| Fetched | ${new Date().toISOString().slice(0, 10)} |`,
      `| Sprite sets | ${presentSets.length} (shinies included) |`,
      `| Files | ${wantedFiles.length} |`,
      `| Sets wanted but without sprites upstream | ${missingSets.length} |`,
      '',
      'Animations: the agreed set only (docs/decisions/2026-11-15-animation-set.md). AnimData.xml is kept whole, so',
      'it can name animations whose sheets were not fetched.',
      '',
      'License: CC BY-NC 4.0, see LICENSE-SpriteCollab.md; artists in CREDITS.md here.',
      '',
      'Re-pin (on purpose, as its own issue): `node tools/fetch-spritecollab.js <commit id>`.',
      '',
      '## Sets without sprites upstream',
      '',
      ...missingSets.map((set) => `- ${set.folder} ${set.label}`),
      '',
    ].join('\n'),
  );
  console.log('Wrote source/spritecollab/README.md, CREDITS.md and LICENSE-SpriteCollab.md');
}

// Portraits of the same sets: every emotion PNG (flipped ^ and Special ones included) and credits.txt, taken only
// from files directly in the set's folder (a set folder's subfolders are other sets).
async function portraitPass(context) {
  const { commitId, commitDate, tracker, nameById, licenseText } = context;
  console.log('Listing upstream portrait files');
  const fileHashByPath = await listUpstreamFiles(commitId, 'portrait');
  const allSets = wantedSpriteSets(tracker);
  const presentSets = allSets.filter((set) => fileHashByPath.has(`${set.folder}/Normal.png`));
  const missingSets = allSets.filter((set) => !fileHashByPath.has(`${set.folder}/Normal.png`));
  const presentFolders = new Set(presentSets.map((set) => set.folder));

  const wantedFiles = [];
  for (const [filePath, blobHash] of fileHashByPath) {
    const slash = filePath.lastIndexOf('/');
    const fileName = filePath.slice(slash + 1);
    if (presentFolders.has(filePath.slice(0, slash)) && (fileName.endsWith('.png') || fileName === 'credits.txt')) {
      wantedFiles.push({ filePath, blobHash });
    }
  }
  console.log(`${presentSets.length} sets with portraits, ${missingSets.length} without, ${wantedFiles.length} files`);

  fs.mkdirSync(PORTRAIT_FOLDER, { recursive: true });
  const wantedLocalPaths = extractVerified(context, 'portrait', wantedFiles, PORTRAIT_FOLDER);
  sweepUnwanted(PORTRAIT_FOLDER, wantedLocalPaths, new Set(['README.md', 'CREDITS.md', 'LICENSE-SpriteCollab.md']));

  fs.writeFileSync(
    path.join(PORTRAIT_FOLDER, 'CREDITS.md'),
    [
      '# Portrait credits (generated by tools/fetch-spritecollab.js, do not edit by hand)',
      '',
      `Portraits from [SpriteCollab](https://github.com/${UPSTREAM_REPO}) at commit ${commitId},`,
      'licensed CC BY-NC 4.0 (LICENSE-SpriteCollab.md). CHUNSOFT marks portraits from the original Pokemon Mystery',
      'Dungeon games by Spike Chunsoft.',
      '',
      ...creditSections(PORTRAIT_FOLDER, presentSets, nameById, 'Portrait set'),
    ].join('\n'),
  );
  fs.writeFileSync(path.join(PORTRAIT_FOLDER, 'LICENSE-SpriteCollab.md'), licenseText);
  fs.writeFileSync(
    path.join(PORTRAIT_FOLDER, 'README.md'),
    [
      '# source/spritecollab-portrait (raw SpriteCollab portraits, do not edit by hand)',
      '',
      `Copied byte-exact from portrait/ of https://github.com/${UPSTREAM_REPO}, same folder layout as`,
      'source/spritecollab (dex number, then form, then 0001 for shiny; names in source/spritecollab/tracker.json).',
      'Each file is one 40x40 portrait named by emotion; a trailing ^ marks the flipped version.',
      '',
      '| | |',
      '|---|---|',
      `| Commit | ${commitId} |`,
      `| Commit date | ${commitDate.slice(0, 10)} |`,
      `| Fetched | ${new Date().toISOString().slice(0, 10)} |`,
      `| Portrait sets | ${presentSets.length} (shinies included) |`,
      `| Files | ${wantedFiles.length} |`,
      `| Sets wanted but without portraits upstream | ${missingSets.length} |`,
      '',
      'License: CC BY-NC 4.0, see LICENSE-SpriteCollab.md; artists in CREDITS.md here.',
      'Packed for Godot by tools/pack_portraits.py into assets/portraits/.',
      '',
      '## Sets without portraits upstream',
      '',
      ...missingSets.map((set) => `- ${set.folder} ${set.label}`),
      '',
    ].join('\n'),
  );
  console.log('Wrote source/spritecollab-portrait/README.md, CREDITS.md and LICENSE-SpriteCollab.md');
}

async function main() {
  const requestedCommit = process.argv[2];
  if (!requestedCommit) {
    console.error('Usage: node tools/fetch-spritecollab.js <commit id> [--tracker-only] [--portraits-only]');
    process.exit(1);
  }

  const commitInfo = await fetchJson(`https://api.github.com/repos/${UPSTREAM_REPO}/commits/${requestedCommit}`);
  const commitId = commitInfo.sha;
  const commitDate = commitInfo.commit.committer.date;
  console.log(`Commit ${commitId} (${commitDate})`);

  const trackerText = await fetchRawText(commitId, 'tracker.json');
  fs.mkdirSync(SPRITE_FOLDER, { recursive: true });
  fs.writeFileSync(path.join(SPRITE_FOLDER, 'tracker.json'), trackerText);
  console.log('tracker.json written');
  if (process.argv.includes('--tracker-only')) return;

  const workFolder = path.join(os.tmpdir(), `poketactics-spritecollab-${commitId.slice(0, 12)}`);
  fs.mkdirSync(workFolder, { recursive: true });
  const archivePath = path.join(workFolder, 'spritecollab.tar.gz');
  await downloadArchive(commitId, archivePath);

  const context = {
    commitId,
    commitDate,
    tracker: JSON.parse(trackerText),
    nameById: parseCreditNames(await fetchRawText(commitId, 'credit_names.txt')),
    licenseText: await fetchRawText(commitId, 'LICENSE.md'),
    workFolder,
    archivePath,
    archiveRoot: `SpriteCollab-${commitId}`,
  };
  if (!process.argv.includes('--portraits-only')) await spritePass(context);
  await portraitPass(context);
  console.log('Next: python tools/pack_sprites.py and python tools/pack_portraits.py');
  console.log(`Archive kept for reruns: ${archivePath}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
