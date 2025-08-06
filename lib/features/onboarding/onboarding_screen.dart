import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/model_config_service.dart';
import '../../core/services/model_download_service.dart';
import '../../core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  
  List<ModelConfig> _modelConfigs = [];
  List<String> _modelNames = [];
  String? _selectedModel;
  bool _loadingModels = true;
  bool _isDownloading = false;
  DownloadProgress? _downloadProgress;
  StreamSubscription<DownloadProgress>? _downloadSub;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _loadModels() async {
    try {
      final configs = await ModelConfigService.loadModelConfigs();
      setState(() {
        _modelConfigs = configs;
        _modelNames = configs.map((c) => c.modelName).toList();
        _loadingModels = false;
        if (_modelNames.isNotEmpty) {
          _selectedModel = _modelNames.first;
        }
      });
    } catch (e) {
      setState(() {
        _loadingModels = false;
      });
    }
  }

  Future<bool> _isModelDownloaded(String modelName) async {
    final configList = _modelConfigs.where((c) => c.modelName == modelName).toList();
    if (configList.isEmpty) return false;
    final modelConfig = configList.first;
    try {
      const _channel = MethodChannel('com.google.ai.edge/model_download');
      final result = await _channel.invokeMethod('isModelDownloaded', {
        'fileName': modelConfig.modelFile,
        'modelDir': modelConfig.modelDir,
        'version': modelConfig.version,
        'totalBytes': modelConfig.totalBytes,
      });
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDownloading && _downloadProgress != null) {
      // Show download progress UI
      final progress = _downloadProgress;
      final percent = progress?.progress ?? 0.0;
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Downloading Model',
            style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF1976D2)),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.download,
                  color: Color(0xFF1976D2),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _selectedModel ?? 'AI Model',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 16),
                    if (progress != null)
                      Text(
                        progress.sizeText +
                            (progress.speedText.isNotEmpty ? ' • ${progress.speedText}' : '') +
                            (progress.etaText.isNotEmpty ? ' • ${progress.etaText}' : ''),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Feel free to switch apps or lock your device.\nThe download will continue in the background.\n',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Onboarding UI
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         MediaQuery.of(context).padding.bottom - 32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    color: Color(0xFF1976D2),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to Medora AI',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Set up your AI-powered medical assistant',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      labelStyle: TextStyle(color: Color(0xFF1976D2)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _loadingModels
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Loading models...',
                                style: TextStyle(color: Color(0xFF1976D2)),
                              ),
                            ],
                          ),
                        )
                      : _modelConfigs.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.psychology,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _modelConfigs.first.modelName,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A1A1A),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Medical AI Assistant',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange[200]!),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.download_outlined,
                                          color: Colors.orange[700],
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Will be downloaded when you continue',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'No models available',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Click Continue to start downloading the AI model. This will happen in the background and you can use other apps.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[500],
                    ),
                    onPressed: () async {
                      final name = _nameController.text.trim();
                      if (name.isEmpty || _modelConfigs.isEmpty) return;
                      
                      // Use the first (and only) model
                      final config = _modelConfigs.first;
                      final modelName = config.modelName;
                      
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('onboard_name', name);
                      await prefs.setString('onboard_model', modelName);
                      // No longer saving HF token to preferences - using embedded token
                      
                      final downloaded = await _isModelDownloaded(modelName);
                      if (!downloaded) {
                        setState(() {
                          _isDownloading = true;
                        });
                        _downloadSub = ModelDownloadService.getDownloadProgress().listen((progress) {
                          setState(() {
                            _downloadProgress = progress;
                          });
                          if (progress.state == 'completed') {
                            _downloadSub?.cancel();
                            _downloadSub = null;
                            setState(() {
                              _isDownloading = false;
                            });
                            if (mounted) {
                              Navigator.of(context).pushReplacementNamed('/welcome');
                            }
                          } else if (progress.state == 'failed' || progress.state == 'cancelled') {
                            _downloadSub?.cancel();
                            _downloadSub = null;
                            setState(() {
                              _isDownloading = false;
                            });
                          }
                        });
                        await ModelDownloadService.downloadModel(
                          modelUrl: config.downloadUrl,
                          modelName: config.modelName,
                          version: config.version,
                          fileName: config.modelFile,
                          modelDir: config.modelDir,
                          totalBytes: config.totalBytes,
                          accessToken: AppConstants.huggingFaceToken, // Use embedded token
                        );
                      } else {
                        if (!mounted) return;
                        Navigator.of(context).pushReplacementNamed('/welcome');
                      }
                    },
                    child: const Text(
                      'Continue & Download Model',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
