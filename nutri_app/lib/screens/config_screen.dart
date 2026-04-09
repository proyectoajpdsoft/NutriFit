import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/services/ads_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/menu_visibility_premium_service.dart';
import 'package:nutri_app/services/nutri_push_settings_service.dart';
import 'package:nutri_app/services/nutri_plan_settings_service.dart';
import 'package:nutri_app/services/privacy_policy_service.dart';
import 'package:nutri_app/models/session.dart';
import 'package:nutri_app/screens/paciente_profile_edit_screen.dart';
import 'package:nutri_app/screens/parametros/parametro_edit_screen.dart'
    as parametro;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutri_app/widgets/delete_account_confirmation_helper.dart';

class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = context.watch<AuthService>();
    final isNutritionistOrAdmin =
        authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';

    final tabs = isNutritionistOrAdmin
        ? <Widget>[
            Tab(text: l10n.configTabParameters),
            Tab(text: l10n.configTabPremium),
            const Tab(text: 'IA'),
            const Tab(text: 'Publicidad'),
            Tab(text: l10n.configTabAppMenu),
            Tab(text: l10n.configTabGeneral),
            Tab(text: l10n.configTabSecurity),
            Tab(text: l10n.configTabDefaults),
            Tab(text: l10n.configTabPrivacy),
          ]
        : <Widget>[
            Tab(text: l10n.configTabParameters),
            Tab(text: l10n.configTabPremium),
            const Tab(text: 'Publicidad'),
            Tab(text: l10n.configTabAppMenu),
            Tab(text: l10n.configTabGeneral),
            Tab(text: l10n.configTabSecurity),
            Tab(text: l10n.configTabDefaults),
            Tab(text: l10n.configTabPrivacy),
          ];

    final views = isNutritionistOrAdmin
        ? const <Widget>[
            _ParametrosTab(),
            _PremiumPaymentsTab(),
            _AiSettingsTab(),
            _AdsSettingsTab(),
            _MenuVisibilityPremiumTab(),
            _GeneralTab(),
            _SecurityTab(),
            _DefectoTab(),
            PrivacyCenterTab(),
          ]
        : const <Widget>[
            _ParametrosTab(),
            _PremiumPaymentsTab(),
            _AdsSettingsTab(),
            _MenuVisibilityPremiumTab(),
            _GeneralTab(),
            _SecurityTab(),
            _DefectoTab(),
            PrivacyCenterTab(),
          ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(l10n.settingsAndPrivacyTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Scrollbar(
              thumbVisibility: true,
              child: TabBar(isScrollable: true, tabs: tabs),
            ),
          ),
        ),
        body: TabBarView(children: views),
      ),
    );
  }
}

class PrivacyCenterTab extends StatefulWidget {
  const PrivacyCenterTab({super.key});

  @override
  State<PrivacyCenterTab> createState() => _PrivacyPolicyTabState();
}

class _PrivacyPolicyTabState extends State<PrivacyCenterTab> {
  Future<void> _openProfileSecurity() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PacienteProfileEditScreen()),
    );
  }

  Future<void> _deleteAllMyData() async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.privacyDeleteDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.privacyDeleteDialogIntro),
              const SizedBox(height: 10),
              Text(l10n.privacyDeleteDialogBody),
              const SizedBox(height: 10),
              Text(
                l10n.privacyDeleteDialogWarning,
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_forever),
              label: Text(l10n.privacyDeleteMyData),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final confirmedStep2 = await showTypedDeleteAccountConfirmation(context);
    if (!confirmedStep2 || !mounted) {
      return;
    }

    try {
      await context.read<ApiService>().deleteCurrentUserWithDetails();
      FocusManager.instance.primaryFocus?.unfocus();
      if (!mounted) return;

      await context.read<AuthService>().logout();
      if (!mounted) return;

      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('login', (_) => false);
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.privacyDeleteConnectionError),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage.isEmpty
                ? l10n.privacyDeleteAccountFailed
                : errorMessage,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required List<Widget> actions,
    Color? tint,
  }) {
    final accent = tint ?? Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  foregroundColor: accent,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(description),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PrivacyPolicyService.policyTitle(l10n),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.privacyLastUpdatedLabel(
                    PrivacyPolicyService.lastUpdated(l10n),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(l10n.privacyIntro),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => PrivacyPolicyService.printPolicyPdf(context),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(l10n.privacyPrintPdf),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...PrivacyPolicyService.sections(l10n).map(
          (section) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...section.blocks.expand((block) {
                    if (block is PrivacyPolicyParagraphBlock) {
                      return [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(block.text, textAlign: TextAlign.justify),
                        ),
                      ];
                    }

                    if (block is PrivacyPolicyBulletListBlock) {
                      return block.items.map(
                        (bullet) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• '),
                              Expanded(
                                child: Text(
                                  bullet,
                                  textAlign: TextAlign.justify,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (block is PrivacyPolicyStepListBlock) {
                      return block.items.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${entry.key + 1}. '),
                              Expanded(child: Text(entry.value)),
                            ],
                          ),
                        ),
                      );
                    }

                    return const <Widget>[];
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: Scrollbar(
              thumbVisibility: true,
              child: TabBar(
                tabs: [
                  Tab(text: l10n.privacyCenterTab),
                  Tab(text: l10n.privacyPolicyTab),
                  Tab(text: l10n.privacySessionsTab),
                ],
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final privacyTabController = DefaultTabController.of(context);

                return TabBarView(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        _buildActionCard(
                          context: context,
                          icon: Icons.policy_outlined,
                          title: l10n.privacyActionPolicyTitle,
                          description: l10n.privacyActionPolicyDescription,
                          actions: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  privacyTabController.animateTo(1),
                              icon: const Icon(Icons.visibility_outlined),
                              label: Text(l10n.privacyViewPolicy),
                            ),
                            FilledButton.icon(
                              onPressed: () =>
                                  PrivacyPolicyService.printPolicyPdf(context),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: Text(l10n.privacyPdfShort),
                            ),
                          ],
                        ),
                        _buildActionCard(
                          context: context,
                          icon: Icons.manage_accounts_outlined,
                          title: l10n.privacyActionSecurityTitle,
                          description: l10n.privacyActionSecurityDescription,
                          actions: [
                            OutlinedButton.icon(
                              onPressed: _openProfileSecurity,
                              icon: const Icon(Icons.open_in_new),
                              label: Text(l10n.privacyOpenEditProfile),
                            ),
                          ],
                        ),
                        _buildActionCard(
                          context: context,
                          icon: Icons.history_toggle_off,
                          title: l10n.privacyActionSessionsTitle,
                          description: l10n.privacyActionSessionsDescription,
                          actions: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  privacyTabController.animateTo(2),
                              icon: const Icon(Icons.visibility_outlined),
                              label: Text(l10n.privacyViewSessions),
                            ),
                          ],
                        ),
                        _buildActionCard(
                          context: context,
                          icon: Icons.delete_forever,
                          title: l10n.privacyActionDeleteTitle,
                          description: l10n.privacyActionDeleteDescription,
                          tint: Colors.red,
                          actions: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _deleteAllMyData,
                              icon: const Icon(Icons.delete_forever),
                              label: Text(l10n.privacyDeleteMyData),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildPolicyContent(context),
                    const _SessionsSubTab(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPaymentsTab extends StatefulWidget {
  const _PremiumPaymentsTab();

  @override
  State<_PremiumPaymentsTab> createState() => _PremiumPaymentsTabState();
}

class _PremiumLanguageOption {
  const _PremiumLanguageOption({
    required this.code,
    required this.label,
    required this.flagBuilder,
  });

  final String code;
  final String label;
  final Widget Function() flagBuilder;
}

const List<_PremiumLanguageOption> _premiumLanguageOptions = [
  _PremiumLanguageOption(
    code: 'es',
    label: 'Español (base)',
    flagBuilder: _buildPremiumSpainFlag,
  ),
  _PremiumLanguageOption(
    code: 'en',
    label: 'English',
    flagBuilder: _buildPremiumUkFlag,
  ),
  _PremiumLanguageOption(
    code: 'it',
    label: 'Italiano',
    flagBuilder: _buildPremiumItalyFlag,
  ),
  _PremiumLanguageOption(
    code: 'de',
    label: 'Deutsch',
    flagBuilder: _buildPremiumGermanyFlag,
  ),
  _PremiumLanguageOption(
    code: 'fr',
    label: 'Francais',
    flagBuilder: _buildPremiumFranceFlag,
  ),
  _PremiumLanguageOption(
    code: 'pt',
    label: 'Portugues',
    flagBuilder: _buildPremiumPortugalFlag,
  ),
];

Widget _buildPremiumFlagFrame({required Widget child}) {
  return Container(
    width: 22,
    height: 16,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0x1F000000)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: child,
  );
}

Widget _buildPremiumHorizontalTricolor({
  required Color top,
  required Color middle,
  required Color bottom,
}) {
  return _buildPremiumFlagFrame(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            heightFactor: 1 / 3,
            widthFactor: 1,
            child: ColoredBox(color: top),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: FractionallySizedBox(
            heightFactor: 1 / 3,
            widthFactor: 1,
            child: ColoredBox(color: middle),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 1 / 3,
            widthFactor: 1,
            child: ColoredBox(color: bottom),
          ),
        ),
      ],
    ),
  );
}

Widget _buildPremiumVerticalTricolor({
  required Color left,
  required Color center,
  required Color right,
  int leftFlex = 1,
  int centerFlex = 1,
  int rightFlex = 1,
}) {
  final totalFlex = leftFlex + centerFlex + rightFlex;
  final leftWidth = leftFlex / totalFlex;
  final centerWidth = centerFlex / totalFlex;
  final rightStart = (leftFlex + centerFlex) / totalFlex;

  return _buildPremiumFlagFrame(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: leftWidth,
            heightFactor: 1,
            child: ColoredBox(color: left),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 22 * leftWidth),
            child: FractionallySizedBox(
              widthFactor: centerWidth,
              heightFactor: 1,
              alignment: Alignment.centerLeft,
              child: ColoredBox(color: center),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 1 - rightStart,
            heightFactor: 1,
            child: ColoredBox(color: right),
          ),
        ),
      ],
    ),
  );
}

Widget _buildPremiumSpainFlag() => _buildPremiumHorizontalTricolor(
  top: const Color(0xFFAA151B),
  middle: const Color(0xFFF1BF00),
  bottom: const Color(0xFFAA151B),
);

Widget _buildPremiumItalyFlag() => _buildPremiumVerticalTricolor(
  left: const Color(0xFF009246),
  center: Colors.white,
  right: const Color(0xFFCE2B37),
);

Widget _buildPremiumGermanyFlag() => _buildPremiumHorizontalTricolor(
  top: Colors.black,
  middle: const Color(0xFFDD0000),
  bottom: const Color(0xFFFFCE00),
);

Widget _buildPremiumFranceFlag() => _buildPremiumVerticalTricolor(
  left: const Color(0xFF0055A4),
  center: Colors.white,
  right: const Color(0xFFEF4135),
);

Widget _buildPremiumPortugalFlag() => _buildPremiumVerticalTricolor(
  left: const Color(0xFF006600),
  center: const Color(0xFF006600),
  right: const Color(0xFFFF0000),
  leftFlex: 2,
  centerFlex: 1,
  rightFlex: 2,
);

Widget _buildPremiumUkFlag() {
  return _buildPremiumFlagFrame(
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF012169)),
        Center(child: Container(width: 22, height: 4, color: Colors.white)),
        Center(child: Container(width: 4, height: 16, color: Colors.white)),
        Center(
          child: Container(
            width: 22,
            height: 2,
            color: const Color(0xFFC8102E),
          ),
        ),
        Center(
          child: Container(
            width: 2,
            height: 16,
            color: const Color(0xFFC8102E),
          ),
        ),
      ],
    ),
  );
}

class _PremiumPaymentsTabState extends State<_PremiumPaymentsTab> {
  static const String _category = 'Premium';
  static const String _type = 'Pago';
  static final RegExp _premiumTranslationTagPattern = RegExp(
    r'^\[\[([^\[\]\n]+)\]\]\s*$',
    multiLine: true,
  );

  late final List<_PremiumPaymentFieldSpec> _fields;
  late final Map<String, TextEditingController> _controllers;
  final Map<String, Map<String, dynamic>?> _existingParams = {};
  bool _loading = false;
  bool _saving = false;
  bool _buildingAiPrompt = false;
  bool _pastingAiTranslation = false;
  String? _loadErrorMessage;
  String? _loadedLanguageCode;
  String _selectedLanguageCode = 'es';

  bool get _isNutri {
    final authService = context.read<AuthService>();
    return authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
  }

  @override
  void initState() {
    super.initState();
    _fields = _buildFieldSpecs();
    _controllers = {
      for (final field in _fields) field.name: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<_PremiumPaymentFieldSpec> _buildFieldSpecs() {
    return const [
      _PremiumPaymentFieldSpec(
        name: 'premium_titulo',
        section: 'General',
        label: 'Título de la pantalla Premium',
        description: 'Título principal visible en la pantalla de alta Premium.',
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_descripcion',
        section: 'General',
        label: 'Descripción principal',
        description:
            'Texto introductorio principal para explicar el servicio Premium.',
        maxLines: 3,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_ventajas',
        section: 'General',
        label: 'Ventajas Premium',
        description: 'Una ventaja por línea o separadas por |.',
        maxLines: 4,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_metodos_pago',
        section: 'General',
        label: 'Resumen de métodos de pago',
        description:
            'Mensajes generales sobre formas de pago. Una línea por mensaje o separadas por |.',
        maxLines: 4,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_pago_descripcion',
        section: 'General',
        label: 'Descripción del bloque de pago',
        description: 'Texto que introduce la zona de pago y contratación.',
        maxLines: 3,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_precio_1m',
        section: 'General',
        label: 'Precio 1 mes',
        description: 'Ejemplo: 9,99 EUR.',
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_precio_3m',
        section: 'General',
        label: 'Precio 3 meses',
        description: 'Ejemplo: 24,99 EUR.',
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_precio_6m',
        section: 'General',
        label: 'Precio 6 meses',
        description: 'Ejemplo: 44,99 EUR.',
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_precio_12m',
        section: 'General',
        label: 'Precio 12 meses',
        description: 'Ejemplo: 79,99 EUR.',
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_precio_texto_1m',
        section: 'General',
        label: 'Texto precio 1 mes',
        description:
            'Ejemplo: Precio: 3,00 EUR (período contratado de un mes).',
        maxLines: 2,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_precio_texto_3m',
        section: 'General',
        label: 'Texto precio 3 meses',
        description:
            'Ejemplo: Precio: 12,00 EUR (período contratado de 3 meses, con descuento del 10%).',
        maxLines: 2,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_precio_texto_6m',
        section: 'General',
        label: 'Texto precio 6 meses',
        description: 'Texto completo que verá el usuario al elegir 6 meses.',
        maxLines: 2,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_precio_texto_12m',
        section: 'General',
        label: 'Texto precio 12 meses',
        description: 'Texto completo que verá el usuario al elegir 12 meses.',
        maxLines: 2,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_concepto_plantilla',
        section: 'General',
        label: 'Plantilla concepto pago',
        description:
            'Variables: {periodo}, {nick}, {codigo}, {email}, {fecha}, {usuario}.',
        maxLines: 2,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_dias_aviso_vencimiento',
        section: 'General',
        label: 'Días de aviso de vencimiento',
        description:
            'Número de días previos para avisar de próxima caducidad (ej: 7).',
        keyboardType: TextInputType.number,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_mensaje_activacion_pago',
        section: 'General',
        label: 'Mensaje de activación tras pago',
        description:
            'Mensaje indicando que el perfil se activará en 24/48 horas una vez recibido el pago.',
        maxLines: 3,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_notificacion_pago_email_plantilla',
        section: 'General',
        label: 'Plantilla email notificación pago Premium',
        description:
            'Variables: {codigo_usuario}, {email_usuario}, {nick_usuario}, {periodo_contratado}, {metodo_pago_elegido}, {fecha_hora_pulsacion_boton}, {precio_mostrado}, {concepto_pago}, {nombre_usuario}.',
        maxLines: 6,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_notificacion_pago_email_asunto',
        section: 'General',
        label: 'Asunto email notificación pago Premium',
        description:
            'Variables: {codigo_usuario}, {email_usuario}, {nick_usuario}, {periodo_contratado}, {metodo_pago_elegido}, {fecha_hora_pulsacion_boton}, {precio_mostrado}, {concepto_pago}, {nombre_usuario}.',
        maxLines: 2,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_paypal_texto',
        section: 'PayPal',
        label: 'Texto del método PayPal',
        description: 'Ejemplo: Pagar por PayPal.',
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_paypal_activo',
        section: 'PayPal',
        label: 'PayPal activo',
        description:
            'Indica S para mostrar PayPal al usuario o N para ocultarlo.',
        isToggle: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_paypal_url',
        section: 'PayPal',
        label: 'URL de PayPal',
        description: 'Enlace directo a la pasarela o botón de pago.',
        keyboardType: TextInputType.url,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_paypal_email',
        section: 'PayPal',
        label: 'Dirección PayPal',
        description: 'Email o dirección de cuenta PayPal que recibirá el pago.',
        keyboardType: TextInputType.emailAddress,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_paypal_concepto',
        section: 'PayPal',
        label: 'Concepto PayPal',
        description: 'Concepto sugerido para identificar el pago.',
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_pasos_pago_paypal',
        section: 'PayPal',
        label: 'Pasos de pago PayPal (segunda pantalla)',
        description:
            'Admite {nick_usuario}, {email_usuario}, {url_paypal}, {email_paypal}, {boton_abrir_url_paypal}, {boton_copiar_concepto}. Separador por saltos de línea o |.',
        maxLines: 6,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_bizum_texto',
        section: 'Bizum',
        label: 'Texto del método Bizum',
        description: 'Ejemplo: Pagar por Bizum.',
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_bizum_activo',
        section: 'Bizum',
        label: 'Bizum activo',
        description:
            'Indica S para mostrar Bizum al usuario o N para ocultarlo.',
        isToggle: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_bizum_telefono',
        section: 'Bizum',
        label: 'Teléfono Bizum',
        description: 'Número de teléfono asociado a Bizum.',
        keyboardType: TextInputType.phone,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_bizum_titular',
        section: 'Bizum',
        label: 'Titular Bizum',
        description: 'Nombre del titular del número de Bizum.',
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_bizum_concepto',
        section: 'Bizum',
        label: 'Concepto Bizum',
        description: 'Concepto sugerido para el pago por Bizum.',
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_pasos_pago_bizum',
        section: 'Bizum',
        label: 'Pasos de pago Bizum (segunda pantalla)',
        description:
            'Admite {nick_usuario}, {email_usuario}, {telefono_nutricionista}, {boton_copiar_telefono}, {boton_copiar_concepto}. Separador por saltos de línea o |.',
        maxLines: 6,
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_transferencia_texto',
        section: 'Transferencia',
        label: 'Texto del método transferencia',
        description: 'Ejemplo: Pagar por transferencia.',
        isLocalized: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_transferencia_activo',
        section: 'Transferencia',
        label: 'Transferencia activa',
        description:
            'Indica S para mostrar transferencia al usuario o N para ocultarla.',
        isToggle: true,
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_transferencia_titular',
        section: 'Transferencia',
        label: 'Titular de la cuenta',
        description: 'Nombre del titular de la cuenta bancaria.',
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_transferencia_iban',
        section: 'Transferencia',
        label: 'IBAN',
        description: 'IBAN completo para recibir la transferencia.',
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_transferencia_banco',
        section: 'Transferencia',
        label: 'Banco',
        description: 'Entidad bancaria de la cuenta.',
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_transferencia_concepto',
        section: 'Transferencia',
        label: 'Concepto transferencia',
        description: 'Concepto sugerido para identificar la transferencia.',
      ),
      _PremiumPaymentFieldSpec(
        name: 'premium_pasos_pago_transferencia',
        section: 'Transferencia',
        label: 'Pasos de pago transferencia (segunda pantalla)',
        description:
            'Admite {nick_usuario}, {email_usuario}, {boton_copiar_concepto}. Separador por saltos de línea o |.',
        maxLines: 6,
        isLocalized: true,
      ),
    ];
  }

  String _parameterNameFor(
    _PremiumPaymentFieldSpec field, {
    String? languageCode,
  }) {
    final code = (languageCode ?? _selectedLanguageCode).trim().toLowerCase();
    if (!field.isLocalized || code.isEmpty || code == 'es') {
      return field.name;
    }
    return '${field.name}_$code';
  }

  String _helperTextFor(_PremiumPaymentFieldSpec field) {
    final paramName = _parameterNameFor(field);

    if (!field.isLocalized) {
      return '${field.description}\nParámetro: ${field.name}\nComún a todos los idiomas.';
    }

    if (_selectedLanguageCode == 'es') {
      return '${field.description}\nParámetro: ${field.name}\nIdioma base español.';
    }

    return '${field.description}\nParámetro: $paramName\nEdición del idioma ${_selectedLanguageCode.toUpperCase()}.';
  }

  List<_PremiumPaymentFieldSpec> get _localizedFields =>
      _fields.where((field) => field.isLocalized).toList(growable: false);

  bool get _canUseAiTranslationTools =>
      _hasLoadedLanguage && _selectedLanguageCode != 'es';

  Future<String> _buildAiTranslationPrompt() async {
    final apiService = context.read<ApiService>();
    final selectedLanguage = _premiumLanguageOptions.firstWhere(
      (option) => option.code == _selectedLanguageCode,
      orElse: () => _premiumLanguageOptions.first,
    );
    final localizedFields = _localizedFields;
    final baseParams = await Future.wait(
      localizedFields.map(
        (field) async =>
            MapEntry(field, await apiService.getParametro(field.name)),
      ),
    );

    final buffer = StringBuffer()
      ..writeln(
        'Traduce al idioma ${selectedLanguage.label} este texto, NO traduzcas NUNCA lo que va entre corchetes dobles [[]], y respeta el formato en el resultado devuelto, no devuelvas nada mas, solo lo que te paso traducido:',
      )
      ..writeln();

    for (var index = 0; index < baseParams.length; index++) {
      final entry = baseParams[index];
      final field = entry.key;
      final targetParamName = _parameterNameFor(field);
      final baseValue = (entry.value?['valor'] ?? '').toString().trim();

      buffer.writeln('[[$targetParamName]]');
      if (baseValue.isNotEmpty) {
        buffer.writeln(baseValue);
      }
      if (index != baseParams.length - 1) {
        buffer.writeln();
      }
    }

    return buffer.toString().trimRight();
  }

  Future<void> _showAiTranslationPromptDialog() async {
    if (!_canUseAiTranslationTools || _buildingAiPrompt) {
      return;
    }

    setState(() => _buildingAiPrompt = true);

    try {
      final aiPrompt = await _buildAiTranslationPrompt();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
          title: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Colors.deepPurple,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Prompt para IA',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copia este prompt y pégalo en tu IA favorita para traducir los parámetros Premium del idioma seleccionado con formato compatible:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        aiPrompt,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: aiPrompt));
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Prompt copiado al portapapeles.'),
                    backgroundColor: Colors.deepPurple,
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo generar el prompt de traducción: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _buildingAiPrompt = false);
      }
    }
  }

  Map<String, String>? _parsePremiumAiTranslation(String rawText) {
    final normalized = rawText.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return null;
    }

    final matches = _premiumTranslationTagPattern
        .allMatches(normalized)
        .toList();
    if (matches.isEmpty) {
      return null;
    }

    final valuesByParamName = <String, String>{};
    var cursor = 0;

    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final strayText = normalized.substring(cursor, match.start).trim();
      if (strayText.isNotEmpty) {
        return null;
      }

      final paramName = (match.group(1) ?? '').trim();
      if (paramName.isEmpty || valuesByParamName.containsKey(paramName)) {
        return null;
      }

      final valueStart = match.end;
      final valueEnd = index + 1 < matches.length
          ? matches[index + 1].start
          : normalized.length;
      valuesByParamName[paramName] = normalized
          .substring(valueStart, valueEnd)
          .trim();
      cursor = valueEnd;
    }

    return valuesByParamName;
  }

  Future<void> _pasteAiTranslationFromClipboard() async {
    if (!_canUseAiTranslationTools || _pastingAiTranslation) {
      return;
    }

    setState(() => _pastingAiTranslation = true);

    try {
      final clipboardData = await Clipboard.getData('text/plain');
      final rawText = clipboardData?.text?.trim() ?? '';
      if (rawText.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El portapapeles está vacío.')),
        );
        return;
      }

      final parsedValues = _parsePremiumAiTranslation(rawText);
      if (parsedValues == null || parsedValues.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se detectó un formato válido de traducción IA para Premium.',
            ),
          ),
        );
        return;
      }

      final expectedParamNames = {
        for (final field in _localizedFields) _parameterNameFor(field),
      };
      final invalidParamNames = parsedValues.keys
          .where((paramName) => !expectedParamNames.contains(paramName))
          .toList(growable: false);
      if (invalidParamNames.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El contenido pegado incluye parámetros que no corresponden al idioma ${_selectedLanguageCode.toUpperCase()}: ${invalidParamNames.join(', ')}',
            ),
          ),
        );
        return;
      }

      final fieldsToReplace = {
        for (final field in _localizedFields)
          if (parsedValues.containsKey(_parameterNameFor(field)))
            field.name: parsedValues[_parameterNameFor(field)] ?? '',
      };
      if (fieldsToReplace.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontraron traducciones IA aplicables a los parámetros Premium cargados.',
            ),
          ),
        );
        return;
      }

      final selectedLanguage = _premiumLanguageOptions.firstWhere(
        (option) => option.code == _selectedLanguageCode,
        orElse: () => _premiumLanguageOptions.first,
      );
      final confirmReplace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reemplazar traducción IA'),
          content: Text(
            'Se han detectado ${fieldsToReplace.length} parámetros traducidos para ${selectedLanguage.label}. Si continúas, se rellenarán esos campos del idioma seleccionado para que los revises antes de guardar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reemplazar'),
            ),
          ],
        ),
      );

      if (confirmReplace != true || !mounted) {
        return;
      }

      setState(() {
        for (final entry in fieldsToReplace.entries) {
          _controllers[entry.key]!.text = entry.value;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se han rellenado ${fieldsToReplace.length} parámetros desde la traducción IA. Revisa los textos y pulsa Guardar si son correctos.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo pegar la traducción IA: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _pastingAiTranslation = false);
      }
    }
  }

  bool get _hasLoadedLanguage => _loadedLanguageCode == _selectedLanguageCode;

  void _clearLoadedValues() {
    _existingParams.clear();
    for (final controller in _controllers.values) {
      controller.clear();
    }
  }

  Future<void> _changeLanguage(String languageCode) async {
    if (_selectedLanguageCode == languageCode) {
      return;
    }

    setState(() {
      _selectedLanguageCode = languageCode;
      _loadedLanguageCode = null;
      _loadErrorMessage = null;
    });

    _clearLoadedValues();
  }

  Future<void> _load() async {
    if (!_isNutri) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    setState(() {
      _loading = true;
      _loadErrorMessage = null;
    });

    _clearLoadedValues();

    try {
      final apiService = context.read<ApiService>();
      final loadedParams = await Future.wait(
        _fields.map((field) async {
          final paramName = _parameterNameFor(field);
          final existing = await apiService.getParametro(paramName);
          return MapEntry(field.name, existing);
        }),
      );

      for (final entry in loadedParams) {
        _existingParams[entry.key] = entry.value;
        _controllers[entry.key]!.text = entry.value?['valor']?.toString() ?? '';
      }

      _loadedLanguageCode = _selectedLanguageCode;
    } catch (e) {
      _loadedLanguageCode = null;
      _loadErrorMessage = 'No se pudo cargar la configuración Premium: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_isNutri || !_hasLoadedLanguage) return;

    setState(() => _saving = true);

    try {
      final apiService = context.read<ApiService>();
      for (final field in _fields) {
        final value = _controllers[field.name]!.text.trim();
        final existing = _existingParams[field.name];
        final paramName = _parameterNameFor(field);

        if (existing == null) {
          if (value.isEmpty) {
            continue;
          }
          await apiService.createParametro(
            nombre: paramName,
            valor: value,
            descripcion: field.description,
            categoria: _category,
            tipo: _type,
          );
        } else {
          await apiService.updateParametro(
            codigo: int.tryParse(existing['codigo']?.toString() ?? ''),
            nombre: paramName,
            nombreOriginal: paramName,
            valor: value,
            descripcion:
                existing['descripcion']?.toString() ?? field.description,
            categoria: existing['categoria']?.toString() ?? _category,
            tipo: existing['tipo']?.toString() ?? _type,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración Premium guardada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la configuración Premium: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildSection(
    String title,
    List<_PremiumPaymentFieldSpec> sectionFields,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ...sectionFields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: field.isToggle
                    ? Card(
                        margin: EdgeInsets.zero,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        child: SwitchListTile(
                          value:
                              _controllers[field.name]!.text
                                  .trim()
                                  .toUpperCase() ==
                              'S',
                          onChanged: !_isNutri || _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    _controllers[field.name]!.text = value
                                        ? 'S'
                                        : 'N';
                                  });
                                },
                          title: Text(field.label),
                          subtitle: Text(_helperTextFor(field)),
                        ),
                      )
                    : TextFormField(
                        controller: _controllers[field.name],
                        enabled: !_saving && _isNutri,
                        keyboardType: field.keyboardType,
                        minLines: field.maxLines > 1 ? field.maxLines : 1,
                        maxLines: field.maxLines,
                        decoration: InputDecoration(
                          labelText: field.label,
                          helperText: _helperTextFor(field),
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: field.maxLines > 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isNutri) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'La configuración de métodos de pago Premium solo está disponible para nutricionistas y administradores.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sections = <String, List<_PremiumPaymentFieldSpec>>{};
    for (final field in _fields) {
      sections.putIfAbsent(field.section, () => []).add(field);
    }

    final selectedLanguage = _premiumLanguageOptions.firstWhere(
      (option) => option.code == _selectedLanguageCode,
      orElse: () => _premiumLanguageOptions.first,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_loadErrorMessage != null) ...[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error al cargar Premium',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loadErrorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            _load();
                          },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar carga'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuración Premium y métodos de pago',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecciona un idioma y pulsa en Cargar para editar sus valores. Los datos se guardan en cada parámetro con sufijo _xx (idioma).',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLanguageCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Idioma de los textos Premium',
                    helperText:
                        'Español usa el parámetro base. El resto usa sufijos como _en, _pt, _it, _de o _fr.',
                    border: OutlineInputBorder(),
                  ),
                  items: _premiumLanguageOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.code,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              option.flagBuilder(),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  option.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) async {
                          if (value == null) {
                            return;
                          }
                          await _changeLanguage(value);
                        },
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      selectedLanguage.flagBuilder(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _hasLoadedLanguage
                              ? (_selectedLanguageCode == 'es'
                                    ? 'Idioma cargado: español base. Los parámetros conservan su nombre original sin sufijo.'
                                    : 'Idioma cargado: ${selectedLanguage.label}. Los campos de texto se guardarán con sufijo _${_selectedLanguageCode}.')
                              : (_selectedLanguageCode == 'es'
                                    ? 'Idioma seleccionado: español base. Pulsa en Cargar para recuperar sus valores.'
                                    : 'Idioma seleccionado: ${selectedLanguage.label}. Pulsa en Cargar para recuperar sus valores.'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _saving || _loading ? null : _load,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(
                        _hasLoadedLanguage
                            ? 'Recargar idioma'
                            : 'Cargar idioma',
                      ),
                    ),
                    if (_canUseAiTranslationTools)
                      OutlinedButton.icon(
                        onPressed: _saving || _buildingAiPrompt
                            ? null
                            : _showAiTranslationPromptDialog,
                        icon: _buildingAiPrompt
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: const Text('Copiar traducción IA'),
                      ),
                    if (_canUseAiTranslationTools)
                      OutlinedButton.icon(
                        onPressed: _saving || _pastingAiTranslation
                            ? null
                            : _pasteAiTranslationFromClipboard,
                        icon: _pastingAiTranslation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.content_paste_rounded),
                        label: const Text('Pegar IA'),
                      ),
                  ],
                ),
                if (_canUseAiTranslationTools) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Copiar traducción IA genera un prompt desde los textos base en español. Pegar IA toma la respuesta de la IA desde el portapapeles y rellena los campos del idioma cargado para que puedas revisarlos antes de guardar.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_hasLoadedLanguage) ...[
          const SizedBox(height: 16),
          ...sections.entries.map(
            (entry) => _buildSection(entry.key, entry.value),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Guardar configuración Premium'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Selecciona un idioma y pulsa en Cargar para editar la configuración Premium de ese idioma.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
        const SizedBox(height: 60),
      ],
    );
  }
}

class _PremiumPaymentFieldSpec {
  const _PremiumPaymentFieldSpec({
    required this.name,
    required this.section,
    required this.label,
    required this.description,
    this.maxLines = 1,
    this.keyboardType,
    this.isToggle = false,
    this.isLocalized = false,
  });

  final String name;
  final String section;
  final String label;
  final String description;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool isToggle;
  final bool isLocalized;
}

class _AiSettingsTab extends StatefulWidget {
  const _AiSettingsTab();

  @override
  State<_AiSettingsTab> createState() => _AiSettingsTabState();
}

class _AiSettingsTabState extends State<_AiSettingsTab> {
  static const String _category = 'IA';
  static const String _type = 'Asistente';
  static const String _promptTemplatesParamName = 'ia_prompt_templates_json';
  static const List<String> _promptModules = <String>[
    'Vídeos de ejercicios',
    'Ejercicios',
    'Alimentos',
    'Planes nutri',
    'Planes fit',
    'Suplementos',
    'Aditivos',
    'Sustituciones saludables',
    'Chat',
    'Revisiones',
    'Entrevistas nutri',
    'Entrevistas fit',
    'Charlas',
    'Todos',
  ];
  static const String _defaultRolePrompt =
      'Actúa siempre con el rol de un especialista cualificado en nutrición y dietética y el de un entrenador personal (personal training) cualificado. Responde con criterio profesional, prudencia y enfoque práctico.';

  late final List<_AiFieldSpec> _fields;
  late final Map<String, TextEditingController> _controllers;
  final Map<String, Map<String, dynamic>?> _existingParams = {};
  final Map<String, bool> _sectionExpanded = <String, bool>{};
  bool _loading = true;
  bool _saving = false;

  bool get _isNutri {
    final authService = context.read<AuthService>();
    return authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
  }

  @override
  void initState() {
    super.initState();
    _fields = _buildFieldSpecs();
    _controllers = {
      for (final field in _fields)
        field.name: TextEditingController(text: field.defaultValue),
    };
    for (final field in _fields) {
      _sectionExpanded.putIfAbsent(field.section, () => false);
    }
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<_AiFieldSpec> _buildFieldSpecs() {
    return const [
      _AiFieldSpec(
        name: 'ia_habilitada',
        section: 'General',
        label: 'Asistente IA habilitado',
        description:
            'Activa o desactiva el uso del asistente IA en la app para nutricionista.',
        defaultValue: 'N',
        isToggle: true,
      ),
      _AiFieldSpec(
        name: 'ia_proveedor',
        section: 'General',
        label: 'Proveedor IA',
        description:
            'Identificador del proveedor activo. Ejemplo: deepseek, openai, gemini.',
        defaultValue: 'deepseek',
      ),
      _AiFieldSpec(
        name: 'ia_modelo',
        section: 'General',
        label: 'Modelo por defecto',
        description: 'Modelo que usará el proxy cuando no se indique otro.',
        defaultValue: 'deepseek-chat',
      ),
      _AiFieldSpec(
        name: 'ia_rol_sistema',
        section: 'Prompts',
        label: 'Rol fijo del sistema',
        description:
            'Mensaje de sistema que se enviará siempre antes de cualquier prompt del usuario.',
        defaultValue: _defaultRolePrompt,
        maxLines: 4,
      ),
      _AiFieldSpec(
        name: 'ia_system_prompt',
        section: 'Prompts',
        label: 'Prompt adicional del sistema',
        description:
            'Instrucciones complementarias para estilo, formato o límites de respuesta.',
        maxLines: 5,
      ),
      _AiFieldSpec(
        name: 'ia_prompt_templates_json',
        section: 'Prompts',
        label: 'Prompts personalizados',
        description:
            'Generador de prompts personalizados para el desplegable del asistente IA.',
        defaultValue: '[]',
        useWindowEditorOnly: true,
      ),
      _AiFieldSpec(
        name: 'ia_base_url',
        section: 'Proveedor',
        label: 'Base URL API',
        description: 'URL base del proveedor IA.',
        defaultValue: 'https://api.deepseek.com',
        keyboardType: TextInputType.url,
      ),
      _AiFieldSpec(
        name: 'ia_endpoint_chat',
        section: 'Proveedor',
        label: 'Endpoint chat/completions',
        description:
            'Ruta relativa del endpoint de conversación. Ejemplo: /chat/completions.',
        defaultValue: '/chat/completions',
      ),
      _AiFieldSpec(
        name: 'ia_api_key',
        section: 'Proveedor',
        label: 'API key',
        description: 'Clave privada del proveedor.',
        isSecret: true,
      ),
      _AiFieldSpec(
        name: 'ia_temperature',
        section: 'Respuesta',
        label: 'Temperature',
        description: 'Creatividad de la respuesta. Ejemplo: 0.7.',
        defaultValue: '0.7',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      _AiFieldSpec(
        name: 'ia_max_tokens',
        section: 'Respuesta',
        label: 'Máximo de tokens',
        description: 'Límite superior de tokens de salida.',
        defaultValue: '1200',
        keyboardType: TextInputType.number,
      ),
      _AiFieldSpec(
        name: 'ia_timeout_segundos',
        section: 'Respuesta',
        label: 'Timeout (segundos)',
        description: 'Tiempo máximo de espera del proxy antes de fallar.',
        defaultValue: '60',
        keyboardType: TextInputType.number,
      ),
    ];
  }

  Future<void> _load() async {
    if (!_isNutri) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final apiService = context.read<ApiService>();
      for (final field in _fields) {
        final existing = await apiService.getParametro(field.name);
        _existingParams[field.name] = existing;
        _controllers[field.name]!.text =
            existing?['valor']?.toString() ?? field.defaultValue;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('No se pudo cargar la configuración IA: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_isNutri) return;

    setState(() => _saving = true);

    try {
      final apiService = context.read<ApiService>();
      for (final field in _fields) {
        final value = _controllers[field.name]!.text.trim();
        final existing = _existingParams[field.name];

        if (existing == null) {
          if (value.isEmpty) {
            continue;
          }
          await apiService.createParametro(
            nombre: field.name,
            valor: value,
            descripcion: field.description,
            categoria: _category,
            tipo: _type,
          );
        } else {
          await apiService.updateParametro(
            codigo: int.tryParse(existing['codigo']?.toString() ?? ''),
            nombre: field.name,
            nombreOriginal: field.name,
            valor: value,
            descripcion:
                existing['descripcion']?.toString() ?? field.description,
            categoria: existing['categoria']?.toString() ?? _category,
            tipo: existing['tipo']?.toString() ?? _type,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración IA guardada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la configuración IA: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<_AiPromptTemplateValue> _decodePromptTemplates(String rawJson) {
    final normalized = rawJson.trim();
    if (normalized.isEmpty) {
      return <_AiPromptTemplateValue>[];
    }

    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! List) {
        return <_AiPromptTemplateValue>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => _AiPromptTemplateValue(
              title: (item['title'] ?? item['titulo'] ?? '').toString(),
              prompt: (item['prompt'] ?? item['texto'] ?? '').toString(),
              module: _decodePromptTemplateModule(item),
              active: _isPromptTemplateActive(item),
              isDefault: _isPromptTemplateDefault(item),
            ),
          )
          .where(
            (item) =>
                item.title.trim().isNotEmpty || item.prompt.trim().isNotEmpty,
          )
          .toList(growable: false);
    } catch (_) {
      return <_AiPromptTemplateValue>[];
    }
  }

  String _encodePromptTemplates(List<_AiPromptTemplateValue> templates) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(
      templates
          .where(
            (item) =>
                item.title.trim().isNotEmpty || item.prompt.trim().isNotEmpty,
          )
          .map(
            (item) => <String, dynamic>{
              'title': item.title.trim(),
              'prompt': item.prompt.trim(),
              'module': item.module.trim(),
              'active': item.active,
              'default': item.isDefault,
            },
          )
          .toList(growable: false),
    );
  }

  String _decodePromptTemplateModule(Map item) {
    final raw = (item['module'] ?? item['modulo'] ?? 'Todos').toString().trim();
    if (_promptModules.contains(raw)) {
      return raw;
    }
    return 'Todos';
  }

  bool _isPromptTemplateActive(Map item) {
    final raw = item['active'] ?? item['activo'] ?? true;
    if (raw is bool) {
      return raw;
    }
    final text = raw.toString().trim().toLowerCase();
    return text.isEmpty ||
        text == '1' ||
        text == 'true' ||
        text == 's' ||
        text == 'si' ||
        text == 'sí' ||
        text == 'yes';
  }

  bool _isPromptTemplateDefault(Map item) {
    final raw = item['default'] ?? item['defecto'] ?? false;
    if (raw is bool) {
      return raw;
    }
    final text = raw.toString().trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 's' ||
        text == 'si' ||
        text == 'sí' ||
        text == 'yes';
  }

  Future<void> _openPromptTemplatesEditor() async {
    final controller = _controllers[_promptTemplatesParamName];
    if (controller == null) {
      return;
    }

    final templates = _decodePromptTemplates(controller.text);
    if (controller.text.trim().isNotEmpty &&
        templates.isEmpty &&
        controller.text.trim() != '[]') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El JSON actual no es válido o no tiene el formato esperado. Se abrirá un editor vacío.',
          ),
        ),
      );
    }

    final result = await showDialog<List<_AiPromptTemplateValue>>(
      context: context,
      builder: (dialogContext) => _AiPromptTemplatesEditorDialog(
        initialTemplates: templates,
        modules: _promptModules,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      controller.text = _encodePromptTemplates(result);
    });
  }

  Widget _buildSection(String title, List<_AiFieldSpec> sectionFields) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: _sectionExpanded[title] ?? false,
        onExpansionChanged: (expanded) {
          setState(() {
            _sectionExpanded[title] = expanded;
          });
        },
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                ...sectionFields.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: field.isToggle
                        ? Card(
                            margin: EdgeInsets.zero,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                            child: SwitchListTile(
                              value:
                                  _controllers[field.name]!.text
                                      .trim()
                                      .toUpperCase() ==
                                  'S',
                              onChanged: !_isNutri || _saving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _controllers[field.name]!.text = value
                                            ? 'S'
                                            : 'N';
                                      });
                                    },
                              title: Text(field.label),
                              subtitle: Text(
                                '${field.description}\nParámetro: ${field.name}',
                              ),
                            ),
                          )
                        : field.useWindowEditorOnly
                        ? _buildPromptTemplatesEditorField(field)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _controllers[field.name],
                                enabled: !_saving && _isNutri,
                                keyboardType: field.keyboardType,
                                minLines: field.maxLines > 1
                                    ? field.maxLines
                                    : 1,
                                maxLines: field.maxLines,
                                obscureText: field.isSecret,
                                decoration: InputDecoration(
                                  labelText: field.label,
                                  helperText:
                                      '${field.description}\nParámetro: ${field.name}',
                                  helperMaxLines: 8,
                                  border: const OutlineInputBorder(),
                                  alignLabelWithHint: field.maxLines > 1,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptTemplatesEditorField(_AiFieldSpec field) {
    final templates = _decodePromptTemplates(
      _controllers[field.name]?.text ?? '[]',
    );
    final activeCount = templates.where((item) => item.active).length;

    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(field.description),
            const SizedBox(height: 6),
            Text(
              'Parámetro: ${field.name}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(
              'Total configurados: ${templates.length}. Activos en el asistente: $activeCount.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Cada prompt admite campos entre corchetes como [título], [descripción], [instrucciones] o [elaboración]. Cada ventana del asistente resolverá los que tenga disponibles.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _openPromptTemplatesEditor,
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Personalizar prompts'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isNutri) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'La configuración IA solo está disponible para nutricionistas y administradores.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sections = <String, List<_AiFieldSpec>>{};
    for (final field in _fields) {
      sections.putIfAbsent(field.section, () => []).add(field);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuración del asistente IA',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Proveedor de IA, generador de prompts personalizados.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...sections.entries.map(
          (entry) => _buildSection(entry.key, entry.value),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Guardar configuración IA'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _AiFieldSpec {
  const _AiFieldSpec({
    required this.name,
    required this.section,
    required this.label,
    required this.description,
    this.defaultValue = '',
    this.maxLines = 1,
    this.keyboardType,
    this.isToggle = false,
    this.isSecret = false,
    this.useWindowEditorOnly = false,
  });

  final String name;
  final String section;
  final String label;
  final String description;
  final String defaultValue;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool isToggle;
  final bool isSecret;
  final bool useWindowEditorOnly;
}

class _AiPromptTemplateValue {
  const _AiPromptTemplateValue({
    required this.title,
    required this.prompt,
    required this.module,
    required this.active,
    required this.isDefault,
  });

  final String title;
  final String prompt;
  final String module;
  final bool active;
  final bool isDefault;
}

class _AiPromptTemplatesEditorDialog extends StatefulWidget {
  const _AiPromptTemplatesEditorDialog({
    required this.initialTemplates,
    required this.modules,
  });

  final List<_AiPromptTemplateValue> initialTemplates;
  final List<String> modules;

  @override
  State<_AiPromptTemplatesEditorDialog> createState() =>
      _AiPromptTemplatesEditorDialogState();
}

class _AiPromptTemplatesEditorDialogState
    extends State<_AiPromptTemplatesEditorDialog> {
  late List<_AiPromptTemplateValue> _items;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _promptCtrl = TextEditingController();
  int? _editingIndex;
  String _selectedModule = 'Todos';
  bool _active = true;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _items = List<_AiPromptTemplateValue>.from(widget.initialTemplates);
    _startNewPrompt();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  void _startNewPrompt() {
    setState(() {
      _editingIndex = null;
      _titleCtrl.clear();
      _promptCtrl.clear();
      _selectedModule = 'Todos';
      _active = true;
      _isDefault = false;
    });
  }

  bool get _hasDraftContent =>
      _titleCtrl.text.trim().isNotEmpty || _promptCtrl.text.trim().isNotEmpty;

  _AiPromptTemplateValue? _buildDraftValue() {
    final title = _titleCtrl.text.trim();
    final prompt = _promptCtrl.text.trim();
    if (title.isEmpty && prompt.isEmpty) {
      return null;
    }

    return _AiPromptTemplateValue(
      title: title,
      prompt: prompt,
      module: _selectedModule,
      active: _active,
      isDefault: _isDefault,
    );
  }

  void _storeDraft() {
    final draft = _buildDraftValue();
    if (draft == null) {
      return;
    }

    setState(() {
      if (_editingIndex != null &&
          _editingIndex! >= 0 &&
          _editingIndex! < _items.length) {
        _items[_editingIndex!] = draft;
      } else {
        _items = <_AiPromptTemplateValue>[..._items, draft];
        _editingIndex = _items.length - 1;
      }
    });
  }

  void _loadItemForEdit(int index) {
    final item = _items[index];
    setState(() {
      _editingIndex = index;
      _titleCtrl.text = item.title;
      _promptCtrl.text = item.prompt;
      _selectedModule = item.module;
      _active = item.active;
      _isDefault = item.isDefault;
    });
  }

  Future<void> _openManagePromptsDialog() async {
    if (_hasDraftContent) {
      _storeDraft();
    }

    final result = await showDialog<_AiPromptManagerResult>(
      context: context,
      builder: (dialogContext) =>
          _AiPromptTemplatesListDialog(initialTemplates: _items),
    );

    if (!mounted || result == null) {
      return;
    }

    _items = List<_AiPromptTemplateValue>.from(result.items);

    if (result.editIndex != null &&
        result.editIndex! >= 0 &&
        result.editIndex! < _items.length) {
      _loadItemForEdit(result.editIndex!);
      return;
    }

    if (_editingIndex != null && _editingIndex! >= _items.length) {
      _startNewPrompt();
      return;
    }

    setState(() {});
  }

  void _save() {
    if (_hasDraftContent) {
      _storeDraft();
    }

    final result = _items
        .where((item) => item.title.isNotEmpty || item.prompt.isNotEmpty)
        .toList(growable: false);

    Navigator.of(context).pop(result);
  }

  Widget _buildPromptEditor() {
    return Card(
      key: ValueKey<int?>(_editingIndex),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              _editingIndex == null ? 'Nuevo prompt' : 'Editar prompt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Mejorar descripción del vídeo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedModule,
              decoration: const InputDecoration(
                labelText: 'Módulo',
                border: OutlineInputBorder(),
              ),
              items: widget.modules
                  .map(
                    (module) => DropdownMenuItem<String>(
                      value: module,
                      child: Text(module),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedModule = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptCtrl,
              minLines: 8,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                hintText:
                    'Escribe aquí la instrucción base. Puedes usar campos como [título], [descripción], [instrucciones] o [elaboración].',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              value: _active,
              onChanged: (value) {
                setState(() {
                  _active = value;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Defecto'),
              subtitle: const Text(
                'Se añadirá al abrir el asistente IA del módulo elegido.',
              ),
              value: _isDefault,
              onChanged: (value) {
                setState(() {
                  _isDefault = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Prompts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Gestionar prompts',
            onPressed: _openManagePromptsDialog,
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            icon: const Icon(Icons.view_list_outlined),
          ),
          IconButton(
            tooltip: 'Nuevo prompt',
            onPressed: _startNewPrompt,
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Define aquí los prompts personalizados.'),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildPromptEditor()),
          ],
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _AiPromptManagerResult {
  const _AiPromptManagerResult({required this.items, this.editIndex});

  final List<_AiPromptTemplateValue> items;
  final int? editIndex;
}

class _AiPromptTemplatesListDialog extends StatefulWidget {
  const _AiPromptTemplatesListDialog({required this.initialTemplates});

  final List<_AiPromptTemplateValue> initialTemplates;

  @override
  State<_AiPromptTemplatesListDialog> createState() =>
      _AiPromptTemplatesListDialogState();
}

class _AiPromptTemplatesListDialogState
    extends State<_AiPromptTemplatesListDialog> {
  late List<_AiPromptTemplateValue> _items;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _items = List<_AiPromptTemplateValue>.from(widget.initialTemplates);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<int> _filteredIndexes() {
    final query = _searchQuery.trim().toLowerCase();
    final indexes = <int>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final haystack = <String>[
        item.title,
        item.prompt,
        item.module,
      ].join(' ').toLowerCase();
      if (query.isEmpty || haystack.contains(query)) {
        indexes.add(i);
      }
    }
    return indexes;
  }

  Future<void> _deleteItem(int index) async {
    final item = _items[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar prompt'),
        content: Text(
          '¿Deseas eliminar el prompt "${item.title.isEmpty ? 'Sin título' : item.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _items.removeAt(index);
    });
  }

  void _editItem(int index) {
    Navigator.of(
      context,
    ).pop(_AiPromptManagerResult(items: _items, editIndex: index));
  }

  @override
  Widget build(BuildContext context) {
    final filteredIndexes = _filteredIndexes();

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Listado de prompts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(
              context,
            ).pop(_AiPromptManagerResult(items: _items)),
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar prompt...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                          _searchCtrl.clear();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredIndexes.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay prompts que coincidan con la búsqueda.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredIndexes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, position) {
                        final index = filteredIndexes[position];
                        final item = _items[index];
                        final title = item.title.trim().isEmpty
                            ? 'Sin título'
                            : item.title.trim();
                        return ListTile(
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item.module} · ${item.active ? 'Activo' : 'Oculto'}${item.isDefault ? ' · Defecto' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                onPressed: () => _editItem(index),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () => _deleteItem(index),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdsSettingsTab extends StatefulWidget {
  const _AdsSettingsTab();

  @override
  State<_AdsSettingsTab> createState() => _AdsSettingsTabState();
}

class _AdsSettingsTabState extends State<_AdsSettingsTab> {
  static const String _category = 'Publicidad';
  static const String _type = 'AdMob';

  late final List<_AdsFieldSpec> _fields;
  late final Map<String, TextEditingController> _controllers;
  final Map<String, Map<String, dynamic>?> _existingParams = {};
  bool _loading = true;
  bool _saving = false;

  bool get _isNutri {
    final authService = context.read<AuthService>();
    return authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
  }

  @override
  void initState() {
    super.initState();
    _fields = _buildFieldSpecs();
    _controllers = {
      for (final field in _fields) field.name: TextEditingController(),
    };
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<_AdsFieldSpec> _buildFieldSpecs() {
    return const [
      _AdsFieldSpec(
        name: AdsService.showAdsParam,
        section: 'General',
        label: 'Publicidad activa',
        description:
            'Activa o desactiva toda la publicidad para usuarios no Premium.',
        isToggle: true,
        defaultValue: 'S',
      ),
      _AdsFieldSpec(
        name: AdsService.adsTestModeParam,
        section: 'General',
        label: 'Modo prueba AdMob',
        description:
            'Usa anuncios de prueba aunque existan IDs reales. Recomendado mientras se valida el flujo.',
        isToggle: true,
        defaultValue: 'S',
      ),
      _AdsFieldSpec(
        name: AdsService.adsTestDeviceIdsParam,
        section: 'General',
        label: 'IDs de dispositivos de prueba',
        description:
            'Separados por comas. Déjalo vacío si no necesitas dispositivos concretos.',
        maxLines: 2,
      ),
      _AdsFieldSpec(
        name: AdsService.bannerEnabledParam,
        section: 'Banner inferior',
        label: 'Banner activo',
        description: 'Activa el banner estándar inferior de la app.',
        isToggle: true,
        defaultValue: 'S',
      ),
      _AdsFieldSpec(
        name: AdsService.bannerAndroidParam,
        section: 'Banner inferior',
        label: 'ID banner Android',
        description: 'Bloque AdMob banner para Android.',
        defaultValue: 'ca-app-pub-9017794352345256/2571077220',
      ),
      _AdsFieldSpec(
        name: AdsService.bannerIosParam,
        section: 'Banner inferior',
        label: 'ID banner iOS',
        description: 'Bloque AdMob banner para iOS.',
      ),
      _AdsFieldSpec(
        name: AdsService.bannerPositionParam,
        section: 'Banner inferior',
        label: 'Posición del banner',
        description: 'Valor esperado actualmente: bottom.',
        defaultValue: 'bottom',
      ),
      _AdsFieldSpec(
        name: AdsService.bannerScreensParam,
        section: 'Banner inferior',
        label: 'Pantallas del banner',
        description:
            'Lista separada por comas. Valor global actual: global_bottom.',
        defaultValue: 'global_bottom',
      ),
      _AdsFieldSpec(
        name: AdsService.bannerHideFirstLaunchesParam,
        section: 'Banner inferior',
        label: 'Ocultar primeros inicios banner',
        description: 'Número de aperturas iniciales sin banner.',
        keyboardType: TextInputType.number,
        defaultValue: '1',
      ),
      _AdsFieldSpec(
        name: AdsService.bannerEveryNLaunchesParam,
        section: 'Banner inferior',
        label: 'Mostrar banner cada N inicios',
        description:
            'Cadencia de aparición del banner tras el bloqueo inicial.',
        keyboardType: TextInputType.number,
        defaultValue: '3',
      ),
      _AdsFieldSpec(
        name: AdsService.bannerCooldownMinutesParam,
        section: 'Banner inferior',
        label: 'Cooldown banner (minutos)',
        description:
            'Tiempo mínimo entre impresiones del banner para no saturar.',
        keyboardType: TextInputType.number,
        defaultValue: '30',
      ),
      _AdsFieldSpec(
        name: AdsService.bannerMaxDailyImpressionsParam,
        section: 'Banner inferior',
        label: 'Máximo impresiones banner por día',
        description: 'Límite diario por dispositivo para el banner.',
        keyboardType: TextInputType.number,
        defaultValue: '4',
      ),
      _AdsFieldSpec(
        name: AdsService.nativeEntryEnabledParam,
        section: 'Nativo avanzado inicio',
        label: 'Nativo avanzado activo',
        description:
            'Activa el bloque nativo avanzado en el inicio del paciente.',
        isToggle: true,
        defaultValue: 'S',
      ),
      _AdsFieldSpec(
        name: AdsService.nativeEntryAndroidParam,
        section: 'Nativo avanzado inicio',
        label: 'ID nativo Android',
        description: 'Bloque AdMob nativo avanzado para Android.',
        defaultValue: 'ca-app-pub-9017794352345256/5388812255',
      ),
      _AdsFieldSpec(
        name: AdsService.nativeEntryIosParam,
        section: 'Nativo avanzado inicio',
        label: 'ID nativo iOS',
        description: 'Bloque AdMob nativo avanzado para iOS.',
      ),
      _AdsFieldSpec(
        name: AdsService.nativeEntryHideFirstLaunchesParam,
        section: 'Nativo avanzado inicio',
        label: 'Ocultar primeros inicios nativo',
        description:
            'Para tu caso de prueba, usa 2 para ocultar los dos primeros inicios.',
        keyboardType: TextInputType.number,
        defaultValue: '2',
      ),
      _AdsFieldSpec(
        name: AdsService.nativeEntryEveryNLaunchesParam,
        section: 'Nativo avanzado inicio',
        label: 'Mostrar nativo cada N inicios',
        description: 'Usa 2 para alternar a partir del tercer inicio.',
        keyboardType: TextInputType.number,
        defaultValue: '2',
      ),
      _AdsFieldSpec(
        name: AdsService.nativeEntryCooldownHoursParam,
        section: 'Nativo avanzado inicio',
        label: 'Cooldown nativo (horas)',
        description: 'Tiempo mínimo entre impresiones del anuncio nativo.',
        keyboardType: TextInputType.number,
        defaultValue: '24',
      ),
      _AdsFieldSpec(
        name: AdsService.nativeEntryMaxDailyImpressionsParam,
        section: 'Nativo avanzado inicio',
        label: 'Máximo impresiones nativo por día',
        description: 'Límite diario por dispositivo para el nativo.',
        keyboardType: TextInputType.number,
        defaultValue: '1',
      ),
      _AdsFieldSpec(
        name: AdsService.nativeEntryTimeoutMsParam,
        section: 'Nativo avanzado inicio',
        label: 'Timeout carga nativo (ms)',
        description:
            'Tiempo máximo de espera antes de ocultar el hueco del anuncio.',
        keyboardType: TextInputType.number,
        defaultValue: '2500',
      ),
      _AdsFieldSpec(
        name: AdsService.nativeEntryLocationParam,
        section: 'Nativo avanzado inicio',
        label: 'Ubicación nativo',
        description: 'Valor esperado actualmente: home_top.',
        defaultValue: 'home_top',
      ),
      _AdsFieldSpec(
        name: AdsService.nativeEntryTemplateParam,
        section: 'Nativo avanzado inicio',
        label: 'Plantilla visual nativo',
        description: 'Valores disponibles: small_card, compact, large_card.',
        defaultValue: 'small_card',
      ),
    ];
  }

  Future<void> _load() async {
    if (!_isNutri) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final apiService = context.read<ApiService>();
      for (final field in _fields) {
        final existing = await apiService.getParametro(field.name);
        _existingParams[field.name] = existing;
        _controllers[field.name]!.text =
            existing?['valor']?.toString() ?? field.defaultValue;
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_isNutri) return;

    setState(() => _saving = true);

    try {
      final apiService = context.read<ApiService>();
      for (final field in _fields) {
        final value = _controllers[field.name]!.text.trim();
        final existing = _existingParams[field.name];

        if (existing == null) {
          if (value.isEmpty) {
            continue;
          }
          await apiService.createParametro(
            nombre: field.name,
            valor: value,
            descripcion: field.description,
            categoria: _category,
            tipo: _type,
          );
        } else {
          await apiService.updateParametro(
            codigo: int.tryParse(existing['codigo']?.toString() ?? ''),
            nombre: field.name,
            nombreOriginal: field.name,
            valor: value,
            descripcion:
                existing['descripcion']?.toString() ?? field.description,
            categoria: existing['categoria']?.toString() ?? _category,
            tipo: existing['tipo']?.toString() ?? _type,
          );
        }
      }

      await context.read<AdsService>().refreshConfig();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración de publicidad guardada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la configuración de publicidad: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildSection(String title, List<_AdsFieldSpec> sectionFields) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ...sectionFields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: field.isToggle
                    ? Card(
                        margin: EdgeInsets.zero,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        child: SwitchListTile(
                          value:
                              _controllers[field.name]!.text
                                  .trim()
                                  .toUpperCase() ==
                              'S',
                          onChanged: !_isNutri || _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    _controllers[field.name]!.text = value
                                        ? 'S'
                                        : 'N';
                                  });
                                },
                          title: Text(field.label),
                          subtitle: Text(
                            '${field.description}\nParámetro: ${field.name}',
                          ),
                        ),
                      )
                    : TextFormField(
                        controller: _controllers[field.name],
                        enabled: !_saving && _isNutri,
                        keyboardType: field.keyboardType,
                        minLines: field.maxLines > 1 ? field.maxLines : 1,
                        maxLines: field.maxLines,
                        decoration: InputDecoration(
                          labelText: field.label,
                          helperText:
                              '${field.description}\nParámetro: ${field.name}',
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: field.maxLines > 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isNutri) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'La configuración de publicidad solo está disponible para nutricionistas y administradores.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sections = <String, List<_AdsFieldSpec>>{};
    for (final field in _fields) {
      sections.putIfAbsent(field.section, () => []).add(field);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuración de publicidad AdMob',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aquí controlas si se muestran banners y nativos, sus bloques, y la frecuencia de aparición. El App ID de Android ya está configurado en el proyecto; esta pestaña gestiona los parámetros globales guardados en base de datos.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...sections.entries.map(
          (entry) => _buildSection(entry.key, entry.value),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Guardar configuración de publicidad'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _AdsFieldSpec {
  const _AdsFieldSpec({
    required this.name,
    required this.section,
    required this.label,
    required this.description,
    this.defaultValue = '',
    this.maxLines = 1,
    this.keyboardType,
    this.isToggle = false,
  });

  final String name;
  final String section;
  final String label;
  final String description;
  final String defaultValue;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool isToggle;
}

class _MenuVisibilityPremiumTab extends StatefulWidget {
  const _MenuVisibilityPremiumTab();

  @override
  State<_MenuVisibilityPremiumTab> createState() =>
      _MenuVisibilityPremiumTabState();
}

class _MenuVisibilityPremiumTabState extends State<_MenuVisibilityPremiumTab> {
  static const String _category = 'Aplicación';
  static const String _type = 'Menu';
  static const String _description =
      'Configuración JSON para controlar la visibilidad y la marca Premium de las ventanas del paciente en el inicio y el menú lateral.';
  static const String _taskLimitParamName = 'numero_tareas_no_premium';
  static const String _shoppingListLimitParamName =
      'numero_lista_compra_no_premium';
  static const String _taskLimitDescription =
      'Número máximo de tareas que puede crear y consultar un usuario no Premium cuando la opción Tareas está marcada como Premium.';
  static const String _shoppingListLimitDescription =
      'Número máximo de elementos de Lista de la compra que puede crear y consultar un usuario no Premium cuando la opción Lista de la compra está marcada como Premium.';
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  final List<_MenuVisibilityFieldSpec> _items = const [
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.planesNutri,
      label: 'Planes Nutri',
      description: 'Planes nutricionales del paciente.',
      icon: Icons.restaurant_menu,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.planesFit,
      label: 'Planes Fit',
      description: 'Planes de entrenamiento y seguimiento Fit.',
      icon: Icons.fitness_center,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.recomendaciones,
      label: 'Recomendaciones',
      description: 'Listado de recomendaciones generales del paciente.',
      icon: Icons.tips_and_updates,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.consejos,
      label: 'Consejos',
      description: 'Consejos y contenidos enviados al paciente.',
      icon: Icons.lightbulb_outline,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.videosEjercicios,
      label: 'Vídeos ejercicios',
      description: 'Acceso a vídeos de ejercicios.',
      icon: Icons.ondemand_video,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.catalogoEjercicios,
      label: 'Catálogo ejercicios',
      description: 'Biblioteca de ejercicios disponibles.',
      icon: Icons.view_list,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.recetas,
      label: 'Recetas',
      description: 'Recetario del paciente.',
      icon: Icons.menu_book,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.sustitucionesSaludables,
      label: 'Sustituciones saludables',
      description: 'Alternativas saludables y equivalencias.',
      icon: Icons.swap_horiz,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.charlasSeminarios,
      label: 'Charlas y seminarios',
      description: 'Charlas, seminarios y eventos.',
      icon: Icons.record_voice_over,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.suplementos,
      label: 'Suplementos',
      description: 'Listado de suplementos.',
      icon: Icons.medication_outlined,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.aditivosAlimentarios,
      label: 'Aditivos alimentarios',
      description: 'Consulta de aditivos y análisis.',
      icon: Icons.science_outlined,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.actividades,
      label: 'Actividades',
      description: 'Registro y seguimiento de actividades.',
      icon: Icons.directions_run,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.controlPeso,
      label: 'Control de peso',
      description: 'Evolución de peso y mediciones.',
      icon: Icons.monitor_weight_outlined,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.listaCompra,
      label: 'Lista de la compra',
      description: 'Lista de la compra del paciente.',
      icon: Icons.shopping_cart_outlined,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.escaner,
      label: 'Escáner',
      description: 'Escáner y utilidades de lectura.',
      icon: Icons.qr_code_scanner,
    ),
    _MenuVisibilityFieldSpec(
      keyName: MenuVisibilityPremiumService.tareas,
      label: 'Tareas',
      description: 'Tareas pendientes asignadas al paciente.',
      icon: Icons.checklist,
    ),
  ];

  Map<String, MenuEntryConfig> _config =
      MenuVisibilityPremiumService.defaultConfig();
  Map<String, dynamic>? _existingParam;
  Map<String, dynamic>? _taskLimitParam;
  Map<String, dynamic>? _shoppingListLimitParam;
  late final TextEditingController _taskLimitController;
  late final TextEditingController _shoppingListLimitController;
  bool _loading = true;
  bool _saving = false;

  bool get _isNutri {
    final authService = context.read<AuthService>();
    return authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
  }

  @override
  void initState() {
    super.initState();
    _taskLimitController = TextEditingController(text: '3');
    _shoppingListLimitController = TextEditingController(text: '3');
    _load();
  }

  @override
  void dispose() {
    _taskLimitController.dispose();
    _shoppingListLimitController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_isNutri) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final apiService = context.read<ApiService>();
      final existing = await apiService.getParametro(
        MenuVisibilityPremiumService.parametroNombre,
      );
      final taskLimitParam = await apiService.getParametro(_taskLimitParamName);
      final shoppingListLimitParam = await apiService.getParametro(
        _shoppingListLimitParamName,
      );
      final loaded = await MenuVisibilityPremiumService.loadConfig(
        apiService: apiService,
        forceRefresh: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _existingParam = existing;
        _taskLimitParam = taskLimitParam;
        _shoppingListLimitParam = shoppingListLimitParam;
        _config = Map<String, MenuEntryConfig>.from(loaded);
        _taskLimitController.text = _sanitizePositiveInt(
          taskLimitParam?['valor']?.toString(),
        );
        _shoppingListLimitController.text = _sanitizePositiveInt(
          shoppingListLimitParam?['valor']?.toString(),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar la configuración del menú: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Map<String, dynamic> _buildPayloadMap() {
    final payload = <String, dynamic>{};

    for (final item in _items) {
      final current =
          _config[item.keyName] ??
          MenuVisibilityPremiumService.defaultConfig()[item.keyName]!;
      payload[item.keyName] = {
        'visible': current.visible,
        'premium': current.premium,
      };
    }

    return payload;
  }

  String _buildJsonPreview() {
    return _encoder.convert(_buildPayloadMap());
  }

  String _sanitizePositiveInt(String? rawValue) {
    final parsed = int.tryParse((rawValue ?? '').trim());
    return parsed != null && parsed > 0 ? parsed.toString() : '3';
  }

  Future<void> _upsertNumericParam({
    required String name,
    required String value,
    required String description,
    required Map<String, dynamic>? existing,
  }) async {
    final apiService = context.read<ApiService>();
    if (existing == null) {
      await apiService.createParametro(
        nombre: name,
        valor: value,
        descripcion: description,
        categoria: _category,
        tipo: _type,
      );
      return;
    }

    await apiService.updateParametro(
      codigo: int.tryParse(existing['codigo']?.toString() ?? ''),
      nombre: name,
      nombreOriginal: name,
      valor: value,
      descripcion: existing['descripcion']?.toString() ?? description,
      categoria: existing['categoria']?.toString() ?? _category,
      tipo: existing['tipo']?.toString() ?? _type,
    );
  }

  void _updateItem(String key, {bool? visible, bool? premium}) {
    final fallback =
        MenuVisibilityPremiumService.defaultConfig()[key] ??
        const MenuEntryConfig(visible: true, premium: false);
    final current = _config[key] ?? fallback;

    setState(() {
      _config[key] = current.copyWith(visible: visible, premium: premium);
    });
  }

  void _restoreDefaults() {
    setState(() {
      _config = MenuVisibilityPremiumService.defaultConfig();
      _taskLimitController.text = '3';
      _shoppingListLimitController.text = '3';
    });
  }

  Future<void> _save() async {
    if (!_isNutri) {
      return;
    }

    final taskLimit = _sanitizePositiveInt(_taskLimitController.text);
    final shoppingListLimit = _sanitizePositiveInt(
      _shoppingListLimitController.text,
    );
    _taskLimitController.text = taskLimit;
    _shoppingListLimitController.text = shoppingListLimit;

    setState(() => _saving = true);

    try {
      final apiService = context.read<ApiService>();
      final jsonValue = _buildJsonPreview();
      final existing = await apiService.getParametro(
        MenuVisibilityPremiumService.parametroNombre,
      );

      if (existing == null) {
        await apiService.createParametro(
          nombre: MenuVisibilityPremiumService.parametroNombre,
          valor: jsonValue,
          descripcion: _description,
          categoria: _category,
          tipo: _type,
        );
      } else {
        await apiService.updateParametro(
          codigo: int.tryParse(existing['codigo']?.toString() ?? ''),
          nombre: MenuVisibilityPremiumService.parametroNombre,
          nombreOriginal: MenuVisibilityPremiumService.parametroNombre,
          valor: jsonValue,
          descripcion: existing['descripcion']?.toString() ?? _description,
          categoria: existing['categoria']?.toString() ?? _category,
          tipo: existing['tipo']?.toString() ?? _type,
        );
      }

      _existingParam = existing;
      await MenuVisibilityPremiumService.loadConfig(
        apiService: apiService,
        forceRefresh: true,
      );

      await _upsertNumericParam(
        name: _taskLimitParamName,
        value: taskLimit,
        description: _taskLimitDescription,
        existing: _taskLimitParam,
      );
      await _upsertNumericParam(
        name: _shoppingListLimitParamName,
        value: shoppingListLimit,
        description: _shoppingListLimitDescription,
        existing: _shoppingListLimitParam,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración del menú guardada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la configuración del menú: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildItemCard(_MenuVisibilityFieldSpec item) {
    final current =
        _config[item.keyName] ??
        MenuVisibilityPremiumService.defaultConfig()[item.keyName] ??
        const MenuEntryConfig(visible: true, premium: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(item.description),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible para el paciente'),
              subtitle: const Text(
                'Controla si el acceso aparece en inicio y menú lateral.',
              ),
              value: current.visible,
              onChanged: _saving
                  ? null
                  : (value) => _updateItem(item.keyName, visible: value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Marcar como Premium'),
              subtitle: const Text(
                'Muestra la insignia Premium en los accesos visibles.',
              ),
              value: current.premium,
              onChanged: _saving
                  ? null
                  : (value) => _updateItem(item.keyName, premium: value),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isNutri) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'La configuración del menú de la app solo está disponible para nutricionistas y administradores.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final preview = _buildJsonPreview();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visibilidad y Premium del menú del paciente',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Desde esta pestaña puedes decidir qué accesos aparecen en el inicio y en el menú lateral del paciente, y cuáles deben mostrarse con insignia Premium. La configuración se guarda en el parámetro global menu_visible_premium.',
                ),
                if (_existingParam == null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Todavía no existe el parámetro en base de datos. Al guardar se creará automáticamente usando esta configuración.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Límites de vista previa no Premium',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Estos valores controlan cuántos elementos pueden crear y consultar los usuarios no Premium cuando Tareas o Lista de la compra están marcados como Premium.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _taskLimitController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Número máximo de tareas',
                    helperText:
                        'Se guarda en el parámetro numero_tareas_no_premium.',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.checklist),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _shoppingListLimitController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Número máximo de items en lista de la compra',
                    helperText:
                        'Se guarda en el parámetro numero_lista_compra_no_premium.',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.shopping_cart_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Recargar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _restoreDefaults,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restablecer'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._items.map(_buildItemCard),
        Card(
          margin: const EdgeInsets.only(top: 4),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              'Vista previa JSON',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  preview,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Guardar configuración del menú'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _MenuVisibilityFieldSpec {
  const _MenuVisibilityFieldSpec({
    required this.keyName,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String keyName;
  final String label;
  final String description;
  final IconData icon;
}

class _MostrarTab extends StatelessWidget {
  const _MostrarTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('Mostrar equivalencias en actividades'),
            subtitle: const Text(
              'Activa o desactiva los mensajes de equivalencias en la pantalla de actividades.',
            ),
            value: configService.showEquivalenciasActividades,
            onChanged: (value) {
              context.read<ConfigService>().setShowEquivalenciasActividades(
                value,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DefectoTab extends StatelessWidget {
  const _DefectoTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      children: const [
        _DefectoExpandableCard(title: 'Citas', height: 440, child: _CitasTab()),
        _DefectoExpandableCard(
          title: 'Entrevistas',
          height: 260,
          child: _EntrevistasTab(),
        ),
        _DefectoExpandableCard(
          title: 'Revisiones',
          height: 260,
          child: _RevisionesTab(),
        ),
        _DefectoExpandableCard(
          title: 'Planes',
          height: 280,
          child: _PlanesTab(),
        ),
        _DefectoExpandableCard(
          title: 'Planes nutricionales',
          height: 300,
          child: _NutriPlanSettingsCard(),
        ),
        _DefectoExpandableCard(
          title: 'Pacientes',
          height: 360,
          child: _PacientesTab(),
        ),
        _DefectoExpandableCard(
          title: 'Clientes',
          height: 320,
          child: _ClientesTab(),
        ),
        _DefectoExpandableCard(
          title: 'Usuario',
          height: 760,
          child: _UsuarioTab(),
        ),
        _DefectoExpandableCard(
          title: 'Mostrar',
          height: 120,
          child: _MostrarTab(),
        ),
        SizedBox(height: 18),
      ],
    );
  }
}

class _DefectoExpandableCard extends StatelessWidget {
  const _DefectoExpandableCard({
    required this.title,
    required this.child,
    required this.height,
  });

  final String title;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        children: [SizedBox(height: height, child: child)],
      ),
    );
  }
}

// Tab General
class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _NutriPushSettingsCard(),
        const SizedBox(height: 16),
        const _DeleteSwipePercentageCard(),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Modo Depuración (Debug)'),
          subtitle: const Text(
            'Muestra errores detallados de la API en la aplicación.',
          ),
          value: configService.appMode == AppMode.debug,
          onChanged: (bool value) {
            final newMode = value ? AppMode.debug : AppMode.normal;
            context.read<ConfigService>().setAppMode(newMode);
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.bug_report),
            label: const Text('Abrir Pantalla de Debug'),
            onPressed: () {
              Navigator.pushNamed(context, 'debug');
            },
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _DeleteSwipePercentageCard extends StatefulWidget {
  const _DeleteSwipePercentageCard();

  @override
  State<_DeleteSwipePercentageCard> createState() =>
      _DeleteSwipePercentageCardState();
}

class _DeleteSwipePercentageCardState
    extends State<_DeleteSwipePercentageCard> {
  static const String _paramName = 'porcentaje_desplazamiento_para_eliminacion';

  late final TextEditingController _percentageController;
  bool _loading = true;
  bool _saving = false;

  bool get _isNutri {
    final authService = context.read<AuthService>();
    return authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
  }

  @override
  void initState() {
    super.initState();
    _percentageController = TextEditingController();
    _load();
  }

  String _formatPercent(double value) {
    final normalized = value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return normalized.replaceAll('.', ',');
  }

  Future<void> _load() async {
    final configService = context.read<ConfigService>();
    _percentageController.text = _formatPercent(
      configService.deleteSwipePercentage,
    );

    if (!_isNutri) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final apiService = context.read<ApiService>();
      final existing = await apiService.getParametro(_paramName);
      if (existing == null) {
        await apiService.createParametro(
          nombre: _paramName,
          valor: '50',
          descripcion:
              'Porcentaje mínimo de desplazamiento horizontal (startToEnd) necesario para activar la acción de eliminación por arrastre.',
          categoria: 'Aplicación',
          tipo: 'General',
        );
      }
      await configService.loadDeleteSwipePercentageFromDatabase(apiService);
      if (!mounted) return;
      _percentageController.text = _formatPercent(
        configService.deleteSwipePercentage,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final parsed = double.tryParse(
      _percentageController.text.trim().replaceAll(',', '.'),
    );
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce un porcentaje válido.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final normalized = parsed <= 1 ? parsed * 100 : parsed;
    if (normalized < 5 || normalized > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El porcentaje debe estar entre 5 y 100.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final apiService = context.read<ApiService>();
      final configService = context.read<ConfigService>();
      final valueToStore = normalized % 1 == 0
          ? normalized.toStringAsFixed(0)
          : normalized.toStringAsFixed(2);

      final existing = await apiService.getParametro(_paramName);
      const description =
          'Porcentaje mínimo de desplazamiento horizontal (startToEnd) necesario para activar la acción de eliminación por arrastre.';

      if (existing == null) {
        await apiService.createParametro(
          nombre: _paramName,
          valor: valueToStore,
          descripcion: description,
          categoria: 'Aplicación',
          tipo: 'General',
        );
      } else {
        await apiService.updateParametro(
          codigo: int.tryParse(existing['codigo']?.toString() ?? ''),
          nombre: _paramName,
          nombreOriginal: _paramName,
          valor: valueToStore,
          descripcion: existing['descripcion']?.toString() ?? description,
          categoria: existing['categoria']?.toString() ?? 'Aplicación',
          tipo: 'General',
        );
      }

      await configService.setDeleteSwipePercentage(normalized);
      _percentageController.text = _formatPercent(
        configService.deleteSwipePercentage,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Porcentaje de desplazamiento guardado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el porcentaje: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _percentageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eliminar por desplazamiento',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isNutri
                  ? 'Define el porcentaje mínimo de arrastre para activar eliminar.'
                  : 'Esta configuración solo está disponible para nutricionistas y administradores.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _percentageController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enabled: _isNutri && !_saving,
              decoration: const InputDecoration(
                labelText: 'Porcentaje de desplazamiento',
                helperText: 'Ejemplo: 50 para requerir la mitad del ancho.',
                suffixText: '%',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isNutri && !_saving ? _save : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar porcentaje'),
              ),
            ),
            if (_saving) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

class _NutriPushSettingsCard extends StatefulWidget {
  const _NutriPushSettingsCard();

  @override
  State<_NutriPushSettingsCard> createState() => _NutriPushSettingsCardState();
}

class _NutriPushSettingsCardState extends State<_NutriPushSettingsCard> {
  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;

  bool get _isNutri {
    final authService = context.read<AuthService>();
    return authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
  }

  String _nutriScope() {
    final authService = context.read<AuthService>();
    final userCode = (authService.userCode ?? '').trim();
    final userType = (authService.userType ?? '').trim();
    return '${userType}_$userCode';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isNutri) {
      setState(() => _loading = false);
      return;
    }

    try {
      final api = context.read<ApiService>();
      final scope = _nutriScope();
      _enabled = await NutriPushSettingsService.getChatUnreadPushEnabled(scope);
      try {
        final serverEnabled = await api.getNutriChatUnreadPushEnabled();
        _enabled = serverEnabled;
        await NutriPushSettingsService.setChatUnreadPushEnabled(
          scope,
          serverEnabled,
        );
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _update(bool enabled) async {
    if (!_isNutri) return;
    final scope = _nutriScope();
    setState(() {
      _enabled = enabled;
      _saving = true;
    });
    try {
      await NutriPushSettingsService.setChatUnreadPushEnabled(scope, enabled);
      await context.read<ApiService>().setNutriChatUnreadPushEnabled(
        enabled: enabled,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Notificaciones push de chat activadas'
                : 'Notificaciones push de chat desactivadas',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar la preferencia push: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notificaciones push',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isNutri
                  ? 'Configura qué notificaciones push recibirá el nutricionista en el dispositivo.'
                  : 'Las notificaciones push de chat solo aplican a usuarios nutricionistas.',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Activar notificaciones de chats no leídos'),
              subtitle: const Text(
                'Recibe una notificación cuando llegue un mensaje nuevo de chat sin leer.',
              ),
              value: _enabled,
              onChanged: !_isNutri || _saving ? null : _update,
            ),
            if (_saving) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// Tab Seguridad
class _SecurityTab extends StatelessWidget {
  const _SecurityTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: Scrollbar(
              thumbVisibility: true,
              child: TabBar(
                tabs: [
                  Tab(text: l10n.securitySubtabAccess),
                  Tab(text: l10n.securitySubtabEmailServer),
                  Tab(text: l10n.securitySubtabCipher),
                  Tab(text: l10n.securitySubtabSessions),
                  Tab(text: l10n.securitySubtabAccesses),
                ],
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _AccessSubTab(),
                _SmtpSubTab(canManageSmtp: true),
                _CipherSecuritySubTab(),
                _SessionsSubTab(),
                _AccessesSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CipherSecuritySubTab extends StatelessWidget {
  const _CipherSecuritySubTab();

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final isNutri =
        authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';

    if (!isNutri) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'La utilidad de cifrado/descifrado solo está disponible para nutricionistas y administradores.',
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [_TextCipherToolCard(), SizedBox(height: 60)],
    );
  }
}

// SubTab de Sesiones (contenido anterior de _SecurityTab)
class _SessionsSubTab extends StatefulWidget {
  const _SessionsSubTab();

  @override
  State<_SessionsSubTab> createState() => _SessionsSubTabState();
}

class _SessionsSubTabState extends State<_SessionsSubTab> {
  late Future<SessionResponse> _sessionDataFuture;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  void _loadSessionData() {
    final apiService = context.read<ApiService>();
    final authService = context.read<AuthService>();
    final usuarioCode = authService.userCode;

    if (usuarioCode != null) {
      _sessionDataFuture = apiService.getSessionData(usuarioCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = context.read<AuthService>();
    final usuarioCode = authService.userCode;

    if (usuarioCode == null) {
      final message = authService.isGuestMode
          ? l10n.sessionsAnonymousGuestInfo
          : l10n.sessionsUserCodeUnavailable;
      return Center(child: Text(message, textAlign: TextAlign.center));
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _loadSessionData();
        });
        await _sessionDataFuture;
      },
      child: FutureBuilder<SessionResponse>(
        future: _sessionDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.sessionsError(snapshot.error.toString())),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.commonRetry),
                      onPressed: () {
                        setState(() {
                          _loadSessionData();
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(child: Text(l10n.sessionsNoDataAvailable));
          }

          final sessionData = snapshot.data!;
          final ultimasSesionesExitosas = sessionData.ultimasSesionesExitosas;
          final ultimosIntentosFallidos = sessionData.ultimosIntentosFallidos;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Card de últimas sesiones exitosas
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.security, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            l10n.sessionsSuccessfulTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (ultimasSesionesExitosas.isNotEmpty) ...[
                        for (
                          int i = 0;
                          i < ultimasSesionesExitosas.length;
                          i++
                        ) ...[
                          if (i > 0) const Divider(height: 24),
                          Text(
                            i == 0
                                ? l10n.sessionsCurrent
                                : l10n.sessionsPrevious,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSessionInfo(ultimasSesionesExitosas[i]),
                        ],
                      ] else
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(l10n.sessionsNoSuccessful),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Card de últimos intentos fallidos
              if (ultimosIntentosFallidos.isNotEmpty)
                Card(
                  elevation: 2,
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              l10n.sessionsFailedTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (
                          int i = 0;
                          i < ultimosIntentosFallidos.length;
                          i++
                        ) ...[
                          if (i > 0) const Divider(height: 24),
                          Text(
                            l10n.sessionsAttemptNumber(i + 1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSessionInfo(ultimosIntentosFallidos[i]),
                        ],
                      ],
                    ),
                  ),
                )
              else if (ultimasSesionesExitosas.isNotEmpty)
                Card(
                  elevation: 2,
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.sessionsNoFailed,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // Card de estadísticas totales
              Card(
                elevation: 1,
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sessionsStatsTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.analytics,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.sessionsTotal(sessionData.totalSesiones),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.sessionsSuccessfulCount(
                              sessionData.totalExitosas,
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.error, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            l10n.sessionsFailedCount(sessionData.totalFallidas),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSessionInfo(SessionLog sesion) {
    final l10n = AppLocalizations.of(context)!;
    final fechaFormato = sesion.fecha;
    final horaFormato = sesion.hora ?? l10n.commonNotAvailable;
    final tipoDispositivo = sesion.tipo ?? l10n.commonNotAvailable;
    final ipPublica = sesion.ipPublica ?? '-';

    // Función para obtener el icono según el tipo de dispositivo
    IconData getDeviceIcon(String? tipo) {
      switch (tipo) {
        case 'Android':
          return Icons.android;
        case 'iOS':
          return Icons.apple;
        case 'Web':
          return Icons.computer;
        default:
          return Icons.devices;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text(
              l10n.sessionsDate(fechaFormato),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.access_time, size: 18),
            const SizedBox(width: 8),
            Text(
              l10n.sessionsTime(horaFormato),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(getDeviceIcon(sesion.tipo), size: 18),
            const SizedBox(width: 8),
            Text(
              l10n.sessionsDevice(tipoDispositivo),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 16),
        Text(
          l10n.sessionsIpAddress,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.public, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.sessionsPublicIp(ipPublica),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccessesSubTab extends StatefulWidget {
  const _AccessesSubTab();

  @override
  State<_AccessesSubTab> createState() => _AccessesSubTabState();
}

class _AccessesSubTabState extends State<_AccessesSubTab> {
  late Future<List<SessionLog>> _accessesFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _accessesFuture = context.read<ApiService>().getLatestAccessLogs();
  }

  String _formatFechaHora(SessionLog s) {
    final f = s.fecha.trim();
    final h = (s.hora ?? '').trim();
    if (h.isEmpty) return f;
    return '$f $h';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(_loadData);
        await _accessesFuture;
      },
      child: FutureBuilder<List<SessionLog>>(
        future: _accessesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      onPressed: () => setState(_loadData),
                    ),
                  ],
                ),
              ),
            );
          }

          final accesos = snapshot.data ?? const <SessionLog>[];

          if (accesos.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: const [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay accesos registrados.'),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: accesos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = accesos[index];
              final isGuest = item.isGuest;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isGuest
                        ? Colors.orange.shade100
                        : Colors.blue.shade100,
                    child: Icon(
                      isGuest ? Icons.public : Icons.person,
                      color: isGuest
                          ? Colors.orange.shade800
                          : Colors.blue.shade800,
                    ),
                  ),
                  title: Text(
                    item.accesoDisplayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    isGuest ? 'Invitado sin registro' : 'Usuario registrado',
                  ),
                  trailing: Text(
                    _formatFechaHora(item),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Nueva SubTab de Acceso
class _AccessSubTab extends StatefulWidget {
  const _AccessSubTab();

  @override
  State<_AccessSubTab> createState() => _AccessSubTabState();
}

class _AccessSubTabState extends State<_AccessSubTab> {
  late TextEditingController _minLengthController;
  bool _requireUpperLower = false;
  bool _requireNumbers = false;
  bool _requireSpecialChars = false;
  bool _isLoading = true;
  bool _isSaving = false;

  static const String _categoryName = 'complejidad_contraseña';

  @override
  void initState() {
    super.initState();
    _minLengthController = TextEditingController(text: '8');
    _loadPasswordPolicies();
  }

  Future<void> _loadPasswordPolicies() async {
    try {
      final apiService = context.read<ApiService>();

      final minLengthParam = await apiService.getParametro(
        '${_categoryName}_longitud_minima',
      );
      final upperLowerParam = await apiService.getParametro(
        '${_categoryName}_mayuscula_minuscula',
      );
      final numbersParam = await apiService.getParametro(
        '${_categoryName}_numeros',
      );
      final specialCharsParam = await apiService.getParametro(
        '${_categoryName}_caracteres_especiales',
      );

      setState(() {
        if (minLengthParam != null) {
          _minLengthController.text =
              minLengthParam['valor']?.toString() ?? '8';
        }
        _requireUpperLower =
            upperLowerParam != null &&
            (upperLowerParam['valor'] == 'S' ||
                upperLowerParam['valor'] == '1');
        _requireNumbers =
            numbersParam != null &&
            (numbersParam['valor'] == 'S' || numbersParam['valor'] == '1');
        _requireSpecialChars =
            specialCharsParam != null &&
            (specialCharsParam['valor'] == 'S' ||
                specialCharsParam['valor'] == '1');
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar políticas. $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePasswordPolicies() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final apiService = context.read<ApiService>();

      // Guardar longitud mínima
      await apiService.updateParametro(
        nombre: '${_categoryName}_longitud_minima',
        valor: _minLengthController.text,
        categoria: 'Aplicación',
        tipo: 'General',
        descripcion:
            'Número de caracteres mínimo que deben tener todas las contraseñas de los usuarios del sistema.',
      );

      // Guardar mayúscula y minúscula
      await apiService.updateParametro(
        nombre: '${_categoryName}_mayuscula_minuscula',
        valor: _requireUpperLower ? 'S' : 'N',
        categoria: 'Aplicación',
        tipo: 'General',
        descripcion:
            'Indica si las contraseñas de los usuarios deben contener al menos una letra mayúscula y una letra minúscula.',
      );

      // Guardar números
      await apiService.updateParametro(
        nombre: '${_categoryName}_numeros',
        valor: _requireNumbers ? 'S' : 'N',
        categoria: 'Aplicación',
        tipo: 'General',
        descripcion:
            'Indica si las contraseñas de los usuarios deben contener al menos un número (0-9).',
      );

      // Guardar caracteres especiales
      await apiService.updateParametro(
        nombre: '${_categoryName}_caracteres_especiales',
        valor: _requireSpecialChars ? 'S' : 'N',
        categoria: 'Aplicación',
        tipo: 'General',
        descripcion:
            'Indica si las contraseñas de los usuarios deben contener al menos un carácter especial (* , . + - # \$ ? ¿ ! ¡ _ ( ) / \\ % &).',
      );

      setState(() {
        _isSaving = false;
      });

      // Actualizar ConfigService con los nuevos valores
      final configService = context.read<ConfigService>();
      await configService.loadPasswordPoliciesFromDatabase(apiService);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Políticas de contraseña guardadas correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar políticas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _minLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.password, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Políticas de Contraseña',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configura los requisitos que deben cumplir las contraseñas al crear o modificar usuarios. Esta configuración se aplica a todos los usuarios.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Divider(height: 32),

                    // Longitud mínima
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Longitud Mínima',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Número mínimo de caracteres para la contraseña',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _minLengthController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            enabled: !_isSaving,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              suffix: Text('chars'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Requiere mayúsculas y minúsculas
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CheckboxListTile(
                        enabled: !_isSaving,
                        title: const Text(
                          'Requiere Mayúsculas y Minúsculas',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'La contraseña debe contener al menos una letra mayúscula y una minúscula',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _requireUpperLower,
                        onChanged: (value) {
                          setState(() {
                            _requireUpperLower = value ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Requiere números
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CheckboxListTile(
                        enabled: !_isSaving,
                        title: const Text(
                          'Requiere Números',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'La contraseña debe contener al menos un número (0-9)',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _requireNumbers,
                        onChanged: (value) {
                          setState(() {
                            _requireNumbers = value ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Requiere caracteres especiales
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CheckboxListTile(
                        enabled: !_isSaving,
                        title: const Text(
                          'Requiere Caracteres Especiales',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Debe contener al menos uno de: * , . + - # \$ ? ¿ ! ¡ - _ ( ) / \\ % &',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _requireSpecialChars,
                        onChanged: (value) {
                          setState(() {
                            _requireSpecialChars = value ?? false;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _savePasswordPolicies,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _isSaving ? 'Guardando...' : 'Guardar Políticas',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Estas políticas se guardan a nivel de base de datos y se aplicarán a todos los usuarios de la aplicación.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tab Citas
class _CitasTab extends StatefulWidget {
  const _CitasTab();

  @override
  State<_CitasTab> createState() => _CitasTabState();
}

class _CitasTabState extends State<_CitasTab> {
  List<String> tiposCita = [];
  bool _isLoadingTipos = true;
  late ApiService _apiService;
  String _citasView = 'list';

  static const estadosCita = ["Pendiente", "Realizada", "Anulada", "Aplazada"];

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _loadCitasViewPref();
    _loadTiposCita();
  }

  Future<void> _loadCitasViewPref() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('citas_default_view') ?? 'list';
    if (!mounted) return;
    setState(() {
      _citasView = value;
    });
  }

  Future<void> _saveCitasViewPref(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('citas_default_view', value);
  }

  Future<void> _loadTiposCita() async {
    try {
      final tiposStr = await _apiService.getParametroValor('tipos_de_citas');
      if (tiposStr != null && tiposStr.isNotEmpty) {
        setState(() {
          tiposCita = tiposStr
              .split(';')
              .map((tipo) => tipo.trim().replaceAll('"', ''))
              .toList();
          _isLoadingTipos = false;
        });
      } else {
        _setDefaultTipos();
      }
    } catch (e) {
      // debugPrint('Error al cargar tipos de citas: $e');
      _setDefaultTipos();
    }
  }

  void _setDefaultTipos() {
    setState(() {
      tiposCita = [
        "Entrevista Nutri",
        "Entrevista Fit",
        "Revisión Nutri",
        "Revisión Fit",
        "Asistencia/Dudas",
        "Charla",
        "Medición",
        "Otro",
      ];
      _isLoadingTipos = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visualizar citas',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'calendar', label: Text('Calendario')),
                ButtonSegment(value: 'list', label: Text('Lista')),
              ],
              selected: {_citasView},
              onSelectionChanged: (Set<String> newSelection) {
                final nextValue = newSelection.first;
                setState(() {
                  _citasView = nextValue;
                });
                _saveCitasViewPref(nextValue);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingTipos)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Cargando tipos de cita...'),
                ],
              ),
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: tiposCita.contains(configService.defaultTipoCita)
                ? configService.defaultTipoCita
                : null,
            decoration: const InputDecoration(
              labelText: 'Tipo de Cita por defecto',
              border: OutlineInputBorder(),
            ),
            items: tiposCita
                .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                .toList(),
            onChanged: (value) {
              context.read<ConfigService>().setDefaultTipoCita(value);
            },
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: configService.defaultEstadoCita,
          decoration: const InputDecoration(
            labelText: 'Estado de Cita por defecto',
            border: OutlineInputBorder(),
          ),
          items: estadosCita
              .map(
                (estado) =>
                    DropdownMenuItem(value: estado, child: Text(estado)),
              )
              .toList(),
          onChanged: (value) {
            context.read<ConfigService>().setDefaultEstadoCita(value);
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Cita Online por defecto'),
          value: configService.defaultOnlineCita,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultOnlineCita(value);
          },
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Entrevistas
class _EntrevistasTab extends StatelessWidget {
  const _EntrevistasTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Entrevista Completada por defecto'),
          value: configService.defaultCompletadaEntrevista,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultCompletadaEntrevista(value);
          },
        ),
        SwitchListTile(
          title: const Text('Entrevista Online por defecto'),
          value: configService.defaultOnlineEntrevista,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultOnlineEntrevista(value);
          },
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Revisiones
class _RevisionesTab extends StatelessWidget {
  const _RevisionesTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Revisión Completada por defecto'),
          value: configService.defaultCompletadaRevision,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultCompletadaRevision(value);
          },
        ),
        SwitchListTile(
          title: const Text('Revisión Online por defecto'),
          value: configService.defaultOnlineRevision,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultOnlineRevision(value);
          },
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Planes
class _PlanesTab extends StatelessWidget {
  const _PlanesTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Plan Completado por defecto'),
          value: configService.defaultCompletadaPlan,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultCompletadaPlan(value);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: configService.defaultSemanasPlan,
          decoration: const InputDecoration(
            labelText: 'Semanas por defecto',
            border: OutlineInputBorder(),
            hintText: 'Ej: 1, 2, 3, 4',
          ),
          onChanged: (value) {
            context.read<ConfigService>().setDefaultSemanasPlan(value);
          },
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Pacientes
class _PacientesTab extends StatelessWidget {
  const _PacientesTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Online por defecto'),
          value: configService.defaultOnlinePaciente,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultOnlinePaciente(value);
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Activo por defecto'),
          value: configService.defaultActivoPaciente,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultActivoPaciente(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: configService.defaultSexoPaciente,
          decoration: const InputDecoration(
            labelText: 'Sexo por defecto',
            border: OutlineInputBorder(),
          ),
          items: const <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(
              value: null,
              child: Text('(Sin especificar)'),
            ),
            DropdownMenuItem<String?>(value: 'Hombre', child: Text('Hombre')),
            DropdownMenuItem<String?>(value: 'Mujer', child: Text('Mujer')),
          ],
          onChanged: (value) {
            context.read<ConfigService>().setDefaultSexoPaciente(value);
          },
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Clientes
class _ClientesTab extends StatelessWidget {
  const _ClientesTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          initialValue: configService.defaultPoblacionCliente,
          decoration: const InputDecoration(
            labelText: 'Población por defecto',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            context.read<ConfigService>().setDefaultPoblacionCliente(value);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: configService.defaultProvinciaCliente,
          decoration: const InputDecoration(
            labelText: 'Provincia por defecto',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            context.read<ConfigService>().setDefaultProvinciaCliente(value);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: configService.defaultCPCliente,
          decoration: const InputDecoration(
            labelText: 'Código Postal por defecto',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            context.read<ConfigService>().setDefaultCPCliente(value);
          },
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _NutriPlanSettingsCard extends StatefulWidget {
  const _NutriPlanSettingsCard();

  @override
  State<_NutriPlanSettingsCard> createState() => _NutriPlanSettingsCardState();
}

class _NutriPlanSettingsCardState extends State<_NutriPlanSettingsCard> {
  static const List<String> _planNutriMealOptions =
      NutriPlanSettingsService.defaultMeals;

  bool _loading = true;
  List<String> _planNutriEnabledMeals = List<String>.from(
    NutriPlanSettingsService.defaultMeals,
  );

  bool get _isNutri {
    final authService = context.read<AuthService>();
    return authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
  }

  String _nutriScope() {
    final authService = context.read<AuthService>();
    final userCode = (authService.userCode ?? '').trim();
    final userType = (authService.userType ?? '').trim();
    return '${userType}_$userCode';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isNutri) {
      setState(() => _loading = false);
      return;
    }

    try {
      final scope = _nutriScope();
      _planNutriEnabledMeals = await NutriPlanSettingsService.getEnabledMeals(
        scope,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _togglePlanNutriMeal(String meal, bool selected) {
    setState(() {
      if (selected) {
        if (!_planNutriEnabledMeals.contains(meal)) {
          _planNutriEnabledMeals.add(meal);
        }
      } else {
        if (_planNutriEnabledMeals.length <= 1) {
          return;
        }
        _planNutriEnabledMeals.remove(meal);
      }
      _planNutriEnabledMeals = _planNutriMealOptions
          .where(_planNutriEnabledMeals.contains)
          .toList();
    });
  }

  Future<void> _savePlanNutriConfig() async {
    if (!_isNutri) return;
    if (_planNutriEnabledMeals.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes mantener al menos una ingesta activa.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final scope = _nutriScope();
      await NutriPlanSettingsService.setEnabledMeals(
        scope,
        _planNutriEnabledMeals,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración de Plan nutri guardada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar Plan nutri: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingestas disponibles por día',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isNutri
                      ? 'Selecciona qué ingestas se crearán en cada día al dar de alta la estructura del plan nutricional.'
                      : 'Esta configuración solo está disponible para nutricionistas y administradores.',
                ),
                const SizedBox(height: 12),
                ..._planNutriMealOptions.map((meal) {
                  final enabled = _planNutriEnabledMeals.contains(meal);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(meal),
                    value: enabled,
                    onChanged: !_isNutri
                        ? null
                        : (value) {
                            _togglePlanNutriMeal(meal, value ?? false);
                          },
                  );
                }),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isNutri ? _savePlanNutriConfig : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar configuración Plan nutri'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Usuario
class _UsuarioTab extends StatefulWidget {
  const _UsuarioTab();

  @override
  State<_UsuarioTab> createState() => _UsuarioTabState();
}

class _UsuarioTabState extends State<_UsuarioTab> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  // Valores por defecto
  double _maxImageSizeKb = 500.0;
  String _defaultUserType = 'Usuario';
  bool _defaultActivo = true;
  bool _defaultAcceso = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final configService = context.read<ConfigService>();

      // Cargar tamaño máximo de imagen (desde base de datos - global)
      final sizeParam = await _apiService.getParametro('usuario_max_imagen_kb');
      if (sizeParam != null) {
        _maxImageSizeKb = double.tryParse(sizeParam['valor'] ?? '500') ?? 500.0;
      }

      // Cargar valores por defecto locales
      _defaultUserType = configService.defaultTipoUsuario;
      _defaultActivo = configService.defaultActivoUsuario;
      _defaultAcceso = configService.defaultAccesoUsuario;
    } catch (e) {
      // Si no existen, usar valores por defecto
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    try {
      final configService = context.read<ConfigService>();

      // Guardar tamaño máximo de imagen (en base de datos - global)
      await _apiService.updateParametroValor(
        nombre: 'usuario_max_imagen_kb',
        valor: _maxImageSizeKb.round().toString(),
      );

      // Guardar valores por defecto locales
      await configService.setDefaultTipoUsuario(_defaultUserType);
      await configService.setDefaultActivoUsuario(_defaultActivo);
      await configService.setDefaultAccesoUsuario(_defaultAcceso);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tamaño de imagen de perfil',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tamaño máximo permitido: ${_maxImageSizeKb.round()} KB',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _maxImageSizeKb,
                  min: 1,
                  max: 3000,
                  divisions: 2999,
                  label: '${_maxImageSizeKb.round()} KB',
                  onChanged: (value) {
                    setState(() {
                      _maxImageSizeKb = value;
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1 KB', style: TextStyle(color: Colors.grey[600])),
                    Text('3000 KB', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valores por defecto en alta de usuario',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _defaultUserType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de usuario por defecto',
                    border: OutlineInputBorder(),
                  ),
                  items: ConfigService.defaultUserTypeOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    setState(() {
                      _defaultUserType = value ?? 'Usuario';
                    });
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Activo por defecto'),
                  subtitle: const Text(
                    'Los nuevos usuarios se crearán activos',
                  ),
                  value: _defaultActivo,
                  onChanged: (value) {
                    setState(() {
                      _defaultActivo = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Permitir acceso por defecto'),
                  subtitle: const Text(
                    'Los nuevos usuarios tendrán acceso habilitado',
                  ),
                  value: _defaultAcceso,
                  onChanged: (value) {
                    setState(() {
                      _defaultAcceso = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _saveConfig,
          icon: const Icon(Icons.save),
          label: const Text('Guardar configuración'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _TextCipherToolCard extends StatefulWidget {
  const _TextCipherToolCard();

  @override
  State<_TextCipherToolCard> createState() => _TextCipherToolCardState();
}

class _TextCipherToolCardState extends State<_TextCipherToolCard> {
  final _inputController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _outputController = TextEditingController();
  bool _isBusy = false;
  bool _showPassphrase = false;

  @override
  void dispose() {
    _inputController.dispose();
    _passphraseController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  Future<void> _encryptText() async {
    final input = _inputController.text;
    if (input.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce un texto para cifrar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.encryptRecoveryText(
        text: input,
        passphrase: _passphraseController.text,
      );

      if (!mounted) return;
      setState(() {
        _outputController.text = (result['encrypted_text'] ?? '').toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Texto cifrado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cifrar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _decryptText() async {
    final input = _inputController.text;
    if (input.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce un texto para descifrar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.decryptRecoveryText(
        text: input,
        passphrase: _passphraseController.text,
      );

      if (!mounted) return;
      setState(() {
        _outputController.text = (result['decrypted_text'] ?? '').toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Texto descifrado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descifrar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _useOutputAsInput() {
    final value = _outputController.text;
    if (value.trim().isEmpty) return;
    setState(() {
      _inputController.text = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Utilidad de cifrado/descifrado SMTP',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Permite generar un valor cifrado compatible con contrasena_smtp (prefijo ENC1:) y validar su descifrado. La palabra de paso es opcional.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inputController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Texto de entrada',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passphraseController,
              obscureText: !_showPassphrase,
              decoration: InputDecoration(
                labelText: 'Palabra de paso (opcional)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassphrase ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassphrase = !_showPassphrase;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _encryptText,
                    icon: const Icon(Icons.lock),
                    label: const Text('Cifrar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _decryptText,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Descifrar'),
                  ),
                ),
              ],
            ),
            if (_isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _outputController,
              minLines: 2,
              maxLines: 5,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Resultado',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _isBusy ? null : _useOutputAsInput,
                  icon: const Icon(Icons.sync_alt),
                  label: const Text('Pasar resultado a entrada'),
                ),
                TextButton.icon(
                  onPressed: _isBusy
                      ? null
                      : () {
                          setState(() {
                            _inputController.clear();
                            _outputController.clear();
                            _passphraseController.clear();
                          });
                        },
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmtpSubTab extends StatefulWidget {
  const _SmtpSubTab({required this.canManageSmtp});

  final bool canManageSmtp;

  @override
  State<_SmtpSubTab> createState() => _SmtpSubTabState();
}

class _SmtpSubTabState extends State<_SmtpSubTab> {
  final _serverController = TextEditingController();
  final _portController = TextEditingController();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasStoredPassword = false;
  bool _keepCurrentPassword = true;

  @override
  void initState() {
    super.initState();
    _loadSmtpSettings();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSmtpSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = context.read<ApiService>();
      final data = await apiService.getSmtpSettings();

      if (!mounted) return;
      setState(() {
        _serverController.text = (data['servidor_smtp'] ?? '').toString();
        _portController.text = (data['puerto_smtp'] ?? '').toString();
        _userController.text = (data['usuario_smtp'] ?? '').toString();
        _hasStoredPassword = data['contrasena_guardada'] == true;
        _keepCurrentPassword = _hasStoredPassword;
        _passwordController.clear();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar SMTP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveSmtpSettings() async {
    final server = _serverController.text.trim();
    final port = _portController.text.trim();
    final user = _userController.text.trim();
    final password = _passwordController.text;

    if (server.isEmpty || port.isEmpty || user.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servidor, puerto y usuario SMTP son obligatorios.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if ((!_keepCurrentPassword || !_hasStoredPassword) && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce la contraseña SMTP o marca mantener.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.updateSmtpSettings(
        servidor: server,
        puerto: port,
        usuario: user,
        contrasena: password,
        mantenerContrasena: _keepCurrentPassword,
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _hasStoredPassword = true;
        _keepCurrentPassword = true;
        _passwordController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((response['message'] ?? 'SMTP guardado.').toString()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar SMTP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!widget.canManageSmtp) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'La configuracion SMTP solo esta disponible para nutricionistas y administradores.',
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Servidor SMTP global',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Se utiliza para verificacion de email y recuperacion de contrasena. La contraseña se guarda cifrada en base de datos.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _serverController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Servidor SMTP',
                    border: OutlineInputBorder(),
                    hintText: 'smtp.tudominio.com',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _portController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Puerto SMTP',
                    border: OutlineInputBorder(),
                    hintText: '587',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Usuario SMTP',
                    border: OutlineInputBorder(),
                    hintText: 'noreply@dominio.com',
                  ),
                ),
                const SizedBox(height: 12),
                if (_hasStoredPassword)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mantener contraseña SMTP actual'),
                    value: _keepCurrentPassword,
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _keepCurrentPassword = value;
                              if (value) {
                                _passwordController.clear();
                              }
                            });
                          },
                  ),
                if (!_keepCurrentPassword || !_hasStoredPassword)
                  TextField(
                    controller: _passwordController,
                    enabled: !_isSaving,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña SMTP',
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSmtpSettings,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Guardando...' : 'Guardar SMTP'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Tab Parámetros
class _ParametrosTab extends StatefulWidget {
  const _ParametrosTab();

  @override
  State<_ParametrosTab> createState() => _ParametrosTabState();
}

class _ParametrosTabState extends State<_ParametrosTab> {
  late Future<List<dynamic>> _parametrosFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String? _userType;

  @override
  void initState() {
    super.initState();
    _loadParametros();
    _loadUserType();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  void _loadUserType() {
    final authService = context.read<AuthService>();
    _userType = authService.userType;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadParametros() {
    final apiService = context.read<ApiService>();
    _parametrosFuture = apiService.getParametros();
  }

  void _refresh() {
    setState(() {
      _loadParametros();
    });
  }

  List<dynamic> _searchParametros(List<dynamic> parametros) {
    if (_searchText.isEmpty) {
      return parametros;
    }

    return parametros.where((parametro) {
      final nombre = (parametro['nombre'] ?? '').toString().toLowerCase();
      final valor = (parametro['valor'] ?? '').toString().toLowerCase();
      final valor2 = (parametro['valor2'] ?? '').toString().toLowerCase();
      final descripcion = (parametro['descripcion'] ?? '')
          .toString()
          .toLowerCase();

      return nombre.contains(_searchText) ||
          valor.contains(_searchText) ||
          valor2.contains(_searchText) ||
          descripcion.contains(_searchText);
    }).toList();
  }

  String _truncateText(String? text, {int maxLength = 200, int maxLines = 2}) {
    if (text == null || text.isEmpty) return '';

    // Contar líneas
    final lines = text.split('\n');
    if (lines.length > maxLines) {
      text = lines.take(maxLines).join('\n');
    }

    // Truncar por caracteres
    if (text.length > maxLength) {
      return '${text.substring(0, maxLength)}...';
    }

    return text;
  }

  Future<void> _deleteParametro(Map<String, dynamic> parametro) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Desea eliminar el parámetro "${parametro['nombre']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final apiService = context.read<ApiService>();
        await apiService.deleteParametro(parametro['codigo']);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Parámetro eliminado')));
          _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Campo de búsqueda
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, valor o descripción...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // Lista de parámetros
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refresh();
                await _parametrosFuture;
              },
              child: FutureBuilder<List<dynamic>>(
                future: _parametrosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: ${snapshot.error}'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                              onPressed: _refresh,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final allParametros = snapshot.data ?? [];
                  final parametros = _searchParametros(allParametros);

                  if (allParametros.isEmpty) {
                    return const Center(
                      child: Text('No hay parámetros registrados'),
                    );
                  }

                  if (parametros.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron parámetros',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Intenta con otros términos de búsqueda',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 8,
                      top: 8,
                      bottom: 80,
                    ),
                    itemCount: parametros.length,
                    itemBuilder: (context, index) {
                      final paramData = parametros[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            paramData['nombre'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                _truncateText(paramData['valor']),
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (paramData['descripcion'] != null &&
                                  paramData['descripcion']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  paramData['descripcion'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_userType == 'Nutricionista')
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            parametro.ParametroEditScreen(
                                              parametro: paramData,
                                            ),
                                      ),
                                    );
                                    if (result == true) {
                                      _refresh();
                                    }
                                  },
                                ),
                              if (_userType == 'Nutricionista')
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteParametro(paramData),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _userType == 'Nutricionista'
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const parametro.ParametroEditScreen(),
                  ),
                );
                if (result == true) {
                  _refresh();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
