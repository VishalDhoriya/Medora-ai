# AI Edge Gallery - Flutter Implementation

This is a Flutter implementation of Google's AI Edge Gallery that demonstrates how to integrate Google's Android download and inference code using Platform Channels.

## Project Structure

```
flutter_gallery/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   └── chat_message.dart     # Chat message data model
│   ├── screens/
│   │   ├── home_screen.dart      # Main navigation screen
│   │   ├── model_manager_screen.dart  # Model download/management UI
│   │   └── chat_screen.dart      # Chat interface with LLM
│   └── services/
│       ├── model_download_service.dart  # Download service wrapper
│       ├── llm_service.dart             # LLM inference service wrapper
│       └── model_config_service.dart    # Model configuration loader
├── android/
│   └── app/src/main/kotlin/
│       ├── com/example/flutter_gallery/
│       │   ├── MainActivity.kt           # Platform channel setup
│       │   ├── ModelDownloadHandler.kt  # Download platform channel handler
│       │   └── LlmInferenceHandler.kt   # Inference platform channel handler
│       └── com/google/ai/edge/gallery/  # Google's original Android code
│           ├── worker/
│           │   └── DownloadWorker.kt    # Google's exact download worker
│           ├── data/
│           │   └── DownloadConstants.kt # Download constants
│           └── common/
│               └── LaunchInfo.kt        # Launch info utilities
└── assets/
    └── model_allowlist.json     # Model configurations
```

## Features Implemented

### 1. **Model Download Management**
- **Google's exact DownloadWorker**: Copy-pasted from original Android project
- **Resume capability**: Interrupted downloads continue from where they left off
- **Progress tracking**: Real-time download speed, ETA, and progress
- **Multi-file support**: Downloads model + tokenizer + config files
- **Background processing**: Uses Android WorkManager for reliable downloads
- **Authentication**: Supports Hugging Face access tokens for gated models

### 2. **LLM Chat Interface**
- **Streaming responses**: Real-time token generation display
- **Model selection**: Choose from available models
- **GPU acceleration**: Ready for MediaPipe integration
- **Performance metrics**: Shows tokens per second
- **Chat history**: Maintains conversation context

### 3. **Platform Channel Integration**
- **Seamless communication**: Flutter UI calls native Android functions
- **Event streaming**: Real-time progress and inference updates
- **Error handling**: Proper error propagation from native to Flutter

## How It Works

### Download Process
1. Flutter UI calls `ModelDownloadService.downloadModel()`
2. Platform channel passes parameters to `ModelDownloadHandler`
3. Handler creates WorkRequest using Google's exact `DownloadWorker`
4. Download progress streams back to Flutter via EventChannel
5. UI updates with real-time progress, speed, and ETA

### Inference Process
1. Flutter UI calls `LlmService.initializeModel()`
2. Platform channel initializes model with GPU acceleration
3. Chat messages sent via `LlmService.generateResponse()`
4. Streaming tokens flow back through EventChannel
5. UI displays real-time response generation

## Integration with Google's Code

### What's Copy-Pasted (No Changes)
- ✅ **`DownloadWorker.kt`** - Google's exact download logic
- ✅ **Download constants** - All the KEY_* definitions
- ✅ **Progress tracking** - Speed calculation, ETA, resume logic
- ✅ **Multi-file downloads** - Model + tokenizer + config handling
- ✅ **Authentication** - Hugging Face token support

### What's Added (Platform Channels)
- 🆕 **`ModelDownloadHandler.kt`** - Bridges Flutter to Google's DownloadWorker
- 🆕 **`LlmInferenceHandler.kt`** - Bridges Flutter to Google's inference code
- 🆕 **Flutter services** - Dart wrappers for platform channels
- 🆕 **Flutter UI** - Modern chat interface and model management

## Running the Project

1. **Install Dependencies**
   ```bash
   cd flutter_gallery
   flutter pub get
   ```

2. **Run on Android** (after enabling Developer Mode)
   ```bash
   flutter run
   ```

3. **Build APK**
   ```bash
   flutter build apk --debug
   ```

This implementation demonstrates how to wrap existing native Android code with Platform Channels while maintaining performance benefits and providing a modern Flutter UI experience.

## Key Benefits

- ✅ **Same performance** as Google's Android app (uses exact same native code)
- ✅ **Cross-platform UI** (Flutter works on Android + iOS)
- ✅ **Modern interface** with real-time updates and streaming
- ✅ **Easy to extend** with additional features and models
- ✅ **Production-ready** architecture with proper error handling
