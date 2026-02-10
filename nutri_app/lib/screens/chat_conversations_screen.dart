import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat_conversation.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class ChatConversationsScreen extends StatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  State<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState extends State<ChatConversationsScreen> {
  late Future<List<ChatConversation>> _conversationsFuture;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = _loadConversations();
  }

  Future<List<ChatConversation>> _loadConversations() async {
    final apiService = context.read<ApiService>();
    return apiService.getChatConversations();
  }

  String _formatFecha(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd/MM HH:mm').format(date);
  }

  String _buildPreview(ChatConversation convo) {
    if ((convo.lastMessage ?? '').trim().isNotEmpty) {
      return convo.lastMessage!.trim();
    }
    if ((convo.lastImageBase64 ?? '').trim().isNotEmpty) {
      return 'Imagen';
    }
    return 'Sin mensajes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<ChatConversation>>(
        future: _conversationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar chats: ${snapshot.error}'),
            );
          }

          // Filtrar solo conversaciones con mensajes no leídos
          final allItems = snapshot.data ?? [];
          final items = allItems.where((c) => c.unreadCount > 0).toList();

          if (items.isEmpty) {
            return const Center(
              child: Text('No hay mensajes sin leer.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _conversationsFuture = _loadConversations();
              });
              await _conversationsFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final convo = items[index];
                final nombre = convo.nombre.isNotEmpty
                    ? convo.nombre
                    : (convo.nick.isNotEmpty ? convo.nick : 'Usuario');
                final fecha = _formatFecha(convo.lastDate);
                final preview = _buildPreview(convo);

                return Card(
                  elevation: 2,
                  child: ListTile(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUserId: convo.usuarioId,
                            otherDisplayName: nombre,
                          ),
                        ),
                      );
                      if (mounted) {
                        setState(() {
                          _conversationsFuture = _loadConversations();
                        });
                      }
                    },
                    leading: CircleAvatar(
                      child: Text(
                        nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                      ),
                    ),
                    title: Text(nombre),
                    subtitle: Text(preview,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (fecha.isNotEmpty)
                          Text(
                            fecha,
                            style: const TextStyle(fontSize: 11),
                          ),
                        const SizedBox(height: 6),
                        if (convo.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              convo.unreadCount > 99
                                  ? '99+'
                                  : convo.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
