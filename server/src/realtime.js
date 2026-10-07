import { WebSocketServer } from 'ws';

/**
 * Хаб WebSocket-подключений. Один пользователь может быть онлайн с нескольких устройств.
 * Клиент подключается к /ws?token=..., сервер шлёт JSON-события:
 *   message.new / message.updated / chat.new / chat.updated / chat.removed / read / typing / presence / user.updated
 * Клиент может слать: { type: "typing", chatId } и { type: "ping" }.
 */
export class Hub {
  constructor() {
    this.sockets = new Map(); // userId -> Set<WebSocket>
    this.locals = null;
  }

  isOnline(userId) {
    return (this.sockets.get(userId)?.size ?? 0) > 0;
  }

  sendToUsers(userIds, event) {
    const data = JSON.stringify(event);
    for (const id of new Set(userIds)) {
      for (const ws of this.sockets.get(id) ?? []) {
        if (ws.readyState === ws.OPEN) ws.send(data);
      }
    }
  }

  /** Событие про пользователя: ему самому и всем, с кем у него есть общий чат. */
  broadcastUser(userId, event) {
    const peers = this.locals ? this.locals.sharedChatPeers(userId) : [];
    this.sendToUsers([userId, ...peers], event);
  }

  attach(server, locals) {
    this.locals = locals;
    const wss = new WebSocketServer({ server, path: '/ws' });

    wss.on('connection', (ws, req) => {
      const url = new URL(req.url, 'http://localhost');
      const userId = locals.resolveToken(url.searchParams.get('token') ?? '');
      if (!userId) {
        ws.close(4001, 'unauthorized');
        return;
      }
      const wasOnline = this.isOnline(userId);
      if (!this.sockets.has(userId)) this.sockets.set(userId, new Set());
      this.sockets.get(userId).add(ws);
      ws.isAlive = true;
      locals.touchLastSeen(userId);
      if (!wasOnline) this.broadcastUser(userId, { type: 'presence', userId, online: true, lastSeen: Date.now() });

      ws.on('pong', () => { ws.isAlive = true; });
      ws.on('message', (raw) => {
        let msg;
        try { msg = JSON.parse(String(raw)); } catch { return; }
        if (msg.type === 'typing' && typeof msg.chatId === 'string' && locals.isMember(msg.chatId, userId)) {
          const others = locals.memberIds(msg.chatId).filter((id) => id !== userId);
          this.sendToUsers(others, { type: 'typing', chatId: msg.chatId, userId, action: msg.action ?? 'typing' });
        } else if (msg.type === 'call.signal' && typeof msg.to === 'string' && msg.data && typeof msg.data === 'object') {
          // Сигналы WebRTC (offer/answer/ice/hangup…) пересылаем, только если у людей есть общий чат.
          if (msg.to !== userId && locals.sharedChatPeers(userId).includes(msg.to)) {
            const delivered = this.isOnline(msg.to);
            this.sendToUsers([msg.to], { type: 'call.signal', from: userId, data: msg.data });
            if (!delivered && msg.data.kind === 'offer') {
              ws.send(JSON.stringify({ type: 'call.signal', from: msg.to, data: { kind: 'unavailable', callId: msg.data.callId } }));
            }
          }
        } else if (msg.type === 'ping') {
          ws.send(JSON.stringify({ type: 'pong' }));
        }
      });
      ws.on('close', () => {
        const set = this.sockets.get(userId);
        set?.delete(ws);
        if (set && set.size === 0) {
          this.sockets.delete(userId);
          locals.touchLastSeen(userId);
          this.broadcastUser(userId, { type: 'presence', userId, online: false, lastSeen: Date.now() });
        }
      });
    });

    const interval = setInterval(() => {
      for (const ws of wss.clients) {
        if (!ws.isAlive) { ws.terminate(); continue; }
        ws.isAlive = false;
        ws.ping();
      }
    }, 30_000);
    wss.on('close', () => clearInterval(interval));
    return wss;
  }
}
