import http from 'node:http';
import path from 'node:path';
import { openDb } from './db.js';
import { createApp } from './app.js';
import { Hub } from './realtime.js';

export function startServer({ port = 8080, dataDir = './data', adminUsernames = [] } = {}) {
  const db = openDb(dataDir);
  const hub = new Hub();
  const app = createApp({ db, dataDir, hub, adminUsernames });
  const server = http.createServer(app);
  const wss = hub.attach(server, app.locals);
  return new Promise((resolve) => {
    server.listen(port, () => resolve({ server, wss, db, hub, port: server.address().port }));
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number(process.env.PORT ?? 8080);
  const dataDir = path.resolve(process.env.DATA_DIR ?? './data');
  const adminUsernames = (process.env.ADMIN_USERNAMES ?? '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
  startServer({ port, dataDir, adminUsernames }).then(({ port: p }) => {
    console.log(`RyzikChat server: http://0.0.0.0:${p} (данные: ${dataDir})`);
  });
}
