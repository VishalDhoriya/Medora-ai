import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/model_config_service.dart';
import '../services/model_download_service.dart';
import '../services/huggingface_token_verifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _hfTokenController = TextEditingController();
  
  List<ModelConfig> _modelConfigs = [];
  List<String> _modelNames = [];
  String? _selectedModel;
  bool _loadingModels = true;
  bool _tokenValid = false;
  bool _verifyingToken = false;
  String? _tokenError;
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
    _hfTokenController.dispose();
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

  void _verifyToken(String token) async {
    if (token.isEmpty) return;
    setState(() {
      _verifyingToken = true;
      _tokenError = null;
    });

    try {
      final isValid = await HuggingFaceTokenVerifier.verifyToken(token);
      setState(() {
        _tokenValid = isValid;
        _verifyingToken = false;
        if (!isValid) {
          _tokenError = 'Invalid token';
        }
      });
    } catch (e) {
      setState(() {
        _tokenValid = false;
        _verifyingToken = false;
        _tokenError = 'Error verifying token';
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
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
                  'Welcome to MedAssist',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set up your AI-powered medical assistant',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
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
                    border: Border.all(
                      color: _tokenError != null ? Colors.red : Colors.grey[300]!,
                      width: _tokenError != null ? 2 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: _hfTokenController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Hugging Face Token',
                      labelStyle: TextStyle(
                        color: _tokenError != null ? Colors.red : const Color(0xFF1976D2),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      suffixIcon: _tokenValid
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    ),
                    obscureText: true,
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        _verifyToken(value.trim());
                      } else {
                        setState(() {
                          _tokenValid = false;
                          _tokenError = null;
                        });
                      }
                    },
                  ),
                ),
                if (_tokenError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _tokenError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                if (_verifyingToken)
                  const Padding(
                    padding: EdgeInsets.only(top: 12.0),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                      minHeight: 3,
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
                      : DropdownButtonFormField<String>(
                          value: _selectedModel,
                          items: _modelNames
                              .map((name) => DropdownMenuItem(
                                    value: name,
                                    child: Text(name),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() => _selectedModel = value),
                          decoration: const InputDecoration(
                            labelText: 'Select Model',
                            labelStyle: TextStyle(color: Color(0xFF1976D2)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                          ),
                          dropdownColor: Colors.white,
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1976D2)),
                        ),
                ),
                const SizedBox(height: 40),
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
                    onPressed: (!_tokenValid || _verifyingToken)
                        ? null
                        : () async {
                            final name = _nameController.text.trim();
                            final modelName = _selectedModel;
                            final hfToken = _hfTokenController.text.trim();
                            if (name.isEmpty || modelName == null || hfToken.isEmpty) return;
                            final configList = _modelConfigs.where((c) => c.modelName == modelName).toList();
                            if (configList.isEmpty) return;
                            final config = configList.first;
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('onboard_name', name);
                            await prefs.setString('onboard_model', modelName);
                            await prefs.setString('onboard_hf_token', hfToken);
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
                                accessToken: hfToken,
                              );
                            } else {
                              if (!mounted) return;
                              Navigator.of(context).pushReplacementNamed('/welcome');
                            }
                          },
                    child: const Text(
                      'Continue',
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
