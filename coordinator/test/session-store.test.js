import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { SqliteSessionStore, MemorySessionStore } from '../src/session-store.js';

test('SQLite preserves encrypted records and token hashes across restart with CAS', () => {
  const dir = mkdtempSync(join(tmpdir(), 'civiltrust-store-test-'));
  const path = join(dir, 'coordinator.sqlite');
  let store = new SqliteSessionStore(path);
  try {
    const row = { id: 'test', version: 1, ownerTokenHash: Buffer.alloc(32, 1), participantTokenHash: Buffer.alloc(32, 2), encryptedPayload: { ciphertext: 'opaque' } };
    store.set(row.id, row); store.close(); store = new SqliteSessionStore(path);
    assert.deepEqual(store.get('test'), row);
    assert.equal(store.set('test', { ...row, version: 2 }, 1), true);
    assert.equal(store.set('test', { ...row, version: 2 }, 1), false);
    assert.equal(store.get('test').version, 2);
  } finally { store.close(); rmSync(dir, { recursive: true }); }
});
test('memory snapshots cannot mutate stored rows without CAS', () => {
  const store = new MemorySessionStore();
  const row = { id: 'test', version: 1, ownerTokenHash: Buffer.alloc(32), participantTokenHash: Buffer.alloc(32) };
  store.set('test', row); const copy = store.get('test'); copy.version = 99;
  assert.equal(store.get('test').version, 1);
  assert.equal(store.set('test', { ...row, version: 2 }, 8), false);
});
