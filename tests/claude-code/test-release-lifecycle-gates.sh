#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

failures=0

record_result() {
    if "$@"; then
        return 0
    fi
    failures=$((failures + 1))
    return 0
}

assert_first_line() {
    local output="$1"
    local expected="$2"
    local test_name="${3:-first line}"
    local first_line="${output%%$'\n'*}"

    if [ "$first_line" = "$expected" ]; then
        echo "  [PASS] $test_name"
        return 0
    fi

    echo "  [FAIL] $test_name"
    echo "  Expected first line: $expected"
    echo "  Actual first line: $first_line"
    echo "  In output:"
    printf '%s\n' "$output" | sed 's/^/    /'
    return 1
}

echo "Test 1: brainstorming Process Flow gates branch setup before writing design docs"
brainstorming_flow=$(awk '/^## Process Flow/ { in_section = 1 } in_section && /^## The Process/ { exit } in_section { print }' "$REPO_ROOT/skills/brainstorming/SKILL.md")
record_result assert_contains "$brainstorming_flow" "User approves design" "Process Flow includes user approval gate"
record_result assert_contains "$brainstorming_flow" "development branch" "Mentions development branch setup"
record_result assert_contains "$brainstorming_flow" "feature branch" "Mentions feature branch setup"
record_result assert_contains "$brainstorming_flow" "Write design doc" "Mentions design/spec file writing"
record_result assert_order "$brainstorming_flow" "User approves design" "development branch" "User approval appears before branch setup"
record_result assert_order "$brainstorming_flow" "development branch" "feature branch" "Development branch appears before feature branch"
record_result assert_order "$brainstorming_flow" "feature branch" "Write design doc" "Feature branch appears before design/spec file"

echo "Test 2: finishing detects dev/develop integration branches before main/master"
finishing_step3=$(awk '/^### Step 3:/ { in_section = 1 } in_section && /^### Step 4:/ { exit } in_section { print }' "$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md")
record_result assert_contains "$finishing_step3" "^### Step 3: Determine Integration Branch$" "Step 3 heading uses integration branch"
record_result assert_contains "$finishing_step3" "dev" "Mentions dev integration branch"
record_result assert_contains "$finishing_step3" "develop" "Mentions develop integration branch"
record_result assert_contains "$finishing_step3" "development" "Mentions development integration branch"
record_result assert_contains "$finishing_step3" "staging" "Mentions staging integration branch"
record_result assert_contains "$finishing_step3" "next" "Mentions next integration branch"
record_result assert_contains "$finishing_step3" "origin/" "Checks origin refs"
record_result assert_contains "$finishing_step3" "newest\|most recent" "Prefers newest merge base"
record_result assert_order "$finishing_step3" "(^|[^[:alnum:]_-])dev([^[:alnum:]_-]|$)" "(^|[^[:alnum:]_-])main([^[:alnum:]_-]|$)" "Dev/develop appears before main/master"

finishing_step4=$(awk '/^### Step 4:/ { in_section = 1 } in_section && /^### Step 5:/ { exit } in_section { print }' "$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md")
record_result assert_contains "$finishing_step4" "Merge back to <integration-branch> locally" "Menu option 1 uses integration branch"
record_result assert_contains "$finishing_step4" "release-preparation question\|separate release" "Menu separates release preparation from merge choice"

finishing_option1=$(awk '/^#### Option 1:/ { in_section = 1 } in_section && /^#### Option 2:/ { exit } in_section { print }' "$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md")
record_result assert_contains "$finishing_option1" 'git checkout "<integration-branch>"' "Option 1 checks out integration branch"
record_result assert_contains "$finishing_option1" 'git checkout -b "<integration-branch>" "origin/<integration-branch>"' "Option 1 handles remote-only integration branch"
record_result assert_contains "$finishing_option1" "git pull --ff-only origin <integration-branch> 2>/dev/null \|\| git pull --ff-only" "Option 1 pulls integration branch with ff-only fallback"
record_result assert_contains "$finishing_option1" 'git merge "<feature-branch>"' "Option 1 merges feature branch"

echo "Test 3: Option 1 release side effects require separate yes/no gate"
record_result assert_contains "$finishing_option1" "Prepare a release now" "Requires explicit release gate"
record_result assert_contains "$finishing_option1" "Merged into <integration-branch> and tests pass\. Prepare a release now\?" "Release gate states merge and test status"
record_result assert_contains "$finishing_option1" "Yes - bump version, update RELEASE-NOTES.md, commit, and tag" "Release gate yes option names side effects"
record_result assert_contains "$finishing_option1" "No - leave the merge without release changes" "Release gate no option skips side effects"
record_result assert_contains "$finishing_option1" 'not `main` or `master`' "Skips release gate outside release branches"
record_result assert_contains "$finishing_option1" 'Merged into `<integration-branch>`. Release preparation is skipped because this is not the release branch.' "Reports non-release branch skip"
record_result assert_contains "$finishing_option1" 'Merged into `<integration-branch>` without release changes.' "Reports explicit no-release skip"
record_result assert_contains "$finishing_option1" "Continue to Step 6, then delete the feature branch" "Skip paths still delete feature branch"
record_result assert_contains "$finishing_option1" "no version bump" "Option 2 reports no version bump"
record_result assert_contains "$finishing_option1" "no release notes" "Option 2 reports no release notes"
record_result assert_contains "$finishing_option1" "no tag" "Option 2 reports no tag"
record_result assert_contains "$finishing_option1" "scripts/bump-version.sh" "Uses project version bump script"
record_result assert_contains "$finishing_option1" "scripts/bump-version.sh --check" "Runs version bump script check"
record_result assert_contains "$finishing_option1" 'scripts/bump-version.sh "$NEW_VERSION"' "Runs version bump script with new version"
record_result assert_contains "$finishing_option1" "plugins\.0\.version" "Documents nested JSON numeric index support"
record_result assert_contains "$finishing_option1" "no longer wants to prepare a release.*then delete the feature branch" "Bump-type backout still deletes feature branch"
record_result assert_contains "$finishing_option1" "quoting each path individually" "Version files are staged as individually quoted paths"
record_result assert_contains "$finishing_option1" "version bump\|bump version" "Mentions version bump side effect"
record_result assert_contains "$finishing_option1" "RELEASE-NOTES.md" "Mentions RELEASE-NOTES.md side effect"
record_result assert_contains "$finishing_option1" "Use only sections with real content" "Release notes omit empty sections"
record_result assert_contains "$finishing_option1" "Remove unused sections before committing" "Release notes remove unused sections before commit"
record_result assert_contains "$finishing_option1" "tag" "Mentions tag creation side effect"
record_result assert_order "$finishing_option1" "release preparation is complete/skipped/not applicable" 'git branch -d "<feature-branch>"' "Deletes feature branch only after release handling"

if [ "$failures" -gt 0 ]; then
    echo ""
    echo "STATUS: FAILED ($failures assertions failed)"
    exit 1
fi

echo ""
echo "STATUS: PASSED"
