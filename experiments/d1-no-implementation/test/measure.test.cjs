// Fixture test for measure.cjs: builds a fake projects dir and checks the numbers.
"use strict";
const fs = require("fs"), os = require("os"), path = require("path"), cp = require("child_process");
const root = fs.mkdtempSync(path.join(os.tmpdir(), "d1m-"));
const proj = path.join(root, "proj"); fs.mkdirSync(proj, { recursive: true });
let fails = 0, passes = 0;
const eq = (name, got, want) => { if (JSON.stringify(got) === JSON.stringify(want)) { passes++; console.log("  PASS: " + name); } else { fails++; console.log(`  FAIL: ${name} (expected ${JSON.stringify(want)} got ${JSON.stringify(got)})`); } };

const t = (s) => new Date(Date.UTC(2026, 10, 12, 10, 0, s)).toISOString();
const user = (s, text) => ({ type: "user", timestamp: t(s), message: { role: "user", content: text } });
const tool = (s) => ({ type: "user", timestamp: t(s), message: { role: "user", content: [{ type: "tool_result", content: "x" }] } });
const asst = (s, id, model, usage, text) => ({ type: "assistant", timestamp: t(s), message: { id, model, usage, content: text ? [{ type: "text", text }] : [] } });
const U = (inp, cr, out) => ({ input_tokens: inp, cache_read_input_tokens: cr, output_tokens: out, cache_creation_input_tokens: 0 });
const write = (f, rows) => fs.writeFileSync(f, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");

function session(id, rows, subs) {
  write(path.join(proj, id + ".jsonl"), rows);
  const sd = path.join(proj, id, "subagents"); fs.mkdirSync(sd, { recursive: true });
  (subs || []).forEach((s, i) => {
    write(path.join(sd, `agent-${i}.jsonl`), s.rows);
    fs.writeFileSync(path.join(sd, `agent-${i}.meta.json`), JSON.stringify({ agentType: s.type }));
  });
}
const M = 1e6;
// Arm A execution: one invocation; the same message id logged twice must count once.
session("a-exec", [
  user(0, "/parallel-dag-execution:execute plan.md"),
  asst(10, "m1", "claude-opus-5-5", U(M, 0, 0)), asst(10, "m1", "claude-opus-5-5", U(M, 0, 0)),
  tool(20), asst(60, "m2", "claude-opus-5-5", U(0, 0, M)),
], [
  { type: "parallel-dag-execution:dag-implementer", rows: [asst(30, "s1", "claude-sonnet-5-5", U(M, 0, 0), "DONE\nCommit abc")] },
  { type: "parallel-dag-execution:dag-spec-reviewer", rows: [asst(40, "s2", "claude-sonnet-5-5", U(M, 0, 0), "Opening says ISSUES\nwithdrawn: x\nVERDICT: APPROVED")] },
  { type: "parallel-dag-execution:dag-quality-reviewer", rows: [asst(50, "s3", "claude-sonnet-5-5", U(M, 0, 0), "1. Important\nVERDICT: ISSUES")] },
  // A background reviewer: its report arrives as a SubagentHandback call, not text.
  { type: "parallel-dag-execution:dag-merged-reviewer", rows: [{ type: "assistant", timestamp: t(55), message: { id: "s4", model: "claude-sonnet-5-5", usage: U(0, 0, 0),
      content: [{ type: "tool_use", name: "SubagentHandback", input: { message: "Both fine.\nSPEC: APPROVED\nQUALITY: ISSUES" } }] } }] },
]);
// An interactive run started with a slash command, recorded with origin.kind;
// a task notification in the middle is not a prompt.
session("c-exec", [
  { type: "user", timestamp: t(0), origin: { kind: "human" }, message: { role: "user", content: "<command-message>x</command-message>\n<command-name>/parallel-dag-execution:execute</command-name>" } },
  asst(20, "c1", "claude-opus-5-5", U(M, 0, 0)),
  { type: "user", timestamp: t(30), origin: { kind: "task-notification" }, message: { role: "user", content: "<task-notification>done</task-notification>" } },
  asst(50, "c2", "claude-opus-5-5", U(M, 0, 0)),
]);
fs.writeFileSync(path.join(root, "manifest-c.json"), JSON.stringify({ projectsDir: root, arms: { C: { stages: { execution: ["c-exec"] } } } }));
// Arm B execution: two invocations (one re-invocation), a NEEDS_CONTEXT, a BLOCKED, a report without a verdict.
session("b-exec1", [user(0, "/parallel-dag-execution:execute plan.md"), asst(30, "n1", "claude-opus-5-5", U(M, 0, 0))], [
  { type: "parallel-dag-execution:dag-implementer", rows: [asst(10, "t1", "claude-haiku-5-5", U(M, 0, 0), "NEEDS_CONTEXT\n1. which format?")] },
  { type: "parallel-dag-execution:dag-implementer", rows: [asst(20, "t2", "claude-haiku-5-5", U(M, 0, 0), "BLOCKED\nfile not in scope")] },
  { type: "parallel-dag-execution:dag-spec-reviewer", rows: [asst(25, "t3", "claude-sonnet-5-5", U(M, 0, 0), "looks fine")] },
]);
session("b-exec2", [user(100, "continue the run"), asst(160, "n2", "claude-opus-5-5", U(M, 0, 0)), user(200, "a question answered by a person"), asst(230, "n3", "claude-opus-5-5", U(M, 0, 0))]);
// Gate 2: A's two round-1 draws cost 4M and 2M tokens; B's cost 1M and 1M; A has a round 2 of 1M.
const g = (id, tok) => session(id, [user(0, "audit"), asst(5, id + "-m", "claude-opus-5-5", U(tok, 0, 0))]);
g("a-r1a", 4 * M); g("a-r1b", 2 * M); g("a-r2", 1 * M); g("b-r1a", 1 * M); g("b-r1b", 1 * M);

const planB = path.join(root, "planB.md");
fs.writeFileSync(planB, "# p\n## Task: x\n## Contracts\nf(a)\nexit 0\n## Acceptance criteria\n- y\n");
const manifest = path.join(root, "manifest.json");
fs.writeFileSync(manifest, JSON.stringify({ projectsDir: root, arms: {
  A: { stages: { "gate2-r1a": ["a-r1a"], "gate2-r1b": ["a-r1b"], "gate2-r2": ["a-r2"], execution: ["a-exec"] } },
  B: { plan: planB, stages: { "gate2-r1a": ["b-r1a"], "gate2-r1b": ["b-r1b"], execution: ["b-exec1", "b-exec2"] } },
} }));

const res = JSON.parse(cp.execFileSync("node", [path.join(__dirname, "..", "measure.cjs"), manifest, "--json"], { encoding: "utf8" }));
const A = res.A, B = res.B;
console.log("measure.cjs");
eq("duplicate message id counted once (controller tokens)", A.stages.execution.controllerTokens, 2 * M);
eq("controller $ at opus prices", +A.stages.execution.controllerUsd.toFixed(4), +(4 + 20).toFixed(4));
eq("execution tokens include subagents", A.stages.execution.tokens, 5 * M);
eq("A elapsed is first to last entry", A.stages.execution.elapsed, 60000);
eq("A gate 2 averages round 1 and adds round 2", A.summary.gate2.tokens, 4 * M);
eq("B gate 2 average", B.summary.gate2.tokens, 1 * M);
eq("A pipeline excludes the second round-1 draw", A.summary.total.tokens, 4 * M + 1 * M + 5 * M);
eq("withdrawn ISSUES with an APPROVED line is not an issue; ISSUES lines are, handback included", A.summary.reviewIssues, 2);
eq("a handback report's verdict lines are read", A.summary.noVerdict, 0);
const C = JSON.parse(cp.execFileSync("node", [path.join(__dirname, "..", "measure.cjs"), path.join(root, "manifest-c.json"), "--json"], { encoding: "utf8" })).C;
eq("slash-command prompt counts; a task notification does not", [C.stages.execution.prompts, C.stages.execution.active], [1, 50000]);
eq("A has no interventions", A.summary.interventions, 0);
eq("B re-invocations", B.summary.reinvocations, 1);
eq("B extra human prompt in a run", B.summary.extraPrompts, 1);
eq("B NEEDS_CONTEXT", B.summary.needsContext, 1);
eq("B interventions sum", B.summary.interventions, 3);
eq("B BLOCKED", B.summary.blocked, 1);
eq("B report with no verdict line", B.summary.noVerdict, 1);
eq("B active time: 30s + 60s + 30s", B.stages.execution.active, 120000);
eq("plan size counts Contracts lines", [B.plan.implementationLines, B.plan.contractsLines], [0, 2]);
const text = cp.execFileSync("node", [path.join(__dirname, "..", "measure.cjs"), manifest], { encoding: "utf8" });
eq("report prints the B/A line", /Gate-2 tokens 0\.25/.test(text), true);
eq("report never prints message content", /which format|file not in scope|looks fine/.test(text), false);

fs.rmSync(root, { recursive: true, force: true });
console.log(`RESULT: ${passes} passed, ${fails} failed`);
process.exit(fails ? 1 : 0);
