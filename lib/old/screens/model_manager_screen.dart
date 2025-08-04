// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'dart:async';
// import '../services/model_config_service.dart';
// import '../services/model_download_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../services/huggingface_token_verifier.dart';

// class ModelManagerScreen extends StatefulWidget {
//   const ModelManagerScreen({super.key});

//   @override
//   State<ModelManagerScreen> createState() => _ModelManagerScreenState();
// }

// class _ModelManagerScreenState extends State<ModelManagerScreen> {
//   static const _channel = MethodChannel('com.google.ai.edge/model_download');
  
//   List<ModelConfig> _models = [];
//   final Map<String, StreamSubscription<DownloadProgress>> _downloadSubscriptions = {};
//   final Map<String, DownloadProgress> _downloadProgress = {};
//   final Set<String> _downloadedModels = {}; // Track completed downloads
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadModels();
//   }

//   @override
//   void dispose() {
//     for (final subscription in _downloadSubscriptions.values) {
//       subscription.cancel();
//     }
//     super.dispose();
//   }

//   Future<void> _loadModels() async {
//     final models = await ModelConfigService.loadModelConfigs();
    
//     // Check which models are already downloaded
//     final Set<String> downloadedModels = {};
//     for (final model in models) {
//       final isDownloaded = await _isModelDownloaded(model);
//       if (isDownloaded) {
//         downloadedModels.add(model.modelId);
//       }
//     }
    
//     setState(() {
//       _models = models;
//       _downloadedModels
//         ..clear()
//         ..addAll(downloadedModels);
//       _isLoading = false;
//     });
//   }

//   Future<bool> _isModelDownloaded(ModelConfig model) async {
//     try {
//       final result = await _channel.invokeMethod('isModelDownloaded', {
//         'fileName': model.modelFile,
//         'modelDir': model.modelDir,
//         'version': model.version,
//         'totalBytes': model.totalBytes,
//       });
//       return result as bool;
//     } catch (e) {
//       // ignore: avoid_print
//       // print('Error checking if model is downloaded: $e');
//       return false;
//     }
//   }

//   void _downloadModel(ModelConfig model) async {
//     if (_downloadSubscriptions.containsKey(model.modelId)) {
//       return; // Already downloading
//     }

//     // Check if already downloaded before starting
//     if (_downloadedModels.contains(model.modelId)) {
//       return; // Already downloaded
//     }

//     // Double-check with file system
//     final isAlreadyDownloaded = await _isModelDownloaded(model);
//     if (isAlreadyDownloaded) {
//       setState(() {
//         _downloadedModels.add(model.modelId);
//       });
//       return;
//     }

//     // Fetch Hugging Face token from SharedPreferences
//     final prefs = await SharedPreferences.getInstance();
//     final accessToken = prefs.getString('huggingface_token') ?? '';
//     if (accessToken.isEmpty) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please enter your Hugging Face token in settings.'), backgroundColor: Colors.red),
//         );
//       }
//       return;
//     }

//     // Verify token before download
//     final valid = await HuggingFaceTokenVerifier.verifyToken(accessToken);
//     if (!valid) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Invalid Hugging Face token. Please update it in settings.'), backgroundColor: Colors.red),
//         );
//       }
//       return;
//     }

//     // Start download
//     ModelDownloadService.downloadModel(
//       modelUrl: model.downloadUrl,
//       modelName: model.modelName,
//       version: model.version,
//       fileName: model.modelFile,
//       modelDir: model.modelDir,
//       totalBytes: model.totalBytes,
//       extraDataUrls: model.extraDataUrls,
//       extraDataFileNames: model.extraDataDownloadFileNames,
//       accessToken: accessToken,
//       isZip: model.isZip,
//       unzippedDir: model.unzippedDir,
//     );

//     // Listen to progress
//     final subscription = ModelDownloadService.getDownloadProgress().listen(
//       (progress) {
//         setState(() {
//           _downloadProgress[model.modelId] = progress;
//           // Mark as downloaded when completed
//           if (progress.state == 'completed') {
//             _downloadedModels.add(model.modelId);
//           }
//         });

//         if (progress.state == 'completed' || progress.state == 'failed' || progress.state == 'cancelled') {
//           _downloadSubscriptions[model.modelId]?.cancel();
//           _downloadSubscriptions.remove(model.modelId);
//           // Keep the final progress state in _downloadProgress for UI display
//         }
//       },
//     );

//     _downloadSubscriptions[model.modelId] = subscription;
//   }

//   void _cancelDownload(String modelId) {
//     ModelDownloadService.cancelDownload();
//     _downloadSubscriptions[modelId]?.cancel();
//     _downloadSubscriptions.remove(modelId);
//     setState(() {
//       _downloadProgress.remove(modelId);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Center(
//         child: CircularProgressIndicator(),
//       );
//     }

//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Available Models',
//             style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 16),
//           Expanded(
//             child: ListView.builder(
//               itemCount: _models.length,
//               itemBuilder: (context, index) {
//                 final model = _models[index];
//                 final progress = _downloadProgress[model.modelId];
//                 final isDownloading = _downloadSubscriptions.containsKey(model.modelId);
                
//                 return Card(
//                   margin: const EdgeInsets.only(bottom: 12),
//                   child: Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     model.modelName,
//                                     style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     model.modelId,
//                                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                                       color: Colors.grey[600],
//                                     ),
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Row(
//                                     children: [
//                                       Icon(Icons.storage, size: 16, color: Colors.grey[600]),
//                                       const SizedBox(width: 4),
//                                       Text(
//                                         model.modelSize,
//                                         style: Theme.of(context).textTheme.bodySmall,
//                                       ),
//                                       const SizedBox(width: 16),
//                                       Icon(Icons.speed, size: 16, color: Colors.grey[600]),
//                                       const SizedBox(width: 4),
//                                       Text(
//                                         model.accelerators.join(', '),
//                                         style: Theme.of(context).textTheme.bodySmall,
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             _buildActionButton(model, progress, isDownloading),
//                           ],
//                         ),
//                         // Only show progress indicator if download is actively in progress
//                         if (progress != null && progress.state == 'downloading') ...[
//                           const SizedBox(height: 12),
//                           _buildProgressIndicator(progress),
//                         ],
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildActionButton(ModelConfig model, DownloadProgress? progress, bool isDownloading) {
//     // Check if model is downloaded (either from progress state or tracked set)
//     bool isDownloaded = progress?.state == 'completed' || _downloadedModels.contains(model.modelId);
    
//     if (isDownloaded) {
//       return Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//         decoration: BoxDecoration(
//           color: Colors.green[100],
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
//             const SizedBox(width: 4),
//             Text(
//               'Downloaded',
//               style: TextStyle(
//                 color: Colors.green[700],
//                 fontSize: 12,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       );
//     }

//     if (isDownloading) {
//       return ElevatedButton.icon(
//         onPressed: () => _cancelDownload(model.modelId),
//         icon: const Icon(Icons.cancel, size: 16),
//         label: const Text('Cancel'),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.red[100],
//           foregroundColor: Colors.red[700],
//           elevation: 0,
//         ),
//       );
//     }

//     return ElevatedButton.icon(
//       onPressed: () => _downloadModel(model),
//       icon: const Icon(Icons.download, size: 16),
//       label: const Text('Download'),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.blue[100],
//         foregroundColor: Colors.blue[700],
//         elevation: 0,
//       ),
//     );
//   }

//   Widget _buildProgressIndicator(DownloadProgress progress) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               progress.isUnzipping ? 'Unzipping...' : 'Downloading...',
//               style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             Text(
//               progress.progressText,
//               style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         LinearProgressIndicator(
//           value: progress.progress,
//           backgroundColor: Colors.grey[300],
//           valueColor: AlwaysStoppedAnimation<Color>(
//             progress.state == 'failed' ? Colors.red : Colors.blue,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               progress.sizeText,
//               style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                 color: Colors.grey[600],
//               ),
//             ),
//             if (progress.speedText.isNotEmpty && progress.etaText.isNotEmpty)
//               Text(
//                 '${progress.speedText} • ${progress.etaText}',
//                 style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                   color: Colors.grey[600],
//                 ),
//               ),
//           ],
//         ),
//         if (progress.errorMessage != null) ...[
//           const SizedBox(height: 4),
//           Text(
//             'Error: ${progress.errorMessage}',
//             style: Theme.of(context).textTheme.bodySmall?.copyWith(
//               color: Colors.red,
//             ),
//           ),
//         ],
//       ],
//     );
//   }
// }
