import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/screens/paciente_profile_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum PremiumPreviewMode { registered, guest }

class PremiumInfoScreen extends StatefulWidget {
  const PremiumInfoScreen({super.key, this.previewMode});

  final PremiumPreviewMode? previewMode;

  @override
  State<PremiumInfoScreen> createState() => _PremiumInfoScreenState();
}

class _PremiumInfoScreenState extends State<PremiumInfoScreen> {
  static const String _paramIntroTitle = 'premium_titulo';
  static const String _paramIntroText = 'premium_descripcion';
  static const String _paramBenefits = 'premium_ventajas';
  static const String _paramPaymentMethods = 'premium_metodos_pago';
  static const String _paramPaymentIntro = 'premium_pago_descripcion';
  static const String _paramActivationNotice =
      'premium_mensaje_activacion_pago';
  static const String _paramPaypalUrl = 'premium_paypal_url';
  static const String _paramPaypalLabel = 'premium_paypal_texto';
  static const String _paramPaypalActive = 'premium_paypal_activo';
  static const String _paramPaypalEmail = 'premium_paypal_email';
  static const String _paramPaypalConcept = 'premium_paypal_concepto';
  static const String _paramBizumPhone = 'premium_bizum_telefono';
  static const String _paramBizumActive = 'premium_bizum_activo';
  static const String _paramBizumHolder = 'premium_bizum_titular';
  static const String _paramBizumConcept = 'premium_bizum_concepto';
  static const String _paramBizumLabel = 'premium_bizum_texto';
  static const String _paramTransferActive = 'premium_transferencia_activo';
  static const String _paramTransferOwner = 'premium_transferencia_titular';
  static const String _paramTransferIban = 'premium_transferencia_iban';
  static const String _paramTransferBank = 'premium_transferencia_banco';
  static const String _paramTransferConcept = 'premium_transferencia_concepto';
  static const String _paramTransferLabel = 'premium_transferencia_texto';
  static const String _paramPrice1m = 'premium_precio_1m';
  static const String _paramPrice3m = 'premium_precio_3m';
  static const String _paramPrice6m = 'premium_precio_6m';
  static const String _paramPrice12m = 'premium_precio_12m';
  static const String _paramPriceText1m = 'premium_precio_texto_1m';
  static const String _paramPriceText3m = 'premium_precio_texto_3m';
  static const String _paramPriceText6m = 'premium_precio_texto_6m';
  static const String _paramPriceText12m = 'premium_precio_texto_12m';
  static const String _paramPaymentConceptTemplate =
      'premium_concepto_plantilla';
  static const String _paramPaymentStepsPaypal = 'premium_pasos_pago_paypal';
  static const String _paramPaymentStepsBizum = 'premium_pasos_pago_bizum';
  static const String _paramPaymentStepsTransfer =
      'premium_pasos_pago_transferencia';

  bool _isLoading = true;
  bool _isCheckingEmail = false;
  bool _emailVerified = false;
  String _verifiedEmail = '';
  int _selectedPeriodMonths = 1;
  String _selectedPaymentLabel = '';
  Map<int, String> _pricesByPeriod = const {1: '', 3: '', 6: '', 12: ''};
  Map<int, String> _priceTextsByPeriod = const {1: '', 3: '', 6: '', 12: ''};
  String _paymentConceptTemplate =
      'Premium {periodo} - {nick} ({codigo}) - {email}';
  late _PremiumContent _content;

  @override
  void initState() {
    super.initState();
    _content = _PremiumContent.defaults();
    _loadContent();
    _loadEmailVerificationStatus();
  }

  Future<void> _loadEmailVerificationStatus() async {
    final authService = context.read<AuthService>();
    if (!authService.isLoggedIn || authService.isGuestMode) {
      return;
    }

    setState(() => _isCheckingEmail = true);
    try {
      final status =
          await context.read<ApiService>().getEmailVerificationStatus();
      if (!mounted) return;
      setState(() {
        _emailVerified = status['email_verified'] == true;
        _verifiedEmail = (status['email'] ?? '').toString();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _emailVerified = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isCheckingEmail = false);
      }
    }
  }

  Future<void> _loadContent() async {
    final apiService = context.read<ApiService>();

    try {
      final values = await Future.wait<String?>([
        apiService.getParametroValor(_paramIntroTitle),
        apiService.getParametroValor(_paramIntroText),
        apiService.getParametroValor(_paramBenefits),
        apiService.getParametroValor(_paramPaymentMethods),
        apiService.getParametroValor(_paramPaymentIntro),
        apiService.getParametroValor(_paramActivationNotice),
        apiService.getParametroValor(_paramPaypalUrl),
        apiService.getParametroValor(_paramPaypalLabel),
        apiService.getParametroValor(_paramPaypalActive),
        apiService.getParametroValor(_paramPaypalEmail),
        apiService.getParametroValor(_paramPaypalConcept),
        apiService.getParametroValor(_paramBizumPhone),
        apiService.getParametroValor(_paramBizumActive),
        apiService.getParametroValor(_paramBizumHolder),
        apiService.getParametroValor(_paramBizumConcept),
        apiService.getParametroValor(_paramBizumLabel),
        apiService.getParametroValor(_paramTransferActive),
        apiService.getParametroValor(_paramTransferOwner),
        apiService.getParametroValor(_paramTransferIban),
        apiService.getParametroValor(_paramTransferBank),
        apiService.getParametroValor(_paramTransferConcept),
        apiService.getParametroValor(_paramTransferLabel),
        apiService.getParametroValor(_paramPrice1m),
        apiService.getParametroValor(_paramPrice3m),
        apiService.getParametroValor(_paramPrice6m),
        apiService.getParametroValor(_paramPrice12m),
        apiService.getParametroValor(_paramPriceText1m),
        apiService.getParametroValor(_paramPriceText3m),
        apiService.getParametroValor(_paramPriceText6m),
        apiService.getParametroValor(_paramPriceText12m),
        apiService.getParametroValor(_paramPaymentConceptTemplate),
        apiService.getParametroValor(_paramPaymentStepsPaypal),
        apiService.getParametroValor(_paramPaymentStepsBizum),
        apiService.getParametroValor(_paramPaymentStepsTransfer),
      ]);

      if (!mounted) return;

      setState(() {
        _content = _PremiumContent(
          introTitle: _textOrDefault(values[0], _content.introTitle),
          introText: _textOrDefault(values[1], _content.introText),
          benefits: _linesOrDefault(values[2], _content.benefits),
          paymentMethods: _linesOrDefault(values[3], _content.paymentMethods),
          paymentIntro: _textOrDefault(values[4], _content.paymentIntro),
          activationNotice: _textOrDefault(
            values[5],
            _content.activationNotice,
          ),
          paymentStepsPaypalTemplate: _textOrDefault(
            values[31],
            _content.paymentStepsPaypalTemplate,
          ),
          paymentStepsBizumTemplate: _textOrDefault(
            values[32],
            _content.paymentStepsBizumTemplate,
          ),
          paymentStepsTransferTemplate: _textOrDefault(
            values[33],
            _content.paymentStepsTransferTemplate,
          ),
          paymentOptions: [
            _PaymentOption.paypal(
              label: _textOrDefault(values[7], 'Pagar por PayPal'),
              url: values[6]?.trim() ?? '',
              active: values[8]?.trim() ?? '',
              email: values[9]?.trim() ?? '',
              concept: values[10]?.trim() ?? '',
            ),
            _PaymentOption.bizum(
              label: _textOrDefault(values[15], 'Pagar por Bizum'),
              phone: values[11]?.trim() ?? '',
              active: values[12]?.trim() ?? '',
              holder: values[13]?.trim() ?? '',
              concept: values[14]?.trim() ?? '',
            ),
            _PaymentOption.transfer(
              label: _textOrDefault(values[21], 'Pagar por transferencia'),
              active: values[16]?.trim() ?? '',
              owner: values[17]?.trim() ?? '',
              iban: values[18]?.trim() ?? '',
              bank: values[19]?.trim() ?? '',
              concept: values[20]?.trim() ?? '',
            ),
          ],
        );
        _pricesByPeriod = {
          1: _textOrDefault(values[22], ''),
          3: _textOrDefault(values[23], ''),
          6: _textOrDefault(values[24], ''),
          12: _textOrDefault(values[25], ''),
        };
        _priceTextsByPeriod = {
          1: _textOrDefault(values[26], ''),
          3: _textOrDefault(values[27], ''),
          6: _textOrDefault(values[28], ''),
          12: _textOrDefault(values[29], ''),
        };
        _paymentConceptTemplate = _textOrDefault(
          values[30],
          _paymentConceptTemplate,
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _content = _PremiumContent.defaults();
        _isLoading = false;
      });
    }
  }

  String _textOrDefault(String? value, String fallback) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  List<String> _linesOrDefault(String? value, List<String> fallback) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return fallback;

    final lines = text
        .split(RegExp(r'\r?\n|\|'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return lines.isEmpty ? fallback : lines;
  }

  String _periodLabel(int months) {
    if (months == 12) return '12 meses';
    return '$months mes${months == 1 ? '' : 'es'}';
  }

  String _resolvePriceAmount(int months) {
    final value = (_pricesByPeriod[months] ?? '').trim();
    if (value.isNotEmpty) return value;
    return '-';
  }

  String _resolvePriceDisplayText(int months) {
    final configuredText = (_priceTextsByPeriod[months] ?? '').trim();
    if (configuredText.isNotEmpty) return configuredText;
    final amount = _resolvePriceAmount(months);
    if (amount == '-') {
      return 'Precio no disponible para ${_periodLabel(months)}.';
    }
    return 'Precio: $amount (período contratado de ${_periodLabel(months)})';
  }

  Future<void> _startPayment(_PaymentOption option) async {
    final authService = context.read<AuthService>();

    if (!authService.isLoggedIn || authService.isGuestMode) {
      await _showRegisterRequiredDialog();
      return;
    }

    if (!_emailVerified) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes verificar tu email antes de continuar con el pago.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _PaymentOption? optionByKind(String kind) {
      for (final item in _content.paymentOptions) {
        if ((item.kind ?? '').trim().toLowerCase() == kind) {
          return item;
        }
      }
      return null;
    }

    String stepsTemplateFor(_PaymentOption selected) {
      final kind = (selected.kind ?? '').trim().toLowerCase();
      if (kind == 'paypal') return _content.paymentStepsPaypalTemplate;
      if (kind == 'bizum') return _content.paymentStepsBizumTemplate;
      return _content.paymentStepsTransferTemplate;
    }

    final paypalOption = optionByKind('paypal');
    final bizumOption = optionByKind('bizum');

    // Registrar pulsación (fire-and-forget, no bloquea el flujo).
    context.read<ApiService>().registerContinuarPago(
          periodMonths: _selectedPeriodMonths,
          paymentMethod: option.label,
        );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PremiumPaymentStepsScreen(
          option: option,
          initialPeriodMonths: _selectedPeriodMonths,
          pricesByPeriod: _pricesByPeriod,
          priceTextsByPeriod: _priceTextsByPeriod,
          fallbackPrice: '',
          verifiedEmail: _verifiedEmail,
          paymentConceptTemplate: _paymentConceptTemplate,
          emailVerified: _emailVerified,
          paymentStepsTemplate: stepsTemplateFor(option),
          nutritionistPhone: (bizumOption?.copyValue ?? '').trim(),
          paypalUrl: (paypalOption?.payUrl ?? '').trim(),
          paypalEmail: (paypalOption?.copyValue ?? '').trim(),
        ),
      ),
    );
  }

  Future<void> _openProfileToVerifyEmail(AuthService authService) async {
    final usuario = Usuario(
      codigo: int.parse(authService.userCode ?? '0'),
      nick: '',
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PacienteProfileEditScreen(
          usuario: usuario,
          expandEmailVerification: true,
        ),
      ),
    );
    _loadEmailVerificationStatus();
  }

  Future<void> _showRegisterRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registro requerido'),
        content: const Text(
          'Para hacerte Premium primero tienes que registrarte. El registro es gratis y, una vez tengas tu cuenta, ya podrás solicitar el acceso Premium al dietista.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/register');
            },
            child: const Text('Registrarme gratis'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentWizardCard(
    BuildContext context,
    List<_PaymentOption> paymentOptions,
    bool needsRegistration,
    bool isManager,
    AuthService authService,
  ) {
    final selectedOption = paymentOptions.firstWhere(
      (item) => item.label == _selectedPaymentLabel,
      orElse: () => paymentOptions.isNotEmpty
          ? paymentOptions.first
          : const _PaymentOption(
              label: '',
              icon: Icons.payment,
              details: [],
              active: 'N',
              isComplete: false,
            ),
    );

    final canProceed = !needsRegistration &&
        !isManager &&
        paymentOptions.isNotEmpty &&
        selectedOption.label.isNotEmpty &&
        _emailVerified;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /*
            Text(
              'Asistente de pago',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),*/
            const SizedBox(height: 12),
            _buildPremiumPeriodSelector(
              context: context,
              selectedMonths: _selectedPeriodMonths,
              onChanged: (value) {
                setState(() => _selectedPeriodMonths = value);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _resolvePriceDisplayText(_selectedPeriodMonths),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue:
                  paymentOptions.any((p) => p.label == _selectedPaymentLabel)
                      ? _selectedPaymentLabel
                      : (paymentOptions.isNotEmpty
                          ? paymentOptions.first.label
                          : null),
              decoration: const InputDecoration(labelText: 'Método de pago'),
              items: paymentOptions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.label,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: paymentOptions.isEmpty
                  ? null
                  : (value) {
                      setState(() => _selectedPaymentLabel = value ?? '');
                    },
            ),
            const SizedBox(height: 10),
            if (_isCheckingEmail) const LinearProgressIndicator(minHeight: 2),
            if (!_isCheckingEmail)
              _buildEmailVerificationNotice(
                context: context,
                needsRegistration: needsRegistration,
                authService: authService,
              ),
            const SizedBox(height: 12),
            if (!needsRegistration &&
                !isManager &&
                !_emailVerified &&
                !_isCheckingEmail) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openProfileToVerifyEmail(authService),
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: const Text('Verifica tu email para realizar el pago'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    canProceed ? () => _startPayment(selectedOption) : null,
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  authService.isPremium
                      ? 'Renovar Premium'
                      : 'Continuar con el pago',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailVerificationNotice({
    required BuildContext context,
    required bool needsRegistration,
    required AuthService authService,
  }) {
    if (_emailVerified) {
      return Text(
        'Email verificado: ${_verifiedEmail.isNotEmpty ? _verifiedEmail : 'ok'}',
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final messagePrefix = needsRegistration
        ? 'Para realizar el pago, primero regístrate, es gratis:'
        : 'Para realizar el pago, primero verifica tu email en';
    final linkLabel = needsRegistration
        ? 'Ir\u00A0al\u00A0registro\u00A0de\u00A0usuario'
        : 'Editar\u00A0perfil';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade800, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(text: '$messagePrefix\u00A0'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () async {
                        if (needsRegistration) {
                          Navigator.pushNamed(context, '/register');
                          return;
                        }
                        await _openProfileToVerifyEmail(authService);
                      },
                      child: Text(
                        linkLabel,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletCard({
    required BuildContext context,
    required List<String> items,
    required Color tint,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 18, color: Colors.black87),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildGuestRegistrationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.lightBlue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.lightBlue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.app_registration, color: Colors.blue),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Si todavía no tienes cuenta, primero debes registrarte gratis para poder solicitar el acceso Premium.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Registrarme gratis'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivationNoticeCard(BuildContext context) {
    if (_content.activationNotice.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_outlined, color: Colors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _content.activationNotice,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isManagerUser = authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
    final isPreview = widget.previewMode != null;
    final isManager = isManagerUser && !isPreview;
    final needsRegistration = isPreview
        ? widget.previewMode == PremiumPreviewMode.guest
        : (!authService.isLoggedIn || authService.isGuestMode);
    final paymentOptions =
        _content.paymentOptions.where((item) => item.isVisible).toList();
    if (_selectedPaymentLabel.isEmpty && paymentOptions.isNotEmpty) {
      _selectedPaymentLabel = paymentOptions.first.label;
    }
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Hazte Premium')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + bottomInset + 12),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade200, Colors.orange.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.workspace_premium,
                                size: 34,
                                color: Colors.deepOrange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _content.introTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.brown.shade900,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _content.introText,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    height: 1.4,
                                    color: Colors.brown.shade800,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                    context,
                    'Ventajas de ser Premium',
                    Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildBulletCard(
                    context: context,
                    items: _content.benefits,
                    tint: Colors.amber.shade50,
                    icon: Icons.star,
                  ),
                  if (isPreview) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        needsRegistration
                            ? 'Vista previa: usuario no registrado/invitado.'
                            : 'Vista previa: usuario registrado.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                  if (needsRegistration) ...[
                    const SizedBox(height: 16),
                    _buildGuestRegistrationCard(),
                  ],
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                    context,
                    'Pago y contratación Premium',
                    Icons.payments_outlined,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _content.paymentIntro,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildBulletCard(
                    context: context,
                    items: _content.paymentMethods,
                    tint: Colors.green.shade50,
                    icon: Icons.credit_card,
                  ),
                  const SizedBox(height: 12),
                  _buildActivationNoticeCard(context),
                  const SizedBox(height: 20),
                  _buildPaymentWizardCard(
                    context,
                    paymentOptions,
                    needsRegistration,
                    isManager || isPreview,
                    authService,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    needsRegistration
                        ? 'Después del registro podrás usar el asistente de pago Premium en esta misma pantalla.'
                        : 'La activación final del acceso Premium la realiza el equipo de NutriFit tras validar el pago y el período elegido. Se realizará en las próximas 24/48/72 horas, en función del método elegido.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PremiumContent {
  const _PremiumContent({
    required this.introTitle,
    required this.introText,
    required this.benefits,
    required this.paymentMethods,
    required this.paymentIntro,
    required this.activationNotice,
    required this.paymentStepsPaypalTemplate,
    required this.paymentStepsBizumTemplate,
    required this.paymentStepsTransferTemplate,
    required this.paymentOptions,
  });

  final String introTitle;
  final String introText;
  final List<String> benefits;
  final List<String> paymentMethods;
  final String paymentIntro;
  final String activationNotice;
  final String paymentStepsPaypalTemplate;
  final String paymentStepsBizumTemplate;
  final String paymentStepsTransferTemplate;
  final List<_PaymentOption> paymentOptions;

  factory _PremiumContent.defaults() {
    return const _PremiumContent(
      introTitle: 'Desbloquea tu experiencia Premium',
      introText:
          'Accede a contenidos exclusivos, recursos avanzados y seguimiento reforzado para sacar más partido a tu plan.',
      benefits: [
        'Acceso a funcionalidades exclusivas para usuarios Premium, como Vídeos Ejercicios y futuras mejoras.',
        'Biblioteca de sustituciones saludables: equivalencias rápidas del tipo “si no tengo X, usa Y” para no romper el plan.',
        'Experiencia más completa dentro de la app con contenido diferencial y acceso ampliado.',
        'Posibilidad de recibir propuestas personalizadas del nutricionista según el servicio contratado.',
      ],
      paymentMethods: [
        'El nutricionista puede ofrecer métodos como PayPal, Bizum, transferencia bancaria u otras opciones personalizadas.',
        'Estos datos son configurables desde parámetros globales para adaptar la propuesta comercial a cada profesional.',
      ],
      paymentIntro:
          'Intrucciones para realizar el pago y activar tu cuenta Premium.',
      activationNotice:
          'Una vez recibido el pago, tu perfil Premium se activará en un plazo aproximado de 24/48/72 horas, en función del método elegido.',
      paymentStepsPaypalTemplate:
          'Abre la pasarela de pago en: {url_paypal}.\nRealiza el pago con la cuenta PayPal ({email_paypal}) e importe indicado.\nSi lo necesitas, usa el botón {boton_abrir_url_paypal}.',
      paymentStepsBizumTemplate:
          'Realiza el Bizum al teléfono {telefono_nutricionista}.\nAñade el concepto antes de confirmar el pago.\nSi lo necesitas, usa el botón {boton_copiar_telefono}.',
      paymentStepsTransferTemplate:
          'Realiza la transferencia con los datos mostrados en pantalla.\nComprueba el importe y añade el concepto antes de enviar.\nSi lo necesitas, copia los datos bancarios disponibles.',
      paymentOptions: [],
    );
  }
}

class _PremiumPeriodChoice {
  const _PremiumPeriodChoice({
    required this.months,
    required this.label,
    required this.badge,
    required this.color,
    required this.softColor,
  });

  final int months;
  final String label;
  final String badge;
  final Color color;
  final Color softColor;
}

const List<_PremiumPeriodChoice> _premiumPeriodChoices = [
  _PremiumPeriodChoice(
    months: 12,
    label: '12 meses',
    badge: 'Máximo descuento',
    color: Color(0xFFE67E22),
    softColor: Color(0xFFFFE4BF),
  ),
  _PremiumPeriodChoice(
    months: 6,
    label: '6 meses',
    badge: 'Ahorro alto',
    color: Color(0xFF1F9D74),
    softColor: Color(0xFFDDF6EC),
  ),
  _PremiumPeriodChoice(
    months: 3,
    label: '3 meses',
    badge: 'Ahorro medio',
    color: Color(0xFF2D7FF9),
    softColor: Color(0xFFDCEBFF),
  ),
  _PremiumPeriodChoice(
    months: 1,
    label: '1 mes',
    badge: 'Sin descuento',
    color: Color(0xFF6B7280),
    softColor: Color(0xFFE9EDF2),
  ),
];

Widget _buildPremiumPeriodSelector({
  required BuildContext context,
  required int selectedMonths,
  required ValueChanged<int> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Período Premium',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _premiumPeriodChoices.map((choice) {
          final isSelected = selectedMonths == choice.months;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onChanged(choice.months),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? choice.color : choice.softColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: choice.color,
                    width: isSelected ? 2.4 : 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: choice.color.withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (choice.months == 12) ...[
                          Icon(
                            Icons.workspace_premium,
                            size: 16,
                            color: isSelected ? Colors.white : choice.color,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          choice.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : choice.color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: isSelected ? Colors.white : choice.color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      choice.badge,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.95)
                            : choice.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ],
  );
}

class _PaymentOption {
  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.details,
    required this.active,
    required this.isComplete,
    this.payUrl,
    this.copyValue,
    this.kind,
    this.copyLabel = 'Dato',
    this.copyButtonLabel = 'Copiar',
  });

  final String label;
  final IconData icon;
  final List<String> details;
  final String active;
  final bool isComplete;
  final String? payUrl;
  final String? copyValue;
  final String? kind;
  final String copyLabel;
  final String copyButtonLabel;

  bool get isActive => active.trim().toUpperCase() == 'S';

  bool get isConfigured =>
      (payUrl?.trim().isNotEmpty ?? false) ||
      (copyValue?.trim().isNotEmpty ?? false);

  bool get isVisible => isActive && isComplete;

  factory _PaymentOption.paypal({
    required String label,
    required String url,
    required String active,
    required String email,
    required String concept,
  }) {
    final trimmedUrl = url.trim();
    final trimmedEmail = email.trim();
    final trimmedConcept = concept.trim();
    return _PaymentOption(
      label: label,
      icon: Icons.account_balance_wallet_outlined,
      active: active,
      isComplete: trimmedUrl.isNotEmpty &&
          trimmedEmail.isNotEmpty &&
          trimmedConcept.isNotEmpty,
      details: [
        if (trimmedUrl.isNotEmpty)
          'Enlace directo para pago online mediante PayPal u otra pasarela equivalente.',
        if (trimmedEmail.isNotEmpty) 'Dirección PayPal: $trimmedEmail',
        if (trimmedConcept.isNotEmpty) 'Concepto recomendado: $trimmedConcept',
      ],
      payUrl: trimmedUrl.isNotEmpty ? trimmedUrl : null,
      copyValue: trimmedUrl.isNotEmpty ? trimmedUrl : null,
      kind: 'paypal',
      copyLabel: 'Dirección web de pago PayPal',
      copyButtonLabel: 'Copiar',
    );
  }

  factory _PaymentOption.bizum({
    required String label,
    required String phone,
    required String active,
    required String holder,
    required String concept,
  }) {
    final trimmedPhone = phone.trim();
    final trimmedHolder = holder.trim();
    final trimmedConcept = concept.trim();
    return _PaymentOption(
      label: label,
      icon: Icons.phone_android_outlined,
      active: active,
      isComplete: trimmedPhone.isNotEmpty &&
          trimmedHolder.isNotEmpty &&
          trimmedConcept.isNotEmpty,
      details: [
        if (trimmedPhone.isNotEmpty) 'Teléfono Bizum: $trimmedPhone',
        if (trimmedHolder.isNotEmpty) 'Titular: $trimmedHolder',
        if (trimmedConcept.isNotEmpty) 'Concepto recomendado: $trimmedConcept',
      ],
      copyValue: trimmedPhone.isNotEmpty ? trimmedPhone : null,
      kind: 'bizum',
      copyLabel: 'Número Bizum',
      copyButtonLabel: 'Copiar teléfono',
    );
  }

  factory _PaymentOption.transfer({
    required String label,
    required String active,
    required String owner,
    required String iban,
    required String bank,
    required String concept,
  }) {
    final trimmedOwner = owner.trim();
    final ibanTrimmed = iban.trim();
    final trimmedBank = bank.trim();
    final trimmedConcept = concept.trim();
    return _PaymentOption(
      label: label,
      icon: Icons.account_balance_outlined,
      active: active,
      isComplete: trimmedOwner.isNotEmpty &&
          ibanTrimmed.isNotEmpty &&
          trimmedBank.isNotEmpty &&
          trimmedConcept.isNotEmpty,
      details: [
        if (trimmedOwner.isNotEmpty) 'Titular: $trimmedOwner',
        if (trimmedBank.isNotEmpty) 'Banco: $trimmedBank',
        if (ibanTrimmed.isNotEmpty) 'IBAN: $ibanTrimmed',
        if (trimmedConcept.isNotEmpty) 'Concepto recomendado: $trimmedConcept',
      ],
      copyValue: ibanTrimmed.isNotEmpty ? ibanTrimmed : null,
      kind: 'transferencia',
      copyLabel: 'IBAN',
      copyButtonLabel: 'Copiar IBAN',
    );
  }
}

class _PremiumPaymentStepsScreen extends StatefulWidget {
  const _PremiumPaymentStepsScreen({
    required this.option,
    required this.initialPeriodMonths,
    required this.pricesByPeriod,
    required this.priceTextsByPeriod,
    required this.fallbackPrice,
    required this.verifiedEmail,
    required this.paymentConceptTemplate,
    required this.emailVerified,
    required this.paymentStepsTemplate,
    required this.nutritionistPhone,
    required this.paypalUrl,
    required this.paypalEmail,
  });

  final _PaymentOption option;
  final int initialPeriodMonths;
  final Map<int, String> pricesByPeriod;
  final Map<int, String> priceTextsByPeriod;
  final String fallbackPrice;
  final String verifiedEmail;
  final String paymentConceptTemplate;
  final bool emailVerified;
  final String paymentStepsTemplate;
  final String nutritionistPhone;
  final String paypalUrl;
  final String paypalEmail;

  @override
  State<_PremiumPaymentStepsScreen> createState() =>
      _PremiumPaymentStepsScreenState();
}

class _PremiumPaymentStepsScreenState
    extends State<_PremiumPaymentStepsScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');
  late int _selectedPeriodMonths;
  bool _sendingNotification = false;
  String? _paymentInfoMessage;

  @override
  void initState() {
    super.initState();
    _selectedPeriodMonths = widget.initialPeriodMonths;
  }

  String _periodLabel(int months) {
    if (months == 12) return '12 meses';
    return '$months mes${months == 1 ? '' : 'es'}';
  }

  String _resolvePriceAmount(int months) {
    final value = (widget.pricesByPeriod[months] ?? '').trim();
    if (value.isNotEmpty) return value;

    final configuredText = (widget.priceTextsByPeriod[months] ?? '').trim();
    final fromConfiguredText = _extractAmountFromText(configuredText);
    if (fromConfiguredText.isNotEmpty) return fromConfiguredText;

    final fallback = widget.fallbackPrice.trim();
    if (fallback.isNotEmpty) return fallback;

    return '-';
  }

  String _extractAmountFromText(String text) {
    if (text.trim().isEmpty) return '';
    final match = RegExp(
      r'(\d+[\.,]\d+\s*(?:EUR|€))',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return '';
    return (match.group(0) ?? '').trim();
  }

  String _resolvePriceDisplayText(int months) {
    final configuredText = (widget.priceTextsByPeriod[months] ?? '').trim();
    if (configuredText.isNotEmpty) return configuredText;
    final amount = _resolvePriceAmount(months);
    if (amount == '-') {
      return 'Precio no disponible para ${_periodLabel(months)}.';
    }
    return 'Precio: $amount (período contratado de ${_periodLabel(months)})';
  }

  String _resolvePeriodText(int months) {
    if (months == 12) {
      return 'Período a contratar de 12 meses (con descuento máximo).';
    }
    if (months == 6) {
      return 'Período a contratar de 6 meses (con descuento alto).';
    }
    if (months == 3) {
      return 'Período a contratar de 3 meses (con descuento).';
    }
    return 'Período a contratar de 1 mes.';
  }

  String _resolvePaymentConcept(AuthService authService) {
    final nick = (authService.userNick ?? '').trim();
    final safeNick = nick.isNotEmpty ? nick : 'usuario';
    return 'NutriFit Premium usuario $safeNick.';
  }

  List<String> _resolveMethodSteps(AuthService authService) {
    final nick = (authService.userNick ?? '').trim();
    final email = widget.verifiedEmail.trim();

    String applyPlaceholders(String input) {
      return input
          .replaceAll('{nick_usuario}', nick)
          .replaceAll('{email_usuario}', email)
          .replaceAll('{telefono_nutricionista}', widget.nutritionistPhone)
          .replaceAll('{url_paypal}', widget.paypalUrl)
          .replaceAll('{email_paypal}', widget.paypalEmail)
          .replaceAll('{boton_copiar_telefono}', 'Copiar teléfono')
          .replaceAll('{botón_copiar_telefono}', 'Copiar teléfono')
          .replaceAll('{boton_abrir_url_paypal}', 'Acceder al pago')
          .replaceAll('{botón_abrir_url_paypal}', 'Acceder al pago')
          .replaceAll('{boton_copiar_concepto}', 'Copiar concepto')
          .replaceAll('{botón_copiar_concepto}', 'Copiar concepto');
    }

    final rawTemplate = widget.paymentStepsTemplate.trim();
    if (rawTemplate.isEmpty) {
      return widget.option.details
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }

    return rawTemplate
        .split(RegExp(r'\r?\n|\|'))
        .map((line) => applyPlaceholders(line.trim()))
        .where((line) => line.isNotEmpty)
        .toList();
  }

  // ignore: unused_element
  Future<void> _copyToClipboard(
    String label,
    String value, {
    String? infoCardMessage,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    if (infoCardMessage != null && infoCardMessage.trim().isNotEmpty) {
      setState(() {
        _paymentInfoMessage = infoCardMessage;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _openUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;
    final normalizedUrl =
        (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
            ? trimmed
            : 'https://$trimmed';
    if (Uri.tryParse(normalizedUrl) == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL no válida.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      await launchUrlString(
        normalizedUrl,
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      try {
        await _externalUrlChannel.invokeMethod('openUrl', {
          'url': normalizedUrl,
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir el enlace de pago: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir el enlace de pago: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _notifyPaymentDone() async {
    if (!widget.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes verificar tu email antes de notificar el pago.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final concept = _resolvePaymentConcept(authService);
    final priceText = _resolvePriceDisplayText(_selectedPeriodMonths);

    setState(() => _sendingNotification = true);
    try {
      // Registrar pulsación (fire-and-forget, no bloquea el flujo).
      context.read<ApiService>().registerHeRealizadoElPago(
            periodMonths: _selectedPeriodMonths,
            paymentMethod: widget.option.label,
          );

      await context.read<ApiService>().notifyPremiumPaymentDone(
            paymentMethod: widget.option.label,
            periodMonths: _selectedPeriodMonths,
            priceText: priceText,
            concept: concept,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notificación enviada al nutricionista. Revisará el pago y activará tu cuenta Premium.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo notificar el pago: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingNotification = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final concept = _resolvePaymentConcept(authService);
    final detailLines = _resolveMethodSteps(authService);
    final amountText = _resolvePriceAmount(_selectedPeriodMonths);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Completar el pago')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 18 + bottomInset),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.deepOrange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepOrange.shade200),
            ),
            child: Column(
              children: [
                Text(
                  amountText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.deepOrange.shade800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _resolvePeriodText(_selectedPeriodMonths),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Concepto que debes indicar en el método de pago:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.brown.shade800,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300, width: 1.6),
            ),
            child: Text(
              concept,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.brown.shade900,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pasos para ${widget.option.label}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...detailLines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Expanded(child: Text(line)),
                        ],
                      ),
                    ),
                  ),
                  if ((widget.option.payUrl ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _openUrl(widget.option.payUrl!),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Acceder al pago'),
                        ),
                      ),
                    ),
                  if (_paymentInfoMessage != null &&
                      _paymentInfoMessage!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.lightBlue.shade200),
                      ),
                      child: Text(
                        _paymentInfoMessage!,
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepOrange.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.deepOrange.shade200, width: 1.8),
            ),
            child: const Text(
              'Cuando hayas realizado el pago, pulsa en "He realizado el pago" para enviar notificación al equipo de NutriFit. En cuanto se verifique el pago, se activará tu cuenta Premium y se te notificará por email.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sendingNotification ? null : _notifyPaymentDone,
              icon: const Icon(Icons.mark_email_read_outlined),
              label: Text(
                _sendingNotification
                    ? 'Enviando notificación...'
                    : 'He realizado el pago',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                elevation: 3,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
