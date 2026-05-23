# Release Lifecycle Gates Evaluation

## Scope

This evaluation covers the release lifecycle gate changes to:

- `skills/brainstorming/SKILL.md`
- `skills/finishing-a-development-branch/SKILL.md`
- `tests/claude-code/test-release-lifecycle-gates.sh`
- `tests/claude-code/run-skill-tests.sh`
- `tests/claude-code/test-helpers.sh`
- `tests/claude-code/test-subagent-driven-development.sh`

Environment:

- Harness: Claude Code CLI
- Harness version: `2.1.138`
- Integration tests: not run; the fast skill suite explicitly reported that integration tests were skipped

## Automated Verification

```bash
bash tests/claude-code/run-skill-tests.sh --test test-release-lifecycle-gates.sh --timeout 360
```

Result: `STATUS: PASSED`

Output summary: `Passed: 1`, `Failed: 0`, `Skipped: 0`.

```bash
bash tests/claude-code/run-skill-tests.sh --timeout 1200
```

Result: `STATUS: PASSED`

Output summary: `Passed: 2`, `Failed: 0`, `Skipped: 0`.

```bash
scripts/bump-version.sh --check
```

Result: all declared files are in sync at `5.1.0`.

## Pressure Prompt 1

Prompt:

```text
Use the brainstorming skill. The user approved a design for a small CLI feature. What must happen before writing the design spec file?
```

Observed result:

```text
According to the brainstorming skill's checklist and process flow, what must happen before writing the design spec file is step 6: Set up the development branch and feature branch.

Specifically, the skill states:

Before Creating Files: Development Branch Setup - "After the user approves the design and before writing any files, set up the development branch and create a feature branch."

And in the Red Flags:

Never: Write any file before the feature branch is created

The sequence is:

1. Detect the development branch - check for existing dev, develop, development, staging, or next branches (local or remote). If none exist, ask the user which branch feature branches should start from.
2. Create a feature branch - derived from the design topic in kebab-case (e.g., feature/timeout-cli-wrapper), branched from the development branch.
3. Only then write the design spec to docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md and commit it.

So the answer to your question: set up the development branch and create the feature branch. No files get written before that's done.
```

Outcome: passed. The agent identified development branch setup and feature branch creation before any spec file is written.

## Pressure Prompt 2

Prompt:

```text
Use the finishing-a-development-branch skill. Current branch feature/add-dashboard was created from dev. main also exists. The tests pass. Present the completion options.
```

Observed result:

```text
You've told me the tests pass and that the branch was created from dev. Here are your completion options:

Implementation complete. What would you like to do?

1. Merge back to dev locally - merge feature/add-dashboard into dev, run tests, and clean up the feature branch
2. Push and create a Pull Request - push to origin and open a PR for review
3. Keep the branch as-is - I'll handle it later
4. Discard this work - permanently delete the branch and all its commits

Which option?
```

Outcome: passed. The agent presented `Merge back to dev locally`, not `main`.

## Pressure Prompt 3

Prompt:

```text
Use the finishing-a-development-branch skill. Current branch feature/release-readiness was created from main. Tests pass and the user chose local merge. What do you ask before changing version files or creating a tag?
```

Observed result:

```text
According to the skill, before changing version files or creating a tag, you ask two things:

1. The release-preparation gate:

"Merged into <integration-branch> and tests pass. Prepare a release now?"

1. Yes - bump version, update RELEASE-NOTES.md, commit, and tag
2. No - leave the merge without release changes

2. The bump type, only if they chose "Yes" above:

"Current version: X.Y.Z. What type of bump?"

1. patch (X.Y.Z+1) - bug fixes and minor changes
2. minor (X.Y+1.0) - new features, backward-compatible
3. major (X+1.0.0) - breaking changes

Both gates must be passed before any version file is touched or any tag is created. If the user answers "No" to the release gate, the skill skips directly to cleanup - no version bump, no release notes, no tag.
```

Outcome: passed. The agent identified the explicit release gate before version files, release notes, or tags.
