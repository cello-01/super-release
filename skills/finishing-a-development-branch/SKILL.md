---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Continue to Step 2.

### Step 2: Detect Environment

**Determine workspace state before presenting options:**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 4 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 4 options | Provenance-based (see Step 6) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 3 options (no merge) | No cleanup (externally managed) |

### Step 3: Determine Integration Branch

```bash
# Prefer the integration branch with the newest merge base.
# Check both local refs and origin refs in this order: dev, develop, development, staging, next, main, master.
integration_branch=""
newest_merge_base_time=0

for candidate in dev develop development staging next main master; do
  for ref in "$candidate" "origin/$candidate"; do
    git rev-parse --verify --quiet "$ref" >/dev/null || continue
    merge_base=$(git merge-base HEAD "$ref") || continue
    merge_base_time=$(git show -s --format=%ct "$merge_base") || continue

    if [ "$merge_base_time" -gt "$newest_merge_base_time" ]; then
      newest_merge_base_time="$merge_base_time"
      integration_branch="$candidate"
    fi
  done
done

printf '%s\n' "$integration_branch"
```

The command prints the local branch name to use as `<integration-branch>`. If only `origin/<integration-branch>` exists, create the local branch during Option 1 before checking it out.

If detection returns no branch or conflicts with the user's stated workflow, ask: "This branch appears to split from <integration-branch> - is that correct?"

### Step 4: Present Options

**Normal repo and named-branch worktree — present exactly these 4 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <integration-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

Option 1 never prepares a release from the menu choice alone. After merge and tests, ask a separate release-preparation question only when `<integration-branch>` is `main` or `master`.

**Detached HEAD — present exactly these 3 options:**

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)
3. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.

### Step 5: Execute Choice

#### Option 1: Merge Locally

```bash
# Capture feature workspace before leaving it; Step 6 uses these values for cleanup.
FEATURE_GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
FEATURE_GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
FEATURE_WORKTREE_PATH=$(git rev-parse --show-toplevel)

# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first — verify success before removing anything
git show-ref --verify --quiet "refs/heads/<integration-branch>" || git checkout -b "<integration-branch>" "origin/<integration-branch>"
git checkout "<integration-branch>"
git pull --ff-only origin "<integration-branch>" 2>/dev/null || git pull --ff-only
git merge "<feature-branch>"

# Verify tests on merged result
<test command>

# Only after merge succeeds and tests pass: handle release preparation, then cleanup
```

After merge and tests:

- If `<integration-branch>` is not `main` or `master`, report: "Merged into `<integration-branch>`. Release preparation is skipped because this is not the release branch." Continue to Step 6, then delete the feature branch.
- If `<integration-branch>` is `main` or `master`, ask exactly or substantively:

```
Merged into <integration-branch> and tests pass. Prepare a release now?

1. Yes - bump version, update RELEASE-NOTES.md, commit, and tag
2. No - leave the merge without release changes

Which option?
```

If the user chooses option 2, report: "Merged into `<integration-branch>` without release changes; no version bump, no release notes, and no tag were created." Continue to Step 6, then delete the feature branch.

If the user chooses option 1, continue to Prepare Release. After release preparation is complete/skipped/not applicable, continue to Step 6 and then delete the feature branch.

### Prepare Release

Only run this section after the explicit release-preparation gate above and a user choice of option 1.

**Announce:** "Merge successful. Preparing the release."

#### Step 5a: Detect Version Configuration

Prefer the project's existing version tooling. If both `scripts/bump-version.sh` and `.version-bump.json` exist, use the script:

```bash
if [ -x scripts/bump-version.sh ] && [ -f .version-bump.json ]; then
  scripts/bump-version.sh --check
fi
```

The script handles every file declared in `.version-bump.json`, including nested JSON fields like `plugins.0.version`, and provides the project's built-in audit/check behavior.

If there is no script but `.version-bump.json` exists, read the declared version files and fields. Each entry has `path` (relative to project root) and `field` (dot-separated JSON path or TOML key). Update every declared file. For JSON, handle dot paths and numeric array indexes such as `plugins.0.version`. For TOML, update the declared key under the specified table.

If there is no `.version-bump.json`, ask the user where the project version is stored and offer to create a `.version-bump.json`:

```json
{
  "files": [
    { "path": "package.json", "field": "version" }
  ]
}
```

#### Step 5b: Ask for Bump Type

Read the current version and present options:

> "Current version: **X.Y.Z**. What type of bump?"
>
> 1. **patch** (X.Y.Z+1) — bug fixes and minor changes
> 2. **minor** (X.Y+1.0) — new features, backward-compatible
> 3. **major** (X+1.0.0) — breaking changes

Wait for the user's response. If the user no longer wants to prepare a release, stop release preparation, report that no release was prepared, continue to Step 6, then delete the feature branch.

#### Step 5c: Calculate and Apply New Version

Apply SemVer rules:
- **patch**: increment Z only (X.Y.Z → X.Y.Z+1)
- **minor**: increment Y, reset Z to 0 (X.Y.Z → X.Y+1.0)
- **major**: increment X, reset Y and Z to 0 (X.Y.Z → X+1.0.0)

Update the version:

```bash
if [ -x scripts/bump-version.sh ] && [ -f .version-bump.json ]; then
  scripts/bump-version.sh "$NEW_VERSION"
fi
```

If using `.version-bump.json` without a script, update every declared version file to the same new version, handling JSON dot paths/numeric indexes and TOML keys as described above.

#### Step 5d: Update Release Notes

Add a new entry at the top of `RELEASE-NOTES.md`. Create the file if it does not exist.

Use only sections with real content. Choose `Added`, `Fixed`, and/or `Changed` based on the actual work. Remove unused sections before committing.

Start with `## vX.Y.Z (YYYY-MM-DD)`, then add one or more of `### Added`, `### Fixed`, and `### Changed`. Each bullet must be a concrete user-facing change derived from the implementation plan's **Goal** header, design spec, and actual diff. Keep entries concise — one line per item. Never commit placeholder bullets.

#### Step 5e: Commit and Tag

```bash
# Add every version file updated above, quoting each path individually.
git add "path/to/version-file" "path/to/another-version-file" RELEASE-NOTES.md
git commit -m "Release vX.Y.Z"
git tag -a "vX.Y.Z" -m "Release vX.Y.Z"
```

Report: "Release vX.Y.Z tagged and committed."

#### Step 5f: Return to Development Branch

```bash
git checkout "<dev-branch>"
```

Detect the development branch using the same logic as the start gate (check for `dev`, `develop`, `development`, `staging`, `next`; fall back to `main`).

Report: "Returned to development branch `<dev-branch>`."

Then continue to Step 6. Delete `<feature-branch>` only after the merge is complete and either release preparation is complete, release preparation was explicitly skipped, or release preparation did not apply because the integration branch was not `main` or `master`.

```bash
git branch -d "<feature-branch>"
```

#### Option 2: Push and Create PR

```bash
# Push branch
git push -u origin "<feature-branch>"

# Create PR
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

**Do NOT clean up worktree** — user needs it alive to iterate on PR feedback.

#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
FEATURE_GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
FEATURE_GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
FEATURE_WORKTREE_PATH=$(git rev-parse --show-toplevel)

MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then: Cleanup worktree (Step 6), then force-delete branch:
```bash
git branch -D "<feature-branch>"
```

### Step 6: Cleanup Workspace

**Only runs for Options 1 and 4.** Options 2 and 3 always preserve the worktree.

```bash
GIT_DIR=${FEATURE_GIT_DIR:-$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)}
GIT_COMMON=${FEATURE_GIT_COMMON:-$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)}
WORKTREE_PATH=${FEATURE_WORKTREE_PATH:-$(git rev-parse --show-toplevel)}
```

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If worktree path is under `.worktrees/`, `worktrees/`, or `~/.config/superpowers/worktrees/`:** Superpowers created this worktree — we own cleanup.

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**Otherwise:** The host environment (harness) owns this workspace. Do NOT remove it. If your platform provides a workspace-exit tool, use it. Otherwise, leave the workspace in place.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| 4. Discard | - | - | - | yes (force) |

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" is ambiguous
- **Fix:** Present exactly 4 structured options (or 3 for detached HEAD)

**Cleaning up worktree for Option 2**
- **Problem:** Remove worktree user needs for PR iteration
- **Fix:** Only cleanup for Options 1 and 4

**Deleting branch before removing worktree**
- **Problem:** `git branch -d` fails because worktree still references the branch
- **Fix:** Merge first, remove worktree, then delete branch

**Running git worktree remove from inside the worktree**
- **Problem:** Command fails silently when CWD is inside the worktree being removed
- **Fix:** Always `cd` to main repo root before `git worktree remove`

**Cleaning up harness-owned worktrees**
- **Problem:** Removing a worktree the harness created causes phantom state
- **Fix:** Only clean up worktrees under `.worktrees/`, `worktrees/`, or `~/.config/superpowers/worktrees/`

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request
- Remove a worktree before confirming merge success
- Clean up worktrees you didn't create (provenance check)
- Run `git worktree remove` from inside the worktree

**Always:**
- Verify tests before offering options
- Detect environment before presenting menu
- Present exactly 4 options (or 3 for detached HEAD)
- Get typed confirmation for Option 4
- Clean up worktree for Options 1 & 4 only
- `cd` to main repo root before worktree removal
- Run `git worktree prune` after removal
