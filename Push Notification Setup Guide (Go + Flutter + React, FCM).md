# Push Notification Setup Guide (Go + Flutter + React, FCM)

A free, isolated push notification service using **Firebase Cloud Messaging (FCM)** for a Go backend, a Flutter mobile app and a React web app.

## 1. Goals and isolation rules

The whole feature is built as a **separate module** so your existing functionality is not touched:

- **Additive only:** new folders, new DB table, new routes. No existing table, route or model is modified.
- **Feature flag:** `PUSH_ENABLED=false` turns the whole thing off. The app behaves exactly as before.
- **Failure isolation:** if Firebase is down, misconfigured or slow, your normal API calls never fail or slow down. Sending runs in a background worker and errors are only logged.
- **Small integration surface:** your existing code needs about 3 lines in the backend, 1 call in Flutter and 1 call in React.

```
Flutter / React -> get FCM token -> POST /api/push/devices -> Go (push module) -> DB
Your business code -> push.Notify(userID, payload) -> queue -> worker -> FCM -> devices
```

## 2. Cost and limits

- FCM is **free with no message limit** (Firebase Spark plan is enough).
- **Android and Web:** completely free.
- **iOS:** needs an Apple Developer account ($99/year) to create the APNs key. This is Apple's rule for every push service. If you cannot pay, ship Android + Web first and add iOS later. Nothing in this guide needs to change except uploading the APNs key.

## 3. Firebase console setup (one time)

1. Open console.firebase.google.com and create a project (disable Google Analytics if you do not need it).
2. Add apps: **Android** (your package name), **Web** (nickname only), **iOS** (bundle ID, optional for now).
3. **Project settings -> Service accounts -> Generate new private key.** Save the JSON as `serviceAccountKey.json`. This is for the Go backend only.
4. **Project settings -> Cloud Messaging -> Web configuration -> Generate key pair.** Copy the public key (VAPID key) for React.
5. Keep the Firebase config values (apiKey, projectId, messagingSenderId, appId) for Flutter and React.

**Security:** never commit `serviceAccountKey.json`. Add it to `.gitignore` and mount it as a secret on your server. The Firebase client config (apiKey etc.) is safe to be public.

## 4. Backend (Go)

### 4.1 Files to add (nothing existing is changed)

```
internal/push/
  model.go
  repository.go
  service.go
  handler.go
migrations/
  0XX_create_push_device_tokens.sql
```

### 4.2 Install

```bash
go get firebase.google.com/go/v4
```

### 4.3 Database migration (new table only)

```sql
CREATE TABLE IF NOT EXISTS push_device_tokens (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id    BIGINT UNSIGNED NOT NULL,                 -- match the type of your users.id
    token      VARCHAR(512) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    platform   ENUM('android','ios','web') NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_push_token (token),
    KEY idx_push_tokens_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

There is intentionally **no foreign key** to your users table, so this migration cannot affect existing tables. Rollback is simply `DROP TABLE push_device_tokens;`.

### 4.4 model.go

```go
package push

type Payload struct {
	Title string
	Body  string
	Data  map[string]string // e.g. {"screen":"orders","id":"123"}
}
```

### 4.5 repository.go (MySQL via database/sql)

```go
package push

import (
	"context"
	"database/sql"
)

type Repository interface {
	Upsert(ctx context.Context, userID int64, token, platform string) error
	TokensByUser(ctx context.Context, userID int64) ([]string, error)
	Delete(ctx context.Context, token string) error
}

type mysqlRepo struct{ db *sql.DB }

func NewRepository(db *sql.DB) Repository { return &mysqlRepo{db: db} }

func (r *mysqlRepo) Upsert(ctx context.Context, userID int64, token, platform string) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO push_device_tokens (user_id, token, platform)
		VALUES (?, ?, ?)
		ON DUPLICATE KEY UPDATE
			user_id = VALUES(user_id),
			platform = VALUES(platform),
			updated_at = CURRENT_TIMESTAMP`,
		userID, token, platform)
	return err
}

func (r *mysqlRepo) TokensByUser(ctx context.Context, userID int64) ([]string, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT token FROM push_device_tokens WHERE user_id = ?`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (r *mysqlRepo) Delete(ctx context.Context, token string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM push_device_tokens WHERE token = ?`, token)
	return err
}
```

This uses your existing `*sql.DB`, so no new connection is opened. If you already use the `github.com/go-sql-driver/mysql` driver, nothing else is needed. The token column uses `ascii_bin` because FCM tokens are case-sensitive, and a case-insensitive collation could wrongly treat two different tokens as duplicates. If you use GORM instead of `database/sql`, only this file changes (use `clause.OnConflict{UpdateAll: true}`).

### 4.6 service.go (async, failure-isolated)

```go
package push

import (
	"context"
	"log"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type job struct {
	userID  int64
	payload Payload
}

type Service struct {
	enabled bool
	client  *messaging.Client
	repo    Repository
	queue   chan job
}

// New never panics and never returns an error that should stop your app.
// If anything is wrong, push is simply disabled and logged.
func New(ctx context.Context, repo Repository, enabled bool, credsFile string) *Service {
	s := &Service{repo: repo, queue: make(chan job, 1000)}
	if !enabled {
		log.Println("[push] disabled by config")
		return s
	}
	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credsFile))
	if err != nil {
		log.Printf("[push] firebase init failed, push disabled: %v", err)
		return s
	}
	client, err := app.Messaging(ctx)
	if err != nil {
		log.Printf("[push] messaging init failed, push disabled: %v", err)
		return s
	}
	s.client, s.enabled = client, true
	go s.worker()
	log.Println("[push] enabled")
	return s
}

// Notify is non-blocking and safe to call from anywhere in your code.
// It never returns an error and never panics into the caller.
func (s *Service) Notify(userID int64, p Payload) {
	if s == nil || !s.enabled {
		return
	}
	select {
	case s.queue <- job{userID, p}:
	default:
		log.Println("[push] queue full, notification dropped")
	}
}

func (s *Service) worker() {
	for j := range s.queue {
		s.process(j)
	}
}

func (s *Service) process(j job) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("[push] recovered panic: %v", r)
		}
	}()
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	tokens, err := s.repo.TokensByUser(ctx, j.userID)
	if err != nil || len(tokens) == 0 {
		return
	}
	resp, err := s.client.SendEachForMulticast(ctx, &messaging.MulticastMessage{
		Tokens:       tokens,
		Notification: &messaging.Notification{Title: j.payload.Title, Body: j.payload.Body},
		Data:         j.payload.Data,
	})
	if err != nil {
		log.Printf("[push] send failed: %v", err)
		return
	}
	// Clean up dead tokens
	for i, r := range resp.Responses {
		if !r.Success && messaging.IsUnregistered(r.Error) {
			_ = s.repo.Delete(ctx, tokens[i])
		}
	}
}
```

The multicast call accepts up to 500 tokens. A single user will never have that many devices, so no batching is needed here.

### 4.7 handler.go (token registration endpoints)

The handler receives a function that extracts the user ID using **your existing auth**, so you do not modify your auth code.

```go
package push

import (
	"encoding/json"
	"net/http"
)

type UserIDFunc func(r *http.Request) (int64, bool)

type Handler struct {
	repo   Repository
	userID UserIDFunc
}

func NewHandler(repo Repository, uid UserIDFunc) *Handler {
	return &Handler{repo: repo, userID: uid}
}

// RegisterRoutes adds ONLY new routes under /api/push/*
func (h *Handler) RegisterRoutes(mux *http.ServeMux, authMiddleware func(http.Handler) http.Handler) {
	mux.Handle("/api/push/devices", authMiddleware(http.HandlerFunc(h.devices)))
}

type deviceReq struct {
	Token    string `json:"token"`
	Platform string `json:"platform"` // android | ios | web
}

func (h *Handler) devices(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.userID(r)
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	var req deviceReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Token == "" {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	switch req.Platform {
	case "android", "ios", "web":
	default:
		http.Error(w, "invalid platform", http.StatusBadRequest)
		return
	}
	switch r.Method {
	case http.MethodPost:
		if err := h.repo.Upsert(r.Context(), uid, req.Token, req.Platform); err != nil {
			http.Error(w, "server error", http.StatusInternalServerError)
			return
		}
	case http.MethodDelete: // call on logout
		_ = h.repo.Delete(r.Context(), req.Token)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

If you use Gin, Echo or Chi, keep the same logic and register the route with that router instead of `ServeMux`.

### 4.8 Wiring it in main.go (the only change to existing backend code)

```go
// --- push notifications (isolated module) ---
pushRepo := push.NewRepository(db)
pushSvc := push.New(ctx, pushRepo,
	os.Getenv("PUSH_ENABLED") == "true",
	os.Getenv("FIREBASE_CREDENTIALS_FILE"))
push.NewHandler(pushRepo, yourExistingUserIDFromRequest).
	RegisterRoutes(mux, yourExistingAuthMiddleware)
// --------------------------------------------
```

Environment variables:

```
PUSH_ENABLED=true
FIREBASE_CREDENTIALS_FILE=/secrets/serviceAccountKey.json
```

### 4.9 Sending a notification from your existing code

Pass `pushSvc` to the place that needs it and add one line where the event happens:

```go
pushSvc.Notify(order.UserID, push.Payload{
	Title: "Order shipped",
	Body:  "Your order #" + order.Number + " is on the way",
	Data:  map[string]string{"screen": "order_detail", "id": order.ID},
})
```

Because `Notify` is non-blocking and never returns an error, it cannot break or slow down the surrounding code. If you want zero code coupling, you can instead expose a small interface in your existing package (`type Notifier interface{ Notify(int64, push.Payload) }`) and pass a no-op implementation when push is off.

## 5. Flutter app

### 5.1 Install

```bash
flutter pub add firebase_core firebase_messaging flutter_local_notifications
dart pub global activate flutterfire_cli
flutterfire configure
```

`flutterfire configure` generates `lib/firebase_options.dart` and adds the Google services config. Commit those files, they are not secrets.

### 5.2 Android requirements

- Make sure `android/app/google-services.json` exists (created by the command above).
- In `android/app/src/main/AndroidManifest.xml` add the Android 13+ permission:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

- Set `minSdkVersion` to at least 21 (23 for some versions of firebase plugins).

These are additive config changes and do not change app behaviour.

### 5.3 Isolated service: lib/services/push/push\_service.dart

```dart
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // The system shows the notification automatically when the app is in the background.
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const bool enabled = true; // flip to false to disable the feature

  final _local = FlutterLocalNotificationsPlugin();
  bool _started = false;

  /// Call once after the user logs in.
  /// [registerToken] posts the token to your Go API using your existing HTTP client.
  /// [onTap] handles navigation when a notification is tapped.
  Future<void> start({
    required Future<void> Function(String token, String platform) registerToken,
    void Function(Map<String, dynamic> data)? onTap,
  }) async {
    if (!enabled || _started) return;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final fm = FirebaseMessaging.instance;

      final settings = await fm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final platform = Platform.isIOS ? 'ios' : 'android';
      final token = await fm.getToken();
      if (token != null) await registerToken(token, platform);
      fm.onTokenRefresh.listen((t) => registerToken(t, platform));

      // Foreground: FCM shows nothing by default, so show a local notification
      await _local.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        _local.show(
          n.hashCode, n.title, n.body,
          const NotificationDetails(
            android: AndroidNotificationDetails('default', 'General',
                importance: Importance.high, priority: Priority.high),
            iOS: DarwinNotificationDetails(),
          ),
        );
      });

      // Tap while app in background
      FirebaseMessaging.onMessageOpenedApp.listen((m) => onTap?.call(m.data));
      // Tap that launched the app from terminated state
      final initial = await fm.getInitialMessage();
      if (initial != null) onTap?.call(initial.data);

      _started = true;
    } catch (e, st) {
      debugPrint('PushService failed (app continues normally): $e\n$st');
    }
  }

  /// Call on logout so the device stops getting this user's notifications.
  Future<void> stop(Future<void> Function(String token) unregisterToken) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await unregisterToken(token);
      await FirebaseMessaging.instance.deleteToken();
      _started = false;
    } catch (e) {
      debugPrint('PushService stop failed: $e');
    }
  }
}
```

### 5.3.1 Register the background handler

In `main()`, add this one line **before** `runApp`:

```dart
FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
```

This needs `Firebase.initializeApp` to have been called in `main()` as well. If your app does not already use Firebase, add `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);` there.

### 5.4 Usage after login

```dart
await PushService.instance.start(
  registerToken: (token, platform) => api.post('/api/push/devices',
      {'token': token, 'platform': platform}), // your existing HTTP client
  onTap: (data) {
    if (data['screen'] == 'order_detail') {
      // navigate using your existing router
    }
  },
);
```

On logout:

```dart
await PushService.instance.stop((token) =>
    api.delete('/api/push/devices', {'token': token, 'platform': 'android'}));
```

### 5.5 iOS (only when you have an Apple Developer account)

1. In Xcode enable **Push Notifications** and **Background Modes -> Remote notifications**.
2. In Apple Developer portal create an **APNs Auth Key (.p8)**.
3. Firebase console -> Project settings -> Cloud Messaging -> Apple app configuration -> upload the .p8 with Key ID and Team ID.
4. Test on a **real device**, the simulator does not receive remote push reliably.

## 6. React web app

### 6.1 Install

```bash
npm install firebase
```

### 6.2 Environment variables (.env)

```
VITE_FIREBASE_API_KEY=...
VITE_FIREBASE_PROJECT_ID=...
VITE_FIREBASE_MESSAGING_SENDER_ID=...
VITE_FIREBASE_APP_ID=...
VITE_FIREBASE_VAPID_KEY=...
VITE_PUSH_ENABLED=true
```

Use the `REACT_APP_` prefix instead of `VITE_` and `process.env` instead of `import.meta.env` if you use Create React App.

### 6.3 Isolated module: src/push/pushClient.js

```js
import { initializeApp } from "firebase/app";
import { getMessaging, getToken, deleteToken, onMessage, isSupported } from "firebase/messaging";

const env = import.meta.env;
const firebaseConfig = {
  apiKey: env.VITE_FIREBASE_API_KEY,
  projectId: env.VITE_FIREBASE_PROJECT_ID,
  messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: env.VITE_FIREBASE_APP_ID,
};

const PUSH_ENABLED = env.VITE_PUSH_ENABLED === "true";
let messaging = null;

/**
 * Call after login, from a user action if possible (browsers prefer that).
 * registerToken(token, "web") should POST to your Go API using your existing client.
 * Never throws: failures are logged and the app continues normally.
 */
export async function enablePush(registerToken, onForegroundMessage) {
  try {
    if (!PUSH_ENABLED || !(await isSupported())) return null;

    const permission = await Notification.requestPermission();
    if (permission !== "granted") return null;

    const app = initializeApp(firebaseConfig, "push"); // named app, will not clash with any other Firebase use
    messaging = getMessaging(app);

    const registration = await navigator.serviceWorker.register("/firebase-messaging-sw.js");
    const token = await getToken(messaging, {
      vapidKey: env.VITE_FIREBASE_VAPID_KEY,
      serviceWorkerRegistration: registration,
    });
    if (token) await registerToken(token, "web");

    onMessage(messaging, (payload) => onForegroundMessage?.(payload));
    return token;
  } catch (err) {
    console.warn("[push] failed, app continues normally:", err);
    return null;
  }
}

export async function disablePush(unregisterToken) {
  try {
    if (!messaging) return;
    const token = await getToken(messaging, { vapidKey: env.VITE_FIREBASE_VAPID_KEY });
    if (token) await unregisterToken(token);
    await deleteToken(messaging);
  } catch (err) {
    console.warn("[push] disable failed:", err);
  }
}
```

### 6.4 Service worker: public/firebase-messaging-sw.js

This file **must** be served from the site root. It uses its own scope, so it does not interfere with any existing service worker unless that one already controls the same scope. If your app already has a service worker (for example a PWA), tell me and I will give you the merged version.

```js
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "YOUR_API_KEY",
  projectId: "YOUR_PROJECT_ID",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID",
});

const messaging = firebase.messaging();
// Messages with a "notification" payload are displayed automatically in the background.

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow("/")); // change to a URL from event.notification.data if needed
});
```

Service workers cannot read `.env` files, so paste the public config values directly.

### 6.5 Usage

```jsx
import { enablePush } from "./push/pushClient";

// e.g. after login, or on an "Enable notifications" button
await enablePush(
  (token, platform) => api.post("/api/push/devices", { token, platform }),
  (payload) => toast(payload.notification?.title)
);
```

Web push requires **HTTPS** in production (`localhost` is allowed for development). Safari on iOS only supports web push for sites installed to the Home Screen.

## 7. Testing checklist

1. **Backend:** with `PUSH_ENABLED=false`, confirm the app runs exactly as before. Then set it to `true` and confirm the log line `[push] enabled`.
2. **Token registration:** log in from Flutter or React and check that a row appears in `push_device_tokens`.
3. **Console test:** Firebase console -> Messaging -> New campaign -> Send test message, paste the token.
4. **End to end:** trigger the real event in your app and confirm that `pushSvc.Notify` delivers the notification.
5. **States to test:** app in foreground, in background, fully closed, and a tap on the notification opening the right screen.
6. **Failure test:** set a wrong credentials path. The app must still start, with only a `[push] ... push disabled` log.

## 8. Troubleshooting

- **No token on Android:** check Google Play Services on the device or emulator (use an image with Google APIs), and that `google-services.json` is present.
- **Nothing shown on Android 13+:** the `POST_NOTIFICATIONS` permission was not granted.
- **Nothing in the foreground:** expected. FCM does not display foreground notifications, which is why `flutter_local_notifications` is used and why React has an `onMessage` handler.
- **Web: token request fails:** wrong VAPID key, service worker not at the site root, or the page is not on HTTPS.
- **Go: `SenderId mismatch` or `unregistered`:** the token came from a different Firebase project, or the app was uninstalled. The code deletes dead tokens automatically.
- **Go: `permission denied` / 401:** the service account JSON is from the wrong project, or the Firebase Cloud Messaging API (V1) is disabled in Google Cloud.
- **Data-only messages not arriving on iOS:** background data messages need the `content-available` flag and are throttled by iOS. Use the `notification` payload for anything the user must see.

## 9. Production notes

- Store `serviceAccountKey.json` as a server secret, not in the repo or the Docker image.
- Keep tokens per **device**, not per user (already done by the table design).
- Delete tokens on logout (done through the DELETE endpoint).
- Optionally prune tokens not updated for 60+ days: `DELETE FROM push_device_tokens WHERE updated_at < NOW() - INTERVAL 60 DAY;`
- Add rate limiting or deduplication in `Notify` later if you start sending high volumes.
- **Rollback plan:** set `PUSH_ENABLED=false`, optionally drop the table, and remove the `internal/push`, `lib/services/push` and `src/push` folders. Nothing else depends on them.

## 10. Summary of every change to existing code

- **Go:** about 6 lines in `main.go` (wiring), plus one `pushSvc.Notify(...)` line wherever you want a notification.
- **Flutter:** one line in `main()` (background handler), one `start()` call after login, one `stop()` on logout, plus Android manifest and Firebase config files.
- **React:** one `enablePush()` call after login. All other files are new.

## 11. Video-upload style notifications (images, channel subscribers, durable queue)

This section upgrades the module for "Channel X uploaded a new video" notifications with a thumbnail. It **replaces** `model.go` (4.4) and `service.go` (4.6) and adds `jobs.go`. The repository, the handler and any `pushSvc.Notify(...)` calls you already wrote keep working unchanged.

What you get:

- A thumbnail image in notifications on Android, web and iOS.
- A MySQL-backed queue: jobs survive server restarts, and failed sends retry up to 5 times (waits of 1, 2, 4 and 8 minutes).
- Channel sends in batches of 500 that resume where they stopped, so a retry does not send duplicates.
- Per-channel mute, a dedupe key to stop double sends, and sent/failed counts per notification.

The upload flow never waits on any of this: your code only inserts one small row, and a background worker does the sending.

### 11.1 Migrations (new tables only)

If your app already has a table for who follows which channel, you can skip `push_subscriptions` and point the query in `sendChannel` at your own table instead.

```sql
CREATE TABLE IF NOT EXISTS push_subscriptions (
    user_id    BIGINT UNSIGNED NOT NULL,
    channel_id BIGINT UNSIGNED NOT NULL,
    muted      TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (channel_id, user_id),
    KEY idx_push_sub_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS push_jobs (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    dedupe_key      VARCHAR(128) NULL,
    kind            ENUM('user','channel') NOT NULL,
    target_id       BIGINT UNSIGNED NOT NULL,        -- user id or channel id
    payload         JSON NOT NULL,
    status          ENUM('pending','processing','done','failed') NOT NULL DEFAULT 'pending',
    attempts        INT UNSIGNED NOT NULL DEFAULT 0,
    cursor_id       BIGINT UNSIGNED NOT NULL DEFAULT 0,  -- resume point inside push_device_tokens
    sent_count      INT UNSIGNED NOT NULL DEFAULT 0,
    failed_count    INT UNSIGNED NOT NULL DEFAULT 0,
    last_error      VARCHAR(500) NULL,
    claim_token     CHAR(32) NULL,
    locked_at       TIMESTAMP NULL DEFAULT NULL,
    next_attempt_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_push_dedupe (dedupe_key),
    KEY idx_push_jobs_pick (status, next_attempt_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

The `JSON` type needs MySQL 5.7 or newer; on older versions use `TEXT`. A `NULL` dedupe key is allowed many times, so only jobs with a key are deduplicated.

### 11.2 model.go (replace)

```go
package push

type Payload struct {
	Title    string            `json:"title"`
	Body     string            `json:"body"`
	ImageURL string            `json:"image_url,omitempty"` // public https URL
	Data     map[string]string `json:"data,omitempty"`      // e.g. {"screen":"video","id":"123"}
}
```

### 11.3 service.go (replace)

```go
package push

import (
	"context"
	"database/sql"
	"log"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type Service struct {
	enabled bool
	client  *messaging.Client
	db      *sql.DB
	repo    Repository
}

// New never stops your app: any problem just disables push and is logged.
// ctx should live as long as the application (the worker stops when it ends).
func New(ctx context.Context, db *sql.DB, repo Repository, enabled bool, credsFile string) *Service {
	s := &Service{db: db, repo: repo}
	if !enabled {
		log.Println("[push] disabled by config")
		return s
	}
	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credsFile))
	if err != nil {
		log.Printf("[push] firebase init failed, push disabled: %v", err)
		return s
	}
	client, err := app.Messaging(ctx)
	if err != nil {
		log.Printf("[push] messaging init failed, push disabled: %v", err)
		return s
	}
	s.client, s.enabled = client, true
	go s.worker(ctx)
	log.Println("[push] enabled")
	return s
}

// Notify sends to all devices of one user. Non-blocking, never returns an error.
func (s *Service) Notify(userID int64, p Payload) {
	if s == nil || !s.enabled {
		return
	}
	s.enqueue("user", userID, p, "")
}

// NotifyChannelSubscribers sends to every non-muted subscriber of a channel.
// dedupeKey (for example "video:123") makes repeated calls for the same event send only once.
func (s *Service) NotifyChannelSubscribers(channelID int64, p Payload, dedupeKey string) {
	if s == nil || !s.enabled {
		return
	}
	s.enqueue("channel", channelID, p, dedupeKey)
}

func (s *Service) worker(ctx context.Context) {
	t := time.NewTicker(2 * time.Second)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			s.recoverStuck()
			for {
				j := s.claim()
				if j == nil {
					break
				}
				s.run(j)
			}
		}
	}
}
```

### 11.4 jobs.go (new)

```go
package push

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"firebase.google.com/go/v4/messaging"
)

const maxAttempts = 5

type jobRow struct {
	ID       int64
	Kind     string
	TargetID int64
	Payload  Payload
	Attempts int
	Cursor   int64
	Sent     int
	Failed   int
}

// enqueue inserts one row in the background so the caller is never slowed down.
func (s *Service) enqueue(kind string, targetID int64, p Payload, dedupeKey string) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("[push] enqueue panic: %v", r)
			}
		}()
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		b, err := json.Marshal(p)
		if err != nil {
			log.Printf("[push] enqueue marshal: %v", err)
			return
		}
		var dk interface{}
		if dedupeKey != "" {
			dk = dedupeKey
		}
		_, err = s.db.ExecContext(ctx,
			`INSERT INTO push_jobs (dedupe_key, kind, target_id, payload) VALUES (?, ?, ?, ?)`,
			dk, kind, targetID, string(b))
		if err != nil && !strings.Contains(err.Error(), "Duplicate entry") {
			log.Printf("[push] enqueue failed: %v", err)
		}
	}()
}

func newToken() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// claim atomically takes the oldest due job, safe even with several server instances.
func (s *Service) claim() *jobRow {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	tok := newToken()
	res, err := s.db.ExecContext(ctx, `
		UPDATE push_jobs
		SET status='processing', attempts=attempts+1, claim_token=?, locked_at=NOW()
		WHERE status='pending' AND next_attempt_at <= NOW()
		ORDER BY id LIMIT 1`, tok)
	if err != nil {
		log.Printf("[push] claim failed: %v", err)
		return nil
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return nil
	}
	var j jobRow
	var raw []byte
	err = s.db.QueryRowContext(ctx, `
		SELECT id, kind, target_id, payload, attempts, cursor_id, sent_count, failed_count
		FROM push_jobs WHERE claim_token=? AND status='processing'`, tok).
		Scan(&j.ID, &j.Kind, &j.TargetID, &raw, &j.Attempts, &j.Cursor, &j.Sent, &j.Failed)
	if err != nil {
		log.Printf("[push] claim read failed: %v", err)
		return nil
	}
	if err := json.Unmarshal(raw, &j.Payload); err != nil {
		log.Printf("[push] bad payload in job %d: %v", j.ID, err)
		s.exec(`UPDATE push_jobs SET status='failed', last_error='bad payload' WHERE id=?`, j.ID)
		return nil
	}
	return &j
}

// recoverStuck frees jobs whose server died mid-send.
func (s *Service) recoverStuck() {
	s.exec(`UPDATE push_jobs SET status='pending'
		WHERE status='processing' AND locked_at < NOW() - INTERVAL 10 MINUTE`)
}

func (s *Service) exec(query string, args ...interface{}) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err := s.db.ExecContext(ctx, query, args...); err != nil {
		log.Printf("[push] db update failed: %v", err)
	}
}

func (s *Service) run(j *jobRow) {
	defer func() {
		if r := recover(); r != nil {
			s.retryOrFail(j, fmt.Errorf("panic: %v", r))
		}
	}()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	var err error
	switch j.Kind {
	case "user":
		err = s.sendUser(ctx, j)
	case "channel":
		err = s.sendChannel(ctx, j)
	}
	if err != nil {
		s.retryOrFail(j, err)
		return
	}
	s.exec(`UPDATE push_jobs SET status='done', last_error=NULL, sent_count=?, failed_count=? WHERE id=?`,
		j.Sent, j.Failed, j.ID)
}

func (s *Service) retryOrFail(j *jobRow, cause error) {
	msg := cause.Error()
	if len(msg) > 500 {
		msg = msg[:500]
	}
	log.Printf("[push] job %d attempt %d failed: %s", j.ID, j.Attempts, msg)
	if j.Attempts >= maxAttempts {
		s.exec(`UPDATE push_jobs SET status='failed', last_error=? WHERE id=?`, msg, j.ID)
		return
	}
	delay := (1 << uint(j.Attempts)) * 30 // 60s, 120s, 240s, 480s
	s.exec(`UPDATE push_jobs SET status='pending', last_error=?,
		next_attempt_at = NOW() + INTERVAL ? SECOND WHERE id=?`, msg, delay, j.ID)
}

func (s *Service) sendUser(ctx context.Context, j *jobRow) error {
	tokens, err := s.repo.TokensByUser(ctx, j.TargetID)
	if err != nil {
		return err
	}
	if len(tokens) == 0 {
		return nil
	}
	sent, failed, err := s.sendBatch(ctx, tokens, j.Payload)
	j.Sent, j.Failed = sent, failed
	return err
}

// sendChannel walks the subscribers' device tokens 500 at a time and saves its
// position after every batch, so a retry continues instead of starting over.
func (s *Service) sendChannel(ctx context.Context, j *jobRow) error {
	for {
		rows, err := s.db.QueryContext(ctx, `
			SELECT t.id, t.token
			FROM push_subscriptions s
			JOIN push_device_tokens t ON t.user_id = s.user_id
			WHERE s.channel_id = ? AND s.muted = 0 AND t.id > ?
			ORDER BY t.id LIMIT 500`, j.TargetID, j.Cursor)
		if err != nil {
			return err
		}
		var ids []int64
		var tokens []string
		for rows.Next() {
			var id int64
			var tok string
			if err := rows.Scan(&id, &tok); err != nil {
				rows.Close()
				return err
			}
			ids = append(ids, id)
			tokens = append(tokens, tok)
		}
		rows.Close()
		if len(tokens) == 0 {
			return nil // finished
		}
		sent, failed, err := s.sendBatch(ctx, tokens, j.Payload)
		if err != nil {
			return err
		}
		j.Cursor = ids[len(ids)-1]
		j.Sent += sent
		j.Failed += failed
		s.exec(`UPDATE push_jobs SET cursor_id=?, sent_count=?, failed_count=? WHERE id=?`,
			j.Cursor, j.Sent, j.Failed, j.ID)
	}
}

func (s *Service) sendBatch(ctx context.Context, tokens []string, p Payload) (sent, failed int, err error) {
	resp, err := s.client.SendEachForMulticast(ctx, buildMessage(tokens, p))
	if err != nil {
		return 0, 0, err
	}
	for i, r := range resp.Responses {
		if r.Success {
			sent++
			continue
		}
		failed++
		if messaging.IsUnregistered(r.Error) { // app uninstalled or token expired
			_ = s.repo.Delete(ctx, tokens[i])
		}
	}
	return sent, failed, nil
}

func buildMessage(tokens []string, p Payload) *messaging.MulticastMessage {
	img := ""
	if strings.HasPrefix(p.ImageURL, "https://") { // a bad URL would make FCM reject the message
		img = p.ImageURL
	}
	m := &messaging.MulticastMessage{
		Tokens:       tokens,
		Notification: &messaging.Notification{Title: p.Title, Body: p.Body, ImageURL: img},
		Data:         p.Data,
	}
	if img != "" {
		m.APNS = &messaging.APNSConfig{
			Payload:    &messaging.APNSPayload{Aps: &messaging.Aps{MutableContent: true}},
			FCMOptions: &messaging.APNSFCMOptions{ImageURL: img},
		}
		m.Webpush = &messaging.WebpushConfig{
			Notification: &messaging.WebpushNotification{Image: img},
		}
	}
	return m
}
```

A failure that affects the whole call (FCM unavailable, network error) triggers a retry. A single dead token does not: it is removed and counted as failed.

### 11.5 main.go wiring (one changed line)

`New` now also receives the database handle:

```go
pushSvc := push.New(ctx, db, pushRepo,
	os.Getenv("PUSH_ENABLED") == "true",
	os.Getenv("FIREBASE_CREDENTIALS_FILE"))
```

### 11.6 Subscribe and mute endpoints (optional)

Skip this if your app already has follow/unfollow. This uses Go 1.22+ route patterns; on older versions or other routers use the same SQL in your own handler.

```go
package push

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
)

func RegisterSubscriptionRoutes(mux *http.ServeMux, db *sql.DB,
	auth func(http.Handler) http.Handler, uid UserIDFunc) {

	// PUT body: {"muted": false}  -> subscribe, or change the mute setting
	mux.Handle("PUT /api/push/channels/{id}/subscription", auth(http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			userID, ok := uid(r)
			channelID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
			if !ok || err != nil {
				http.Error(w, "bad request", http.StatusBadRequest)
				return
			}
			var body struct {
				Muted bool `json:"muted"`
			}
			_ = json.NewDecoder(r.Body).Decode(&body)
			_, err = db.ExecContext(r.Context(), `
				INSERT INTO push_subscriptions (user_id, channel_id, muted) VALUES (?, ?, ?)
				ON DUPLICATE KEY UPDATE muted = VALUES(muted)`, userID, channelID, body.Muted)
			if err != nil {
				http.Error(w, "server error", http.StatusInternalServerError)
				return
			}
			w.WriteHeader(http.StatusNoContent)
		})))

	mux.Handle("DELETE /api/push/channels/{id}/subscription", auth(http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			userID, ok := uid(r)
			channelID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
			if !ok || err != nil {
				http.Error(w, "bad request", http.StatusBadRequest)
				return
			}
			_, _ = db.ExecContext(r.Context(),
				`DELETE FROM push_subscriptions WHERE user_id = ? AND channel_id = ?`, userID, channelID)
			w.WriteHeader(http.StatusNoContent)
		})))
}
```

### 11.7 Sending when a video is published

Add one call where the video becomes public. It returns immediately and cannot fail your upload:

```go
pushSvc.NotifyChannelSubscribers(video.ChannelID, push.Payload{
	Title:    channel.Name + " uploaded a new video",
	Body:     video.Title,
	ImageURL: video.ThumbnailURL, // public https URL
	Data:     map[string]string{"screen": "video", "id": strconv.FormatInt(video.ID, 10)},
}, "video:"+strconv.FormatInt(video.ID, 10))
```

Call it only when the video goes public (not on every edit). The dedupe key `video:<id>` guarantees one notification per video even if your code runs twice.

### 11.8 Image rules

- A public **HTTPS** URL that needs no login or cookies.
- Under about 1 MB, JPEG or PNG, ideally 1024x512 (2:1).
- Use a stable CDN or storage URL. If the image is slow or fails to download, the notification still arrives, just without the picture.

### 11.9 Flutter changes (foreground image and video tap)

Background and terminated notifications show the image automatically on Android. While the app is open you show it yourself. In `push_service.dart`, add a download helper and replace the `FirebaseMessaging.onMessage.listen` block:

```dart
import 'dart:typed_data';
// (dart:io and package:flutter/foundation.dart are already imported)

Future<Uint8List?> _download(String url) async {
  try {
    final req = await HttpClient().getUrl(Uri.parse(url)).timeout(const Duration(seconds: 5));
    final res = await req.close().timeout(const Duration(seconds: 5));
    return Uint8List.fromList(await consolidateHttpClientResponseBytes(res));
  } catch (_) {
    return null; // show the notification without the picture
  }
}

// inside start(), replacing the previous onMessage listener:
FirebaseMessaging.onMessage.listen((m) async {
  final n = m.notification;
  if (n == null) return;
  final imageUrl = n.android?.imageUrl ?? n.apple?.imageUrl;
  final bytes = imageUrl == null ? null : await _download(imageUrl);
  _local.show(
    n.hashCode, n.title, n.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'default', 'General',
        importance: Importance.high, priority: Priority.high,
        styleInformation: bytes == null
            ? null
            : BigPictureStyleInformation(ByteArrayAndroidBitmap(bytes)),
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    payload: m.data['id'],
  );
});
```

In your `onTap` callback, add the video case:

```dart
if (data['screen'] == 'video') {
  // navigate to the video page with data['id'] using your existing router
}
```

### 11.10 React changes (foreground image and video tap)

In `src/push/pushClient.js`, replace the `onMessage(...)` line inside `enablePush` so foreground messages also show the image:

```js
onMessage(messaging, async (payload) => {
  onForegroundMessage?.(payload);
  const n = payload.notification;
  if (n && Notification.permission === "granted") {
    const reg = await navigator.serviceWorker.ready;
    reg.showNotification(n.title, { body: n.body, image: n.image, data: payload.data });
  }
});
```

In `public/firebase-messaging-sw.js`, open the right video when the notification is clicked:

```js
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const d = event.notification.data || {};
  const url = d.screen === "video" ? "/video/" + d.id : "/";
  event.waitUntil(clients.openWindow(url));
});
```

Chrome and Edge show the image. Safari and Firefox may show a plain notification without it.

### 11.11 iOS image support

iOS only shows images through a **Notification Service Extension**, and needs the paid Apple Developer account from section 2:

1. In Xcode: File -> New -> Target -> **Notification Service Extension**.
2. Make sure its deployment target matches your app's.
3. Keep the generated `NotificationService.swift`, or use the Firebase-provided `FIRMessagingExtensionHelper` (`populateNotificationContent`) so the image from `fcm_options.image` is downloaded and attached.
4. Test on a real device. The `mutable-content` flag is already set by `buildMessage` when an image is present.

Without the extension, iOS still delivers the notification, only without the picture.

### 11.12 Tracking and cleanup (plain SQL)

```sql
-- How did the last 20 notifications do?
SELECT id, kind, target_id, status, attempts, sent_count, failed_count, last_error, created_at
FROM push_jobs ORDER BY id DESC LIMIT 20;

-- Anything stuck or failed?
SELECT * FROM push_jobs WHERE status IN ('failed','processing') ORDER BY id DESC;

-- Weekly cleanup of finished jobs
DELETE FROM push_jobs WHERE status IN ('done','failed') AND created_at < NOW() - INTERVAL 30 DAY;
```

These counts show sends and failures. Counting taps (opens) needs an extra tap event sent to your own API from the apps, which this guide leaves out.

### 11.13 Test checklist for this section

1. Run the two migrations, restart the backend, and check for the `[push] enabled` log line.
2. Subscribe a test user to a channel, register their device token, and call `NotifyChannelSubscribers`. Within about 2 seconds the job should be `done` with `sent_count` of 1 or more.
3. Call it twice with the same dedupe key and confirm only one `push_jobs` row exists and one notification arrives.
4. Mute the channel for that user and confirm no notification arrives.
5. Stop the backend right after enqueueing, start it again, and confirm the notification is still sent.
6. Use a wrong credentials path and confirm uploads still work and jobs stay `pending`, then retry once Firebase is fixed.
7. Test with an image URL, with a broken image URL (the text should still arrive), and with the app in foreground, background and closed.
