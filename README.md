# LAN Personal Music Server & Streaming Application

A complete, **LAN-only personal music streaming application** engineered to stream high-fidelity audio (FLAC, M4A, Opus, WAV, MP4, MP3, AAC, OGG) from a Linux PC (`192.168.31.224`) to an Android mobile device over your local Wi-Fi (Jio AirFiber LAN).

> [!IMPORTANT]
> **Zero Cloud Dependencies:** Requires **NO** Internet connection, cloud storage, Firebase, Supabase, Spotify API, or external web services.

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Flutter Mobile Application                  │
│       (Android Target / Riverpod / just_audio Player)       │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTP REST API & Range Audio Stream
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Python FastAPI Backend                   │
│               (Listening on 0.0.0.0:8000)                    │
├─────────────────┬───────────────────┬───────────────────────┤
│ SQLite Database │  Mutagen Scanner  │ HTTP Range Streamer   │
│  (Indexed Meta) │ (Recursive Scan)  │ (206 Partial Content) │
└─────────────────┴─────────┬─────────┴───────────────────────┘
                            │ Read-Only Access
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                 External HDD Music Library                  │
│                   /media/tharun/HD/Songs                    │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚡ Quick Start

### 1. Start the Backend Server (Zorin OS Linux)

```bash
cd /media/tharun/App/Music_player
./start_backend.sh
```

Or manually:

```bash
cd /media/tharun/App/Music_player/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 run.py
```

The server will start listening at:
`http://192.168.31.224:8000`

### 2. Verify Backend Health

Open in your browser or run:
```bash
curl http://192.168.31.224:8000/api/health
```

Expected output:
```json
{
  "status": "ok",
  "library": "/media/tharun/HD/Songs"
}
```

---

## 📱 Flutter Mobile Application Setup

### Prerequisites
- Flutter SDK 3.24+ / 3.35+
- Android Studio / Android Device on the same Jio AirFiber Wi-Fi

### Build & Run
```bash
cd /media/tharun/App/Music_player/mobile_app
flutter pub get
flutter run -d <your-android-device-or-emulator>
```

### Server Settings Screen
1. Open the app on your phone.
2. Navigate to **Settings**.
3. Enter your PC's LAN IP: `http://192.168.31.224:8000`.
4. Tap **Test Connection** (measures response latency in milliseconds).

---

## 🔒 Safety & Performance Features

- **Strict Read-Only HDD Access:** The backend opens music files exclusively in read binary (`rb`) mode. Your music library files will **NEVER** be renamed, modified, moved, or deleted.
- **Path Traversal Protection:** Validates canonical realpaths against `/media/tharun/HD/Songs`. Requests attempting path traversal outside the music folder are rejected (`403 Forbidden`).
- **HTTP 206 Partial Content Streaming:** Supports seeking and instant playback of large FLAC/WAV files (90MB+) without loading entire files into system RAM.
- **Embedded Artwork Caching:** Extracts album covers via Mutagen and caches them locally inside `backend/cache/covers/` using MD5 hashes.

---

## 🌐 Finding Your Linux PC LAN IP

If your router assigns a new local IP to your PC, find it by running:
```bash
hostname -I
```

Then update the Server URL inside the **Flutter Settings** screen.

---

## 🧪 Running Automated Tests

### Backend Test Suite
```bash
cd /media/tharun/App/Music_player/backend
PYTHONPATH=. .venv/bin/pytest -v
```

### Flutter Test Suite
```bash
cd /media/tharun/App/Music_player/mobile_app
flutter test
```
