#!/usr/bin/env node
// D1 experiment measurement. Reads Claude Code session transcripts named in a
// manifest and reports, per arm and stage: tokens, estimated dollars, elapsed
// and active time, and the run events the decision rule needs.
//
// Reads message content only to classify run events (a subagent's verdict line,
// NEEDS_CONTEXT, BLOCKED). It never prints content.
//
// usage: node measure.cjs <manifest.json> [--json]
//
// Manifest:
// {
//   "projectsDir": "C:/Users/Brett/.claude/projects",
//   "arms": {
//     "A": { "plan": "<path to the plan at READY>",
//            "stages": { "plan-writing": ["<session id>"], "gate2-r1a": [...],
//                        "gate2-r1b": [...], "gate2-r2": [...], "fix-r1": [...],
//                        "execution": [...] } },
//     "B": { ... }
//   }
// }
// Stage names: "gate2-r1a" and "gate2-r1b" are the two draws of round 1 and are
// averaged; any other "gate2-*" stage is a later round and is added. "execution"
// sessions are the headless runs: one session per invocation, so a second session
// there is a re-invocation.
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

function summarize(arm, stages) {
  const g = { usd: 0, tokens: 0 }, tot = { usd: 0, tokens: 0, active: 0, elapsed: 0 };
  const r1 = ["gate2-r1a", "gate2-r1b"].filter((k) => stages[k]);
  for (const k of r1) { g.usd += stages[k].usd / r1.length; g.tokens += stages[k].tokens / r1.length; }
  for (const [k, s] of Object.entries(stages)) {
    if (k.startsWith("gate2-") && !r1.includes(k)) { g.usd += s.usd; g.tokens += s.tokens; }
    if (k === "gate2-r1b") continue; // the second draw is measurement only; the pipeline ran once
    tot.usd += s.usd; tot.tokens += s.tokens; tot.active += s.active; tot.elapsed += s.elapsed;
  }
  const ex = stages.execution || { ev: {}, sessions: 0, prompts: 0 };
  const reinvocations = Math.max(0, ex.sessions - 1);
  const extraPrompts = Math.max(0, ex.prompts - ex.sessions); // each invocation's own prompt is not an intervention
  const needsContext = ex.ev.needsContext || 0;
  return { arm, gate2: g, total: tot, reinvocations, extraPrompts, needsContext,
           interventions: reinvocations + extraPrompts + needsContext,
           blocked: ex.ev.blocked || 0, reviewIssues: ex.ev.issues || 0, noVerdict: ex.ev.noVerdict || 0 };
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

function main() {
  const [manifestPath, flag] = process.argv.slice(2);
  if (!manifestPath) { console.error("usage: node measure.cjs <manifest.json> [--json]"); process.exit(2); }
  const m = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const res = {};
  for (const [arm, spec] of Object.entries(m.arms)) {
    const stages = {};
    for (const [st, ids] of Object.entries(spec.stages || {})) if (ids && ids.length) stages[st] = measureStage(m.projectsDir, ids);
    res[arm] = { stages, summary: summarize(arm, stages), plan: planSize(spec.plan) };
  }
  if (flag === "--json") { console.log(JSON.stringify(res, null, 2)); return; }
  const $ = (n) => "$" + n.toFixed(2), M = (n) => (n / 1e6).toFixed(2) + "M", min = (ms) => (ms / 60000).toFixed(0) + "m";
  for (const [arm, r] of Object.entries(res)) {
    console.log(`\n## Arm ${arm}` + (r.plan ? ` (plan ${r.plan.lines} lines; Implementation ${r.plan.implementationLines}, Contracts ${r.plan.contractsLines})` : ""));
    console.log("| stage | sessions | tokens | excl. cache reads | $ | controller $ | active | elapsed | events |");
    console.log("|---|---|---|---|---|---|---|---|---|");
    for (const [st, s] of Object.entries(r.stages))
      console.log(`| ${st} | ${s.sessions} | ${M(s.tokens)} | ${M(s.tokens - s.cacheRead)} | ${$(s.usd)} | ${$(s.controllerUsd)} | ${min(s.active)} | ${min(s.elapsed)} | ${Object.entries(s.ev).map(([k, v]) => k + " " + v).join(", ") || "-"} |`);
    const x = r.summary;
    console.log(`\nGate 2 (round 1 averaged): ${M(x.gate2.tokens)}, ${$(x.gate2.usd)}. Pipeline: ${M(x.total.tokens)}, ${$(x.total.usd)}, active ${min(x.total.active)}.`);
    console.log(`Interventions ${x.interventions} (re-invocations ${x.reinvocations}, extra prompts ${x.extraPrompts}, NEEDS_CONTEXT ${x.needsContext}); BLOCKED ${x.blocked}; reviewer ISSUES ${x.reviewIssues}; reports without a verdict line ${x.noVerdict}.`);
  }
  if (res.A && res.B) {
    const a = res.A.summary, b = res.B.summary, ratio = (n, d) => (d ? (n / d).toFixed(2) : "n/a");
    console.log(`\n## B / A\nGate-2 tokens ${ratio(b.gate2.tokens, a.gate2.tokens)} (pilot passes at <= 0.50). Pipeline tokens ${ratio(b.total.tokens, a.total.tokens)}, $ ${ratio(b.total.usd, a.total.usd)}, active time ${ratio(b.total.active, a.total.active)} (big run passes at <= 0.50 each). Interventions B ${b.interventions} vs A ${a.interventions} (passes at B <= A).`);
  }
}
if (require.main === module) main();
module.exports = { usageOf, times, events, summarize, planSize };
