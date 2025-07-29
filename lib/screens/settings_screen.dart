import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../services/model_config_service.dart';
import '../services/model_download_service.dart';
import 'dart:async';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _hfTokenController = TextEditingController();
  String? _selectedModel;
  List<ModelConfig> _modelConfigs = [];
  List<String> _modelNames = [];
  Map<String, bool> _downloadedStatus = {};
  bool _loading = true;
  bool _isDownloading = false;
  DownloadProgress? _downloadProgress;
  StreamSubscription<DownloadProgress>? _downloadSub;

  @override
  void initState() {
    super.initState();
    _loadPrefsAndModels();
  }

  Future<void> _loadPrefsAndModels() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('onboard_name') ?? '';
    _hfTokenController.text = prefs.getString('onboard_hf_token') ?? '';
    _selectedModel = prefs.getString('onboard_model');
    final configs = await ModelConfigService.loadModelConfigs();
    final names = configs.map((c) => c.modelName).toList();
    _modelConfigs = configs;
    _modelNames = names;
    // Check which models are downloaded
    for (final config in configs) {
      _downloadedStatus[config.modelName] = await _isModelDownloaded(config.modelName);
    }
    setState(() { _loading = false; });
  }

  Future<bool> _isModelDownloaded(String modelName) async {
    final configList = _modelConfigs.where((c) => c.modelName == modelName).toList();
    if (configList.isEmpty) return false;
    final modelConfig = configList.first;
    try {
      final _channel = MethodChannel('com.google.ai.edge/model_download');
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

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('onboard_name') ?? '';
    _hfTokenController.text = prefs.getString('onboard_hf_token') ?? '';
    _selectedModel = prefs.getString('onboard_model');
    // TODO: Load model names from ModelConfigService if needed
    setState(() { _loading = false; });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('onboard_name', _nameController.text.trim());
    await prefs.setString('onboard_hf_token', _hfTokenController.text.trim());
    if (_selectedModel != null) {
      await prefs.setString('onboard_model', _selectedModel!);
    }
    Navigator.of(context).pop();
    // Optionally notify other screens of changes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('User Name', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(controller: _nameController),
                  const SizedBox(height: 16),
                  const Text('Hugging Face Token', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(controller: _hfTokenController, obscureText: true),
                  const SizedBox(height: 16),
                  const Text('Model', style: TextStyle(fontWeight: FontWeight.bold)),
                  _modelNames.isEmpty
                      ? Text(_selectedModel ?? '')
                      : DropdownButtonFormField<String>(
                          value: _selectedModel,
                          items: _modelConfigs.map((config) {
                            final downloaded = _downloadedStatus[config.modelName] ?? false;
                            return DropdownMenuItem(
                              value: config.modelName,
                              child: Row(
                                children: [
                                  Text(config.modelName),
                                  const SizedBox(width: 8),
                                  downloaded
                                      ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                                      : const Icon(Icons.cloud_download, color: Colors.grey, size: 18),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            setState(() { _selectedModel = value; });
                          },
                        ),
                  const SizedBox(height: 16),
                  if (_selectedModel != null && !(_downloadedStatus[_selectedModel!] ?? false))
                    _isDownloading && _downloadProgress != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LinearProgressIndicator(value: _downloadProgress!.progress, minHeight: 6),
                              const SizedBox(height: 8),
                              Text(_downloadProgress!.sizeText + (_downloadProgress!.speedText.isNotEmpty ? ' • ' + _downloadProgress!.speedText : '') + (_downloadProgress!.etaText.isNotEmpty ? ' • ' + _downloadProgress!.etaText : ''), style: const TextStyle(fontSize: 14)),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.cloud_download),
                              label: const Text('Download Model'),
                              onPressed: () async {
                                final configList = _modelConfigs.where((c) => c.modelName == _selectedModel).toList();
                                if (configList.isEmpty) return;
                                final config = configList.first;
                                setState(() { _isDownloading = true; });
                                _downloadSub = ModelDownloadService.getDownloadProgress().listen((progress) {
                                  setState(() { _downloadProgress = progress; });
                                  if (progress.state == 'completed') {
                                    _downloadSub?.cancel();
                                    _downloadSub = null;
                                    setState(() {
                                      _isDownloading = false;
                                      _downloadedStatus[_selectedModel!] = true;
                                    });
                                  } else if (progress.state == 'failed' || progress.state == 'cancelled') {
                                    _downloadSub?.cancel();
                                    _downloadSub = null;
                                    setState(() { _isDownloading = false; });
                                  }
                                });
                                await ModelDownloadService.downloadModel(
                                  modelUrl: config.downloadUrl,
                                  modelName: config.modelName,
                                  version: config.version,
                                  fileName: config.modelFile,
                                  modelDir: config.modelDir,
                                  totalBytes: config.totalBytes,
                                  accessToken: _hfTokenController.text.trim(),
                                );
                              },
                            ),
                          ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savePrefs,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
