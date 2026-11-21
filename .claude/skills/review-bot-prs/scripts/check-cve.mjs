#!/usr/bin/env node
// Check known vulnerabilities (CVE / GHSA) for dependency versions using the
// OSV database (https://osv.dev), which aggregates the GitHub Advisory
// Database, NVD and others.
//
// Usage:
//   node check-cve.mjs <name>@<version> [...]            # npm packages
//   node check-cve.mjs --ecosystem "GitHub Actions" actions/checkout@4.2.0
//   node check-cve.mjs --git <base-ref> <head-ref>        # every npm package and
//                                                         # GitHub Action whose
//                                                         # version changed
// Options:
//   --json         Print machine-readable JSON instead of a text report.
//
// Exit codes: 0 = no known vulnerabilities, 1 = vulnerabilities found,
//             2 = usage or network error.

import { execFileSync } from 'node:child_process';

const OSV_BATCH_URL = 'https://api.osv.dev/v1/querybatch';
const OSV_VULN_URL = 'https://api.osv.dev/v1/vulns/';
const BATCH_SIZE = 500;

function usage(message) {
  if (message) console.error(`error: ${message}`);
  console.error(
    'usage: check-cve.mjs [--json] [--ecosystem <eco>] <name>@<version> ...\n' +
      '       check-cve.mjs [--json] --git <base-ref> <head-ref>',
  );
  process.exit(2);
}

function parseSpec(spec, ecosystem) {
  // Split on the last '@' so scoped packages (@scope/name@1.0.0) work.
  const at = spec.lastIndexOf('@');
  if (at <= 0) usage(`invalid spec "${spec}", expected <name>@<version>`);
  return { ecosystem, name: spec.slice(0, at), version: spec.slice(at + 1), from: null };
}

function gitShow(ref, path) {
  try {
    return execFileSync('git', ['show', `${ref}:${path}`], {
      encoding: 'utf8',
      maxBuffer: 256 * 1024 * 1024,
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  } catch {
    return null;
  }
}

function gitLsFiles(ref, dir) {
  try {
    return execFileSync('git', ['ls-tree', '-r', '--name-only', ref, '--', dir], {
      encoding: 'utf8',
    })
      .split('\n')
      .filter((f) => /\.ya?ml$/.test(f));
  } catch {
    return [];
  }
}

// Map "name" -> Set(versions) from a package-lock.json (lockfileVersion 2/3).
function lockPackages(text) {
  const result = new Map();
  if (!text) return result;
  const lock = JSON.parse(text);
  for (const [path, info] of Object.entries(lock.packages ?? {})) {
    if (!path || !info.version || info.link) continue;
    const name =
      info.name ?? path.slice(path.lastIndexOf('node_modules/') + 'node_modules/'.length);
    if (!result.has(name)) result.set(name, new Set());
    result.get(name).add(info.version);
  }
  return result;
}

// Map "owner/repo" -> Set(versions) from workflow files. The version is taken
// from the ref (`@v4.2.0`) or, for SHA-pinned actions, from the trailing
// comment (`@<sha> # v4.2.0`).
function workflowActions(ref) {
  const result = new Map();
  const re = /uses:\s*['"]?([\w.-]+\/[\w.-]+)(?:\/[^@\s'"]*)?@([^\s'"#]+)['"]?(?:\s*#\s*(\S+))?/g;
  for (const file of gitLsFiles(ref, '.github/workflows')) {
    const text = gitShow(ref, file) ?? '';
    for (const m of text.matchAll(re)) {
      const [, name, gitRef, comment] = m;
      const raw = /^[0-9a-f]{40}$/.test(gitRef) ? comment : gitRef;
      if (!raw) continue;
      const version = raw.replace(/^v/, '');
      if (!/^\d+(\.\d+){0,2}/.test(version)) continue;
      if (!result.has(name)) result.set(name, new Set());
      result.get(name).add(version);
    }
  }
  return result;
}

function changedEntries(base, head, ecosystem) {
  const entries = [];
  for (const [name, versions] of head) {
    const before = base.get(name) ?? new Set();
    for (const version of versions) {
      if (before.has(version)) continue;
      entries.push({ ecosystem, name, version, from: [...before].join(', ') || null });
    }
  }
  return entries;
}

function collectFromGit(baseRef, headRef) {
  const npmBase = lockPackages(gitShow(baseRef, 'package-lock.json'));
  const npmHead = lockPackages(gitShow(headRef, 'package-lock.json'));
  return [
    ...changedEntries(npmBase, npmHead, 'npm'),
    ...changedEntries(workflowActions(baseRef), workflowActions(headRef), 'GitHub Actions'),
  ];
}

async function postJson(url, body) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  return res.json();
}

async function getJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  return res.json();
}

function severityOf(vuln) {
  return (
    vuln.database_specific?.severity ??
    vuln.affected?.find((a) => a.ecosystem_specific?.severity)?.ecosystem_specific.severity ??
    vuln.severity?.[0]?.score ??
    'UNKNOWN'
  );
}

function fixedVersionsOf(vuln, entry) {
  const fixed = new Set();
  for (const affected of vuln.affected ?? []) {
    if (affected.package?.name !== entry.name) continue;
    for (const range of affected.ranges ?? []) {
      for (const event of range.events ?? []) if (event.fixed) fixed.add(event.fixed);
    }
  }
  return [...fixed];
}

async function check(entries) {
  const ids = [];
  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const chunk = entries.slice(i, i + BATCH_SIZE);
    const { results } = await postJson(OSV_BATCH_URL, {
      queries: chunk.map((e) => ({
        package: { name: e.name, ecosystem: e.ecosystem },
        version: e.version,
      })),
    });
    for (const r of results) ids.push((r.vulns ?? []).map((v) => v.id));
  }

  const cache = new Map();
  const findings = [];
  for (const [i, entry] of entries.entries()) {
    const vulns = [];
    for (const id of ids[i]) {
      if (!cache.has(id)) cache.set(id, await getJson(OSV_VULN_URL + encodeURIComponent(id)));
      const v = cache.get(id);
      if (v.withdrawn) continue;
      vulns.push({
        id: v.id,
        aliases: v.aliases ?? [],
        severity: severityOf(v),
        summary: v.summary ?? '',
        fixed: fixedVersionsOf(v, entry),
        url: `https://osv.dev/vulnerability/${v.id}`,
      });
    }
    findings.push({ ...entry, vulns });
  }
  return findings;
}

function printText(findings) {
  if (findings.length === 0) {
    console.log('No changed dependency versions to check.');
    return;
  }
  const vulnerable = findings.filter((f) => f.vulns.length > 0);
  console.log(`Checked ${findings.length} package version(s) against OSV.`);
  for (const f of findings) {
    const from = f.from ? `${f.from} -> ` : '';
    const status = f.vulns.length ? `VULNERABLE (${f.vulns.length})` : 'ok';
    if (f.vulns.length || findings.length <= 30) {
      console.log(`  [${f.ecosystem}] ${f.name} ${from}${f.version}: ${status}`);
    }
    for (const v of f.vulns) {
      const cves = v.aliases.filter((a) => a.startsWith('CVE-')).join(', ');
      console.log(`      - ${v.id}${cves ? ` (${cves})` : ''} [${v.severity}] ${v.summary}`);
      console.log(`        fixed in: ${v.fixed.join(', ') || 'no fix available'}  ${v.url}`);
    }
  }
  if (findings.length > 30) {
    console.log(`  (${findings.length - vulnerable.length} package(s) without findings omitted)`);
  }
  console.log(
    vulnerable.length
      ? `RESULT: ${vulnerable.length} package version(s) have known vulnerabilities.`
      : 'RESULT: no known vulnerabilities.',
  );
}

async function main() {
  const args = process.argv.slice(2);
  let json = false;
  let ecosystem = 'npm';
  let git = null;
  const specs = [];
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--json') json = true;
    else if (a === '--ecosystem') ecosystem = args[++i] ?? usage('--ecosystem needs a value');
    else if (a === '--git') {
      git = [args[++i], args[++i]];
      if (!git[0] || !git[1]) usage('--git needs <base-ref> <head-ref>');
    } else if (a === '-h' || a === '--help') usage();
    else specs.push(a);
  }
  if (!git && specs.length === 0) usage('no packages given');

  const entries = git ? collectFromGit(...git) : specs.map((s) => parseSpec(s, ecosystem));
  const findings = entries.length ? await check(entries) : [];

  if (json) console.log(JSON.stringify(findings, null, 2));
  else printText(findings);
  process.exit(findings.some((f) => f.vulns.length > 0) ? 1 : 0);
}

main().catch((err) => {
  console.error(`error: ${err.message}`);
  process.exit(2);
});
