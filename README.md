<div align="center">

# NooNooBook

**An AI-powered study companion for students**

PDF Annotation + Live Interpretation + AI Summarization

Built with Flutter + Python

</div>

---

## Features

### PDF Bookshelf & Annotation
- Organize PDFs in folders with a visual bookshelf UI
- Draw and highlight directly on PDF pages with pressure-sensitive pen and highlighter tools
- Annotations persist across sessions and scale correctly with zoom
- Drag & drop PDFs into folders, rename, and favorite
- In-reader translation and AI summarization via side panel

### Live Interpreter (Simultaneous Translation)
- Real-time speech-to-text powered by **faster-whisper** (local GPU inference)
- Instant translation via Google Translate
- Typewriter-style live subtitles with sentence-level segmentation
- Session history with sidebar navigation
- Structured AI summaries (topic, key points, action items) powered by DeepSeek

### Settings
- Light / Dark / Eye Care theme modes
- Persistent preferences

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Windows desktop) |
| State Management | Provider + ChangeNotifier |
| PDF Rendering | pdfrx |
| Drawing | perfect_freehand |
| Backend | Python FastAPI |
| Speech-to-Text | faster-whisper (CUDA GPU) |
| Translation | Google Translate (real-time) + DeepSeek (AI summary) |
| Storage | JSON files + SharedPreferences |

---

## Getting Started

### Prerequisites
- Flutter SDK
- Python 3.10+
- NVIDIA GPU with CUDA (for faster-whisper; CPU fallback available)

### 1. Start the Backend

```bash
cd backend
pip install -r requirements.txt
python ai_server.py
```

The backend loads the Whisper model on first run (~500MB download). You should see:
```
✅ Whisper 模型加载完成 (GPU)
🚀 Starting SimulNote DeepSeek Backend on http://localhost:8000
```

### 2. Run the Flutter App

```bash
flutter pub get
flutter run -d windows
```

### Configuration

- **Proxy**: If you're in China, the backend uses `localhost:7890` (Clash) for DeepSeek API access. Edit `backend/ai_server.py` lines 23-24 if your proxy port differs.
- **DeepSeek API Key**: Set via `DEEPSEEK_API_KEY` environment variable or edit the default in `backend/ai_server.py`.

---

## Project Structure

```
noooobook/
├── lib/
│   ├── main.dart                 # App entry + provider setup
│   ├── models/                   # Data models (Stroke, Session, PdfDocument)
│   ├── painters/                 # CustomPainter for stroke rendering
│   ├── providers/                # State management (Note, Bookshelf, Theme, etc.)
│   ├── screens/                  # UI screens
│   │   ├── dashboard_screen.dart
│   │   ├── bookshelf_screen.dart
│   │   ├── pdf_annotation_screen.dart
│   │   ├── interpretation_screen.dart
│   │   ├── settings_screen.dart
│   │   └── ...
│   └── services/                 # Audio recording, session storage, HTTP
├── backend/
│   ├── ai_server.py              # FastAPI backend (STT + translate + summarize)
│   └── requirements.txt
└── pubspec.yaml
```

---

## License

MIT
