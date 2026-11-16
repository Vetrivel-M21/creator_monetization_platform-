/* eslint-disable no-undef */
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

// Firebase configuration for Web Push Background Service Worker
const firebaseConfig = {
  apiKey: "AIzaSyDvWncHlGQlCWYwAJ86eF2mp87yNMZgJfI",
  authDomain: "creator-monetization-platform.firebaseapp.com",
  projectId: "creator-monetization-platform",
  storageBucket: "creator-monetization-platform.firebasestorage.app",
  messagingSenderId: "171036833667",
  appId: "1:171036833667:web:f3aa4b51e6cafc2e99e8b6"
};

try {
  firebase.initializeApp(firebaseConfig);
  const messaging = firebase.messaging();

  messaging.onBackgroundMessage((payload) => {
    console.log("[SW] Background push notification received:", payload);
    const n = payload.notification || {};
    const d = payload.data || {};
    const title = n.title || "ARMSS Creator Platform";
    const options = {
      body: n.body || "",
      icon: "/vite.svg",
      image: n.image || d.image_url,
      data: d,
      badge: "/vite.svg"
    };

    self.registration.showNotification(title, options);
  });
} catch (e) {
  console.warn("[SW] Firebase messaging SW initialization note:", e);
}

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const d = event.notification.data || {};
  let targetUrl = "/";

  if (d.screen === "video" && d.id) {
    targetUrl = "/?video=" + encodeURIComponent(d.id);
  } else if (d.screen === "admin_review") {
    targetUrl = "/?tab=admin";
  } else if (d.screen === "studio_video") {
    targetUrl = "/?tab=studio";
  } else if (d.url) {
    targetUrl = d.url;
  }

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((windowClients) => {
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i];
        if (client.url.includes(self.location.origin) && "focus" in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});

