import 'package:flutter/services.dart';
import 'model_config_service.dart';

class LlmService {
  static bool _isModelInitialized = false;
  static const _channel = MethodChannel('com.google.ai.edge/llm');
  static const _inferenceChannel = EventChannel('com.google.ai.edge/inference_stream');
  
  // Initialize model with all relevant parameters (including accelerator, topK, topP)
  static Future<bool> initializeModel({
    required ModelConfig config,
    required String modelPath,
    int? maxTokens,
    double? temperature,
    int? topK,
    double? topP,
    String? accelerator,
  }) async {
    if (_isModelInitialized) {
      print('Model already initialized, skipping.');
      return true;
    }
    try {
      final result = await _channel.invokeMethod('initializeModel', {
        'modelId': config.modelId,
        'modelPath': modelPath,
        'maxTokens': maxTokens ?? 8192,  // Increased from 1024
        'temperature': temperature ?? 1.0,
        'topK': topK ?? 40,
        'topP': topP ?? 0.9,
        'accelerator': accelerator ?? (config.accelerators.isNotEmpty ? config.accelerators.first.toLowerCase() : 'gpu'),
      }) as bool;
      if (result) {
        _isModelInitialized = true;
      }
      return result;
    } catch (e) {
      print('Model initialization error: $e');
      return false;
    }
  }
  
  // Check if model is downloaded
  static Future<bool> isModelDownloaded(String modelId) async {
    try {
      // Get model config to get file details
      final config = await ModelConfigService.getModelConfig(modelId);
      if (config == null) return false;

      // Use the correct version and modelDir from config or JSON
      final version = (config as dynamic).version ?? 'main';
      final modelDir = config.modelDir;
      final fileName = config.modelFile;
      final totalBytes = config.totalBytes;

      print('[LlmService.isModelDownloaded] Checking: modelDir=$modelDir, version=$version, fileName=$fileName, totalBytes=$totalBytes');

      const downloadChannel = MethodChannel('com.google.ai.edge/model_download');
      return await downloadChannel.invokeMethod('isModelDownloaded', {
        'fileName': fileName,
        'modelDir': modelDir,
        'version': version,
        'totalBytes': totalBytes,
      }) as bool;
    } catch (e) {
      print('Check model error: $e');
      return false;
    }
  }
  
  // Generate response with streaming
  static Future<void> generateResponse(String prompt) async {
    try {
      await _channel.invokeMethod('generateResponse', {
        'prompt': prompt,
      });
    } catch (e) {
      print('Generate response error: $e');
    }
  }
  
  // Listen to streaming inference results
  static Stream<InferenceResult> getInferenceStream() {
    return _inferenceChannel.receiveBroadcastStream().map((event) {
      final data = Map<String, dynamic>.from(event);
      return InferenceResult(
        partialResult: data['partialResult'] ?? '',
        isDone: data['isDone'] ?? false,
        tokensPerSecond: data['tokensPerSecond']?.toDouble() ?? 0.0,
        totalTokens: data['totalTokens'] ?? 0,
      );
    });
  }
  
  // Cleanup model
  static Future<void> disposeModel() async {
    try {
      await _channel.invokeMethod('disposeModel');
    } catch (e) {
      print('Dispose model error: $e');
    }
  }
}

class InferenceResult {
  final String partialResult;
  final bool isDone;
  final double tokensPerSecond;
  final int totalTokens;
  
  InferenceResult({
    required this.partialResult,
    required this.isDone,
    required this.tokensPerSecond,
    required this.totalTokens,
  });
  
  String get speedText => '${tokensPerSecond.toStringAsFixed(1)} tokens/s';
}
