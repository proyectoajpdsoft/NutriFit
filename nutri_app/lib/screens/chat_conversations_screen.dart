import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/chat_conversation.dart';
import '../models/paciente.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class ChatConversationsScreen extends StatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  State<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState extends State<ChatConversationsScreen> {
  late Future<void> _loadFuture;
  List<ChatConversation> _conversations = [];
  List<Paciente> _pacientesActivos = [];
  List<Usuario> _usuariosConPaciente = [];
  List<Usuario> _usuariosSinPaciente = [];
  final Map<int, Future<int>> _messageCountByUser = {};

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

    if (authService.isGuestMode) {
      return;
    }

    final conversations = await apiService.getChatConversations();

    if (_isNutri(authService)) {
      final pacientes = await apiService.getPacientes(activo: 'S');
      final usuarios = await apiService.getUsuarios();
      final myUserCode = int.tryParse(authService.userCode ?? '') ?? 0;

      _messageCountByUser.clear();

      _conversations = conversations
          .where((convo) => convo.unreadCount > 0 && convo.usuarioId > 0)
          .toList();
      _pacientesActivos = [...pacientes]..sort(
          (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      _usuariosConPaciente = usuarios
          .where(
            (u) =>
                u.activo == 'S' &&
                (u.codigoPaciente ?? 0) > 0 &&
                u.codigo != myUserCode,
          )
          .toList()
        ..sort((a, b) {
          final aName = (a.nombre ?? a.nick).toLowerCase();
          final bName = (b.nombre ?? b.nick).toLowerCase();
          return aName.compareTo(bName);
        });
      _usuariosSinPaciente = usuarios
          .where(
            (u) =>
                u.activo == 'S' &&
                (u.codigoPaciente == null || u.codigoPaciente! <= 0) &&
                u.codigo != myUserCode,
          )
          .toList()
        ..sort((a, b) {
          final aName = (a.nombre ?? a.nick).toLowerCase();
          final bName = (b.nombre ?? b.nick).toLowerCase();
          return aName.compareTo(bName);
        });
    } else {
      _conversations = conversations.where((c) => c.unreadCount > 0).toList();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loadFuture = _loadData();
    });
    await _loadFuture;
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

  Future<int> _getMessageCountForUser(int userId) {
    return _messageCountByUser.putIfAbsent(userId, () async {
      final items = await context.read<ApiService>().getChatMessages(
            otherUserId: userId,
          );
      return items.length;
    });
  }

  Future<void> _openChatWithUser({
    required int userId,
    required String displayName,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: userId,
          otherDisplayName: displayName,
        ),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  Widget _buildChatTargetCard({
    required int userId,
    required String title,
    String? subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: ListTile(
        title: Text(title),
        subtitle: subtitle == null || subtitle.isEmpty ? null : Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<int>(
              future: _getMessageCountForUser(userId),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  radius: 14,
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: () => _openChatWithUser(
          userId: userId,
          displayName: title,
        ),
      ),
    );
  }

  Widget _buildUnreadChatsList() {
    if (_conversations.isEmpty) {
      return const Center(
        child: Text('No hay mensajes sin leer.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _conversations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final convo = _conversations[index];
        final nombre = convo.nombre.isNotEmpty
            ? convo.nombre
            : (convo.nick.isNotEmpty ? convo.nick : 'Usuario');
        final fecha = _formatFecha(convo.lastDate);
        final preview = _buildPreview(convo);

        return Card(
          elevation: 2,
          child: ListTile(
            onTap: () => _openChatWithUser(
              userId: convo.usuarioId,
              displayName: nombre,
            ),
            leading: CircleAvatar(
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
              ),
            ),
            title: Text(nombre),
            subtitle:
                Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    );
  }

  Widget _buildPacientesTab() {
    if (_usuariosConPaciente.isEmpty) {
      return const Center(
        child: Text('No hay usuarios pacientes con chat asociado.'),
      );
    }

    final pacientesById = <int, Paciente>{
      for (final paciente in _pacientesActivos) paciente.codigo: paciente,
    };

    return ListView.builder(
      itemCount: _usuariosConPaciente.length,
      itemBuilder: (context, index) {
        final usuarioPaciente = _usuariosConPaciente[index];
        final codigoPaciente = usuarioPaciente.codigoPaciente;
        final paciente =
            codigoPaciente != null ? pacientesById[codigoPaciente] : null;
        final nombrePaciente = (paciente?.nombre ?? '').trim().isNotEmpty
            ? paciente!.nombre
            : ((usuarioPaciente.nombre ?? '').trim().isNotEmpty
                ? usuarioPaciente.nombre!.trim()
                : usuarioPaciente.nick);
        final subtitle = 'Paciente · @${usuarioPaciente.nick}';

        return _buildChatTargetCard(
          userId: usuarioPaciente.codigo,
          title: nombrePaciente,
          subtitle: subtitle,
        );
      },
    );
  }

  Widget _buildUsuariosTab() {
    if (_usuariosSinPaciente.isEmpty) {
      return const Center(
        child: Text('No hay usuarios sin paciente asociado.'),
      );
    }

    return ListView.builder(
      itemCount: _usuariosSinPaciente.length,
      itemBuilder: (context, index) {
        final usuario = _usuariosSinPaciente[index];
        final nombre = (usuario.nombre ?? '').trim().isNotEmpty
            ? usuario.nombre!.trim()
            : usuario.nick;
        final tipo = (usuario.tipo ?? 'Usuario').trim();
        return _buildChatTargetCard(
          userId: usuario.codigo,
          title: nombre,
          subtitle: tipo,
        );
      },
    );
  }

  Widget _buildGuestGate() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              l10n.messagesInboxGuestBody,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: Text(l10n.messagesInboxGuestAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutriContent() {
    final unreadCount = _conversations.length;
    final pacientesCount = _usuariosConPaciente.length;
    final usuariosCount = _usuariosSinPaciente.length;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Sin leer ($unreadCount)'),
              Tab(text: 'Pacientes ($pacientesCount)'),
              Tab(text: 'Usuarios ($usuariosCount)'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildUnreadChatsList(),
                _buildPacientesTab(),
                _buildUsuariosTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
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
                    child: Text('Error al cargar chats: ${snapshot.error}'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: _isNutri(authService)
                      ? _buildNutriContent()
                      : _buildUnreadChatsList(),
                );
              },
            ),
    );
  }
}
