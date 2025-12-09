# Firebase Cloud Functions Backend

Minimal secure backend that only exposes:

1. `POST /getAssemblyRealtimeToken` – returns an AssemblyAI realtime token so the
   iOS app can open a WebSocket directly with AssemblyAI (no key in the app).
2. `POST /summarizeTranscript` – sends existing transcript text to Gemini for a
   short summary.

## Setup

```bash
cd /Users/simon-sung/Desktop/Workspace/AINote-iOS/firebase/functions
npm install
```

### Configure secrets (recommended)

Use Firebase CLI:

```bash
firebase functions:secrets:set ASSEMBLYAI_API_KEY
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

Or for local emulator, create `.env` in `firebase/functions/` with:

```
ASSEMBLYAI_API_KEY=xxx
GEMINI_API_KEY=yyy
FIREBASE_REGION=us-central1
```

## Local testing

```bash
cd /Users/simon-sung/Desktop/Workspace/AINote-iOS/firebase/functions
npm run build
firebase emulators:start --only functions
```

## How the iOS app uses it

1. Call `POST https://<cloud-function-url>/getAssemblyRealtimeToken` → receive
   `{ token, websocket_url, expires_at }`. Connect your microphone stream
   directly to that `websocket_url`.
2. When you have a transcript (live or saved), call
   `POST https://<cloud-function-url>/summarizeTranscript` with
   `{ "transcript": "..." }` to get `{ "summary": "..." }`.

Both functions run entirely on Firebase, so the API keys never leave your
backend.

