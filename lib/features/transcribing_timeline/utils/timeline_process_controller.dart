import 'dart:async';
import '../../base_transcriber/base_transcriber.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/llm_service.dart';
import 'timeline_utils.dart';

class TimelineProcessController {
  final BaseTranscriber transcriber;
  final String systemPrompt;
  final Map<String, dynamic>? patient;
  
  // State variables
  String? _transcript;
  String? _llmResponse;
  Map<String, dynamic>? _parsedLlmJson;
  bool _transcribeDone = false;
  bool _llmDone = false;
  Duration? _transcribeDuration;
  Duration? _llmDuration;
  DateTime? _stepStart;
  Duration _liveTranscribe = Duration.zero;
  Duration _liveLlm = Duration.zero;
  Timer? _timer;
  
  // Callbacks
  Function(String? transcript, bool transcribeDone, Duration? transcribeDuration, Duration liveTranscribe)? onTranscribeUpdate;
  Function(String? llmResponse, Map<String, dynamic>? parsedJson, bool llmDone, Duration? llmDuration, Duration liveLlm)? onLlmUpdate;
  Function()? onProcessComplete;

  TimelineProcessController({
    required this.transcriber,
    required this.systemPrompt,
    this.patient,
  });

  // Getters
  String? get transcript => _transcript;
  String? get llmResponse => _llmResponse;
  Map<String, dynamic>? get parsedLlmJson => _parsedLlmJson;
  bool get transcribeDone => _transcribeDone;
  bool get llmDone => _llmDone;
  Duration? get transcribeDuration => _transcribeDuration;
  Duration? get llmDuration => _llmDuration;
  Duration get liveTranscribe => _liveTranscribe;
  Duration get liveLlm => _liveLlm;

  void dispose() {
    _timer?.cancel();
  }

  void _startLiveTimer() {
    if (_llmDone) {
      print('⏹️ Not starting timer: LLM already done');
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Cancel timer if LLM is done (regardless of transcribe state)
      if (_llmDone) {
        print('⏹️ Timer cancelled: LLM done');
        _timer?.cancel();
        return;
      }
      
      if (!_transcribeDone) {
        _liveTranscribe = DateTime.now().difference(_stepStart!);
        onTranscribeUpdate?.call(_transcript, _transcribeDone, _transcribeDuration, _liveTranscribe);
      } else if (!_llmDone) {
        _liveLlm = DateTime.now().difference(_stepStart!);
        onLlmUpdate?.call(_llmResponse, _parsedLlmJson, _llmDone, _llmDuration, _liveLlm);
      }
    });
  }

  Future<void> startProcess() async {
    // Step 1: Transcribe
    _stepStart = DateTime.now();
    _liveTranscribe = Duration.zero;
    _startLiveTimer();
    print('🟡 Awaiting transcriber.stop()...');
    final transcript = await transcriber.stop();
    print('🟢 transcriber.stop() completed, transcript: $transcript');
    
    // Save transcription to database
    if (patient != null && patient!['currentConversationId'] != null && transcript.isNotEmpty) {
      await DatabaseService.insertTranscription(TranscriptionData(
        conversationId: patient!['currentConversationId'],
        transcript: transcript,
      ));
      print('💾 Transcription saved to database');
    }
    
    _transcript = transcript;
    _transcribeDone = true;
    _transcribeDuration = DateTime.now().difference(_stepStart!);
    _stepStart = DateTime.now();
    _liveLlm = Duration.zero;
    
    onTranscribeUpdate?.call(_transcript, _transcribeDone, _transcribeDuration, _liveTranscribe);
    
    // Step 2: LLM (async - handled by stream listener)
    final prompt = "$systemPrompt\n$transcript";
    String llmResponse = '';
    final stream = LlmService.getInferenceStream();
    print('🔄 Setting up LLM stream listener...');
    
    StreamSubscription? sub;
    sub = stream.listen((result) async {
      print('📨 Stream event received: isDone=${result.isDone}, partialResult length=${result.partialResult.length}');
      if (result.isDone) {
        final llmDuration = DateTime.now().difference(_stepStart!);
        print('✅ LLM is done! Duration: ${llmDuration.inSeconds}s, partial: ${result.partialResult.length} chars');
        
        // Cancel timer first
        _timer?.cancel();
        print('⏹️ Timer cancelled due to LLM completion');
        
        // Update response
        llmResponse += result.partialResult;
        
        // Debug: Print the raw LLM response
        print('🔍 Raw LLM Response (${llmResponse.length} chars):');
        print('---START---');
        print(llmResponse);
        print('---END---');
        
        // Parse JSON
        Map<String, dynamic>? parsedJson;
        try {
          parsedJson = TimelineUtils.parseJson(llmResponse);
          print('✅ JSON parsed successfully: ${parsedJson != null}');
          if (parsedJson != null) {
            print('📄 Parsed JSON: $parsedJson');
          }
        } catch (e) {
          print('❌ JSON parsing failed: $e');
          parsedJson = null;
        }
        
        // Update state
        _llmDone = true;
        _llmResponse = llmResponse;
        _llmDuration = llmDuration;
        _liveLlm = llmDuration; // Freeze the live timer
        _parsedLlmJson = parsedJson;
        
        onLlmUpdate?.call(_llmResponse, _parsedLlmJson, _llmDone, _llmDuration, _liveLlm);
        
        print('🔄 State updated. _llmDone=$_llmDone, _llmResponse length=${_llmResponse?.length}, _parsedLlmJson=$_parsedLlmJson');
        
        // Save LLM output to database
        if (patient != null && patient!['currentConversationId'] != null && llmResponse.isNotEmpty) {
          await DatabaseService.insertLlmOutput(LlmOutputData(
            conversationId: patient!['currentConversationId'],
            rawOutput: llmResponse,
            parsedJson: parsedJson,
            extractionSuccess: parsedJson != null,
            duration: llmDuration.inSeconds,
          ));
          print('💾 LLM output saved to database');
          
          // Update conversation with total duration
          final totalDuration = _transcribeDuration?.inSeconds ?? 0 + llmDuration.inSeconds;
          await DatabaseService.updateConversation(
            ConversationData(
              id: patient!['currentConversationId'],
              patientId: patient!['id'],
              duration: totalDuration,
            ),
          );
          print('💾 Conversation updated with total duration: ${totalDuration}s');
        }
        
        onProcessComplete?.call();
        
        // Cancel subscription after processing
        sub?.cancel();
      } else {
        print('📨 Partial result: ${result.partialResult}');
        llmResponse += result.partialResult;
        onLlmUpdate?.call(llmResponse, _parsedLlmJson, _llmDone, _llmDuration, _liveLlm);
      }
    }, onError: (error) {
      print('❌ Stream error: $error');
    }, onDone: () {
      print('🏁 Stream closed');
    });
    
    print('🚀 Starting LLM generation...');
    // Start the generation but don't wait for it to complete
    // The completion will be handled by the stream listener
    LlmService.generateResponse(prompt);
    print('✅ LLM generation method called (not waiting for completion)');
  }

  Duration? getCumulativeDuration() {
    if (_transcribeDuration != null && _llmDuration != null) {
      return Duration(
        milliseconds: _transcribeDuration!.inMilliseconds + _llmDuration!.inMilliseconds
      );
    }
    return null;
  }

  void updateParsedLlmJson(Map<String, dynamic> updatedData) {
    _parsedLlmJson = updatedData;
  }
}
