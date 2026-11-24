// Fixture test for the D2 measure.cjs: one shared gate 2, three arms, two runs each.
"use strict";
const fs = require("fs"), os = require("os"), path = require("path"), cp = require("child_process");
const root = fs.mkdtempSync(path.join(os.tmpdir(), "d2m-"));
const proj = path.join(root, "proj"); fs.mkdirSync(proj, { recursive: true });
const MEASURE = path.join(__dirname, "..", "measure.cjs");
let fails = 0, passes = 0;
const eq = (name, got, want) => { if (JSON.stringify(got) === JSON.stringify(want)) { passes++; console.log("  PASS: " + name); } else { fails++; console.log(`  FAIL: ${name} (expected ${JSON.stringify(want)} got ${JSON.stringify(got)})`); } };

const t = (s) => new Date(Date.UTC(2026, 10, 16, 10, 0, s)).toISOString();
const user = (s, text) => ({ type: "user", timestamp: t(s), message: { role: "user", content: text } });
// $1 at opus input prices ($4/M) is 250k input tokens.
const asst = (s, id, usd, text) => ({ type: "assistant", timestamp: t(s), message: { id, model: "claude-opus-5-5",
  usage: { input_tokens: usd * 250000, cache_read_input_tokens: 0, output_tokens: 0, cache_creation_input_tokens: 0 },
  content: text ? [{ type: "text", text }] : [] } });
const write = (f, rows) => fs.writeFileSync(f, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
// One session: one human prompt, one assistant turn costing usd, 60 s active.
const session = (id, usd) => write(path.join(proj, id + ".jsonl"), [user(0, "go"), asst(60, id + "-m", usd, "SECRET-CONTENT")]);

for (const [id, usd] of [["pw", 1], ["r1", 2], ["f1", 1], ["r2", 2], ["f2", 1],
  ["n1", 3], ["n1pf", 1], ["n2a", 2.5], ["n2b", 2.5], ["o1", 4], ["o2", 4], ["u1", 3], ["u2", 3]]) session(id, usd);

const shared = { "plan-writing": ["pw"], "gate2-r1": ["r1"], "fix-r1": ["f1"], "gate2-r2": ["r2"], "fix-r2": ["f2"] };
const arms = { none: { snapshot: "d2-S0" }, round1: { snapshot: "d2-S1" }, full: { snapshot: "d2-S2" } };
const runs = {
  "none-1": { arm: "none", stages: { execution: ["n1"], "preflight-fix": ["n1pf"] } },
  "none-2": { arm: "none", stages: { execution: ["n2a", "n2b"] }, infra: ["n2a"] },
  "round1-1": { arm: "round1", stages: { execution: ["o1"] } },
  "round1-2": { arm: "round1", stages: { execution: ["o2"] } },
  "full-1": { arm: "full", stages: { execution: ["u1"] } },
  "full-2": { arm: "full", stages: { execution: ["u2"] } },
};
const mf = (name, obj) => { const p = path.join(root, name); fs.writeFileSync(p, JSON.stringify(obj)); return p; };
const manifest = mf("manifest.json", { projectsDir: root, shared, arms, runs });
const run = (p, json) => cp.spawnSync("node", [MEASURE, p].concat(json ? ["--json"] : []), { encoding: "utf8" });

const r = run(manifest, true);
eq("exit 0", r.status, 0);
const res = JSON.parse(r.stdout || "{}");
const usd = (a) => +((res.arms || {})[a] || {}).usd.toFixed(2);
eq("none $ = plan-writing + mean(3+1, 5)", usd("none"), 5.5);
eq("round1 $ = plan-writing + r1 + fix-r1 + mean(4, 4)", usd("round1"), 8);
eq("full $ = every shared stage + mean(3, 3)", usd("full"), 10);
eq("none interventions: the preflight fix counts, the infra re-invocation does not", res.arms.none.interventions, 1);
eq("none-2 plan-caused re-invocations", res.runs["none-2"].summary.reinvocations, 0);
eq("none-1 preflight halts", res.runs["none-1"].summary.preflightHalts, 1);
eq("full interventions", res.arms.full.interventions, 0);
eq("none/full $ ratio", +res.ratios["none/full"].usd.toFixed(2), 0.55);
eq("round1/full $ ratio", +res.ratios["round1/full"].usd.toFixed(2), 0.8);

const text = run(manifest, false).stdout;
eq("text has the none / full line", /none \/ full: \$ 0\.55, tokens 0\.55, active /.test(text), true);
eq("text has the round1 / full line", /round1 \/ full: \$ 0\.80, /.test(text), true);
eq("text never prints message content", /SECRET-CONTENT/.test(text), false);

const floor = run(mf("floor.json", { projectsDir: root, shared, arms,
  runs: { "none-1": { arm: "none", stages: { execution: ["n1"] }, infra: ["n1", "n2a"] } } }), true);
eq("more infra stops than re-invocations floors at 0", JSON.parse(floor.stdout).runs["none-1"].summary.reinvocations, 0);

// A real preflight halt: the halted session, the fix, then a re-invocation. One intervention.
const halt = run(mf("halt.json", { projectsDir: root, shared, arms,
  runs: { "none-1": { arm: "none", stages: { execution: ["n2a", "n2b"], "preflight-fix": ["n1pf"] } } } }), true);
eq("a preflight halt with its re-invocation is one intervention", JSON.parse(halt.stdout).runs["none-1"].summary.interventions, 1);

// A run with no execution yet is left out of its arm's mean, with a warning.
const pending = run(mf("pending.json", { projectsDir: root, shared, arms, runs: {
  "full-1": { arm: "full", stages: { execution: ["u1"] } }, "full-2": { arm: "full", stages: { execution: [] } } } }), true);
eq("an empty run is left out of the mean", +JSON.parse(pending.stdout).arms.full.usd.toFixed(2), 10);
eq("an empty run is named on stderr", /measure: run full-2 has no execution sessions; left out of the full mean/.test(pending.stderr), true);

const empty = run(mf("empty.json", { projectsDir: root, shared: { "plan-writing": [] }, arms,
  runs: { "none-1": { arm: "none", stages: { execution: [] } } } }), false);
eq("empty lists are not missing sessions", empty.status, 0);

const missing = run(mf("missing.json", { projectsDir: root, shared: { "plan-writing": ["nope"] }, arms, runs: {} }), false);
eq("missing transcript exits 2", missing.status, 2);
eq("missing transcript is named", /measure: no transcript for nope/.test(missing.stderr), true);

fs.rmSync(root, { recursive: true, force: true });
console.log(`RESULT: ${passes} passed, ${fails} failed`);
process.exit(fails ? 1 : 0);
