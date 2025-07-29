import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/model_config_service.dart';
import 'dart:async';
import '../services/model_download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/huggingface_token_verifier.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

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
  DownloadProgress? _downloadProgress;
  bool _isDownloading = false;
  StreamSubscription<DownloadProgress>? _downloadSub;
  bool _verifyingToken = false;
  bool _tokenValid = false;
  String? _tokenError;

  @override
  void initState() {
    super.initState();
    _loadPrefsAndModels();
  }

  Future<void> _loadPrefsAndModels() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('onboard_name');
    final savedModel = prefs.getString('onboard_model');
    final savedToken = prefs.getString('onboard_hf_token');
    await _loadModelNames();
    if (savedName != null) _nameController.text = savedName;
    if (savedModel != null && _modelNames.contains(savedModel)) {
      setState(() { _selectedModel = savedModel; });
    }
    if (savedToken != null) _hfTokenController.text = savedToken;
    // If token present, verify it
    if (savedToken != null && savedToken.isNotEmpty) {
      _verifyToken(savedToken);
    }
    // If all present, skip onboarding (replace with navigation to main app)
    if (savedName != null && savedModel != null && savedToken != null) {
      // TODO: Navigate to main app
    }
  }

  Future<void> _verifyToken(String token) async {
    setState(() {
      _verifyingToken = true;
      _tokenError = null;
      _tokenValid = false;
    });
    try {
      final valid = await HuggingFaceTokenVerifier.verifyToken(token);
      setState(() {
        _tokenValid = valid;
        _verifyingToken = false;
        _tokenError = valid ? null : 'Invalid Hugging Face token.';
      });
    } catch (e) {
      setState(() {
        _tokenValid = false;
        _verifyingToken = false;
        _tokenError = 'Error verifying token.';
      });
    }
  }

  Future<void> _loadModelNames() async {
    try {
      final configs = await ModelConfigService.loadModelConfigs();
      final names = configs.map((c) => c.modelName).toList();
      setState(() {
        _modelConfigs = configs;
        _modelNames = names;
        _selectedModel = names.isNotEmpty ? names.first : null;
        _loadingModels = false;
      });
    } catch (e) {
      setState(() {
        _modelConfigs = [];
        _modelNames = [];
        _selectedModel = null;
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
    final colorScheme = Theme.of(context).colorScheme;
    if (_isDownloading && _downloadProgress != null) {
      // Show download progress UI
      final progress = _downloadProgress;
      final percent = progress?.progress ?? 0.0;
      return Scaffold(
        appBar: AppBar(title: const Text('Downloading Model'), centerTitle: true),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_selectedModel ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 32),
              LinearProgressIndicator(value: percent, minHeight: 6),
              const SizedBox(height: 12),
              if (progress != null)
                Text(progress.sizeText + (progress.speedText.isNotEmpty ? ' • ' + progress.speedText : '') + (progress.etaText.isNotEmpty ? ' • ' + progress.etaText : ''), style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 24),
              Text('Feel free to switch apps or lock your device.\nThe download will continue in the background.\nWe’ll send a notification when it’s done.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.black54)),
            ],
          ),
        ),
      );
    }

    // Onboarding UI
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(Icons.android, color: colorScheme.primary, size: 40),
                const SizedBox(height: 24),
                Text('Welcome to AI Edge', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: colorScheme.onBackground)),
                const SizedBox(height: 32),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _hfTokenController,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Hugging Face Token',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    errorText: _tokenError,
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
                if (_verifyingToken)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                const SizedBox(height: 24),
                _loadingModels
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<String>(
                        value: _selectedModel,
                        items: _modelNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                        onChanged: (value) => setState(() => _selectedModel = value),
                        decoration: const InputDecoration(
                          labelText: 'Select Model',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    child: const Text('Continue'),
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
