# Mobile App Feature Parity & Implementation Plan

**Project**: Creator Monetization Platform  
**Target**: Flutter Mobile Application (`mobile/`)  
**Created**: November 2, 2026  
**Status**: Fully Implemented & Verified  

---

## 1. Executive Summary & Purpose
The web application of the **Creator Monetization Platform** has recently gained major capabilities:
1. **Google OAuth & JWT Authentication** with guest viewing and social action gating (`AuthRequiredModal`).
2. **Dynamic Categories** (`/api/categories`) dynamically managed by the admin (Self / Personal Brand, Promotion & Sponsorship, Business & MSME, Product Review).
3. **Format Separation** (`video_type`: `landscape` 16:9 vs. `short` 9:16) with dedicated feeds for each format.
4. **Interactive Shorts Player** with a real-time progress bar, drag/scrub seek, tap-to-play/pause, volume mute/unmute, and timestamp tracking.
5. **Landscape Video Playback (Theater Experience)** with controls, creator subscribe/follow, and live comments.
6. **Creator Video Upload Studio** with format selector, file picker, and progress bar.
7. **Clean Duration Formatting** (zero decimals / `MM:SS`).

Currently, the mobile app (`mobile/`) has mock placeholders:
- `ShortsScreen` uses static Unsplash images with no video player or progress scrubber.
- `HomeScreen` uses hardcoded categories and clicking a video only triggers a SnackBar.
- `UploadActionSheet` only shows placeholder SnackBars without actual file picking or uploading.
- There is no Authentication (Guest vs. Logged In) or Auth Gate for social actions (like, comment, subscribe).

This document outlines the systematic upgrade of the mobile app to achieve **complete feature parity, high performance, and rich aesthetics**.

---

## 2. Feature-by-Feature Gap Analysis

| Feature Area | Web Platform Status | Mobile App Current Status | Planned Mobile Solution |
| :--- | :--- | :--- | :--- |
| **Authentication & Session** | Google OAuth + JWT (Login/Register), guest viewing | No Auth system, hardcoded mock user | Add `AuthService`, JWT storage in `SharedPreferences`, Login/Register Sheet with Google Sign-In & guest mode. |
| **Guest Action Gating** | Unauthenticated like/comment/subscribe opens `AuthRequiredModal` | Actions increment locally without auth check | Create `AuthRequiredDialog` in Flutter, intercept Like, Comment, and Subscribe taps for guests. |
| **Categories** | Dynamic `/api/categories` (Self, Promotion, Business, Product) | Hardcoded static list in `HomeScreen` | Add `CategoryModel`, fetch from `/api/categories`, render dynamic ChoiceChips. |
| **Video Format Filter** | Landscape (16:9) in Explore; Vertical (9:16) in Shorts | All videos lumped together in `HomeScreen` | Add `videoType` to `VideoModel`; `HomeScreen` filters landscape; `ShortsScreen` loads real short videos. |
| **Shorts Video Player** | Real video with bottom interactive scrubber, drag seek, tap pause | Static images (`Image.network`) with no player | Implement `video_player` in `ShortsScreen` with bottom interactive hairline scrubber, tap play/pause, volume toggle. |
| **Landscape Video Player** | Full `TheaterModal` with player, controls, comments, subscribe | Tap only shows a SnackBar | Create dedicated `VideoDetailScreen` with native `video_player`, interactive controls, subscribe, and comments. |
| **Video Upload** | Complete modal with format picker, category picker, upload progress | Dummy sheet showing SnackBars | Create `UploadVideoScreen` with `file_picker`, title, description, category selector, format selector, and upload API call. |
| **Comments & Social** | Live `/api/videos/:id/comments`, like count, subscriber sync | Static mock comments, local increment only | Connect `CommentsSheet` to live API with post comment, like, and subscribe endpoints. |

---

## 3. Step-by-Step Implementation Roadmap

### Phase 1: Dependencies & Network Service Layer
1. **Update `mobile/pubspec.yaml`**:
   - `video_player: ^2.9.2` — native mobile hardware-accelerated playback.
   - `file_picker: ^8.1.4` — native gallery/file selection for videos and thumbnails.
2. **Models Upgrade (`mobile/lib/data/models/`)**:
   - **`CategoryModel`**: `id`, `name`, `slug`, `icon`, `videoCount`.
   - **`VideoModel`**: Add `videoType` (`'landscape'` | `'short'`), update `durationFormatted` to ensure clean `MM:SS` display.
   - **`UserModel`**: `id`, `email`, `fullName`, `avatarUrl`, `role`, `token`.
3. **API Service Expansion (`mobile/lib/data/services/api_service.dart`)**:
   - `fetchCategories()` -> `GET /api/categories`.
   - `fetchVideos({String? category, String? videoType})` -> `GET /api/videos?category=...&video_type=...`.
   - `fetchShorts()` -> `GET /api/videos?video_type=short`.
   - `toggleLike(String videoId)` -> `POST /api/videos/:id/like`.
   - `toggleSubscribe(String creatorName)` -> `POST /api/creators/subscribe`.
   - `postComment(String videoId, String text)` -> `POST /api/videos/:id/comments`.
   - `uploadVideo(...)` -> `POST /api/videos/upload` (multipart with progress).

---

### Phase 2: Authentication & Social Action Gate
1. **Auth Service & State (`mobile/lib/data/services/auth_service.dart`)**:
   - Persist JWT and user profile in `SharedPreferences`.
   - Provide `currentUser`, `isLoggedIn`, `login()`, `register()`, `googleLogin()`, and `logout()`.
2. **Auth Bottom Sheet (`mobile/lib/presentation/widgets/auth_sheet.dart`)**:
   - Clean dark-mode dialog matching the platform design tokens.
   - Tabs for "Log In" and "Sign Up", plus Google Sign-In button.
3. **Guest Action Gate (`mobile/lib/presentation/widgets/auth_required_dialog.dart`)**:
   - Displays when a guest taps Like, Comment, or Subscribe:
     > *"Account Required — Please log in to like this video, leave comments, or subscribe to creators."*
   - Buttons: **Log In / Sign Up** (opens auth sheet) and **Cancel**.

---

### Phase 3: Interactive Shorts & Reels Player
1. **Refactor `ShortsScreen` (`mobile/lib/presentation/screens/shorts/shorts_screen.dart`)**:
   - Fetch real short videos from `ApiService.fetchShorts()`.
   - Convert reel item into `ReelVideoPlayerItem` with its own `VideoPlayerController`.
   - **Modern Interactive Scrubber**:
     - Slim 3px hairline progress bar at the bottom edge.
     - Supports tap and drag (`onHorizontalDragUpdate`) to seek video playback.
     - Displays time counter: `${current} / ${duration}`.
   - **Controls**:
     - Tap video: Toggle Play/Pause with center animated icon splash.
     - Top-right sound toggle: Mute/Unmute.
     - Double-tap: Heart burst animation + Like trigger.
     - Right action bar: Like count, Comment count (opens live `CommentsSheet`), Share, Save.
     - Subscribe button: Follows creator with auth check.

---

### Phase 4: Long-Form Video Player & Home Feed
1. **Home Feed (`mobile/lib/presentation/screens/home/home_screen.dart`)**:
   - Fetch dynamic category chips from `/api/categories`.
   - Filter `_videos` to only show `video_type == 'landscape'`.
   - Tapping a `VideoCard` navigates to `VideoDetailScreen`.
2. **Video Detail Screen (`mobile/lib/presentation/screens/video_detail/video_detail_screen.dart`)**:
   - Embedded 16:9 `VideoPlayer` with scrub bar, play/pause, fullscreen toggle.
   - Video title, view count, clean duration, upload date.
   - Channel header with creator avatar, subscriber count, and Follow/Subscribe button.
   - Action row: Like, Share, Save.
   - Live Comments preview that expands into full `CommentsSheet`.

---

### Phase 5: Mobile Upload Studio
1. **Upload Screen (`mobile/lib/presentation/screens/upload/upload_video_screen.dart`)**:
   - Pick Video file via `FilePicker`.
   - Pick Custom Thumbnail via `FilePicker`.
   - Enter Title & Description.
   - Select Category from dynamic category list.
   - **Format Selector**:
     - Card 1: **Landscape (16:9)** — Recommended for standard long-form tutorials & reviews.
     - Card 2: **Vertical Reel / Short (9:16)** — Recommended for 60s shorts.
   - Upload Button with progress bar indicator.

---

## 4. Verification & Testing Strategy
1. **Dart Analysis**: Run `flutter analyze` in `mobile/` to ensure zero compilation or lint errors.
2. **API Verification**: Verify mobile communicates with local backend (`http://10.10.100.251:8085/api`) across all endpoints (`/categories`, `/videos`, `/comments`, `/auth`).
3. **Player Testing**: Verify smooth playback, scrubbing, and pausing in both Shorts (vertical) and Landscape detail players.
4. **Auth Flow Testing**: Verify unauthenticated guests can browse freely, and tapping Like/Comment/Subscribe properly prompts the Auth Required dialog.

---

## 5. Execution Summary & Deliverables

All phases have been fully engineered and integrated:
- **Phase 1 (Network & Foundation)**: Added `video_player: ^2.9.2` and `file_picker: ^8.1.4`, configured Android cleartext network & iOS security plist, created `CategoryModel`, `UserModel`, upgraded `VideoModel` with `videoType`, clean duration, and URL normalization, expanded `ApiService` to cover categories, shorts, comments, likes, auth, and upload. Upgraded Go backend (`ListVideos`) with `video_type` filtering.
- **Phase 2 (Auth & Social Gating)**: Created `AuthService` (`ChangeNotifier` with `SharedPreferences` session persistence), `AuthRequiredDialog` with action customization, and `AuthSheet` with Sign In, Create Account, and Google OAuth tabs.
- **Phase 3 (Interactive Shorts Player)**: Built `ShortsScreen` with sliding-window `VideoPlayerController` cache (max 3), interactive bottom hairline scrubber (2.5px -> 5px) with live timestamp tooltip, single tap play/pause splash, double tap heart burst, global mute/unmute toggle, and auth-gated like, subscribe, and comments.
- **Phase 4 (Long-Form Theater Player & Home Feed)**: Built `VideoDetailScreen` with 16:9 native player, scrub slider with timestamp, creator tier badge & follow button, action pill row, expandable description, live comments preview, and recommended videos. Upgraded `HomeScreen` with dynamic categories from `/api/categories` and 16:9 filtering.
- **Phase 5 (Mobile Upload Studio)**: Built `UploadVideoScreen` with native `FilePicker` for video & custom thumbnail, format selector (16:9 Landscape vs 9:16 Short), dynamic category selector, upload progress indicator, and wired to `UploadActionSheet`.
