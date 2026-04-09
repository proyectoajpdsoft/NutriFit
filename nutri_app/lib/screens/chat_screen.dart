import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final List<ChatMessage> _messages = [];
  Timer? _refreshTimer;

  bool _isLoading = true;
  bool _isSending = false;
  bool _isSearchVisible = false;
  bool _isLoadingMore = false;
  bool _didInitialAutoScroll = false;
  bool _hasMoreHistory = true;
  int? _nextBeforeId;
  Uint8List? _selectedImageBytes;
  String? _selectedImageMime;

  static const int _chatPageSize = 30;
  static const String _chatSearchVisiblePrefKey = 'chat_show_search_field';

  String _searchText = '';

  // Caché para imágenes decodificadas para evitar parpadeos
  final Map<String, Uint8List> _imageCache = {};

  // Parámetros de tamaño de imagen para chat
  int _maxImageWidth = 1280;
  int _maxImageHeight = 1280;

  static const String _chatImageSizeParam = 'tamaño_imagen_maximo_chat';

  @override
  void initState() {
    super.initState();
    _ensureNotGuest();
    _loadSearchUiState();
    _loadImageSizeParams();
    _loadInitialMessages();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshLatestMessages(),
    );
    _scrollController.addListener(_handleScrollForHistoryPagination);
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        _scrollToBottom();
        Future.delayed(
          const Duration(milliseconds: 220),
          () {
            if (mounted && _messageFocusNode.hasFocus) {
              _scrollToBottom();
            }
          },
        );
      }
    });
    _messageController.addListener(() {
      // Si está escribiendo, mantener visibles los últimos mensajes
      if (_scrollController.hasClients && _messageFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 80), _scrollToBottom);
      }
    });
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });

    _scrollToBottomWhenReady(forceJump: true);
  }

  Future<void> _loadImageSizeParams() async {
    try {
      final apiService = context.read<ApiService>();
      final param = await apiService.getParametro(_chatImageSizeParam);
      if (param == null) {
        return;
      }

      final width = int.tryParse((param['valor'] ?? '').toString());
      final height = int.tryParse((param['valor2'] ?? '').toString());
      if (width != null && width > 0 && height != null && height > 0) {
        if (mounted) {
          setState(() {
            _maxImageWidth = width;
            _maxImageHeight = height;
          });
        }
      }
    } catch (e) {
      // Usar valores por defecto si falla
    }
  }

  Future<void> _ensureNotGuest() async {
    final authService = context.read<AuthService>();
    if (!authService.isGuestMode) return;
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.drawerRegistrationRequiredTitle),
        content: Text(l10n.drawerRegistrationRequiredChatMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/register');
            },
            child: Text(l10n.navStartRegistration),
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
    _scrollController.removeListener(_handleScrollForHistoryPagination);
    _messageFocusNode.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final isVisible = prefs.getBool(_chatSearchVisiblePrefKey) ?? false;
    if (!mounted) return;
    setState(() {
      _isSearchVisible = isVisible;
    });
  }

  Future<void> _saveSearchUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chatSearchVisiblePrefKey, _isSearchVisible);
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _searchText = '';
      }
    });
    _saveSearchUiState();
  }

  bool _isNutriUser(AuthService authService) {
    return authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
  }

  Future<void> _loadInitialMessages() async {
    try {
      final apiService = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final isNutri = _isNutriUser(authService);

      if (isNutri && widget.otherUserId == null) {
        return;
      }

      final page = await apiService.getChatMessagesPage(
        otherUserId: isNutri ? widget.otherUserId : null,
        limit: _chatPageSize,
      );
      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(page.items);
        _hasMoreHistory = page.hasMore;
        _nextBeforeId = page.nextBeforeId;
        _isLoading = false;
      });

      if (!_didInitialAutoScroll && page.items.isNotEmpty) {
        _didInitialAutoScroll = true;
        _ensureInitialPositionAtBottom();
      }

      await apiService.markChatRead(
        otherUserId: isNutri ? widget.otherUserId : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshLatestMessages({bool smoothAutoScroll = false}) async {
    try {
      final apiService = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final isNutri = _isNutriUser(authService);
      final shouldKeepBottom = !_scrollController.hasClients || _isNearBottom();

      if (isNutri && widget.otherUserId == null) {
        return;
      }

      final page = await apiService.getChatMessagesPage(
        otherUserId: isNutri ? widget.otherUserId : null,
        limit: _chatPageSize,
      );
      if (!mounted) return;

      final existingById = <int, ChatMessage>{
        for (final m in _messages) m.id: m,
      };
      bool hasNewMessages = false;
      for (final m in page.items) {
        if (!existingById.containsKey(m.id)) {
          hasNewMessages = true;
        }
        existingById[m.id] = m;
      }

      final merged = existingById.values.toList()
        ..sort((a, b) => a.id.compareTo(b.id));

      final hasAnyChanges = merged.length != _messages.length ||
          merged.asMap().entries.any((entry) {
            final i = entry.key;
            final m = entry.value;
            if (i >= _messages.length) return true;
            return _messages[i].id != m.id || _messages[i].read != m.read;
          });

      if (hasAnyChanges || _isLoading) {
        setState(() {
          _messages
            ..clear()
            ..addAll(merged);
          _isLoading = false;
        });
      }

      if (!_didInitialAutoScroll && _messages.isNotEmpty) {
        _didInitialAutoScroll = true;
        _ensureInitialPositionAtBottom();
      } else if (shouldKeepBottom && (hasNewMessages || smoothAutoScroll)) {
        _scrollToBottomWhenReady(forceJump: false);
      }

      await apiService.markChatRead(
        otherUserId: isNutri ? widget.otherUserId : null,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMoreHistory || _nextBeforeId == null) {
      return;
    }

    final authService = context.read<AuthService>();
    final isNutri = _isNutriUser(authService);
    if (isNutri && widget.otherUserId == null) {
      return;
    }

    final previousMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final previousOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final apiService = context.read<ApiService>();
      final page = await apiService.getChatMessagesPage(
        otherUserId: isNutri ? widget.otherUserId : null,
        limit: _chatPageSize,
        beforeId: _nextBeforeId,
      );
      if (!mounted) return;

      if (page.items.isNotEmpty) {
        final existingIds = _messages.map((m) => m.id).toSet();
        final olderUnique =
            page.items.where((m) => !existingIds.contains(m.id)).toList();

        setState(() {
          _messages.insertAll(0, olderUnique);
          _hasMoreHistory = page.hasMore;
          _nextBeforeId = page.nextBeforeId;
          _isLoadingMore = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final newMaxExtent = _scrollController.position.maxScrollExtent;
          final delta = newMaxExtent - previousMaxExtent;
          _scrollController.jumpTo(previousOffset + delta);
        });
      } else {
        setState(() {
          _hasMoreHistory = false;
          _nextBeforeId = page.nextBeforeId;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _scrollToBottom({bool forceJump = false}) async {
    if (!_scrollController.hasClients) return;
    await Future.delayed(const Duration(milliseconds: 120));
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (forceJump) {
      _scrollController.jumpTo(maxExtent);
      return;
    }
    _scrollController.animateTo(
      maxExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToBottomWhenReady({bool forceJump = false, int retries = 8}) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_scrollController.hasClients) {
        _scrollToBottom(forceJump: forceJump);
        return;
      }

      if (retries <= 0) {
        return;
      }

      Future.delayed(const Duration(milliseconds: 90), () {
        _scrollToBottomWhenReady(
          forceJump: forceJump,
          retries: retries - 1,
        );
      });
    });
  }

  void _ensureInitialPositionAtBottom() {
    // Reintentos escalonados para cubrir el primer layout y ajustes tardios de altura.
    _scrollToBottomWhenReady(forceJump: true, retries: 14);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) {
        _scrollToBottomWhenReady(forceJump: true, retries: 10);
      }
    });
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) {
        _scrollToBottomWhenReady(forceJump: true, retries: 8);
      }
    });
  }

  bool _isNearBottom({double threshold = 120}) {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return (position.maxScrollExtent - position.pixels) <= threshold;
  }

  void _handleScrollForHistoryPagination() {
    if (!_scrollController.hasClients || _isLoading || _isLoadingMore) {
      return;
    }
    if (_scrollController.position.pixels <= 120) {
      _loadOlderMessages();
    }
  }

  String _formatDaySeparatorLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Hoy';
    if (target == yesterday) return 'Ayer';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _buildDaySeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDaySeparatorLabel(date),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMessageListWithDaySeparators(int myId) {
    final widgets = <Widget>[];
    DateTime? lastDay;
    final visibleMessages = _searchText.isEmpty
        ? _messages
        : _messages.where((message) {
            final body = (message.body ?? '').toLowerCase();
            return body.contains(_searchText);
          }).toList();

    if (_isLoadingMore) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.only(top: 6, bottom: 10),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    for (final message in visibleMessages) {
      final messageDay = DateTime(message.createdAt.year,
          message.createdAt.month, message.createdAt.day);
      if (lastDay == null || messageDay != lastDay) {
        widgets.add(_buildDaySeparator(message.createdAt));
        lastDay = messageDay;
      }
      widgets.add(_buildMessageBubble(message, myId));
    }

    if (visibleMessages.isEmpty && _searchText.isNotEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('No hay mensajes que coincidan con la búsqueda.'),
          ),
        ),
      );
    }

    return widgets;
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    // Redimensionar la imagen si es necesario
    try {
      final image = img.decodeImage(bytes);
      if (image != null) {
        img.Image? resizedImage = image;

        // Redimensionar si excede los límites
        if (image.width > _maxImageWidth || image.height > _maxImageHeight) {
          // Calcular el factor de escala manteniendo la relación de aspecto
          final widthScale = _maxImageWidth / image.width;
          final heightScale = _maxImageHeight / image.height;
          final scale = widthScale < heightScale ? widthScale : heightScale;

          final newWidth = (image.width * scale).round().clamp(1, image.width);
          final newHeight =
              (image.height * scale).round().clamp(1, image.height);

          resizedImage = img.copyResize(
            image,
            width: newWidth,
            height: newHeight,
            interpolation: img.Interpolation.linear,
          );
        }

        // Codificar la imagen redimensionada
        final requestedMime = _guessMime(picked.path);
        final bool encodeAsPng = requestedMime == 'image/png';
        final List<int> imageData = encodeAsPng
            ? img.encodePng(resizedImage)
            : img.encodeJpg(resizedImage, quality: 85);
        final encodedMime = encodeAsPng ? 'image/png' : 'image/jpeg';

        if (!mounted) return;

        setState(() {
          _selectedImageBytes = Uint8List.fromList(imageData);
          _selectedImageMime = encodedMime;
        });
      }
    } catch (e) {
      // Si falla el resize, usar la imagen original
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageMime = _guessMime(picked.path);
      });
    }
  }

  String _guessMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// Obtiene una imagen decodificada desde el caché o la decodifica si no existe
  Uint8List? _getDecodedImage(String? base64Image) {
    if (base64Image == null || base64Image.isEmpty) return null;

    // Verificar si ya está en caché
    if (_imageCache.containsKey(base64Image)) {
      return _imageCache[base64Image];
    }

    // Decodificar y guardar en caché
    try {
      final bytes = base64Decode(base64Image);
      _imageCache[base64Image] = bytes;
      return bytes;
    } catch (e) {
      return null;
    }
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
      _scrollToBottomWhenReady(forceJump: false);
      await _refreshLatestMessages(smoothAutoScroll: true);
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
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });
    await _refreshLatestMessages();
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
                if (hasImage) ...[
                  Builder(
                    builder: (context) {
                      final imageBytes = _getDecodedImage(message.imageBase64);
                      if (imageBytes == null) {
                        return const SizedBox(
                          width: 220,
                          height: 180,
                          child: Center(child: Icon(Icons.broken_image)),
                        );
                      }
                      return GestureDetector(
                        onTap: () => showImageViewerDialog(
                          context: context,
                          base64Image: message.imageBase64!,
                          title: 'Imagen',
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 220,
                              maxHeight: 260,
                            ),
                            child: Image.memory(
                              imageBytes,
                              fit: BoxFit.contain,
                              gaplessPlayback:
                                  true, // Evita parpadeos en actualizaciones
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (hasText) ...[
                  if (hasImage) const SizedBox(height: 8),
                  Text(message.body ?? ''),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm dd/MM/yyyy').format(message.createdAt),
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
    final l10n = AppLocalizations.of(context)!;
    final authService = context.watch<AuthService>();
    final myId = int.tryParse(authService.userCode ?? '') ?? 0;
    final isNutri = _isNutriUser(authService);
    final hasCustomTitle = widget.otherDisplayName != null &&
        widget.otherDisplayName!.trim().isNotEmpty;
    final title = isNutri
        ? (hasCustomTitle ? widget.otherDisplayName!.trim() : l10n.chatTitle)
        : l10n.navChatWithDietitian;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchVisible ? Icons.search_off_outlined : Icons.search,
            ),
            tooltip: _isSearchVisible ? l10n.chatHideSearch : l10n.chatSearch,
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isSearchVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.chatSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      children: _buildMessageListWithDaySeparators(myId),
                    ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                top: 6,
                bottom: 12,
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
                          focusNode: _messageFocusNode,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 1,
                          maxLines: 6,
                          scrollPadding: const EdgeInsets.only(bottom: 24),
                          onTap: () {
                            _scrollToBottom(forceJump: true);
                          },
                          onChanged: (_) {
                            _scrollToBottom();
                          },
                          decoration: InputDecoration(
                            hintText: l10n.chatMessageHint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
        ),
      ),
    );
  }
}
