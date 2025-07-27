import 'package:flutter/services.dart';

class ModelDownloadService {
  static const _channel = MethodChannel('com.google.ai.edge/model_download');
  static const _progressChannel = EventChannel('com.google.ai.edge/download_progress');
  
  // Start download using Google's DownloadWorker
  static Future<bool> downloadModel({
    required String modelUrl,
    required String modelName,
    required String version,
    required String fileName,
    required String modelDir,
    required int totalBytes,
    List<String>? extraDataUrls,
    List<String>? extraDataFileNames,
    String? accessToken,
    bool isZip = false,
    String? unzippedDir,
  }) async {
    try {
      final result = await _channel.invokeMethod('downloadModel', {
        'modelUrl': modelUrl,
        'modelName': modelName,
        'version': version,
        'fileName': fileName,
        'modelDir': modelDir,
        'totalBytes': totalBytes,
        'extraDataUrls': extraDataUrls?.join(','),
        'extraDataFileNames': extraDataFileNames?.join(','),
        'accessToken': accessToken,
        'isZip': isZip,
        'unzippedDir': unzippedDir,
      });
      return result as bool;
    } catch (e) {
      print('Download error: $e');
      return false;
    }
  }
  
  // Cancel download
  static Future<bool> cancelDownload() async {
    try {
      final result = await _channel.invokeMethod('cancelDownload');
      return result as bool;
    } catch (e) {
      print('Cancel download error: $e');
      return false;
    }
  }
  
  // Listen to download progress
  static Stream<DownloadProgress> getDownloadProgress() {
    return _progressChannel.receiveBroadcastStream().map((event) {
      final data = Map<String, dynamic>.from(event);
      return DownloadProgress(
        receivedBytes: data['receivedBytes'] ?? 0,
        totalBytes: data['totalBytes'] ?? 0,
        downloadRate: data['downloadRate'] ?? 0,
        remainingMs: data['remainingMs'] ?? 0,
        isUnzipping: data['isUnzipping'] ?? false,
        state: data['state'] ?? 'unknown',
        errorMessage: data['errorMessage'],
      );
    });
  }
}

class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final int downloadRate;
  final int remainingMs;
  final bool isUnzipping;
  final String state; // downloading, completed, failed, cancelled
  final String? errorMessage;
  
  DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.downloadRate,
    required this.remainingMs,
    required this.isUnzipping,
    required this.state,
    this.errorMessage,
  });
  
  double get progress => totalBytes > 0 ? receivedBytes / totalBytes : 0.0;
  
  String get speedText {
    if (downloadRate <= 0) return '';
    final mbps = downloadRate / 1024 / 1024;
    return '${mbps.toStringAsFixed(1)} MB/s';
  }
  
  String get etaText {
    if (remainingMs <= 0) return '';
    final minutes = remainingMs / 1000 / 60;
    if (minutes < 1) {
      final seconds = remainingMs / 1000;
      return '${seconds.toStringAsFixed(0)} sec remaining';
    }
    return '${minutes.toStringAsFixed(1)} min remaining';
  }
  
  String get progressText => '${(progress * 100).toStringAsFixed(1)}%';
  
  String get sizeText {
    final receivedMB = receivedBytes / 1024 / 1024;
    final totalMB = totalBytes / 1024 / 1024;
    return '${receivedMB.toStringAsFixed(1)} / ${totalMB.toStringAsFixed(1)} MB';
  }
}
