---
name: bug-fix
description: "Automate investigation and fixing of reported bugs from GitHub backlog. Use when user requests bug fixing, wants to pick up issues from backlog, or says phrases like 'fix this bug', 'investigate bug report', 'work on reported issue'. REQUIRED: Always create regression tests before committing any fix."
---

# Bug Fix Automation

> **Critical Requirement:** Regression tests are MANDATORY for every bug fix. No fix may be committed without tests that validate the fix and prevent recurrence.

## Quick Start

```bash
# Invoke the skill
/bug-fix

# Skill workflow:
# 1. Fetch bugs from GitHub (label: "bug")
# 2. Select bug to work on
# 3. Investigate root cause
# 4. Implement fix
# 5. Create regression tests (REQUIRED)
# 6. Commit fix + tests
# 7. Create PR linked to bug issue
```

## Workflow

### Step 1: Fetch Bugs from GitHub Backlog

```bash
# List open bugs
gh issue list \
  --label "bug" \
  --state open \
  --json number,title,body,labels,createdAt \
  --limit 20
```

**Present bugs to user** via AskUserQuestion:
- Show bug number, title, and age
- Include severity labels if present (critical, high, medium, low)
- Allow user to select which bug to work on

**Store selected bug:**
```bash
# Save to .claude/active-bug.json
{
  "issueNumber": 123,
  "title": "Authentication fails with expired tokens",
  "body": "...",
  "url": "https://github.com/owner/repo/issues/123",
  "labels": ["bug", "authentication", "high-priority"]
}
```

### Step 2: Investigation Phase

**Read the bug report thoroughly:**
- Extract reproduction steps
- Identify error messages and stack traces
- Note affected components/files
- Check for related issues or PRs

**Locate relevant code** using Task tool with Explore agent:
```bash
# Example investigation
# If bug mentions "authentication fails", search for:
# - authentication logic
# - token validation code
# - error handling paths
```

**Analyze git history** if helpful:
```bash
# Find recent changes to relevant files
git log --since="1 month ago" --oneline -- path/to/file.ts

# Check when bug might have been introduced
git blame path/to/file.ts
```

**Document findings:**
- Which file(s) contain the bug
- What code is responsible
- When the bug was likely introduced
- Why the code behaves incorrectly

### Step 3: Root Cause Analysis

Identify the **specific cause**:
- Logic error (wrong condition, off-by-one, etc.)
- Missing validation or error handling
- Race condition or timing issue
- Incorrect assumptions about data
- Dependency or configuration issue

Understand **why it wasn't caught**:
- Missing test coverage
- Edge case not considered
- Integration gap between components

Determine **scope of impact**:
- How many users affected
- Which features/paths trigger the bug
- Data integrity concerns
- Security implications

### Step 4: Generate Fix

**Create minimal, focused fix:**
- Change only what's necessary
- Preserve existing behavior for non-bug cases
- Add validation if missing
- Improve error messages if unclear

**Explain the fix clearly:**
- What changed and why
- Why this approach was chosen
- What edge cases are now handled
- Any performance or compatibility considerations

**Example fix explanation:**
```
The bug occurs because token expiration is checked using > instead of >=,
causing tokens to be accepted for one extra second after expiration.

Fix: Change condition from `exp > now` to `exp >= now`

This ensures tokens are rejected at or after their expiration time,
matching RFC 7519 JWT specification.
```

### Step 5: Create Regression Tests (REQUIRED)

**This step is MANDATORY.** No fix may be committed without regression tests.

#### Test Requirements

**Must include:**
1. **Test that reproduces the bug** - Fails before fix, passes after fix
2. **Edge case tests** - Cover boundary conditions related to the bug
3. **Integration tests** - Verify fix works end-to-end if applicable

**Test structure:**
```typescript
describe('Bug #123: Authentication with expired tokens', () => {
  it('should reject tokens at exact expiration time', () => {
    // This test would fail before the fix
    const token = createToken({ exp: now });
    expect(validateToken(token)).toBe(false);
  });

  it('should reject tokens after expiration time', () => {
    const token = createToken({ exp: now - 1 });
    expect(validateToken(token)).toBe(false);
  });

  it('should accept tokens before expiration time', () => {
    const token = createToken({ exp: now + 3600 });
    expect(validateToken(token)).toBe(true);
  });

  it('should handle edge case: expiration at epoch 0', () => {
    const token = createToken({ exp: 0 });
    expect(validateToken(token)).toBe(false);
  });
});
```

#### Test Location

**Add tests to existing test files** when possible:
- Keep tests near the code they validate
- Follow project's test structure conventions
- Example: Fix in `src/auth.ts` → Tests in `src/__tests__/auth.test.ts`

**Create new test file** if needed:
- Use project's naming convention (`.test.ts`, `.spec.ts`, `_test.py`, etc.)
- Place in appropriate test directory
- Include descriptive name: `bug-123-token-expiration.test.ts`

#### Test Validation

**Before committing:**
1. Run tests to confirm they fail without the fix
2. Apply the fix
3. Run tests to confirm they now pass
4. Run full test suite to ensure no regressions

```bash
# Run specific test
npm test -- path/to/test.test.ts

# Run full suite
npm test
```

**Test coverage:**
- Aim for 100% coverage of the bug scenario
- Cover all code paths affected by the fix
- Include edge cases discovered during investigation

### Step 6: Commit Fix and Tests

**Use /commit skill** with active bug issue:

```bash
# Commit the fix
git add <fixed-files>
/commit
# → {{PROJECT_PREFIX}}-123: Fix token expiration validation off-by-one error

# Commit the tests (separate commit)
git add <test-files>
/commit
# → {{PROJECT_PREFIX}}-123a: Add regression tests for token expiration bug
```

**Commit message format:**
```
{{PROJECT_PREFIX}}-123: Fix token expiration validation off-by-one error

Tokens were incorrectly accepted for one second after expiration due
to > instead of >= comparison. Changed to >= to match RFC 7519 spec.

Fixes #123

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Link to bug issue:**
- Use `Fixes #123` in commit message
- GitHub will auto-close issue when PR merges

### Step 7: Create Pull Request

**Use /mr skill:**

```bash
/mr
```

**PR description:**

Use the template in @templates/pr-description.md.

## Configuration

Create `config.yaml` in skill directory:

```yaml
bug_selection:
  label: "bug"
  auto_assign_to_self: true
  max_bugs_to_show: 20

investigation:
  explore_depth: "thorough"  # quick, medium, thorough
  include_git_history: true
  analyze_stack_traces: true

fix:
  require_explanation: true
  require_edge_case_analysis: true

tests:
  required: true  # CANNOT be false
  separate_commit: true
  test_before_and_after: true
  require_edge_cases: true

commit:
  link_to_issue: true  # Add "Fixes #123" to commit
  use_aigcode_prefix: true

pr:
  auto_create: true
  request_review: false  # Set to true to auto-request reviews
```

## Error Handling

See @references/error-handling.md.

## Best Practices

### Investigation

1. **Read the full bug report** - Don't skip reproduction steps
2. **Search for related issues** - May provide additional context
3. **Test locally if possible** - Reproduce before fixing
4. **Check git blame** - Understand why code was written that way

### Fixing

1. **Minimal changes** - Fix only the bug, don't refactor
2. **Preserve behavior** - Ensure non-buggy paths still work
3. **Consider edge cases** - Think beyond the reported scenario
4. **Add validation** - Prevent similar bugs in future

### Testing

1. **Test-driven** - Write failing test first
2. **Cover edge cases** - Not just the happy path
3. **Integration tests** - Verify fix works end-to-end
4. **Run full suite** - Catch unintended regressions

### Committing

1. **Separate commits** - Fix in one, tests in another
2. **Link to issue** - Use "Fixes #123" syntax
3. **Clear messages** - Explain what and why
4. **Verify CI passes** - Don't break the build

## Examples

See @references/examples.md (logic error, missing validation, race condition).

## Troubleshooting

See @references/troubleshooting.md.

## Integration with Other Skills

- **Uses `/commit` skill** for creating commits
- **Uses `/mr` skill** for creating pull requests
- **Uses Task tool** with Explore agent for investigation
- **Compatible with `/play-story`** workflow

## References

- See @references/testing-best-practices.md for test patterns
- See @references/bug-investigation.md for debugging techniques
- See @references/examples.md, @references/error-handling.md, @references/troubleshooting.md and @templates/pr-description.md
