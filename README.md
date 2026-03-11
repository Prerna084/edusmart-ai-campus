# EduSmart AI Campus (Flutter)

A high-performance, AI-powered smart campus assistant built with Flutter and Clean Architecture.

## Features
- **AI Assessment**: Dynamic quiz generation using Gemini 1.5 Flash.
- **Modern UI**: Glassmorphic design system with custom backdrop blurring.
- **Clean Architecture**: Domain-driven design with distinct layer separation (Core, Domain, Data, Presentation).

## Getting Started

### Prerequisites
- Flutter SDK (>=3.10.7)
- Gemini API Key

### Running the App
Provide your Gemini API key as a dart-define:
```bash
flutter run --dart-define=GEMINI_API_KEY=your_api_key_here
```

## Architecture
- **lib/src/core**: Shared themes, styles, and networking.
- **lib/src/domain**: Feature entities and business use cases.
- **lib/src/data**: Repositories, models, and external datasources (Gemini).
- **lib/src/presentation**: UI screens, widgets, and state controllers (Riverpod).
