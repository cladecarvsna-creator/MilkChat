import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';

export function openDb(dataDir) {
  fs.mkdirSync(dataDir, { recursive: true });
  const db = new DatabaseSync(path.join(dataDir, 'ryzikchat.db'));
  db.exec(`
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;

    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL UNIQUE COLLATE NOCASE,
      display_name TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      bio TEXT NOT NULL DEFAULT '',
      avatar_file_id TEXT,
      is_admin INTEGER NOT NULL DEFAULT 0,
      public_key TEXT NOT NULL,
      encrypted_private_key TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      last_seen INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS sessions (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS chats (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL CHECK (type IN ('direct', 'group', 'saved')),
      title TEXT NOT NULL DEFAULT '',
      avatar_file_id TEXT,
      created_by TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      last_seq INTEGER NOT NULL DEFAULT 0,
      direct_key TEXT UNIQUE
    );

    CREATE TABLE IF NOT EXISTS chat_members (
      chat_id TEXT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role TEXT NOT NULL DEFAULT 'member',
      pinned INTEGER NOT NULL DEFAULT 0,
      muted INTEGER NOT NULL DEFAULT 0,
      archived INTEGER NOT NULL DEFAULT 0,
      last_read_seq INTEGER NOT NULL DEFAULT 0,
      joined_at INTEGER NOT NULL,
      PRIMARY KEY (chat_id, user_id)
    );
    CREATE INDEX IF NOT EXISTS chat_members_user ON chat_members(user_id);

    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      chat_id TEXT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
      seq INTEGER NOT NULL,
      sender_id TEXT NOT NULL,
      type TEXT NOT NULL,
      payload TEXT NOT NULL,
      reply_to TEXT,
      forwarded_from TEXT,
      client_id TEXT,
      created_at INTEGER NOT NULL,
      edited_at INTEGER,
      deleted INTEGER NOT NULL DEFAULT 0,
      UNIQUE (chat_id, seq)
    );

    CREATE TABLE IF NOT EXISTS reactions (
      message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL,
      emoji TEXT NOT NULL,
      PRIMARY KEY (message_id, user_id)
    );

    CREATE TABLE IF NOT EXISTS files (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      size INTEGER NOT NULL,
      mime TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS badges (
      id TEXT PRIMARY KEY,
      emoji TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      color TEXT NOT NULL DEFAULT '#6750A4',
      created_by TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS user_badges (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      badge_id TEXT NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
      granted_by TEXT NOT NULL,
      granted_at INTEGER NOT NULL,
      PRIMARY KEY (user_id, badge_id)
    );
  `);
  return db;
}

/** Выполняет fn внутри транзакции. */
export function tx(db, fn) {
  db.exec('BEGIN');
  try {
    const r = fn();
    db.exec('COMMIT');
    return r;
  } catch (e) {
    db.exec('ROLLBACK');
    throw e;
  }
}
