import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'entrenamiento_comentarios_pendientes_screen.dart';
import 'entrenamiento_sensaciones_pendientes_screen.dart';

class MessagesInboxScreen extends StatefulWidget {
  const MessagesInboxScreen({super.key});

  @override
  State<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends State<MessagesInboxScreen> {
  late Future<void> _loadFuture;
  List<ChatConversation> _conversations = [];
  List<ChatMessage> _unreadChatMessages = [];
  List<Map<String, dynamic>> _sensacionesPendientes = [];
  List<Map<String, dynamic>> _comentariosPendientes = [];

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadData();
  }

  bool _isNutri(AuthService authService) {
    return authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
  }

  Future<void> _loadData() async {
    final apiService = context.read<ApiService>();
    final authService = context.read<AuthService>();
    final isNutri = _isNutri(authService);

    if (authService.isGuestMode) {
      return;
    }

    if (isNutri) {
      final conversations = await apiService.getChatConversations();
      final sensaciones = await apiService.getSensacionesPendientesNutri();

      _conversations = conversations;
      _sensacionesPendientes = sensaciones;
    } else {
      final messages = await apiService.getChatMessages();
      final comentarios = await apiService.getComentariosPendientes();
      final userId = int.tryParse(authService.userCode ?? '') ?? 0;

      _unreadChatMessages =
          messages.where((m) => !m.read && m.receiverId == userId).toList();
      _comentariosPendientes = comentarios;
    }
  }

  Widget _buildGuestGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Para chatear con tu dietista online, por favor, regístrate (es gratis).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('Registrarse'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count, {
    required Color background,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNutriContent() {
    return ListView(
      children: [
        _buildSectionHeader(
          'Chats',
          _conversations.length,
          background: const Color(0xFFE7F3FF),
          accent: const Color(0xFF1B6FD8),
          icon: Icons.mark_chat_unread_outlined,
        ),
        if (_conversations.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('No hay chats pendientes.'),
          )
        else
          ..._conversations.map((convo) {
            final nombre = convo.nombre.isNotEmpty
                ? convo.nombre
                : (convo.nick.isNotEmpty ? convo.nick : 'Usuario');
            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                ),
              ),
              title: Text(nombre),
              subtitle: Text(
                convo.lastMessage?.isNotEmpty == true
                    ? convo.lastMessage!
                    : (convo.lastImageBase64?.isNotEmpty == true
                        ? 'Imagen'
                        : 'Sin mensajes'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: convo.unreadCount > 0
                  ? Container(
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
                    )
                  : null,
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
                    _loadFuture = _loadData();
                  });
                }
              },
            );
          }),
        _buildSectionHeader(
          'Sensaciones de ejercicios pendientes',
          _sensacionesPendientes.length,
          background: const Color(0xFFFFF1E6),
          accent: const Color(0xFFE0721A),
          icon: Icons.assignment_outlined,
        ),
        if (_sensacionesPendientes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('No hay sensaciones de ejercicios pendientes.'),
          )
        else
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('Ver sensaciones de ejercicios pendientes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const EntrenamientoSensacionesPendientesScreen(),
                ),
              );
              if (mounted) {
                setState(() {
                  _loadFuture = _loadData();
                });
              }
            },
          ),
      ],
    );
  }

  Widget _buildPacienteContent() {
    return ListView(
      children: [
        _buildSectionHeader(
          'Chat',
          _unreadChatMessages.length,
          background: const Color(0xFFE7F3FF),
          accent: const Color(0xFF1B6FD8),
          icon: Icons.mark_chat_unread_outlined,
        ),
        if (_unreadChatMessages.isEmpty)
          ListTile(
            leading: const Icon(Icons.mark_chat_unread_outlined),
            title: const Text('Abrir chat con dietista'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatScreen(
                    otherDisplayName: 'Dietista',
                  ),
                ),
              );
              if (mounted) {
                setState(() {
                  _loadFuture = _loadData();
                });
              }
            },
          )
        else
          ..._unreadChatMessages.map((msg) {
            final preview = msg.body?.isNotEmpty == true
                ? msg.body!
                : (msg.imageBase64?.isNotEmpty == true ? 'Imagen' : 'Mensaje');
            return ListTile(
              leading: const Icon(Icons.mark_chat_unread_outlined),
              title: const Text('Mensaje de dietista'),
              subtitle:
                  Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatScreen(
                      otherDisplayName: 'Dietista',
                    ),
                  ),
                );
                if (mounted) {
                  setState(() {
                    _loadFuture = _loadData();
                  });
                }
              },
            );
          }),
        _buildSectionHeader(
          'Comentarios pendientes',
          _comentariosPendientes.length,
          background: const Color(0xFFF1F7E8),
          accent: const Color(0xFF3E7C29),
          icon: Icons.assignment_outlined,
        ),
        if (_comentariosPendientes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('No tienes comentarios pendientes.'),
          )
        else
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('Ver comentarios pendientes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const EntrenamientoComentariosPendientesScreen(),
                ),
              );
              if (mounted) {
                setState(() {
                  _loadFuture = _loadData();
                });
              }
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: authService.isGuestMode
          ? _buildGuestGate()
          : FutureBuilder<void>(
              future: _loadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error al cargar mensajes: ${snapshot.error}'),
                  );
                }

                final isNutri = _isNutri(authService);
                return isNutri ? _buildNutriContent() : _buildPacienteContent();
              },
            ),
    );
  }
}
