# Error Handling

**No bugs found:**
```
❌ No open bugs found in backlog with label "bug"

Try:
- Check if bugs use different labels
- Verify GitHub CLI authentication
- Look for closed bugs that need reopening
```

**Investigation fails:**
```
⚠️  Unable to locate bug in codebase

Options:
1. Provide more details about where to search
2. Share reproduction steps
3. Link to related files or error logs
```

**Tests cannot be created:**
```
🛑 BLOCKED: Cannot commit without regression tests

Regression tests are REQUIRED for all bug fixes. Please:
1. Identify test framework (Jest, pytest, etc.)
2. Locate existing test files for reference
3. Write tests that reproduce the bug
4. Verify tests fail before fix, pass after fix
```

**Tests fail after fix:**
```
❌ Tests still failing after applying fix

This suggests:
- Fix is incomplete
- Fix introduced new bugs
- Tests need adjustment

Review and iterate before committing.
```
