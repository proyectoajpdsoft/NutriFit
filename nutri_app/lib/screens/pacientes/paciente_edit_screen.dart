import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PacienteEditScreen extends StatefulWidget {
  final Paciente? paciente;

  const PacienteEditScreen({super.key, this.paciente});

  @override
  State<PacienteEditScreen> createState() => _PacienteEditScreenState();
}

class _PacienteEditScreenState extends State<PacienteEditScreen> {
  static const String _cardStateStorageKey =
      'paciente_edit_card_expanded_state';

  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final Map<String, GlobalKey> _fieldKeys = {};
  final Map<String, FocusNode> _fieldFocusNodes = {};
  final Map<String, bool> _cardExpanded = {
    'sexo': true,
    'medidas': true,
    'otros': false,
    'observacion': false,
    'estado': false,
  };

  bool _hasChanges = false;
  bool _loadingUsuarios = false;
  bool _cardStateReady = false;

  late TextEditingController _nombreController;
  late TextEditingController _dniController;
  late TextEditingController _edadController;
  late TextEditingController _alturaController;
  late TextEditingController _pesoController;
  late TextEditingController _telefonoController;
  late TextEditingController _email1Controller;
  late TextEditingController _email2Controller;
  late TextEditingController _observacionController;

  DateTime? _fechaNacimiento;
  String? _sexo;
  bool _online = false;
  bool _activo = true;
  int? _codigoUsuarioSeleccionado;
  List<Usuario> _usuariosList = const [];

  bool get _isEditing => widget.paciente != null;
  int? get _currentPacienteCodigo => widget.paciente?.codigo;

  List<Usuario> get _associatedUsers {
    final codigoPaciente = _currentPacienteCodigo;
    if (codigoPaciente == null || codigoPaciente <= 0) {
      return const [];
    }

    final users = _usuariosList
        .where((usuario) => usuario.codigoPaciente == codigoPaciente)
        .toList()
      ..sort((a, b) => _usuarioDisplayName(a)
          .toLowerCase()
          .compareTo(_usuarioDisplayName(b).toLowerCase()));
    return users;
  }

  List<Usuario> get _assignableUsers {
    final codigoPaciente = _currentPacienteCodigo;
    final users = _usuariosList.where((usuario) {
      final pacienteAsignado = usuario.codigoPaciente;
      final libre = pacienteAsignado == null || pacienteAsignado == 0;
      final mismoPaciente =
          codigoPaciente != null && pacienteAsignado == codigoPaciente;
      final seleccionado = usuario.codigo == _codigoUsuarioSeleccionado;
      return usuario.activo == 'S' && (libre || mismoPaciente || seleccionado);
    }).toList()
      ..sort((a, b) => _usuarioDisplayName(a)
          .toLowerCase()
          .compareTo(_usuarioDisplayName(b).toLowerCase()));
    return users;
  }

  Usuario? get _selectedUser {
    final codigo = _codigoUsuarioSeleccionado;
    if (codigo == null) return null;
    for (final usuario in _usuariosList) {
      if (usuario.codigo == codigo) {
        return usuario;
      }
    }
    return null;
  }

  bool get _hasPendingUserSelection {
    final selected = _selectedUser;
    if (selected == null) return false;
    return !_associatedUsers
        .any((usuario) => usuario.codigo == selected.codigo);
  }

  @override
  void initState() {
    super.initState();
    final paciente = widget.paciente;

    _nombreController = TextEditingController(text: paciente?.nombre ?? '');
    _dniController = TextEditingController(text: paciente?.dni ?? '');
    _edadController =
        TextEditingController(text: paciente?.edad?.toString() ?? '');
    _alturaController =
        TextEditingController(text: paciente?.altura?.toString() ?? '');
    _pesoController =
        TextEditingController(text: paciente?.peso?.toString() ?? '');
    _telefonoController = TextEditingController(text: paciente?.telefono ?? '');
    _email1Controller = TextEditingController(text: paciente?.email1 ?? '');
    _email2Controller = TextEditingController(text: paciente?.email2 ?? '');
    _observacionController =
        TextEditingController(text: paciente?.observacion ?? '');

    _fechaNacimiento = paciente?.fechaNacimiento;
    _sexo = paciente?.sexo;
    _online = paciente?.online == 'S';
    _activo = paciente?.activo == 'S';

    for (final controller in [
      _nombreController,
      _dniController,
      _edadController,
      _alturaController,
      _pesoController,
      _telefonoController,
      _email1Controller,
      _email2Controller,
      _observacionController,
    ]) {
      controller.addListener(_handleTextFieldChanged);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCardExpandedState();
      if (!_isEditing) {
        _loadDefaultValues();
      }
      await _loadUsuarios();
      if (!mounted) return;
      setState(() {
        _cardStateReady = true;
      });
    });
  }

  void _handleTextFieldChanged() {
    if (!mounted) return;
    setState(() {
      _hasChanges = true;
    });
  }

  void _loadDefaultValues() {
    final configService = context.read<ConfigService>();
    setState(() {
      _online = configService.defaultOnlinePaciente;
      _activo = configService.defaultActivoPaciente;
      if (configService.defaultSexoPaciente != null) {
        _sexo = configService.defaultSexoPaciente;
      }
    });
  }

  Future<void> _loadCardExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cardStateStorageKey);
    if (raw == null || raw.trim().isEmpty || !mounted) return;

    try {
      final savedState = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      setState(() {
        for (final entry in savedState.entries) {
          if (_cardExpanded.containsKey(entry.key) && entry.value is bool) {
            _cardExpanded[entry.key] = entry.value as bool;
          }
        }
      });
    } catch (_) {
      await prefs.remove(_cardStateStorageKey);
    }
  }

  Future<void> _saveCardExpandedState() async {
    if (!_cardStateReady) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cardStateStorageKey, jsonEncode(_cardExpanded));
  }

  Future<void> _setCardExpanded(String key, bool expanded) async {
    setState(() {
      _cardExpanded[key] = expanded;
    });
    await _saveCardExpandedState();
  }

  Future<void> _toggleCard(String key) async {
    await _setCardExpanded(key, !(_cardExpanded[key] ?? false));
  }

  Future<void> _loadUsuarios() async {
    if (!mounted) return;
    setState(() {
      _loadingUsuarios = true;
    });

    try {
      final usuarios = await _apiService.getUsuarios();
      final asociados = _currentPacienteCodigo == null
          ? const <Usuario>[]
          : usuarios
              .where(
                  (usuario) => usuario.codigoPaciente == _currentPacienteCodigo)
              .toList();

      if (!mounted) return;
      setState(() {
        _usuariosList = usuarios;
        _codigoUsuarioSeleccionado = asociados.isNotEmpty
            ? asociados.first.codigo
            : _codigoUsuarioSeleccionado;
        _loadingUsuarios = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingUsuarios = false;
      });
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges) return true;
    return showUnsavedChangesDialog(
      context,
      onSave: () => _saveForm(closeOnSuccess: false),
    );
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscardChanges() && mounted) {
      Navigator.of(context).pop();
    }
  }

  GlobalKey _getFieldKey(String key) {
    return _fieldKeys.putIfAbsent(key, GlobalKey.new);
  }

  FocusNode _getFieldFocusNode(String key) {
    return _fieldFocusNodes.putIfAbsent(key, FocusNode.new);
  }

  Future<void> _focusField(String sectionKey, String fieldKey) async {
    if (!(_cardExpanded[sectionKey] ?? false)) {
      await _setCardExpanded(sectionKey, true);
    }
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final fieldContext = _getFieldKey(fieldKey).currentContext;
      if (fieldContext != null) {
        await Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: 0.18,
        );
      }
      _fieldFocusNodes[fieldKey]?.requestFocus();
    });
  }

  Future<void> _openDateField() async {
    await _focusField('medidas', 'fecha_nacimiento');
    if (!mounted) return;
    await _selectDate(context);
  }

  @override
  void dispose() {
    for (final controller in [
      _nombreController,
      _dniController,
      _edadController,
      _alturaController,
      _pesoController,
      _telefonoController,
      _email1Controller,
      _email2Controller,
      _observacionController,
    ]) {
      controller.removeListener(_handleTextFieldChanged);
      controller.dispose();
    }
    for (final focusNode in _fieldFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _fechaNacimiento) {
      setState(() {
        _fechaNacimiento = picked;
        _hasChanges = true;
      });
    }
  }

  void _submitForm() {
    _saveForm(closeOnSuccess: true);
  }

  Future<bool> _saveForm({required bool closeOnSuccess}) async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    _formKey.currentState!.save();

    final pacienteData = Paciente(
      codigo: widget.paciente?.codigo ?? 0,
      nombre: _nombreController.text,
      dni: _dniController.text,
      fechaNacimiento: _fechaNacimiento,
      sexo: _sexo,
      edad: int.tryParse(_edadController.text),
      altura: int.tryParse(_alturaController.text),
      peso: double.tryParse(_pesoController.text),
      telefono: _telefonoController.text,
      email1: _email1Controller.text,
      email2: _email2Controller.text,
      activo: _activo ? 'S' : 'N',
      online: _online ? 'S' : 'N',
      observacion: _observacionController.text,
      calle: widget.paciente?.calle,
      codigoPostal: widget.paciente?.codigoPostal,
      provincia: widget.paciente?.provincia,
      pais: widget.paciente?.pais,
    );

    try {
      final success = _isEditing
          ? await _apiService.updatePacienteWithUser(
              pacienteData,
              codigoUsuario: _codigoUsuarioSeleccionado,
            )
          : await _apiService.createPacienteWithUser(
              pacienteData,
              codigoUsuario: _codigoUsuarioSeleccionado,
            );

      if (!success) return false;

      _hasChanges = false;
      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Paciente modificado correctamente'
                : 'Paciente añadido correctamente',
          ),
          backgroundColor: Colors.green,
        ),
      );
      if (closeOnSuccess) {
        Navigator.of(context).pop(true);
      }
      return true;
    } catch (e) {
      final configService = context.read<ConfigService>();

      if (configService.appMode == AppMode.debug) {
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Error Detallado de la API'),
            content: SingleChildScrollView(child: Text(e.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar el paciente'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  String _usuarioDisplayName(Usuario usuario) {
    final nombre = (usuario.nombre ?? '').trim();
    if (nombre.isNotEmpty) return nombre;
    final nick = usuario.nick.trim();
    return nick.isNotEmpty ? nick : 'Usuario';
  }

  String _usuarioSecondaryLine(Usuario usuario) {
    final email = (usuario.email ?? '').trim();
    if (email.isNotEmpty) return email;
    return '@${usuario.nick}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  String? _shortSexoLabel() {
    if (_sexo == 'Mujer') return 'M';
    if (_sexo == 'Hombre') return 'H';
    return null;
  }

  Widget _buildSectionCard({
    required String sectionKey,
    required String title,
    Widget? summary,
    required Widget child,
  }) {
    final isExpanded = _cardExpanded[sectionKey] ?? false;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _toggleCard(sectionKey),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (summary != null) ...[
                          const SizedBox(height: 10),
                          summary,
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: isExpanded
                  ? Column(
                      children: [
                        Divider(height: 1, color: Colors.grey.shade200),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: child,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final bg = backgroundColor ?? const Color(0xFFF3F5F7);
    final fg = foregroundColor ?? const Color(0xFF1D2939);
    return ActionChip(
      avatar: Icon(icon, size: 16, color: fg),
      label: Text(label, style: TextStyle(color: fg)),
      backgroundColor: bg,
      side: BorderSide(color: bg),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: onTap,
    );
  }

  Widget _buildStatusTag({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = selected ? const Color(0xFF0F766E) : const Color(0xFF667085);
    final background =
        selected ? const Color(0xFFE6FFFA) : const Color(0xFFF2F4F7);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionSpacing() => const SizedBox(height: 12);

  Widget _buildUsuarioBadge(Usuario usuario, {bool pending = false}) {
    final primary = pending ? const Color(0xFF9A3412) : const Color(0xFF0F766E);
    final background =
        pending ? const Color(0xFFFFEDD5) : const Color(0xFFE6FFFA);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withAlpha(64)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            pending ? 'Se asociará' : 'Asociado',
            style: TextStyle(
              color: primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _usuarioDisplayName(usuario),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            _usuarioSecondaryLine(usuario),
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUsuariosSection() {
    final assignableUsers = _assignableUsers;
    final selectedUser = _selectedUser;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Usuarios asociados',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (_loadingUsuarios)
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else ...[
            if (_associatedUsers.isEmpty)
              Text(
                'No tiene usuarios asociados',
                style: TextStyle(color: Colors.grey.shade700),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _associatedUsers
                    .map((usuario) => _buildUsuarioBadge(usuario))
                    .toList(),
              ),
            if (_hasPendingUserSelection && selectedUser != null) ...[
              const SizedBox(height: 8),
              _buildUsuarioBadge(selectedUser, pending: true),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: assignableUsers.any(
                (usuario) => usuario.codigo == _codigoUsuarioSeleccionado,
              )
                  ? _codigoUsuarioSeleccionado
                  : null,
              decoration: InputDecoration(
                labelText: _isEditing
                    ? 'Usuario asociado'
                    : 'Usuario a asociar al guardar',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              hint: const Text('Seleccionar usuario'),
              items: assignableUsers
                  .map(
                    (usuario) => DropdownMenuItem<int>(
                      value: usuario.codigo,
                      child: Text(_usuarioDisplayName(usuario)),
                    ),
                  )
                  .toList(),
              onChanged: assignableUsers.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _codigoUsuarioSeleccionado = value;
                        _hasChanges = true;
                      });
                    },
            ),
            if (assignableUsers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No hay usuarios activos libres para asociar.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSexoCard() {
    final shortLabel = _shortSexoLabel();
    return _buildSectionCard(
      sectionKey: 'sexo',
      title: 'Sexo',
      summary: Row(
        children: [
          _buildStatusTag(
            label: shortLabel ?? '-',
            selected: shortLabel != null,
            onTap: () => _toggleCard('sexo'),
          ),
        ],
      ),
      child: FormField<String>(
        validator: (_) => _sexo == null ? 'Selecciona el sexo' : null,
        builder: (state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Hombre'),
                    selected: _sexo == 'Hombre',
                    onSelected: (selected) {
                      setState(() {
                        _sexo = selected ? 'Hombre' : null;
                        _hasChanges = true;
                      });
                      state.didChange(_sexo);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Mujer'),
                    selected: _sexo == 'Mujer',
                    onSelected: (selected) {
                      setState(() {
                        _sexo = selected ? 'Mujer' : null;
                        _hasChanges = true;
                      });
                      state.didChange(_sexo);
                    },
                  ),
                ],
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.errorText ?? '',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMedidasCard() {
    final summaryItems = <Widget>[];
    if (_edadController.text.trim().isNotEmpty) {
      summaryItems.add(
        _buildSummaryAction(
          icon: Icons.cake_outlined,
          label: '${_edadController.text.trim()} a',
          onTap: () => _focusField('medidas', 'edad'),
        ),
      );
    }
    if (_alturaController.text.trim().isNotEmpty) {
      summaryItems.add(
        _buildSummaryAction(
          icon: Icons.height,
          label: '${_alturaController.text.trim()} cm',
          onTap: () => _focusField('medidas', 'altura'),
        ),
      );
    }
    if (_pesoController.text.trim().isNotEmpty) {
      summaryItems.add(
        _buildSummaryAction(
          icon: Icons.monitor_weight_outlined,
          label: '${_pesoController.text.trim()} kg',
          onTap: () => _focusField('medidas', 'peso'),
        ),
      );
    }
    summaryItems.add(
      _buildSummaryAction(
        icon: Icons.calendar_today_outlined,
        label: _fechaNacimiento == null
            ? 'Sin fecha'
            : _formatDate(_fechaNacimiento),
        onTap: _openDateField,
      ),
    );

    return _buildSectionCard(
      sectionKey: 'medidas',
      title: 'Edad, altura, peso y fecha',
      summary: Wrap(spacing: 8, runSpacing: 8, children: summaryItems),
      child: Column(
        children: [
          TextFormField(
            key: _getFieldKey('edad'),
            focusNode: _getFieldFocusNode('edad'),
            controller: _edadController,
            decoration: const InputDecoration(labelText: 'Edad'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final edad = int.tryParse(value);
                if (edad == null || edad <= 0 || edad >= 110) {
                  return 'Edad no válida (1-109)';
                }
              }
              return null;
            },
          ),
          _buildSectionSpacing(),
          TextFormField(
            key: _getFieldKey('altura'),
            focusNode: _getFieldFocusNode('altura'),
            controller: _alturaController,
            decoration: const InputDecoration(labelText: 'Altura (cm)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
            ],
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final altura = double.tryParse(value);
                if (altura == null || altura <= 50 || altura >= 230) {
                  return 'Altura no válida (50-230)';
                }
              }
              return null;
            },
          ),
          _buildSectionSpacing(),
          TextFormField(
            key: _getFieldKey('peso'),
            focusNode: _getFieldFocusNode('peso'),
            controller: _pesoController,
            decoration: const InputDecoration(labelText: 'Peso (kg)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final peso = double.tryParse(value);
                if (peso == null || peso <= 2 || peso >= 290) {
                  return 'Peso no válido (2-290)';
                }
              }
              return null;
            },
          ),
          _buildSectionSpacing(),
          ListTile(
            key: _getFieldKey('fecha_nacimiento'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Fecha de nacimiento: ${_fechaNacimiento == null ? 'No seleccionada' : _formatDate(_fechaNacimiento)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(context),
          ),
        ],
      ),
    );
  }

  Widget _buildOtrosDatosCard() {
    final summaryItems = <Widget>[];
    if (_telefonoController.text.trim().isNotEmpty) {
      summaryItems.add(
        _buildSummaryAction(
          icon: Icons.phone_outlined,
          label: _telefonoController.text.trim(),
          onTap: () => _focusField('otros', 'telefono'),
        ),
      );
    }
    if (_email1Controller.text.trim().isNotEmpty) {
      summaryItems.add(
        _buildSummaryAction(
          icon: Icons.mail_outline,
          label: _email1Controller.text.trim(),
          onTap: () => _focusField('otros', 'email1'),
        ),
      );
    }
    if (_dniController.text.trim().isNotEmpty) {
      summaryItems.add(
        _buildSummaryAction(
          icon: Icons.badge_outlined,
          label: _dniController.text.trim(),
          onTap: () => _focusField('otros', 'dni'),
        ),
      );
    }

    return _buildSectionCard(
      sectionKey: 'otros',
      title: 'Otros datos',
      summary: summaryItems.isEmpty
          ? Text(
              'Teléfono, emails y DNI',
              style: TextStyle(color: Colors.grey.shade700),
            )
          : Wrap(spacing: 8, runSpacing: 8, children: summaryItems),
      child: Column(
        children: [
          TextFormField(
            key: _getFieldKey('telefono'),
            focusNode: _getFieldFocusNode('telefono'),
            controller: _telefonoController,
            decoration: const InputDecoration(labelText: 'Teléfono'),
            keyboardType: TextInputType.phone,
          ),
          _buildSectionSpacing(),
          TextFormField(
            key: _getFieldKey('email1'),
            focusNode: _getFieldFocusNode('email1'),
            controller: _email1Controller,
            decoration: const InputDecoration(labelText: 'Email 1'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null &&
                  value.isNotEmpty &&
                  !RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                return 'Introduce un email válido';
              }
              return null;
            },
          ),
          _buildSectionSpacing(),
          TextFormField(
            key: _getFieldKey('email2'),
            focusNode: _getFieldFocusNode('email2'),
            controller: _email2Controller,
            decoration: const InputDecoration(labelText: 'Email 2'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null &&
                  value.isNotEmpty &&
                  !RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                return 'Introduce un email válido';
              }
              return null;
            },
          ),
          _buildSectionSpacing(),
          TextFormField(
            key: _getFieldKey('dni'),
            focusNode: _getFieldFocusNode('dni'),
            controller: _dniController,
            decoration: const InputDecoration(labelText: 'DNI'),
          ),
        ],
      ),
    );
  }

  Widget _buildObservacionCard() {
    final textLength = _observacionController.text.trim().length;
    final accentColor =
        textLength > 0 ? const Color(0xFF15803D) : const Color(0xFF98A2B3);
    final backgroundColor =
        textLength > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFF2F4F7);

    return _buildSectionCard(
      sectionKey: 'observacion',
      title: 'Observación',
      summary: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              border: Border.all(color: accentColor.withAlpha(72)),
            ),
            child: Text(
              '$textLength',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      child: TextFormField(
        key: _getFieldKey('observacion'),
        focusNode: _getFieldFocusNode('observacion'),
        controller: _observacionController,
        decoration: const InputDecoration(labelText: 'Observación'),
        maxLines: 4,
      ),
    );
  }

  Widget _buildEstadoCard() {
    return _buildSectionCard(
      sectionKey: 'estado',
      title: 'Estado',
      summary: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildStatusTag(
            label: 'O',
            selected: _online,
            onTap: () {
              setState(() {
                _online = !_online;
                _hasChanges = true;
              });
            },
          ),
          _buildStatusTag(
            label: 'A',
            selected: _activo,
            onTap: () {
              setState(() {
                _activo = !_activo;
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatusTag(
              label: 'Online',
              selected: _online,
              onTap: () {
                setState(() {
                  _online = !_online;
                  _hasChanges = true;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatusTag(
              label: 'Activo',
              selected: _activo,
              onTap: () {
                setState(() {
                  _activo = !_activo;
                  _hasChanges = true;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(_isEditing ? 'Editar Paciente' : 'Nuevo Paciente'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _submitForm,
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, introduce un nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildUsuariosSection(),
                  _buildSexoCard(),
                  _buildMedidasCard(),
                  _buildOtrosDatosCard(),
                  _buildObservacionCard(),
                  _buildEstadoCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
