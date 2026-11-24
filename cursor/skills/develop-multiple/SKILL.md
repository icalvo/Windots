---
name: develop-multiple
description: >-
  Develops several features in parallel, each in its own git worktree and
  feature branch, by delegating per-feature work to the repository's local
  `develop-feature` skill. Use when the user invokes `/develop-multiple`, asks
  to implement multiple Jira tickets / features at the same time across
  separate branches, or asks for parallel multi-feature development using git
  worktrees.
---

# Develop Multiple Features in Parallel

This skill orchestrates parallel feature development. It only handles
**worktrees, branches, and subagent dispatch**. The actual per-feature
implementation is delegated to the repository's local `develop-feature` skill
running inside each worktree.

## When to Use

When the user wants to implement **two or more** features at the same time in
the current repository, each on its own branch. If the user mentions only one
ticket, suggest using the local `develop-feature` skill directly instead.

## Inputs (required)

A list of **two or more** Jira issue keys for the current repo, for example:

```
GSL-194 GSL-201 ARGO-2458
```

If the user has not provided keys, **stop** and ask for them. Do not invent
keys and do not derive scope from free-form descriptions.

## Hard rules

- Each feature MUST end up on its own `feature/<key-lower>-<slug>` branch in
  its own **sibling** git worktree. Never share a worktree or a branch between
  features.
- This skill MUST NOT modify `src/` (or any production code) itself. All code
  changes happen inside the subagent running in each worktree, via the local
  `develop-feature` skill.
- This skill MUST NOT run `git commit` in any worktree. Commits are owned by
  the user (or by whatever rules the local `develop-feature` skill follows).
- This skill MUST be invoked from a **clean working tree** on the main
  checkout. If `git status` is dirty, stop and ask the user to commit, stash,
  or discard before continuing.
- The repository MUST have a local skill at
  `.cursor/skills/develop-feature/SKILL.md`. If it does not, **stop** — this
  orchestration cannot proceed without one.

## Workflow

Strictly follow steps **1 → 7** in order.

### 1. Validate the environment

In the main checkout:

1. Confirm it is a git repo and capture the absolute repo path. Call it
   `REPO_ROOT`. Capture its parent directory as `PARENT` and its folder name
   (just the leaf) as `REPO_NAME`.
   - `git rev-parse --show-toplevel`
2. Confirm the local develop-feature skill exists:
   - File: `REPO_ROOT/.cursor/skills/develop-feature/SKILL.md`
   - If it does **not** exist, **stop** and tell the user the repository is
     missing a local `develop-feature` skill. Do not fall back to a generic
     workflow.
3. Confirm `git status` is clean. If not, **stop** and ask the user to commit,
   stash, or discard before continuing.
4. Run `git fetch origin main` once in the main checkout. If this fails,
   **stop**.

### 2. Resolve each feature

For every issue key the user provided:

1. Lowercase the key (`GSL-194` → `gsl-194`). Call it `KEY`.
2. Find a backlog file matching `docs/definitions/backlog/<KEY>-*.md` inside
   `REPO_ROOT`.
   - If **exactly one** matches, derive `SLUG` by stripping the `<KEY>-`
     prefix and the `.md` suffix from the filename. Example:
     `gsl-194-explainability-service.md` → `explainability-service`.
   - If **none** match, record the key as `missing-backlog`.
   - If **more than one** matches, record the key as `ambiguous-backlog`.
3. Derive:
   - `BRANCH = "feature/<KEY>-<SLUG>"`
   - `WORKTREE = "<PARENT>/<REPO_NAME>-<KEY>-<SLUG>"`

After processing every key, if any was `missing-backlog` or
`ambiguous-backlog`, **stop** and list the offending keys. Ask the user to
create or disambiguate the backlog files first. Do not create any worktrees.

### 3. Show the plan and confirm

Present a table to the user with one row per feature:

| Issue key | Branch                                  | Worktree path                                                  |
| --------- | --------------------------------------- | -------------------------------------------------------------- |
| GSL-194   | feature/gsl-194-explainability-service  | C:\Repos\ResearchTopicService-gsl-194-explainability-service   |
| GSL-201   | feature/gsl-201-topic-history-endpoint  | C:\Repos\ResearchTopicService-gsl-201-topic-history-endpoint   |

Ask the user to confirm before any worktrees are created. **Stop** until they
say yes.

### 4. Create the worktrees and branches

For each feature, in order:

1. Verify `WORKTREE` does not already exist on disk. If it does, **stop** and
   ask the user whether to delete, rename, or skip this feature.
2. Verify `BRANCH` does not already exist, locally or on the remote:
   - `git show-ref --verify --quiet "refs/heads/<BRANCH>"`
   - `git ls-remote --exit-code --heads origin "<BRANCH>"`
   - If either exists, **stop** and ask the user how to proceed.
3. Create the worktree on a new branch off `origin/main`:
   - `git worktree add "<WORKTREE>" -b "<BRANCH>" origin/main`
4. Copy the MCP secrets file into the new worktree, if present. The
   conventional path is `.cursor/mcp.local.env`, which is gitignored and
   therefore absent from a fresh worktree. The subagent's MCP servers
   typically need it to authenticate.
   - If `REPO_ROOT/.cursor/mcp.local.env` exists, copy it to
     `WORKTREE/.cursor/mcp.local.env` (creating `WORKTREE/.cursor/` first if
     necessary). Preserve file contents byte-for-byte.
   - If it does not exist, skip silently — do not create an empty file and
     do not stop.
   - Do **not** copy any other gitignored files; leave per-worktree setup
     (dependencies, build outputs, other `.env` files) to the local
     `develop-feature` skill.
5. Push the new branch and set its upstream from inside the worktree:
   - `git -C "<WORKTREE>" push -u origin HEAD`
   - If this push fails, **stop** and tell the user.

After all worktrees are created, run `git worktree list` in the main checkout
and show the user the final layout.

### 5. Dispatch one background subagent per feature

For each feature, spawn one **background** subagent using the Task tool with
`subagent_type: "generalPurpose"` and `run_in_background: true`.

Launch all subagents in a **single message** (one batch of Task calls) so
they truly start in parallel.

Each subagent prompt MUST include, verbatim and adapted to the feature:

1. **Where to work:**
   > Your working directory is `<WORKTREE>`. You MUST pass
   > `working_directory: "<WORKTREE>"` on every `Shell` tool call. Do not
   > touch any other directory.

2. **What is already set up:**
   > The git worktree at `<WORKTREE>` already exists, is checked out on
   > branch `<BRANCH>` (created from `origin/main`), and has its upstream set
   > to `origin/<BRANCH>`. The working tree is clean. Do NOT create another
   > worktree, do NOT create another branch, and do NOT re-push the upstream.

3. **What skill to follow:**
   > Read and follow the local skill at
   > `<WORKTREE>/.cursor/skills/develop-feature/SKILL.md` end-to-end, using
   > `<KEY>` as the Jira issue key input. When that skill reaches a step that
   > would fetch `origin/main`, create the feature branch, or push the
   > upstream — those have already been done by the parent orchestrator;
   > simply run `git rev-parse --abbrev-ref HEAD` to confirm you are on
   > `<BRANCH>` and continue. Perform every other step of the local skill
   > as written (Jira validation, backlog read, context gathering, plan
   > design, plan approval, implementation, verification).

4. **User interaction:**
   > You have your own independent conversation with the user. Surface any
   > clarifying questions, plan-approval requests, or blockers back to the
   > user via your normal Q&A path. Do not assume answers.

5. **Commits:**
   > Do NOT run `git commit` unless the user explicitly asks you to. Finish
   > with verified, **uncommitted** changes in the working tree, on
   > `<BRANCH>`, in `<WORKTREE>`.

6. **Reporting back:**
   > When you finish (success or blocked), return a short summary: issue key,
   > branch, worktree path, what was implemented, and any follow-ups.

Set the subagent's `description` to something concrete like
`develop <KEY>` so the user can tell the background tasks apart.

### 6. Report to the user

After the batch of Task calls is dispatched, summarize:

- How many background subagents were launched.
- For each: issue key, branch, worktree path, subagent description.
- A reminder that each subagent will independently ask clarifying questions
  and request plan approval — the user should expect several parallel
  conversations.
- A reminder that worktrees are **left in place** when subagents finish; the
  user owns cleanup with `git worktree remove "<WORKTREE>"` (and deletion of
  the now-removed branch with `git branch -d <BRANCH>` if desired).

### 7. Do not poll

Do not actively poll subagent progress with `AwaitShell` or similar. Each
background subagent will notify the user (and parent) when it completes.
Continue with whatever the user asks next.

## Re-running on a subset

If the user asks to launch only some of the keys (e.g. retry one that
failed), repeat the full workflow but only for those keys. Step 4 will fail
fast if a worktree or branch from a previous run is still around — ask the
user whether to remove it first (`git worktree remove ...` and
`git branch -D ...`).

## Notes on worktrees

- Worktrees share the same `.git` database as the main repo, so disk cost is
  cheap and a single `git fetch` is visible to all of them.
- A given branch can only be checked out in **one** worktree at a time — this
  is why step 4 fails fast if `BRANCH` already exists anywhere.
- Each worktree has its own untracked files. `node_modules/`, `bin/`, `obj/`,
  `.env`, etc. must be (re)installed or copied inside each worktree as the
  repo's normal setup requires. The subagent's local `develop-feature`
  workflow is responsible for whatever build/setup the repo needs.
- The MCP secrets file at `.cursor/mcp.local.env` is gitignored, so it is
  **not** carried into a new worktree by `git worktree add`. Step 4 copies
  it from the main checkout when present so subagents can use authenticated
  MCP servers without manual setup. Other gitignored files are deliberately
  left untouched.
- Worktree cleanup, once a feature is fully merged or abandoned:
  - `git worktree remove "<WORKTREE>"` (or `--force` if dirty).
  - Optionally `git branch -d <BRANCH>` after the branch is merged.

## Output

- The list of issue keys, branches, and worktree paths created in step 4.
- Confirmation that one background subagent per feature has been launched in
  step 5.
- No code changes in the main checkout.
