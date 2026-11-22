# Troubleshooting

**Issue: Can't find the bug in codebase**
- Try broader search terms
- Search error messages in logs
- Check recently modified files
- Ask user for more context

**Issue: Fix seems too complex**
- Reassess root cause - might be misunderstood
- Consider if refactoring is truly needed
- Ask user if simpler approach acceptable

**Issue: Tests are flaky**
- Add proper setup/teardown
- Mock external dependencies
- Use deterministic test data
- Add delays for async operations if needed

**Issue: Fix breaks other tests**
- Review what broke - might reveal larger issue
- Consider if original code had hidden dependencies
- May need to update other tests
