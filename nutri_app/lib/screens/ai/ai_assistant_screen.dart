import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';

class AiAssistantScreen extends StatefulWidget {
  final String origin;
  final String title;
  final Map<String, String> placeholders;
  final String? initialPrompt;

  const AiAssistantScreen({
    super.key,
    required this.origin,
    required this.title,
    required this.placeholders,
    this.initialPrompt,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const String _allModulesLabel = 'Todos';
  final TextEditingController _promptCtrl = TextEditingController();
  final List<_AiChatMessage> _messages = <_AiChatMessage>[];

  bool _loadingConfig = true;
  bool _sending = false;
  bool _enabled = true;
  bool _configLoaded = false;
  bool _originExpanded = true;
  bool _initialPromptApplied = false;

  String _provider = '';
  String _model = '';
  String _systemPrompt = '';
  String? _selectedTemplateId;
  double? _temperature;
  int? _maxTokens;

  List<_AiPromptTemplate> _templates = <_AiPromptTemplate>[];

  @override
  void initState() {
    super.initState();
    if ((widget.initialPrompt ?? '').trim().isNotEmpty) {
      _promptCtrl.text = widget.initialPrompt!.trim();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configLoaded) return;
    _configLoaded = true;
    _loadConfig();
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _loadingConfig = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final config = await api.getAiAssistantConfig();
      final templates = <_AiPromptTemplate>[];
      final rawTemplates = config['templates'];
      if (rawTemplates is List) {
        for (final item in rawTemplates) {
          if (item is Map<String, dynamic>) {
            final template = _AiPromptTemplate.fromJson(item);
            if (template.active &&
                template.prompt.trim().isNotEmpty &&
                _templateMatchesCurrentOrigin(template)) {
              templates.add(template);
            }
          } else if (item is Map) {
            final template = _AiPromptTemplate.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (template.active &&
                template.prompt.trim().isNotEmpty &&
                _templateMatchesCurrentOrigin(template)) {
              templates.add(template);
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _enabled = config['enabled'] == true;
        _provider = (config['provider'] ?? '').toString();
        _model = (config['model'] ?? '').toString();
        _systemPrompt = (config['system_prompt'] ?? '').toString();
        _temperature = _toDouble(config['temperature']);
        _maxTokens = _toInt(config['max_tokens']);
        _templates = templates;
      });

      if (!_initialPromptApplied) {
        _applyConfiguredInitialPrompt(templates);
      }
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('No se pudo cargar el asistente IA: $e');
      }
      setState(() {
        _enabled = false;
        _templates = <_AiPromptTemplate>[];
      });
    } finally {
      if (mounted) {
        setState(() => _loadingConfig = false);
      }
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _resolvePlaceholders(String input) {
    var output = input;
    final replacements = _buildPlaceholderReplacements();

    replacements.forEach((key, value) {
      output = output.replaceAll(key, value.trim());
    });
    return output.trim();
  }

  Future<void> _sendPrompt() async {
    final rawPrompt = _promptCtrl.text.trim();
    if (rawPrompt.isEmpty || _sending) {
      return;
    }

    final resolvedPrompt = _resolvePlaceholders(rawPrompt);
    if (resolvedPrompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El prompt no contiene texto utilizable.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final history = _messages
          .map(
            (message) => <String, String>{
              'role': message.role,
              'content': _resolvePlaceholders(message.content),
            },
          )
          .toList();

      final response = await api.sendAiAssistantMessage(
        messages: history,
        prompt: resolvedPrompt,
        origin: widget.origin,
        systemPrompt: _systemPrompt,
        temperature: _temperature,
        maxTokens: _maxTokens,
      );

      final reply = (response['reply'] ?? '').toString().trim();
      if (reply.isEmpty) {
        throw Exception('La IA no devolvió contenido.');
      }

      if (!mounted) return;
      setState(() {
        _messages.add(_AiChatMessage(role: 'user', content: resolvedPrompt));
        _messages.add(_AiChatMessage(role: 'assistant', content: reply));
        _promptCtrl.clear();
        _originExpanded = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error usando el asistente IA: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _insertToken(String token) {
    final text = _promptCtrl.text;
    final selection = _promptCtrl.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, token);

    _promptCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Texto copiado al portapapeles')),
    );
  }

  void _applyTemplate(_AiPromptTemplate template) {
    final current = _promptCtrl.text.trim();
    final nextText = current.isEmpty
        ? template.prompt.trim()
        : '$current\n\n${template.prompt.trim()}';

    setState(() {
      _promptCtrl.text = nextText;
      _promptCtrl.selection = TextSelection.collapsed(
        offset: _promptCtrl.text.length,
      );
      _selectedTemplateId = null;
    });
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _originExpanded = true;
    });
  }

  void _applyConfiguredInitialPrompt(List<_AiPromptTemplate> templates) {
    final defaults = templates
        .where((template) => template.isDefault)
        .map((template) => template.prompt.trim())
        .where((prompt) => prompt.isNotEmpty)
        .toList(growable: false);

    final initialText = defaults.isNotEmpty
        ? defaults.join('\n\n')
        : (widget.initialPrompt ?? '').trim();

    if (initialText.isEmpty) {
      _initialPromptApplied = true;
      return;
    }

    setState(() {
      _promptCtrl.text = initialText;
      _promptCtrl.selection =
          TextSelection.collapsed(offset: initialText.length);
      _initialPromptApplied = true;
    });
  }

  bool _templateMatchesCurrentOrigin(_AiPromptTemplate template) {
    final module = _resolveOriginModule(widget.origin);
    final templateModule = template.module.trim();
    return templateModule.isEmpty ||
        templateModule == _allModulesLabel ||
        templateModule == module;
  }

  String _resolveOriginModule(String origin) {
    final normalized = _normalizePlaceholderKey(origin).replaceAll('_', ' ');
    if (normalized.contains('video') && normalized.contains('ejercicio')) {
      return 'Vídeos de ejercicios';
    }
    if (normalized.contains('ejercicio')) {
      return 'Ejercicios';
    }
    if (normalized.contains('alimento')) {
      return 'Alimentos';
    }
    if (normalized.contains('planes nutri') ||
        normalized.contains('plan nutri')) {
      return 'Planes nutri';
    }
    if (normalized.contains('planes fit') || normalized.contains('plan fit')) {
      return 'Planes fit';
    }
    if (normalized.contains('suplement')) {
      return 'Suplementos';
    }
    if (normalized.contains('aditivo')) {
      return 'Aditivos';
    }
    if (normalized.contains('sustituc')) {
      return 'Sustituciones saludables';
    }
    if (normalized.contains('chat')) {
      return 'Chat';
    }
    if (normalized.contains('revision')) {
      return 'Revisiones';
    }
    if (normalized.contains('entrevista nutri')) {
      return 'Entrevistas nutri';
    }
    if (normalized.contains('entrevista fit')) {
      return 'Entrevistas fit';
    }
    if (normalized.contains('charla')) {
      return 'Charlas';
    }
    return _allModulesLabel;
  }

  Widget _buildOriginCard(List<MapEntry<String, String>> availableTokens) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() => _originExpanded = !_originExpanded);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    _buildCompactTag(
                      'Origen: ${widget.origin}',
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                    if (availableTokens.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${availableTokens.length} campo${availableTokens.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      _originExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ],
                ),
              ),
            ),
            if (_originExpanded) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: availableTokens
                    .map(
                      (entry) => ActionChip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _insertToken(entry.key),
                      ),
                    )
                    .toList(),
              ),
              if (availableTokens.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Toca un campo para insertarlo en el prompt.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComposerCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_templates.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _selectedTemplateId,
                decoration: const InputDecoration(
                  labelText: 'Prompt personalizado',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Selecciona un prompt para añadirlo'),
                items: _templates
                    .map(
                      (template) => DropdownMenuItem<String>(
                        value: template.id,
                        child: Text(template.title),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _sending
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        final template = _templates.where(
                          (item) => item.id == value,
                        );
                        if (template.isEmpty) {
                          return;
                        }
                        _applyTemplate(template.first);
                      },
              ),
              const SizedBox(height: 8),
              Text(
                'El prompt seleccionado se añadirá al editor para que puedas revisarlo antes de enviarlo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _promptCtrl,
              minLines: 3,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                hintText: 'Escribe la instrucción o usa una plantilla.',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _sendPrompt,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _sending ? 'Consultando...' : 'Enviar a la IA',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRoleTag(String label, String content) {
    return GestureDetector(
      onLongPress: () => _copyText(content),
      child: _buildCompactTag(label),
    );
  }

  Widget _buildCompactTag(
    String label, {
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final bg =
        backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer;
    final fg = foregroundColor ?? Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          height: 1,
        ),
      ),
    );
  }

  Map<String, String> _buildPlaceholderReplacements() {
    final replacements = <String, String>{};

    widget.placeholders.forEach((rawKey, rawValue) {
      final key = rawKey.trim();
      final value = rawValue.trim();
      if (key.isEmpty || value.isEmpty) {
        return;
      }

      final normalizedKey = _normalizePlaceholderKey(key);
      replacements['[$key]'] = value;
      replacements['[${key.toLowerCase()}]'] = value;
      replacements['[$normalizedKey]'] = value;

      if (normalizedKey == 'titulo') {
        replacements['[título]'] = value;
      }
      if (normalizedKey == 'descripcion') {
        replacements['[descripción]'] = value;
      }
    });

    return replacements;
  }

  String _normalizePlaceholderKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  String _displayTokenForKey(String key) {
    final normalized = _normalizePlaceholderKey(key);
    switch (normalized) {
      case 'titulo':
        return '[título]';
      case 'descripcion':
        return '[descripción]';
      default:
        return '[${key.trim()}]';
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableTokens = widget.placeholders.entries
        .map(
          (entry) => MapEntry(
            _displayTokenForKey(entry.key),
            entry.value.trim(),
          ),
        )
        .where((entry) => entry.value.isNotEmpty)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(widget.title)),
            if (_provider.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildCompactTag(
                _provider,
                backgroundColor: const Color(0xFFF8D7E8),
                foregroundColor: const Color(0xFF8A245A),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Recargar configuración',
            onPressed: _loadingConfig ? null : _loadConfig,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Limpiar conversación',
            onPressed: _messages.isEmpty ? null : _clearConversation,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: _loadingConfig
          ? const Center(child: CircularProgressIndicator())
          : !_enabled
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'El asistente IA está deshabilitado en la configuración.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _buildOriginCard(availableTokens),
                    ),
                    Expanded(
                      child: _messages.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'La conversación se mantendrá aquí mientras esta ventana siga abierta.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                final isAssistant = message.role == 'assistant';
                                return Align(
                                  alignment: isAssistant
                                      ? Alignment.centerLeft
                                      : Alignment.centerRight,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 560,
                                    ),
                                    child: Card(
                                      color: isAssistant
                                          ? Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                          : Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildMessageRoleTag(
                                              isAssistant ? 'IA' : 'Tú',
                                              message.content,
                                            ),
                                            const SizedBox(height: 8),
                                            SelectableText(message.content),
                                            if (isAssistant) ...[
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  OutlinedButton.icon(
                                                    onPressed: () => _copyText(
                                                        message.content),
                                                    icon:
                                                        const Icon(Icons.copy),
                                                    label: const Text('Copiar'),
                                                  ),
                                                  FilledButton.icon(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                      context,
                                                    ).pop(message.content),
                                                    icon:
                                                        const Icon(Icons.check),
                                                    label: const Text(
                                                      'Usar este texto',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _buildComposerCard(),
                    ),
                  ],
                ),
    );
  }
}

class _AiPromptTemplate {
  final String id;
  final String title;
  final String prompt;
  final String module;
  final bool active;
  final bool isDefault;

  const _AiPromptTemplate({
    required this.id,
    required this.title,
    required this.prompt,
    required this.module,
    required this.active,
    required this.isDefault,
  });

  factory _AiPromptTemplate.fromJson(Map<String, dynamic> json) {
    final title =
        (json['title'] ?? json['titulo'] ?? 'Plantilla IA').toString();
    final prompt = (json['prompt'] ?? json['texto'] ?? '').toString();
    final id = (json['id'] ?? title).toString();
    final module =
        (json['module'] ?? json['modulo'] ?? 'Todos').toString().trim();
    final rawActive = json['active'] ?? json['activo'] ?? true;
    final active = rawActive is bool
        ? rawActive
        : <String>{'1', 'true', 's', 'si', 'sí', 'yes'}
            .contains(rawActive.toString().trim().toLowerCase());
    final rawDefault = json['default'] ?? json['defecto'] ?? false;
    final isDefault = rawDefault is bool
        ? rawDefault
        : <String>{'1', 'true', 's', 'si', 'sí', 'yes'}
            .contains(rawDefault.toString().trim().toLowerCase());

    return _AiPromptTemplate(
      id: id,
      title: title,
      prompt: prompt,
      module: module,
      active: active,
      isDefault: isDefault,
    );
  }
}

class _AiChatMessage {
  final String role;
  final String content;

  const _AiChatMessage({required this.role, required this.content});
}
