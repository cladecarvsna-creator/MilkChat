import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import WebSocket from 'ws';
import { startServer } from '../src/index.js';

let srv, base, dir;

before(async () => {
  dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ryzik-'));
  srv = await startServer({ port: 0, dataDir: dir });
  base = `http://127.0.0.1:${srv.port}`;
});
after(() => { srv.wss.close(); srv.server.closeAllConnections(); srv.server.close(); fs.rmSync(dir, { recursive: true, force: true }); });

async function api(method, url, body, token) {
  const res = await fetch(base + url, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, body: await res.json() };
}

const reg = (username) => api('POST', '/api/auth/register', {
  username, displayName: username.toUpperCase(), password: 'x'.repeat(64), publicKey: 'pk-' + username, encryptedPrivateKey: 'enc-' + username,
});

test('регистрация, чаты, сообщения, бейджи, websocket', async () => {
  const a = await reg('alice');
  assert.equal(a.status, 201);
  assert.equal(a.body.user.isAdmin, true, 'первый пользователь — администратор');
  const b = await reg('bob');
  assert.equal(b.body.user.isAdmin, false);
  assert.equal((await reg('Alice')).status, 409);

  const login = await api('POST', '/api/auth/login', { username: 'bob', password: 'x'.repeat(64) });
  assert.equal(login.status, 200);
  assert.equal(login.body.encryptedPrivateKey, 'enc-bob');
  assert.equal((await api('POST', '/api/auth/login', { username: 'bob', password: 'nope' })).status, 401);

  const chatsA = await api('GET', '/api/chats', null, a.body.token);
  assert.equal(chatsA.body.length, 1);
  assert.equal(chatsA.body[0].type, 'saved');

  const found = await api('GET', '/api/users/search?q=bo', null, a.body.token);
  assert.equal(found.body[0].username, 'bob');

  // Bob слушает websocket
  const ws = new WebSocket(`${base.replace('http', 'ws')}/ws?token=${b.body.token}`);
  const events = [];
  ws.on('message', (d) => events.push(JSON.parse(String(d))));
  await new Promise((r) => ws.on('open', r));

  const direct = await api('POST', '/api/chats/direct', { userId: b.body.user.id }, a.body.token);
  assert.equal(direct.status, 201);
  const again = await api('POST', '/api/chats/direct', { userId: b.body.user.id }, a.body.token);
  assert.equal(again.body.id, direct.body.id);

  const sent = await api('POST', `/api/chats/${direct.body.id}/messages`, { type: 'text', payload: '{"ct":"..."}' }, a.body.token);
  assert.equal(sent.status, 201);
  assert.equal(sent.body.seq, 1);

  const chatsB = await api('GET', '/api/chats', null, b.body.token);
  const dB = chatsB.body.find((c) => c.id === direct.body.id);
  assert.equal(dB.unread, 1);

  await api('PUT', `/api/messages/${sent.body.id}/reaction`, { emoji: '🔥' }, b.body.token);
  const msgs = await api('GET', `/api/chats/${direct.body.id}/messages`, null, b.body.token);
  assert.deepEqual(msgs.body[0].reactions, [{ userId: b.body.user.id, emoji: '🔥' }]);

  // Bob не может удалить сообщение Alice
  assert.equal((await api('DELETE', `/api/messages/${sent.body.id}`, null, b.body.token)).status, 403);

  // Бейджи: только админ
  assert.equal((await api('POST', '/api/admin/badges', { emoji: '⭐', title: 'Звезда' }, b.body.token)).status, 403);
  const badge = await api('POST', '/api/admin/badges', { emoji: '⭐', title: 'Звезда', color: '#FFB300' }, a.body.token);
  assert.equal(badge.status, 201);
  const granted = await api('PUT', `/api/admin/users/${b.body.user.id}/badges/${badge.body.id}`, null, a.body.token);
  assert.equal(granted.body.badges[0].title, 'Звезда');

  await new Promise((r) => setTimeout(r, 100));
  const types = events.map((e) => e.type);
  assert.ok(types.includes('chat.new'));
  assert.ok(types.includes('message.new'));
  assert.ok(types.includes('user.updated'));
  ws.close();
});
