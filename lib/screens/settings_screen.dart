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
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1976D2),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Profile Section
                    _buildSectionCard(
                      title: 'User Profile',
                      icon: Icons.person_outline,
                      child: Column(
                        children: [
                          _buildInputField(
                            label: 'Display Name',
                            controller: _nameController,
                            icon: Icons.person,
                            hint: 'Enter your name',
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // API Configuration Section
                    _buildSectionCard(
                      title: 'API Configuration',
                      icon: Icons.key_outlined,
                      child: Column(
                        children: [
                          _buildInputField(
                            label: 'Hugging Face Token',
                            controller: _hfTokenController,
                            icon: Icons.security,
                            hint: 'Enter your HF token',
                            obscureText: true,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Model Selection Section
                    _buildSectionCard(
                      title: 'AI Model',
                      icon: Icons.psychology_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_modelNames.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                _selectedModel ?? 'No model selected',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedModel,
                                  hint: const Text('Select a model'),
                                  isExpanded: true,
                                  items: _modelConfigs.map((config) {
                                    final downloaded = _downloadedStatus[config.modelName] ?? false;
                                    return DropdownMenuItem(
                                      value: config.modelName,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              config.modelName,
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: downloaded ? Colors.green[50] : Colors.orange[50],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  downloaded ? Icons.check_circle : Icons.cloud_download,
                                                  color: downloaded ? Colors.green[700] : Colors.orange[700],
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  downloaded ? 'Ready' : 'Download',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: downloaded ? Colors.green[700] : Colors.orange[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) async {
                                    setState(() { _selectedModel = value; });
                                  },
                                ),
                              ),
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // Download section
                          if (_selectedModel != null && !(_downloadedStatus[_selectedModel!] ?? false))
                            _isDownloading && _downloadProgress != null
                                ? Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.download, color: Colors.blue[700], size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Downloading Model...',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        LinearProgressIndicator(
                                          value: _downloadProgress!.progress,
                                          minHeight: 6,
                                          backgroundColor: Colors.blue[100],
                                          valueColor: AlwaysStoppedAnimation(Colors.blue[600]),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _downloadProgress!.sizeText + 
                                          (_downloadProgress!.speedText.isNotEmpty ? ' • ${_downloadProgress!.speedText}' : '') + 
                                          (_downloadProgress!.etaText.isNotEmpty ? ' • ${_downloadProgress!.etaText}' : ''),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.cloud_download, size: 20),
                                      label: const Text(
                                        'Download Model',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1976D2),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
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
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _savePrefs,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1976D2).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
