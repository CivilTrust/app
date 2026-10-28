import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

function encode(record) {
  return JSON.stringify({ ...record,
    ownerTokenHash: record.ownerTokenHash.toString('base64'),
    participantTokenHash: record.participantTokenHash.toString('base64') });
}
function decode(value) {
  const record = JSON.parse(value);
  return { ...record, ownerTokenHash: Buffer.from(record.ownerTokenHash, 'base64'),
    participantTokenHash: Buffer.from(record.participantTokenHash, 'base64') };
}

export class MemorySessionStore {
  #records = new Map();
  get size() { return this.#records.size; }
  keys() { return this.#records.keys(); }
  get(id) { const value = this.#records.get(id); return value ? decode(value) : undefined; }
  set(id, record, expectedVersion = null) {
    if (expectedVersion !== null && this.get(id)?.version !== expectedVersion) return false;
    this.#records.set(id, encode(record)); return true;
  }
  delete(id) { return this.#records.delete(id); }
}

export class SqliteSessionStore {
  constructor(path) {
    mkdirSync(dirname(path), { recursive: true });
    this.db = new DatabaseSync(path);
    this.db.exec('PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000; CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY, version INTEGER NOT NULL, record TEXT NOT NULL)');
  }
  get size() { return Number(this.db.prepare('SELECT COUNT(*) AS count FROM sessions').get().count); }
  keys() { return this.db.prepare('SELECT id FROM sessions').all().map(row => row.id); }
  get(id) { const row = this.db.prepare('SELECT record FROM sessions WHERE id=?').get(id); return row ? decode(row.record) : undefined; }
  set(id, record, expectedVersion = null) {
    if (expectedVersion !== null) {
      return this.db.prepare('UPDATE sessions SET version=?, record=? WHERE id=? AND version=?')
        .run(record.version, encode(record), id, expectedVersion).changes === 1;
    }
    this.db.prepare('INSERT INTO sessions(id,version,record) VALUES(?,?,?)').run(id, record.version, encode(record));
    return true;
  }
  delete(id) { return this.db.prepare('DELETE FROM sessions WHERE id=?').run(id).changes === 1; }
  close() { this.db.close(); }
}
