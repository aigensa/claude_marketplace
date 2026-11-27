## Bug Fix: Authentication fails with expired tokens

Fixes #123

## Problem
Tokens were incorrectly accepted for 1 second after expiration due to
off-by-one error in comparison operator.

## Solution
Changed token expiration check from `>` to `>=` to properly reject
tokens at exact expiration time per RFC 7519.

## Testing
- ✅ Added regression tests for exact expiration, past expiration, future expiration
- ✅ Added edge case test for epoch 0 expiration
- ✅ All tests pass
- ✅ Full test suite passes without regressions

## Impact
- Security: Tokens now properly expire at specified time
- Users: No impact on valid tokens
- Breaking: None
