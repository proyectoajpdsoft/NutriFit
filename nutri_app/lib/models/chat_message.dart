class ChatMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final int receiverId;
  final String? body;
  final String? imageBase64;
  final String? imageMime;
  final bool read;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    this.body,
    this.imageBase64,
    this.imageMime,
    required this.read,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      conversationId:
          int.tryParse(json['conversation_id']?.toString() ?? '') ?? 0,
      senderId: int.tryParse(json['sender_id']?.toString() ?? '') ?? 0,
      receiverId: int.tryParse(json['receiver_id']?.toString() ?? '') ?? 0,
      body: json['cuerpo']?.toString(),
      imageBase64: json['imagen_base64']?.toString(),
      imageMime: json['imagen_mime']?.toString(),
      read: json['leido']?.toString() == '1' ||
          json['leido']?.toString().toLowerCase() == 'true',
      createdAt: DateTime.tryParse(json['creado_en']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
