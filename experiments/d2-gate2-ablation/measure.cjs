#!/usr/bin/env node
// D2 experiment measurement. Reads Claude Code session transcripts named in a
// manifest and reports tokens, estimated dollars, elapsed and active time, and the
// run events the decision rule needs: per shared gate-2 stage, per run, and per arm.
//
// Reads message content only to classify run events (a subagent's verdict line,
// NEEDS_CONTEXT, BLOCKED). It never prints content.
//
// usage: node measure.cjs <manifest.json> [--json]
//
// Manifest:
// {
//   "projectsDir": "C:/Users/Brett/.claude/projects",
//   "shared": { "plan-writing": [id], "gate2-r1": [id], "fix-r1": [id], "gate2-r2": [id], ... },
//   "arms": { "none": { "snapshot": "d2-S0", "plan": "<path>" }, "round1": {...}, "full": {...} },
//   "runs": { "none-1": { "arm": "none", "stages": { "execution": [id], "preflight-fix": [id] },
//                         "infra": [ids of execution sessions that ended on an infra stop] } }
// }
// Charging: none gets plan-writing; round1 adds gate2-r1 and fix-r1; full gets every
// shared stage. An arm's execution is the mean over its runs of execution plus
// preflight-fix. Plan-caused interventions per run: re-invocations not caused by an
// infra stop, extra human prompts, NEEDS_CONTEXT, and each preflight-fix session.
// A session id with no transcript is an error (exit 2), never a cheap run.
"use strict";
const fs = require("fs");
const path = require("path");

const PRICE = { opus: [4, 20], sonnet: [2, 10], haiku: [0.1, 0.5], fable: [8, 40] }; // $/M in, out
const family = (m) => Object.keys(PRICE).find((k) => (m || "").includes(k)) || "other";

function readJsonl(file) {
  const out = [];
  for (const l of fs.readFileSync(file, "utf8").split("\n")) {
    if (!l.trim()) continue;
    try { out.push(JSON.parse(l)); } catch { /* partial line at the end of a live file */ }
  }
  return out;
}
function textOf(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content.filter((b) => b && b.type === "text").map((b) => b.text).join("\n");
}
function isHumanPrompt(o) {
  if (o.type !== "user" || o.isSidechain || o.isMeta || !o.message) return false;
  if (o.origin && o.origin.kind) return o.origin.kind === "human"; // recorded by current Claude Code
  const c = o.message.content;
  // Older records: a slash command arrives as <command-name>...; other text that
  // starts with "<" is injected by the harness (task notifications, reminders).
  if (typeof c === "string") return c.includes("<command-name>") || !c.startsWith("<");
  return Array.isArray(c) && c.some((b) => b.type === "text") && !c.some((b) => b.type === "tool_result");
}

function usageOf(entries) {
  const seen = new Set();
  const u = { tokens: 0, cacheRead: 0, out: 0, usd: 0 };
  for (const o of entries) {
    const m = o.message;
    if (o.type !== "assistant" || !m || !m.usage || seen.has(m.id)) continue;
    seen.add(m.id);
    const x = m.usage, p = PRICE[family(m.model)] || [0, 0];
    const cw1h = (x.cache_creation && x.cache_creation.ephemeral_1h_input_tokens) || 0;
    const cw5 = (x.cache_creation_input_tokens || 0) - cw1h;
    const inp = x.input_tokens || 0, cr = x.cache_read_input_tokens || 0, out = x.output_tokens || 0;
    u.tokens += inp + cw5 + cw1h + cr + out;
    u.cacheRead += cr;
    u.out += out;
    u.usd += (inp + cw5 * 1.25 + cw1h * 2 + cr * 0.1) * p[0] / 1e6 + out * p[1] / 1e6;
  }
  return u;
}
function times(entries) {
  const ts = entries.map((o) => o.timestamp).filter(Boolean).map((t) => Date.parse(t)).filter((n) => !isNaN(n));
  if (!ts.length) return { elapsed: 0, active: 0, prompts: 0 };
  const elapsed = Math.max(...ts) - Math.min(...ts);
  // Active: from each human prompt to the last entry before the next one.
  let active = 0, start = null, last = null, prompts = 0;
  for (const o of entries) {
    const t = Date.parse(o.timestamp);
    if (isNaN(t)) continue;
    if (isHumanPrompt(o)) {
      prompts++;
      if (start !== null) active += last - start;
      start = t;
    }
    last = t;
  }
  if (start !== null) active += last - start;
  return { elapsed, active, prompts };
}
// A background subagent hands its report back through a SubagentHandback tool
// call; a foreground one ends with plain text. Take whichever comes last.
function finalText(entries) {
  for (let i = entries.length - 1; i >= 0; i--) {
    const o = entries[i];
    if (o.type !== "assistant" || !o.message) continue;
    const c = Array.isArray(o.message.content) ? o.message.content : [];
    const hb = c.find((b) => b.type === "tool_use" && b.name === "SubagentHandback" && b.input);
    if (hb) return String(hb.input.message || Object.values(hb.input).join("\n"));
    const t = textOf(o.message.content);
    if (t.trim()) return t;
  }
  return "";
}
function events(type, text) {
  const e = {};
  const lines = text.trim().split("\n").map((s) => s.trim()).filter(Boolean);
  if (/implementer/.test(type)) {
    if (/\bNEEDS_CONTEXT\b/.test(text)) e.needsContext = 1;
    if (/\bBLOCKED\b/.test(text) && !/\bDONE\b/.test(lines[0] || "")) e.blocked = 1;
  }
  if (/reviewer/.test(type)) {
    const tail = lines.slice(-2).join(" ");
    if (/(VERDICT|SPEC|QUALITY): ISSUES/.test(tail)) e.issues = 1;
    if (!/(VERDICT|SPEC|QUALITY): (APPROVED|ISSUES)/.test(tail)) e.noVerdict = 1;
  }
  return e;
}

function findSession(projectsDir, id) {
  for (const d of fs.readdirSync(projectsDir)) {
    const f = path.join(projectsDir, d, id + ".jsonl");
    if (fs.existsSync(f)) return f;
  }
  throw new Error(`session ${id} not found under ${projectsDir}`);
}
function addInto(a, b) { for (const k of Object.keys(b)) a[k] = (a[k] || 0) + b[k]; return a; }

// An entry may be "<session id>@<ISO time>": only what happened up to that time
// counts (a session that went on to other work after its stage ended).
function measureSession(projectsDir, entry) {
  const [id, until] = String(entry).split("@");
  const cut = until ? Date.parse(until) : Infinity;
  const upTo = (rows) => rows.filter((o) => !o.timestamp || Date.parse(o.timestamp) <= cut);
  const file = findSession(projectsDir, id);
  const main = upTo(readJsonl(file));
  const r = { usd: 0, tokens: 0, cacheRead: 0, out: 0, controllerUsd: 0, controllerTokens: 0,
              elapsed: 0, active: 0, prompts: 0, ev: {}, agents: {} };
  const mu = usageOf(main);
  addInto(r, { usd: mu.usd, tokens: mu.tokens, cacheRead: mu.cacheRead, out: mu.out });
  r.controllerUsd = mu.usd; r.controllerTokens = mu.tokens;
  Object.assign(r, (({ elapsed, active, prompts }) => ({ elapsed, active, prompts }))(times(main)));
  const sdir = path.join(path.dirname(file), id, "subagents");
  if (fs.existsSync(sdir)) for (const s of fs.readdirSync(sdir)) {
    if (!s.endsWith(".jsonl")) continue;
    let type = "unknown";
    try { type = JSON.parse(fs.readFileSync(path.join(sdir, s.replace(/\.jsonl$/, ".meta.json")), "utf8")).agentType || type; } catch {}
    const ent = upTo(readJsonl(path.join(sdir, s)));
    const u = usageOf(ent);
    addInto(r, { usd: u.usd, tokens: u.tokens, cacheRead: u.cacheRead, out: u.out });
    const a = r.agents[type] = r.agents[type] || { n: 0, usd: 0, tokens: 0 };
    a.n++; a.usd += u.usd; a.tokens += u.tokens;
    addInto(r.ev, events(type, finalText(ent)));
  }
  return r;
}

function measureStage(projectsDir, ids) {
  const r = { usd: 0, tokens: 0, cacheRead: 0, out: 0, controllerUsd: 0, controllerTokens: 0,
              elapsed: 0, active: 0, prompts: 0, sessions: ids.length, ev: {}, agents: {} };
  for (const id of ids) {
    const s = measureSession(projectsDir, id);
    for (const k of ["usd", "tokens", "cacheRead", "out", "controllerUsd", "controllerTokens", "elapsed", "active", "prompts"]) r[k] += s[k];
    addInto(r.ev, s.ev);
    for (const [t, a] of Object.entries(s.agents)) addInto(r.agents[t] = r.agents[t] || {}, a);
  }
  return r;
}

function planSize(p) {
  if (!p || !fs.existsSync(p)) return null;
  const lines = fs.readFileSync(p, "utf8").split("\n");
  let sec = null, impl = 0, con = 0;
  for (const l of lines) {
    if (/^## /.test(l)) sec = /^## Implementation\s*$/.test(l) ? "impl" : /^## Contracts\s*$/.test(l) ? "con" : null;
    else if (sec === "impl") impl++;
    else if (sec === "con") con++;
  }
  return { lines: lines.length, implementationLines: impl, contractsLines: con };
}

const CHARGE = { none: ["plan-writing"], round1: ["plan-writing", "gate2-r1", "fix-r1"] }; // full: every shared stage
const KEYS = ["usd", "tokens", "cacheRead", "active", "elapsed"];
const zero = () => ({ usd: 0, tokens: 0, cacheRead: 0, active: 0, elapsed: 0 });
const add = (a, s) => { for (const k of KEYS) a[k] += s[k] || 0; return a; };

function measureStages(projectsDir, stageMap) {
  const out = {};
  for (const [st, ids] of Object.entries(stageMap || {})) if (ids && ids.length) out[st] = measureStage(projectsDir, ids);
  return out;
}
function summarizeRun(spec, stages) {
  const ex = stages.execution || { ev: {}, sessions: 0, prompts: 0 };
  const pf = stages["preflight-fix"] || { sessions: 0 };
  const cost = add(zero(), ex.sessions ? ex : {});
  if (pf.sessions) add(cost, pf);
  const infra = (spec.infra || []).length;
  // A preflight halt leaves the halted session and a re-invocation after the fix; the
  // halt is counted once, as the preflight-fix session, so its re-invocation is not.
  const reinvocations = Math.max(0, ex.sessions - 1 - infra - pf.sessions);
  const extraPrompts = Math.max(0, ex.prompts - ex.sessions); // each invocation's own prompt is not an intervention
  const needsContext = ex.ev.needsContext || 0, preflightHalts = pf.sessions;
  return Object.assign(cost, { infra, reinvocations, extraPrompts, needsContext, preflightHalts,
    interventions: reinvocations + extraPrompts + needsContext + preflightHalts,
    blocked: ex.ev.blocked || 0, reviewIssues: ex.ev.issues || 0, noVerdict: ex.ev.noVerdict || 0 });
}

function measureAll(m) {
  const res = { shared: measureStages(m.projectsDir, m.shared), runs: {}, arms: {}, ratios: {} };
  for (const [label, spec] of Object.entries(m.runs || {})) {
    const stages = measureStages(m.projectsDir, spec.stages);
    res.runs[label] = { arm: spec.arm, stages, summary: summarizeRun(spec, stages) };
  }
  for (const [arm, spec] of Object.entries(m.arms || {})) {
    const charged = CHARGE[arm] || Object.keys(res.shared);
    const sh = zero(); for (const st of charged) if (res.shared[st]) add(sh, res.shared[st]);
    // A run with no execution yet would enter the mean as $0 and make the arm look cheap.
    const mine = Object.entries(res.runs).filter(([l, r]) => {
      if (r.arm !== arm) return false;
      if (r.stages.execution) return true;
      console.error(`measure: run ${l} has no execution sessions; left out of the ${arm} mean`);
      return false;
    });
    const ex = zero(); for (const [, r] of mine) add(ex, r.summary);
    if (mine.length) for (const k of KEYS) ex[k] /= mine.length;
    const total = add(add(zero(), sh), ex);
    res.arms[arm] = Object.assign(total, { shared: sh, execution: ex, runs: mine.map(([l]) => l),
      interventions: mine.reduce((n, [, r]) => n + r.summary.interventions, 0),
      infra: mine.reduce((n, [, r]) => n + r.summary.infra, 0), plan: planSize(spec.plan) });
  }
  const ratio = (n, d) => (d ? n / d : null);
  for (const a of ["none", "round1"]) if (res.arms[a] && res.arms.full)
    res.ratios[a + "/full"] = { usd: ratio(res.arms[a].usd, res.arms.full.usd), tokens: ratio(res.arms[a].tokens, res.arms.full.tokens),
                                active: ratio(res.arms[a].active, res.arms.full.active) };
  return res;
}

function main() {
  const [manifestPath, flag] = process.argv.slice(2);
  if (!manifestPath) { console.error("usage: node measure.cjs <manifest.json> [--json]"); process.exit(2); }
  const m = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  let res;
  try { res = measureAll(m); } catch (e) {
    const id = /session (\S+) not found/.exec(e.message);
    if (!id) throw e;
    console.error(`measure: no transcript for ${id[1]}`); process.exit(2);
  }
  if (flag === "--json") { console.log(JSON.stringify(res, null, 2)); return; }
  const $ = (n) => "$" + n.toFixed(2), M = (n) => (n / 1e6).toFixed(2) + "M", min = (ms) => (ms / 60000).toFixed(0) + "m";
  const r2 = (n) => (n === null ? "n/a" : n.toFixed(2));
  console.log("## Shared gate 2\n| stage | sessions | tokens | excl. cache reads | $ | active |\n|---|---|---|---|---|---|");
  for (const [st, s] of Object.entries(res.shared))
    console.log(`| ${st} | ${s.sessions} | ${M(s.tokens)} | ${M(s.tokens - s.cacheRead)} | ${$(s.usd)} | ${min(s.active)} |`);
  console.log("\n## Runs\n| run | arm | $ | tokens | active | interventions | infra stops | preflight halts | BLOCKED | ISSUES | no verdict |\n|---|---|---|---|---|---|---|---|---|---|---|");
  for (const [l, r] of Object.entries(res.runs)) { const x = r.summary;
    console.log(`| ${l} | ${r.arm} | ${$(x.usd)} | ${M(x.tokens)} | ${min(x.active)} | ${x.interventions} | ${x.infra} | ${x.preflightHalts} | ${x.blocked} | ${x.reviewIssues} | ${x.noVerdict} |`); }
  console.log("\n## Arms (shared charge + mean execution)\n| arm | $ | tokens | active | interventions | infra stops | plan lines |\n|---|---|---|---|---|---|---|");
  for (const [a, x] of Object.entries(res.arms))
    console.log(`| ${a} | ${$(x.usd)} | ${M(x.tokens)} | ${min(x.active)} | ${x.interventions} | ${x.infra} | ${x.plan ? x.plan.lines : "-"} |`);
  console.log("");
  for (const [k, x] of Object.entries(res.ratios))
    console.log(`${k.replace("/", " / ")}: $ ${r2(x.usd)}, tokens ${r2(x.tokens)}, active ${r2(x.active)}`);
}
if (require.main === module) main();
module.exports = { usageOf, times, events, summarizeRun, planSize, measureAll };
