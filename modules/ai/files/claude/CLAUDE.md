# Development Guidelines (universal)

Personal, language-agnostic rules that apply to **every** project.
Lives at `~/.claude/CLAUDE.md`, loaded on every session.
Stack-specific conventions come from a stack file (see section 5), not from here.

---

## 0. Prime directive: plan first

**Do not write code until I've approved a plan.** For any non-trivial task:

1. Restate the goal in one line so we agree on scope.
2. Propose a short plan: files to touch, approach, test strategy, open questions.
3. **Stop and wait for my approval.**
4. Then build.

Trivial, unambiguous edits (typo, rename, obvious one-liner) can skip straight to the change. When in doubt, plan.

---

## 1. Testing: TDD

Tests come **before or alongside** the implementation, not after.

- Write a failing test that captures the desired behavior, then make it pass.
- Cover behavior and edge cases, not implementation details. Tests shouldn't break on a clean refactor.
- A task isn't "done" until its tests are written and green.
- If a requirement is ambiguous, the test is where we pin it down. Surface the ambiguity before writing it.
- Use the project's existing test framework. Don't introduce a new one without asking.

---

## 2. Code style: concise & idiomatic

Lean toward fewer lines and the idioms of the language, not verbose ceremony or over-defensive scaffolding.

- Prefer the standard, idiomatic way over a clever or hand-rolled one.
- No speculative abstraction. Build for the case in front of you; generalize when a second case actually shows up.
- Match the surrounding code's conventions over any personal preference. Consistency within a file or module wins.
- Keep functions focused. A function that needs a paragraph to explain itself probably wants splitting.

---

## 3. Comments: earn their place

Not anti-comment. A good comment is welcome; a noisy one isn't.

- **Do** comment the *why*: non-obvious decisions, tradeoffs, gotchas, the reason behind a workaround.
- **Do** add a quick one-liner where it genuinely speeds understanding of a dense or unusual block.
- **Don't** restate what the code already says (`i++ // increment i`).
- **Don't** leave commented-out code or "changed X" history comments. That's what git is for.

---

## 4. Dependencies: pragmatic

Vet each dependency before adding it. A library is fine when it pulls real weight; bloat isn't.

- Check before adding: maintained (recent commits), reasonably popular, sensibly sized, license-compatible.
- Avoid heavy or abandoned packages for problems the stdlib or a few lines can handle.
- When proposing a new dependency, say why in the plan (what it saves vs. the cost).
- Don't silently bump or add transitive-heavy deps.

---

## 5. Stack conventions

This file is stack-agnostic. The active stack's rules (tooling, idioms, gotchas) come from a stack file in `~/.claude/stacks/`, wired in per project:

- **Single-stack repo:** the repo's root `CLAUDE.md` imports one stack file, e.g. `@~/.claude/stacks/react.md`.
- **Monorepo:** nested files load on demand. `frontend/CLAUDE.md` imports the frontend stack, `backend/CLAUDE.md` imports the backend stack; root stays lean.

If no stack file is wired in, default to the language's de-facto standard toolchain and style guide, and respect the repo's existing config files.

---

## 6. Git & commits

Default convention, change if the repo says otherwise:

- **Conventional Commits**: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.
- Subject line imperative, under ~72 chars; body explains *why* when it's not obvious.
- One logical change per commit. Don't bundle an unrelated refactor into a feature commit.
- Don't commit unless I ask, and never push without explicit go-ahead.

---

## 7. Code review

- Use the `code-review` skill for all PR / code reviews.
- **Never post reviews, comments, or any external content automatically.** Draft, show me, wait for explicit sign-off, then post exactly what was approved.
- Full review mechanics (GitHub API shape, comment anchoring, suggestion blocks, status events, dedup) live in `~/.claude/rules/code-review.md`. Read and follow that file before drafting any review. It is intentionally not `@`-imported, so it only loads when you actually review, keeping base context lean.

---

## 8. How to communicate with me

- Lead with the answer or result. No preamble, no recap of what I just said.
- Be terse and technically precise. I'll ask for more depth if I want it.
- Show diffs/changes over prose descriptions of changes.
- Flag assumptions and risks briefly; don't bury them.
- At a real decision point or ambiguity, ask one sharp question rather than guessing.

---

## 9. Writing style (all output: chat, PR text, commits, prose)

- No emojis.
- No em-dashes. Use commas, colons, or periods instead.

---

## 10. Error handling

Default, adjust per project:

- **Fail loud, fail early.** Surface errors with context; don't swallow exceptions or return silent nulls.
- Validate at boundaries (inputs, external calls); trust internal invariants after that.
- Don't add broad try/catch that hides bugs. Handle what you can act on; let the rest propagate.

---

## 11. When to proceed vs. ask

**Just do it:** anything inside the approved plan, obvious fixes, following existing patterns.

**Stop and ask:** scope creep beyond the plan, a new dependency, a schema/API/contract change, anything destructive (deleting files, data, migrations), or an ambiguity that materially changes the approach.
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.
