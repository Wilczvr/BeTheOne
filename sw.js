const APP_VERSION = "2026.08.05.10";
const CACHE_NAME = `betheone-static-${APP_VERSION}`;
const STATIC_ASSETS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./styles.css?v=20260805-email-sync-v1",
  "./app.js?v=20260805-email-sync-v1",
  "./league-config.js?v=20260624b",
  "./vendor/supabase.min.js?v=20260624b",
  "./vendor/qrcode.js",
  "./assets/icons/app-icon-192.png",
  "./assets/icons/app-icon-512.png",
  "./assets/icons/app-icon-maskable-512.png",
  "./assets/icons/apple-touch-icon.png",
  "./assets/avatars/panda-calm.png",
  "./assets/avatars/panda-feral.png",
  "./assets/avatars/tiger-calm.png",
  "./assets/avatars/tiger-feral.png",
  "./assets/avatars/wolf-calm.png",
  "./assets/avatars/wolf-feral.png",
  "./assets/avatars/dragon-calm.png",
  "./assets/avatars/dragon-feral.png"
];
const STATIC_ASSET_URLS = new Set(STATIC_ASSETS.map((asset) => new URL(asset, self.location).href));

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(STATIC_ASSETS))
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys
        .filter((key) => key.startsWith("betheone-static-") && key !== CACHE_NAME)
        .map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "SKIP_WAITING") {
    self.skipWaiting();
  }
});

self.addEventListener("fetch", (event) => {
  const { request } = event;
  const url = new URL(request.url);

  if (request.method !== "GET" || url.origin !== self.location.origin) {
    return;
  }

  if (request.mode === "navigate") {
    event.respondWith(fetch(request).catch(() => caches.match("./index.html")));
    return;
  }

  if (!STATIC_ASSET_URLS.has(url.href)) {
    return;
  }

  event.respondWith(
    caches.match(request).then((cachedResponse) => {
      if (cachedResponse) {
        return cachedResponse;
      }

      return fetch(request).then((response) => {
        if (response && response.ok) {
          const responseCopy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, responseCopy));
        }
        return response;
      });
    })
  );
});
