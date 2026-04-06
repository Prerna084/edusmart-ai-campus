# EduSmart AI Campus

A high-performance, AI-powered smart campus assistant built with **Flutter** (frontend) and **FastAPI** (backend), following Clean Architecture principles.

---

## Features

- 🤖 **AI Assessment** — Dynamic quiz generation using Gemini 1.5 Flash
- 📸 **Face Recognition Attendance** — Register faces and auto-mark attendance via CCTV/camera
- 📚 **Syllabus Module** — Structured subject/module/topic content served from PostgreSQL
- 💬 **AI Tutor Chatbot** — Keyword-driven tutor assistant (pluggable with OpenAI/Gemini)
- 🎨 **Modern UI** — Glassmorphic design with custom backdrop blurring
- 🏛️ **Clean Architecture** — Domain-driven design with Core, Domain, Data, and Presentation layers

---

## Project Structure

```
edusmart-ai-campus/
├── lib/                    # Flutter app (Clean Architecture)
│   └── src/
│       ├── core/           # Themes, styles, networking
│       ├── domain/         # Entities and use cases
│       ├── data/           # Repositories, models, datasources
│       └── presentation/   # Screens, widgets, Riverpod controllers
├── backend/                # FastAPI backend
│   ├── app/
│   │   ├── main.py         # All API route definitions
│   │   ├── models.py       # SQLAlchemy database models
│   │   ├── schemas.py      # Pydantic schemas
│   │   ├── database.py     # DB connection and session
│   │   ├── face_engine.py  # Face encoding & matching logic
│   │   ├── camera.py       # Camera capture utilities
│   │   └── syllabus_seed.py# Database seeding script
│   ├── requirements.txt
│   └── venv/
├── .env                    # Local environment variables (gitignored)
└── .env.example            # Environment variable template
```

---

## Prerequisites

- **Flutter SDK** >= 3.10.7
- **Python** >= 3.9
- **PostgreSQL** (running locally or via a cloud provider)
- **Gemini API Key** ([get one here](https://aistudio.google.com/))

---

## Environment Setup

Copy the example env file and fill in your values:

```bash
cp .env.example .env
```

`.env` values:

```env
GEMINI_API_KEY=your_gemini_api_key_here
API_BASE_URL=http://10.0.2.2:8000        # Use 10.0.2.2 for Android emulator, localhost for web/desktop
ADMIN_EMAIL=admin@edusmart.edu
ADMIN_PASSWORD=admin123
```

---

## Backend Setup (FastAPI)

### 1. Navigate to the backend directory

```bash
cd backend
```

### 2. Create and activate a virtual environment

```powershell
# Create venv
python -m venv venv

# Activate — Windows PowerShell ✅
.\venv\Scripts\activate

# Activate — macOS / Linux (bash/zsh) ✅
# source venv/bin/activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Run the backend server

```bash
# Development mode (with auto-reload)
.\venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at:
- **Base URL**: `http://localhost:8000`
- **Swagger UI (Interactive Docs)**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

### 5. Seed the syllabus database (optional)

```bash
.\venv\Scripts\python.exe app/syllabus_seed.py
```

---

## Flutter App Setup

### 1. Install Flutter dependencies

```bash
flutter pub get
```

### 2. Run the app (with Gemini API Key)

```bash
flutter run --dart-define=GEMINI_API_KEY=your_api_key_here
```

### 3. Run on a specific device

```bash
# List available devices
flutter devices

# Run on a specific device
flutter run -d <device_id> --dart-define=GEMINI_API_KEY=your_api_key_here
```

### 4. Build for release (Android APK)

```bash
flutter build apk --dart-define=GEMINI_API_KEY=your_api_key_here
```

---

## API Endpoints Reference

### Face Registration & Attendance

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/register/` | Register a new user with a face image |
| `POST` | `/attendance/mark` | Mark attendance by uploading a face image |
| `POST` | `/recognize` | Recognize a face without marking attendance |
| `GET` | `/attendance/today` | Get all attendance records for today |
| `GET` | `/attendance/{student_id}` | Get full attendance history for a student |

### Syllabus

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/syllabus` | Get all subjects with modules and topics |
| `GET` | `/syllabus/topic/{topic_id}` | Get full rich content for a specific topic |

### AI Tutor

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/tutor/ask` | Send a message to the AI tutor chatbot |

### Students & Profiles

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/students` | Get all registered students with attendance count |
| `GET` | `/students/{id}/profile` | Get extended profile (email, phone, dept, year) from DB |
| `PUT` | `/students/{id}/profile` | Create or update extended profile in DB |
| `DELETE` | `/students/{id}` | Delete a student and all their records |


---

## Architecture

| Layer | Location | Responsibility |
|-------|----------|----------------|
| **Core** | `lib/src/core/` | Shared themes, styles, and networking utilities |
| **Domain** | `lib/src/domain/` | Feature entities and business use cases |
| **Data** | `lib/src/data/` | Repositories, models, and external datasources (Gemini) |
| **Presentation** | `lib/src/presentation/` | UI screens, widgets, and Riverpod state controllers |
