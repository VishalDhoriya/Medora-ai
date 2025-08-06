import 'dart:convert';
import 'package:flutter/services.dart';

class ModelConfig {
  final String modelId;
  final String modelName;
  final String modelFile;
  final String modelSize;
  final List<String> accelerators;
  final List<String>? extraDataUrls;
  final List<String>? extraDataDownloadFileNames;
  // Remove accessToken from ModelConfig; it will be provided dynamically at download time.
  final bool isZip;
  final String? unzippedDir;
  final int totalBytes;
  final String version;

  ModelConfig({
    required this.modelId,
    required this.modelName,
    required this.modelFile,
    required this.modelSize,
    required this.accelerators,
    this.extraDataUrls,
    this.extraDataDownloadFileNames,
    // accessToken is not stored here
    this.isZip = false,
    this.unzippedDir,
    required this.totalBytes,
    required this.version,
  }) {
    print('[ModelConfig] Created: modelId=$modelId, modelName=$modelName, modelFile=$modelFile, modelSize=$modelSize, accelerators=$accelerators, totalBytes=$totalBytes, version=$version');
  }

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    print('[ModelConfig.fromJson] Raw JSON: ' + jsonEncode(json));
    // Convert size in bytes to readable format
    final sizeInBytes = json['sizeInBytes'] ?? 0;
    final modelSize = _formatBytes(sizeInBytes);
    // Parse accelerators from the defaultConfig
    final defaultConfig = json['defaultConfig'] ?? {};
    final acceleratorsStr = defaultConfig['accelerators'] ?? 'cpu';
    final accelerators = acceleratorsStr.toString().split(',').map((s) => s.trim()).toList();
    final version = json['version']?.toString() ?? 'main';
    final config = ModelConfig(
      modelId: json['modelId'] ?? '',
      modelName: json['name'] ?? '',
      modelFile: json['modelFile'] ?? '',
      modelSize: modelSize,
      accelerators: accelerators,
      extraDataUrls: null, // Not provided in this JSON structure
      extraDataDownloadFileNames: null, // Not provided in this JSON structure
      isZip: false, // These are .task files, not zip files
      unzippedDir: null, // Not applicable for .task files
      totalBytes: sizeInBytes,
      version: version,
    );
    print('[ModelConfig.fromJson] Created ModelConfig for modelId=${config.modelId}');
    return config;
  }
  
  static String _formatBytes(int bytes) {
    String result;
    if (bytes >= 1024 * 1024 * 1024) {
      result = '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      result = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      result = '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      result = '$bytes B';
    }
    print('[ModelConfig._formatBytes] $bytes bytes -> $result');
    return result;
  }
  
  String get downloadUrl {
    // Build Hugging Face download URL
    final baseUrl = 'https://huggingface.co';
    final url = '$baseUrl/$modelId/resolve/main/$modelFile';
    print('[ModelConfig.downloadUrl] $url');
    return url;
  }
  
  // Remove the old version getter; now use the field
  String get modelDir => modelId.replaceAll('/', '-').replaceAll('google-', '');
}

class ModelConfigService {
  static Future<List<ModelConfig>> loadModelConfigs() async {
    print('[ModelConfigService.loadModelConfigs] Loading model configs...');
    try {
      final String jsonString = await rootBundle.loadString('assets/model_allowlist.json');
      print('[ModelConfigService.loadModelConfigs] Loaded JSON string, length: \\${jsonString.length}');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      print('[ModelConfigService.loadModelConfigs] Decoded JSON, keys: \\${jsonData.keys}');
      final List<dynamic> modelsList = jsonData['models'] ?? [];
      print('[ModelConfigService.loadModelConfigs] Found \\${modelsList.length} models');
      final configs = modelsList.map((json) => ModelConfig.fromJson(json)).toList();
      print('[ModelConfigService.loadModelConfigs] Returning \\${configs.length} ModelConfig objects');
      return configs;
    } catch (e, stack) {
      print('[ModelConfigService.loadModelConfigs] Error loading model configs: $e');
      print(stack);
      return [];
    }
  }

  static Future<ModelConfig?> getModelConfig(String modelId) async {
    print('[ModelConfigService.getModelConfig] Looking for modelId=$modelId');
    final configs = await loadModelConfigs();
    try {
      final config = configs.firstWhere((config) => config.modelId == modelId);
      print('[ModelConfigService.getModelConfig] Found config for modelId=$modelId');
      return config;
    } catch (e) {
      print('[ModelConfigService.getModelConfig] No config found for modelId=$modelId: $e');
      return null;
    }
  }
}
