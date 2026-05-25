# AINote-iOS

A SwiftUI iOS app for studying out loud. Create a note, add questions, record your spoken answers, and get an AI-generated transcript, summary, and graded review — all backed by Firebase Cloud Functions so API keys never ship in the app.

## How it works

1. **Create a note** and add one or more questions you want to practice.
2. **Tap record** on a question. Your microphone audio is streamed over WebSocket to AssemblyAI's real-time transcription service.
3. **Stop recording.** The full transcript is sent to Google Gemini via a Cloud Function for a 3-bullet summary.
4. **Get a review.** The question + transcript are sent to Gemini to produce written feedback and a numeric score.
5. Everything (question, answer transcript, summary, review, score) is saved locally with Core Data.

## Architecture

```
┌────────────────────┐      WebSocket (audio)        ┌─────────────────┐
│                    │ ────────────────────────────▶ │  AssemblyAI     │
│   iOS App          │ ◀──────────── transcript ──── │  Streaming v3   │
│   (SwiftUI +       │                                └─────────────────┘
│    Core Data)      │
│                    │      HTTPS                     ┌─────────────────┐
│                    │ ────────────────────────────▶ │ Firebase        │
│                    │ ◀────── summary / review ──── │ Cloud Functions │
└────────────────────┘                                │  → Gemini 2.5   │
                                                      └─────────────────┘
```

### iOS app (`AINotes/`)

| Area | Files |
| --- | --- |
| App entry | `AINotesApp.swift` |
| Core Data | `Controller/PersistenceController.swift`, `Controller/NotesDataController.swift`, `Note/NotesContainer.xcdatamodel` |
| Note UI | `Note/NoteListView.swift`, `Note/NewNoteView.swift`, `Note/EditNoteView.swift`, `Note/NoteView.swift`, `Note/NoteViewModel.swift` |
| Question UI | `Question/QuestionRowView.swift`, `Question/QuestionRowViewModel.swift` |
| Audio capture | `Manager/RecordingManager.swift` — `AVAudioEngine`, converts mic input to 16 kHz mono PCM16 |
| Live transcript | `Manager/WebSocketManager.swift` — fetches a token from Firebase, opens a WebSocket to AssemblyAI |
| Summarization | `Manager/SummarizeManager.swift` — POSTs transcript to `summarizeTranscript` |
| Review / scoring | `Manager/ReviewManager.swift` — POSTs `{question, transcript}` to `reviewAnswer` |

### Data model

- **NotesEntity** — `id`, `title`, `createdDate`, `modifiedDate`, has many `QuestionsEntity`
- **QuestionsEntity** — `id`, `question`, `answer` (transcript), `summary`, `review`, `score`

### Backend (`firebase/functions/`)

Three HTTPS Cloud Functions written in TypeScript on Node.js 20:

| Endpoint | Purpose |
| --- | --- |
| `POST /getAssemblyRealtimeToken` | Returns the AssemblyAI streaming WebSocket URL and a short-lived API key so the iOS client can connect directly. |
| `POST /summarizeTranscript` | `{ transcript }` → `{ summary }` via Gemini 2.5 Flash. |
| `POST /reviewAnswer` | `{ question, transcript }` → `{ review, score }` via Gemini 2.5 Flash. |

Secrets are stored with Firebase Functions Secrets — `ASSEMBLYAI_API_KEY` and `GEMINI_API_KEY` are never exposed to the client.

## Requirements

- Xcode 16+
- iOS 17+ deployment target
- A Firebase project with the Blaze plan (required to call third-party APIs from Cloud Functions)
- AssemblyAI account + API key
- Google AI Studio (Gemini) API key
- Node.js 20 for the Functions deploy

## Getting started

### 1. Backend

```bash
cd firebase/functions
npm install

# set secrets in your Firebase project
firebase functions:secrets:set ASSEMBLYAI_API_KEY
firebase functions:secrets:set GEMINI_API_KEY

# build and deploy
npm run deploy
```

For local development, create `firebase/functions/.env`:

```
ASSEMBLYAI_API_KEY=...
GEMINI_API_KEY=...
FIREBASE_REGION=us-central1
```

Then:

```bash
npm run serve   # tsc build + firebase emulators
```

### 2. iOS app

If you are using your own Firebase project, update the function URLs in:

- `AINotes/Manager/WebSocketManager.swift` — `firebaseFunctionURL`
- `AINotes/Manager/SummarizeManager.swift` — `summarizeFunctionURL`
- `AINotes/Manager/ReviewManager.swift` — `reviewFunctionURL`

Then open `AINotes.xcodeproj` in Xcode and run on a device or simulator. The app requests microphone permission on first record — add `NSMicrophoneUsageDescription` to `Info.plist` if it isn't already set.

## Project layout

```
AINote-iOS/
├── AINotes/                      # SwiftUI app source
│   ├── AINotesApp.swift
│   ├── Controller/               # Core Data stack
│   ├── Extension/                # Date helpers
│   ├── Manager/                  # Recording, WebSocket, Summarize, Review
│   ├── Note/                     # Note list, create, edit, view
│   └── Question/                 # Question row UI + view model
├── AINotes.xcodeproj
├── firebase/
│   ├── README.md                 # Backend-specific notes
│   └── functions/                # TypeScript Cloud Functions
└── firebase.json
```

## Notes

- Audio is sent as 16 kHz mono PCM16 over WebSocket — the format AssemblyAI's v3 streaming API expects.
- Transcripts are accumulated client-side: partial turns roll up into `fullTranscript` either on the server's `end_of_turn` signal or after a 1.2 s client-side silence timeout.
- The summarize and review functions both time out at 25 s on the client (30 s on the server).
