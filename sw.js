const CACHE = 'super-off-v13';
// נתיבים יחסיים — האתר מוגש תחת /super-off/ ולא בשורש הדומיין
const ASSETS = ['./', './index.html'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).catch(() => {}));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
  ));
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const req = e.request;
  // רק בקשות GET מהאתר עצמו. Supabase, ספריות וכו' — ישירות לרשת, בלי התערבות
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;
  // דף האפליקציה: תמיד הגרסה העדכנית מהשרת (עוקף את מטמון הדפדפן) — בלי צורך ב-Ctrl+Shift+R אחרי עדכון
  const isPage = req.mode === 'navigate' || req.destination === 'document';
  e.respondWith(
    fetch(req, isPage ? { cache: 'no-store' } : undefined)
      .then(res => {
        if (isPage && res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put('./index.html', copy)); }
        return res;
      })
      .catch(() => caches.match(isPage ? './index.html' : req))
  );
});
