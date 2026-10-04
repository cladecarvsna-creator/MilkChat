// Выдаёт аккаунту галочку и роль модератора через Custom Claims и создаёт
// официальный канал MilkChat с этим аккаунтом в роли администратора.
//
// Запуск (на своём компьютере, ключ в репозиторий НЕ класть):
//   1. Firebase Console → Project settings → Service accounts → Generate new private key
//   2. cd tool/admin && npm install
//   3. GOOGLE_APPLICATION_CREDENTIALS=/путь/к/ключу.json node verify.mjs почта@аккаунта-MilkDev
//
// UID не нужен: аккаунт ищется по почте, под которой MilkDev зарегистрирован.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const email = process.argv[2];
const revoke = process.argv.includes('--revoke');
if (!email) {
  console.error('Укажите почту: node verify.mjs milkdev@example.com [--revoke]');
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: 'milkchat-915d4' });
const auth = getAuth();
const db = getFirestore();

const user = await auth.getUserByEmail(email);
const claims = { ...(user.customClaims ?? {}), verified: !revoke, staff: !revoke };
await auth.setCustomUserClaims(user.uid, claims);
await db.doc(`users/${user.uid}`).set({ verified: !revoke }, { merge: true });
console.log(`${email} (${user.uid}): verified=${!revoke}, staff=${!revoke}`);

if (!revoke) {
  const channel = db.doc('chats/milkchat');
  const snap = await channel.get();
  if (!snap.exists) {
    await channel.set({
      kind: 'channel',
      title: 'MilkChat',
      handle: '@milkchat',
      about: 'Официальный канал MilkChat',
      verified: true,
      members: [user.uid],
      admins: [user.uid],
      createdBy: user.uid,
      createdAt: FieldValue.serverTimestamp(),
      lastAt: FieldValue.serverTimestamp(),
    });
    console.log('Создан официальный канал MilkChat');
  } else {
    await channel.update({
      admins: FieldValue.arrayUnion(user.uid),
      members: FieldValue.arrayUnion(user.uid),
    });
    console.log('Аккаунт добавлен в админы канала MilkChat');
  }
}
console.log('Готово. Пользователю нужно перезайти, чтобы новая роль попала в токен.');
process.exit(0);
