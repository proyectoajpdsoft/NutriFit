import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/image_viewer_dialog.dart';

class ChatScreen extends StatefulWidget {
  final int? otherUserId;
  final String? otherDisplayName;

  const ChatScreen({
    super.key,
    this.otherUserId,
    this.otherDisplayName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final List<ChatMessage> _messages = [];
  Timer? _refreshTimer;

  bool _isLoading = true;
  bool _isSending = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageMime;

  @override
  void initState() {
    super.initState();
    _ensureNotGuest();
    _loadMessages();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadMessages(),
    );
    _messageController.addListener(() {
      // Cuando el usuario empieza a escribir, baja el scroll
      if (_scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });
  }

  Future<void> _ensureNotGuest() async {
    final authService = context.read<AuthService>();
    if (!authService.isGuestMode) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registro requerido'),
        content: const Text(
            'Para chatear con tu dietista online, por favor, regístrate (es gratis)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/register');
            },
            child: const Text('Registrarse'),
          ),
        ],
      ),
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isNutriUser(AuthService authService) {
    return authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
  }

  Future<void> _loadMessages() async {
    try {
      final apiService = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final isNutri = _isNutriUser(authService);

      if (isNutri && widget.otherUserId == null) {
        return;
      }

      final items = await apiService.getChatMessages(
        otherUserId: isNutri ? widget.otherUserId : null,
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(items);
        _isLoading = false;
      });

      await apiService.markChatRead(
        otherUserId: isNutri ? widget.otherUserId : null,
      );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    await Future.delayed(const Duration(milliseconds: 120));
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageMime = _guessMime(picked.path);
    });
  }

  String _guessMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final text = _messageController.text.trim();

    if (text.isEmpty && _selectedImageBytes == null) {
      return;
    }

    setState(() => _isSending = true);

    try {
      final apiService = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final isNutri = _isNutriUser(authService);

      await apiService.sendChatMessage(
        message: text,
        imageBytes: _selectedImageBytes,
        imageMime: _selectedImageMime,
        receiverId: isNutri ? widget.otherUserId : null,
      );

      if (!mounted) return;
      setState(() {
        _messageController.clear();
        _selectedImageBytes = null;
        _selectedImageMime = null;
      });
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar mensaje. $errorMessage')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final apiService = context.read<ApiService>();
    await apiService.deleteChatMessage(message.id, deleteForAll: true);
    if (!mounted) return;
    await _loadMessages();
  }

  Widget _buildImagePreview() {
    if (_selectedImageBytes == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _selectedImageBytes!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Imagen lista para enviar'),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _selectedImageBytes = null;
                _selectedImageMime = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int myId) {
    final isMine = message.senderId == myId;
    final bubbleColor = isMine ? Colors.green.shade100 : Colors.white;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(isMine ? 14 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 14),
    );

    final hasImage = (message.imageBase64 ?? '').isNotEmpty;
    final hasText = (message.body ?? '').trim().isNotEmpty;

    return Column(
      crossAxisAlignment: align,
      children: [
        GestureDetector(
          onLongPress: isMine
              ? () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Borrar mensaje'),
                      content: const Text('Quieres borrar este mensaje?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Borrar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await _deleteMessage(message);
                  }
                }
              : null,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: align,
              children: [
                if (hasImage)
                  GestureDetector(
                    onTap: () => showImageViewerDialog(
                      context: context,
                      base64Image: message.imageBase64!,
                      title: 'Imagen',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        base64Decode(message.imageBase64!),
                        width: 220,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                if (hasText) ...[
                  if (hasImage) const SizedBox(height: 8),
                  Text(message.body ?? ''),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.createdAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 6),
                      Icon(
                        message.read ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.read
                            ? Colors.blueGrey.shade700
                            : Colors.grey.shade600,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final myId = int.tryParse(authService.userCode ?? '') ?? 0;
    final title = widget.otherDisplayName ?? 'Chat';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewInsets = MediaQuery.of(context).viewInsets.bottom;
            final inputHeight = 80.0 +
                (_selectedImageBytes != null ? 70.0 : 0.0); // Ajuste estimado
            final listViewHeight =
                constraints.maxHeight - inputHeight - viewInsets;
            return Column(
              children: [
                SizedBox(
                  height: listViewHeight > 0 ? listViewHeight : 0,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          // Orden original: más antiguos arriba, más recientes abajo
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _buildMessageBubble(message, myId);
                          },
                        ),
                ),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 6,
                    bottom: 12 + viewInsets,
                  ),
                  child: Column(
                    children: [
                      _buildImagePreview(),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.photo_outlined),
                            onPressed: _pickImage,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Escribe un mensaje',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: _isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                            onPressed: _isSending ? null : _sendMessage,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
