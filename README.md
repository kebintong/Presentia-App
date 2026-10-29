# Presentia Phone App

The phone companion to **Presentia Desktop**. The desktop watches online classes (Google Meet, Zoom, Teams);
the phone handles what happens **in the room**: taking attendance in person, calling on students at random,
and accepting new student registrations. Both work on the same data through the teacher's Presentia account.

> The phone does **not** monitor online meetings. That stays on the desktop.

---

## What it does

### 1. Sign in
- The teacher types their email, receives a **sign-in code** (the length is set in Supabase; this project uses 8 digits), and types it in. No password.
- It is the **same account** as Settings → Phone app on the desktop, so the phone shows the same classes and students.

### 2. Classes
- The list of the teacher's classes, synced from the desktop.
- Opening a class shows its students by name and student number (faces are stored as templates, not pictures).

### 3. In-person attendance
- **Start session** creates an in-person session for the class.
- **Face scan:** each student looks at the teacher's phone; when the face matches a student in the class, they are
  marked **Present** (or **Late** after the late time).
- **Tap list (fallback):** the class list with Present / Late / Absent buttons, for when the camera can't be used.
- **End session** marks everyone not seen as Absent.
- The session and its attendance appear on the desktop's Students and Reports pages within seconds.

### 4. Random recitation
- Picks a student at random **from those marked present** in the current session.
- Nobody is picked twice until everyone present has had a turn.
- Optional: type the question.
- The teacher taps **✓ Correct** or **✗ Wrong**. Each pick is saved and synced.

### 5. Accept or decline registrations
- Students register on the Presentia registration website with the class join code.
- The desktop downloads each registration and builds the face template, then it appears on **both** the desktop and
  the phone, with a small photo and what accepting will do ("new student", "already registered as …, joins this
  class", "⚠ number belongs to …").
- The teacher taps **Accept** or **Decline** on either device. **The first decision wins**; the prompt disappears
  from the other device within seconds.
- Accepting a registration flagged ⚠ is not allowed (conflict, number taken, no usable face).

---

## How it connects to the desktop

```
 Students' phones                 Teacher's computer                      Teacher's phone
┌──────────────────┐   HTTPS   ┌───────────────────────────┐          ┌─────────────────────┐
│ Registration     │ ───────▶  │ Presentia Desktop         │          │ Presentia Phone App │
│ website (web/)   │ ◀───────  │ - builds face templates   │          │ - in-person         │
│ Cloudflare       │  collects │ - online class monitoring │          │   attendance        │
└──────────────────┘           │ - local SQLite database   │          │ - recitation        │
                               └─────────────┬─────────────┘          │ - accept/decline    │
                                             │ sync every 5 s         └──────────┬──────────┘
                                             │ (only when signed in)              │ live (Realtime)
                                             ▼                                    ▼
                               ┌──────────────────────────────────────────────────────────┐
                               │ Supabase (supabase/ in the Presentia repo)               │
                               │ Postgres + row-level security: each teacher sees only    │
                               │ their own rows. Same tables for both apps.               │
                               └──────────────────────────────────────────────────────────┘
```

- The **desktop stays the main copy**: it works offline and keeps everything in its own database; when the teacher is
  signed in it uploads changes and downloads the phone's changes every 5 seconds.
- The **phone talks only to Supabase**, never to the desktop directly. The two never need to be on the same network.
- **Face templates are only made on the desktop** (from the website photos or the desktop webcam). The phone uses them
  to recognise students; it does not create students. New students come in through registrations (section 5).
- If the desktop is off, the phone still works with what is already synced: attendance and recitation are saved to the
  account and reach the desktop when it starts. A registration accepted on the phone is added on the desktop the next
  time it runs.

---

## Data it uses

All tables live in Supabase (`supabase/migrations/0001_presentia.sql`). Every row has:

| Column | Meaning |
|---|---|
| `id` | UUID, made by the device that creates the row |
| `owner_id` | the teacher's account (set automatically) |
| `updated_at` | when it last changed, by the device's clock; the newest change wins |
| `server_at` | set by the server; used to fetch "what changed since" |
| `deleted` | rows are never removed, only marked; marking one wipes its names and face data |

| Table | Phone reads | Phone writes |
|---|---|---|
| `classes` | ✓ | — |
| `students` | ✓ (with `embedding`) | — |
| `student_faces` | ✓ (extra angles) | — |
| `class_students` | ✓ (who is in which class) | — |
| `sessions` | ✓ | ✓ in-person sessions |
| `attendance` | ✓ | ✓ `status` = `Present` / `Late` / `Absent` |
| `pending_students` | ✓ | ✓ the decision only |
| `recitations` | ✓ | ✓ picks and Correct / Wrong |

Times the teacher sees (`started_at`, `time_in`, `asked_at`, …) are **local time as text**,
`YYYY-MM-DD HH:MM:SS`, the same format the desktop writes.

### Rules the phone must follow
- **Fetch changes:** `rpc/presentia_changes({ since })` returns every changed row per table; keep the newest
  `server_at` and ask again with it (minus a minute of overlap).
- **Save:** upsert with `on_conflict: 'id'` and a fresh `updated_at` (UTC). Create the UUID on the phone, so saving
  again after a failed request is safe.
- **Delete:** set `deleted = true` (never a real delete).
- **Decide a registration:** update `pending_students` **only where** `decision is null` and `deleted = false`,
  setting `decision` (`accepted` / `declined`), `decided_by = 'phone'`, `decided_at`. **Do not send `updated_at`.**
  If no row comes back, the desktop decided first.
- **Live updates:** subscribe to `pending_students` and `attendance` with Supabase Realtime so prompts disappear the
  moment the desktop decides.

---

## Face recognition on the phone

It must use the **same model as the desktop**, or desktop-made templates won't match.

| | |
|---|---|
| Recognition | ArcFace `w600k_r50` (InsightFace), 112×112 aligned face → 512 numbers |
| Template format | `students.embedding`: base64 of 512 little-endian float32 |
| Match | cosine similarity **≥ 0.45** (same as the desktop); compare against `students.embedding` and `student_faces` |
| Detection | SCRFD or YuNet to find the face and its 5 landmarks for alignment |
| Runtime | ONNX Runtime on the phone (ONNX Runtime for iOS) |
| Model size | about 170 MB, downloaded once on first use |
| Liveness (optional) | MediaPipe Face Landmarker: ask for a blink or head turn so a photo can't check in |

Speed: one face at a time at the door, a few hundred ms per face on a mid-range phone — fine for check-in.

> License: the InsightFace models are for non-commercial research use only (same as the desktop).

---

## Tech stack

iOS only, native Swift. Open `Presentia.xcodeproj` in Xcode 16 or newer.

| Part | Choice | Why |
|---|---|---|
| App | **SwiftUI** (iOS 17+) | native iPhone app built in Xcode |
| Backend | **Supabase** ([`supabase-swift`](https://github.com/supabase/supabase-swift), Swift Package) | already set up for the desktop: auth by email code, Postgres, row-level security, Realtime |
| Camera | AVFoundation | frame access for face recognition |
| Face models | ONNX Runtime for iOS (`onnxruntime-swift-package-manager`) | runs the same ONNX models as the desktop |
| Offline queue | SwiftData (or SQLite) | keep attendance taken without signal and upload it later |
| Builds | Xcode → TestFlight / App Store | needs a Mac and an Apple developer account |

Configuration goes in `Presentia/Config.swift` (from Supabase → Project Settings → API):

```swift
static let supabaseURL = URL(string: "https://<project>.supabase.co")!
static let supabaseKey = "<publishable / anon key>"
```

The publishable key is meant to be in the app; row-level security protects the data.
**Never** put the `service_role` / secret key in the app or its repository.

---

## Privacy

- Face templates come down to the phone so it can recognise students; they are 512 numbers, not photos.
- Signing out clears the phone's copy.
- Everything is limited to the teacher's own account by row-level security.
- Students are told in the registration website's privacy notice that, if their teacher uses the phone app, their
  name, student ID, face template and attendance are kept in the teacher's own Presentia account online.
- Have the school's data protection officer review it (Philippine Data Privacy Act of 2012).

---

## Suggested build order

1. **Sign in + class list + student list** (proves the account and the data).
2. **Accept / decline registrations** with Realtime (no camera needed; uses what the desktop already does).
3. **Tap-list attendance** and **random recitation** (no camera needed).
4. **Face-scan check-in** (camera + ONNX models).
5. **Offline queue** for attendance taken without signal.
6. **Liveness check** (optional).

## Not in the phone app

- Monitoring online meetings (desktop only).
- Registering a student's face from scratch (desktop webcam, or the registration website).
- Deleting classes or students (desktop).
