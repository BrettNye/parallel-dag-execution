**ISSUES**

1. Requirement: each fixture must be structurally valid so that S9 is the only finding. It must also produce the documented suggestion. The `s9-security-no-opus.md` fixture must produce only "Suggest quality_reviewer_hint: opus".
   Actual: in /home/user/parallel-dag-execution/tests/fixtures/tiers/should-warn/s9-security-no-opus.md, the task body says "Produces a cryptographically random token". "cryptographically" contains "cryptographic", which is in the S9 novelty-signal regex. So pattern (2) also fires, since `model_hint` resolves to `standard`. That adds an unintended `model_hint: opus` suggestion on top of the documented one, and S9 no longer matches the fixture's EXPECTED comment.
   Fix: reword that task body to avoid every novelty term (`consensus algorithm`, `distributed`, `formal proof`, `cryptographic`, `zero-knowledge`, `state machine replication`, `byzantine`). For example, use "Generates a random session token (random bytes, hex-encoded), stores it, and validates it on incoming requests." The `node:crypto` import in the code block can stay, because pattern (2) matches on body text.

Everything else is met:
- The S9 row in /home/user/parallel-dag-execution/skills/writing-dag-plans/plan-quality.md has all five patterns and the single-direction rule.
- Detection-algorithm step 3 now reads "S1-S9".
- The other three fixtures (`s9-mechanical-no-cheap.md`, `s9-novelty-phrase.md`, `s9-multi-system-wiring.md`) conform to the spec.
- All four EXPECTED comments match the spec.
