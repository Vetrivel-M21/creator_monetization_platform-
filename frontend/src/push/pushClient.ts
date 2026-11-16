import { initializeApp, getApps, getApp } from 'firebase/app';
import { getMessaging, getToken, deleteToken, onMessage, isSupported } from 'firebase/messaging';

// Client-side Firebase configuration (public keys only)
const env = import.meta.env || {};
const firebaseConfig = {
  apiKey: env.VITE_FIREBASE_API_KEY || "AIzaSyDvWncHlGQlCWYwAJ86eF2mp87yNMZgJfI",
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN || "creator-monetization-platform.firebaseapp.com",
  projectId: env.VITE_FIREBASE_PROJECT_ID || "creator-monetization-platform",
  storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET || "creator-monetization-platform.firebasestorage.app",
  messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID || "171036833667",
  appId: env.VITE_FIREBASE_APP_ID || "1:171036833667:web:f3aa4b51e6cafc2e99e8b6",
  measurementId: env.VITE_FIREBASE_MEASUREMENT_ID || "G-KD66QC0SVF",
};

const VAPID_KEY = env.VITE_FIREBASE_VAPID_KEY || "";
const PUSH_ENABLED = env.VITE_PUSH_ENABLED !== 'false';

let messagingInstance: ReturnType<typeof getMessaging> | null = null;

function getFirebaseMessaging() {
  if (messagingInstance) return messagingInstance;
  const app = getApps().some((a: any) => a.name === 'armss-push')
    ? getApp('armss-push')
    : initializeApp(firebaseConfig, 'armss-push');
  messagingInstance = getMessaging(app);
  return messagingInstance;
}

export interface ForegroundNotificationPayload {
  title?: string;
  body?: string;
  image?: string;
  data?: Record<string, string>;
}

/**
 * Initializes and requests Web Push permissions.
 * Non-blocking: failures are logged and the app continues seamlessly.
 */
export async function enableWebPush(
  registerTokenToServer: (token: string, platform: 'web') => Promise<void>,
  onForeground?: (payload: ForegroundNotificationPayload) => void
): Promise<string | null> {
  try {
    if (!PUSH_ENABLED) {
      console.log("[Push] Web push is disabled via VITE_PUSH_ENABLED");
      return null;
    }

    if (typeof window === 'undefined' || !('Notification' in window) || !('serviceWorker' in navigator)) {
      console.log("[Push] Notifications or Service Workers not supported in this browser");
      return null;
    }

    const supported = await isSupported();
    if (!supported) {
      console.log("[Push] Firebase messaging not supported in this environment");
      return null;
    }

    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      console.log("[Push] User notification permission:", permission);
      return null;
    }

    const registration = await navigator.serviceWorker.register('/firebase-messaging-sw.js');
    await navigator.serviceWorker.ready;

    const messaging = getFirebaseMessaging();
    const tokenOptions: { serviceWorkerRegistration: ServiceWorkerRegistration; vapidKey?: string } = {
      serviceWorkerRegistration: registration,
    };
    if (VAPID_KEY) {
      tokenOptions.vapidKey = VAPID_KEY;
    }

    const token = await getToken(messaging, tokenOptions);
    if (token) {
      console.log("[Push] FCM Web Token obtained:", token.substring(0, 15) + "...");
      await registerTokenToServer(token, 'web');
    }

    // Foreground listener: FCM doesn't show OS popups automatically when tab is focused
    onMessage(messaging, async (payload: any) => {
      console.log("[Push] Foreground message received:", payload);
      const n = payload?.notification || {};
      const d = (payload?.data || {}) as Record<string, string>;

      onForeground?.({
        title: n.title,
        body: n.body,
        image: n.image,
        data: d,
      });

      // Show system notification if browser permits
      if (Notification.permission === 'granted') {
        const sw = await navigator.serviceWorker.ready;
        const options: any = {
          body: n.body,
          icon: '/vite.svg',
          data: d,
          image: n.image,
        };
        sw.showNotification(n.title || "ARMSS Alert", options);
      }
    });

    return token;
  } catch (err) {
    console.warn("[Push] Web push setup note (app continues normally):", err);
    return null;
  }
}

/**
 * Deregisters device token from backend and Firebase on logout.
 */
export async function disableWebPush(
  unregisterTokenFromServer: (token: string) => Promise<void>
): Promise<void> {
  try {
    if (!messagingInstance) return;
    const token = await getToken(messagingInstance);
    if (token) {
      await unregisterTokenFromServer(token);
    }
    await deleteToken(messagingInstance);
  } catch (err) {
    console.warn("[Push] Disable push note:", err);
  }
}
