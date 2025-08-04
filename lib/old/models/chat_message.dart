class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final double? tokensPerSecond;
  final bool isStreaming;
  
  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.tokensPerSecond,
    this.isStreaming = false,
  });
  
  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    double? tokensPerSecond,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      tokensPerSecond: tokensPerSecond ?? this.tokensPerSecond,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
