# Bug Fix Examples

## Example 1: Logic Error Bug

**Bug report:** "Search returns 11 results when limit=10"

**Investigation:**
- Located: `src/api/search.ts:45`
- Root cause: Loop condition `i <= limit` instead of `i < limit`

**Fix:**
```typescript
// Before
for (let i = 0; i <= limit; i++) {

// After
for (let i = 0; i < limit; i++) {
```

**Regression tests:**
```typescript
describe('Bug #156: Search limit off-by-one', () => {
  it('should return exactly 10 results when limit=10', () => {
    const results = search('query', { limit: 10 });
    expect(results).toHaveLength(10);
  });

  it('should return exactly 1 result when limit=1', () => {
    const results = search('query', { limit: 1 });
    expect(results).toHaveLength(1);
  });

  it('should handle limit=0', () => {
    const results = search('query', { limit: 0 });
    expect(results).toHaveLength(0);
  });
});
```

## Example 2: Missing Validation Bug

**Bug report:** "App crashes when uploading 0-byte file"

**Investigation:**
- Located: `src/upload/handler.ts:78`
- Root cause: No validation for empty files

**Fix:**
```typescript
async function handleUpload(file: File) {
  // Add validation
  if (file.size === 0) {
    throw new Error('Cannot upload empty file');
  }

  // Existing upload logic
  await processFile(file);
}
```

**Regression tests:**
```typescript
describe('Bug #201: Empty file upload crash', () => {
  it('should reject empty file with clear error', async () => {
    const emptyFile = new File([], 'empty.txt');

    await expect(handleUpload(emptyFile))
      .rejects.toThrow('Cannot upload empty file');
  });

  it('should accept file with content', async () => {
    const validFile = new File(['content'], 'valid.txt');

    await expect(handleUpload(validFile))
      .resolves.not.toThrow();
  });

  it('should accept 1-byte file (edge case)', async () => {
    const tinyFile = new File(['a'], 'tiny.txt');

    await expect(handleUpload(tinyFile))
      .resolves.not.toThrow();
  });
});
```

## Example 3: Race Condition Bug

**Bug report:** "Occasionally get duplicate entries in database"

**Investigation:**
- Located: `src/db/insert.ts:92`
- Root cause: No locking or uniqueness check before insert

**Fix:**
```typescript
async function insertUser(data: UserData) {
  // Add unique constraint check
  const existing = await db.user.findUnique({
    where: { email: data.email }
  });

  if (existing) {
    throw new Error(`User with email ${data.email} already exists`);
  }

  return db.user.create({ data });
}
```

**Regression tests:**
```typescript
describe('Bug #178: Duplicate user entries race condition', () => {
  it('should prevent duplicate users with same email', async () => {
    const userData = { email: 'test@example.com', name: 'Test' };

    await insertUser(userData);

    await expect(insertUser(userData))
      .rejects.toThrow('already exists');
  });

  it('should allow multiple users with different emails', async () => {
    await insertUser({ email: 'user1@example.com', name: 'User 1' });
    await insertUser({ email: 'user2@example.com', name: 'User 2' });

    const users = await db.user.findMany();
    expect(users).toHaveLength(2);
  });

  it('should handle concurrent insert attempts', async () => {
    const userData = { email: 'concurrent@example.com', name: 'Test' };

    const promises = Array(5).fill(null).map(() =>
      insertUser(userData).catch(e => e)
    );

    const results = await Promise.all(promises);
    const successes = results.filter(r => !(r instanceof Error));

    expect(successes).toHaveLength(1);
  });
});
```
