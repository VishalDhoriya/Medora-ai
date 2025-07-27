import 'package:flutter/material.dart';
import 'dart:async';
import '../services/llm_service.dart';
import '../services/model_config_service.dart';
import '../models/chat_message.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  StreamSubscription<InferenceResult>? _inferenceSubscription;
  bool _isModelReady = false;
  bool _isGenerating = false;
  String _currentStreamingResponse = '';
  String? _selectedModelId;
  List<ModelConfig> _availableModels = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableModels();
    _setupInferenceListener();
  }

  @override
  void dispose() {
    _inferenceSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    LlmService.disposeModel();
    super.dispose();
  }

  Future<void> _loadAvailableModels() async {
    final models = await ModelConfigService.loadModelConfigs();
    setState(() {
      _availableModels = models;
      if (models.isNotEmpty) {
        _selectedModelId = models.first.modelId;
      }
    });
  }

  void _setupInferenceListener() {
    _inferenceSubscription = LlmService.getInferenceStream().listen(
      (result) {
        print('[ChatScreen._setupInferenceListener] Got inference result: isDone=${result.isDone}, partialResult=${result.partialResult}');
        loo('[ChatScreen._setupInferenceListener] Got inference result: isDone=${result.isDone}, partialResult=${result.partialResult}');
        setState(() {
          if (result.isDone) {
            loo('[ChatScreen._setupInferenceListener] Inference is done');
            if (_currentStreamingResponse.isNotEmpty) {
              _messages.add(ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                content: _currentStreamingResponse,
                isUser: false,
                timestamp: DateTime.now(),
                tokensPerSecond: result.tokensPerSecond,
              ));
              _currentStreamingResponse = '';
            }
            _isGenerating = false;
          } else {
            // Append new tokens to the streaming response for true streaming effect
            _currentStreamingResponse += result.partialResult;
          }
        });
        _scrollToBottom();
      },
      onError: (error) {
        print('[ChatScreen._setupInferenceListener] Inference error: $error');
        setState(() {
          _isGenerating = false;
          _currentStreamingResponse = '';
        });
        _showErrorSnackBar('Inference error: $error');
      },
    );
  }

  Future<void> _initializeModel() async {
    if (_selectedModelId == null) return;

    final config = await ModelConfigService.getModelConfig(_selectedModelId!);
    if (config == null) return;

    setState(() {
      _isModelReady = false;
    });

    // Check if model is downloaded
    final isDownloaded = await LlmService.isModelDownloaded(_selectedModelId!);
    if (!isDownloaded) {
      _showErrorSnackBar('Model not downloaded. Please download it first.');
      return;
    }

    // Initialize model (Google-style: always use external files dir)
    final directory = await getExternalStorageDirectory();
    final modelPath = '${directory!.path}/${config.modelDir}/${config.version}/${config.modelFile}';
    print('[ChatScreen._initializeModel] Using modelPath: $modelPath');
    final success = await LlmService.initializeModel(
      config: config,
      modelPath: modelPath,
    );

    setState(() {
      _isModelReady = success;
    });

    if (success) {
      _showSuccessSnackBar('Model initialized successfully with GPU acceleration');
    } else {
      _showErrorSnackBar('Failed to initialize model');
    }
  }

  // TEMP: Add a debug print function for extra logging
  void loo(Object? msg) {
    // ignore: avoid_print
    print('[LOO_DEBUG] $msg');
  }

  void _sendMessage() async {
    if (!_isModelReady || _isGenerating || _messageController.text.trim().isEmpty) {
      print('[ChatScreen._sendMessage] Not sending: modelReady=${_isModelReady}, isGenerating=${_isGenerating}, textEmpty=${_messageController.text.trim().isEmpty}');
      loo('[ChatScreen._sendMessage] Not sending: modelReady=${_isModelReady}, isGenerating=${_isGenerating}, textEmpty=${_messageController.text.trim().isEmpty}');
      return;
    }

    final userMessage = _messageController.text.trim();
    print('[ChatScreen._sendMessage] Sending user message: $userMessage');
    loo('[ChatScreen._sendMessage] Sending user message: $userMessage');
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isGenerating = true;
      _currentStreamingResponse = '';
    });
    loo('[ChatScreen._sendMessage] Set _isGenerating to true');

    _scrollToBottom();
    loo('[ChatScreen._sendMessage] Called _scrollToBottom');

    // Generate response using Google's GPU-accelerated inference
    try {
      await LlmService.generateResponse(userMessage);
      print('[ChatScreen._sendMessage] Called LlmService.generateResponse');
      loo('[ChatScreen._sendMessage] Called LlmService.generateResponse');
    } catch (e, stack) {
      print('[ChatScreen._sendMessage] ERROR: $e');
      loo('[ChatScreen._sendMessage] ERROR: $e');
      loo(stack.toString());
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildModelSelector(),
        Expanded(child: _buildChatArea()),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildModelSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedModelId,
              decoration: const InputDecoration(
                labelText: 'Select Model',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _availableModels.map((model) {
                // Shorten long model names for display
                String displayName = model.modelName;
                if (displayName.length > 20) {
                  displayName = '${displayName.substring(0, 17)}...';
                }
                
                return DropdownMenuItem<String>(
                  value: model.modelId,
                  child: Text(
                    '$displayName (${model.modelSize})',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedModelId = value;
                  _isModelReady = false;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _selectedModelId != null ? _initializeModel : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isModelReady ? Colors.green[100] : null,
              foregroundColor: _isModelReady ? Colors.green[700] : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(80, 36),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isModelReady ? Icons.check_circle : Icons.psychology,
                  size: 16,
                  color: _isModelReady ? Colors.green : null,
                ),
                const SizedBox(width: 4),
                Text(
                  _isModelReady ? 'Ready' : 'Init',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length + (_currentStreamingResponse.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _messages.length) {
            return _buildMessageBubble(_messages[index]);
          } else {
            // Show streaming response
            return _buildMessageBubble(ChatMessage(
              id: 'streaming',
              content: _currentStreamingResponse,
              isUser: false,
              timestamp: DateTime.now(),
              isStreaming: true,
            ));
          }
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.psychology, size: 16, color: Colors.blue[700]),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[500] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromRGBO(0, 0, 0, 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  if (!isUser && message.tokensPerSecond != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${message.tokensPerSecond!.toStringAsFixed(1)} tokens/s',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (message.isStreaming) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Generating...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person, size: 16, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: _isModelReady 
                    ? 'Type your message...' 
                    : 'Initialize a model to start chatting',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              enabled: _isModelReady && !_isGenerating,
              maxLines: null,
              onSubmitted: (_) => _sendMessage(),
              onChanged: (_) => setState(() {}), // <-- Add this line
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _isModelReady && !_isGenerating && _messageController.text.trim().isNotEmpty 
                ? _sendMessage 
                : null,
            mini: true,
            backgroundColor: _isModelReady && !_isGenerating && _messageController.text.trim().isNotEmpty
                ? Colors.blue[500]
                : Colors.grey[300],
            child: _isGenerating 
                ? const Text('...')
                : const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
