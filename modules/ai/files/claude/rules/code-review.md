# Code review mechanics

Detailed rules for drafting and posting PR reviews. Read and follow this before
drafting any review. Loaded on demand (not `@`-imported), so it stays out of
context until you actually review.

The always-on guardrail (universal `CLAUDE.md` section 7) still applies: never
post anything automatically; draft, wait for explicit sign-off, then post exactly
what was approved.

## Drafting

- Before drafting, read the existing reviews and comments on the PR (top-level reviews, issue comments, and inline review comments). Dedup against what others already flagged: drop duplicates, or if you have real added detail, post it as a reply on the existing thread rather than a new standalone finding.
- Post findings as a single PR review (GitHub reviews API: `POST /repos/{o}/{r}/pulls/{n}/reviews`) with each finding as a line-anchored entry in the `comments` array, not as separate standalone comments. This bundles the review status with the comments in one action and keeps each finding as its own resolvable thread.

## Review body (the human-facing summary)

- Keep it free of mechanism jargon (do not say "inline", "comments array", etc.) and free of status/pointer boilerplate (do not say "Requesting changes", "Approving", "see comments", "details inline"); the review event already conveys status and the anchored comments already convey the detail. Just summarize the findings and end on substance, not on a status sentence.

## Comment wording

- For longer review comments (multiple paragraphs, a list, or a code block), open with a short orienting lead line that frames what follows (a soft TLDR, not labeled one), then the detail. Never bold it; plain text. Short one- or two-line comments need no lead, just state the issue.
- Never use `#N` in any posted PR text (body or comments): GitHub auto-links it to issue/PR N. Refer to findings by name or position ("the data-loss bug", "the first item"), and describe other PRs in words instead of `#8`.

## Anchoring

- A review comment can only anchor to a line that is part of the PR diff (a changed/added line in a hunk), not unchanged context. When the root cause sits on an unchanged line, anchor on the nearest in-diff line and word the comment so it reads naturally there (e.g. "the file from this input is never sent in submitGrant"). Do not pin a comment to one line while its text sends the reader to a different line number, it reads as misplaced.
- For a finding about a multi-line construct (a JSX element, an object literal, a block), use a multi-line anchor (`start_line` + `line`, both with `side`/`start_side`) so the comment highlights the whole construct. Pinning to a single attribute/middle line looks arbitrary and shows confusing leading context (e.g. a closing tag above the anchor).

## Suggestions

- For a finding with a small, concrete fix (a one-line guard, a typo, a flipped condition), include a GitHub ```suggestion block so the author can accept it directly. Two constraints: the suggestion replaces the comment's anchored lines exactly, so reproduce every anchored line verbatim (indentation included) changing only the fix; and a suggestion can only sit on diff lines, so a fix that lands on unchanged/context code cannot be a suggestion (use prose anchored on the nearest in-diff line instead).

## Status

- Always confirm the review status before posting. Available events: `APPROVE`, `REQUEST_CHANGES`, `COMMENT` (neutral), or omit for a pending draft. `APPROVE`/`REQUEST_CHANGES` are blocked on your own PRs. Suggest a default from the findings (blocking bug -> REQUEST_CHANGES, only nits -> COMMENT, clean -> APPROVE) but let the user choose.
