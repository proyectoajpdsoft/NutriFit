class ChatConversation {
  final int id;
  final int usuarioId;
  final String nombre;
  final String nick;
  final String? lastMessage;
  final String? lastImageBase64;
  final DateTime? lastDate;
  final int unreadCount;

  ChatConversation({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.nick,
    this.lastMessage,
    this.lastImageBase64,
    this.lastDate,
    required this.unreadCount,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      usuarioId: int.tryParse(json['usuario_id']?.toString() ?? '') ?? 0,
      nombre: json['nombre']?.toString() ?? '',
      nick: json['nick']?.toString() ?? '',
      lastMessage: json['ultimo_mensaje']?.toString(),
      lastImageBase64: json['ultimo_imagen']?.toString(),
      lastDate: json['ultimo_fecha'] != null
          ? DateTime.tryParse(json['ultimo_fecha'].toString())
          : null,
      unreadCount: int.tryParse(json['no_leidos']?.toString() ?? '') ?? 0,
    );
  }
}
