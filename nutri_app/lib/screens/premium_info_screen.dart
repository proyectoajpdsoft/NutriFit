import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/screens/paciente_profile_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum PremiumPreviewMode { registered, guest }

const String premiumPaymentConfirmationArgumentKey =
    'showPremiumPaymentConfirmation';

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
    final languageCode = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;
    final defaultContent = _PremiumContent.defaults(l10n);

    try {
      final values = await Future.wait<String?>([
        apiService.getParametroValorLocalized(
          _paramIntroTitle,
          languageCode: languageCode,
        ),
        apiService.getParametroValorLocalized(
          _paramIntroText,
          languageCode: languageCode,
        ),
        apiService.getParametroValorLocalized(
          _paramBenefits,
          languageCode: languageCode,
        ),
        apiService.getParametroValorLocalized(
          _paramPaymentMethods,
          languageCode: languageCode,
        ),
        apiService.getParametroValorLocalized(
          _paramPaymentIntro,
          languageCode: languageCode,
        ),
        apiService.getParametroValorLocalized(
          _paramActivationNotice,
          languageCode: languageCode,
        ),
        apiService.getParametroValor(_paramPaypalUrl),
        apiService.getParametroValorLocalized(
          _paramPaypalLabel,
          languageCode: languageCode,
        ),
        apiService.getParametroValor(_paramPaypalActive),
        apiService.getParametroValor(_paramPaypalEmail),
        apiService.getParametroValor(_paramPaypalConcept),
        apiService.getParametroValor(_paramBizumPhone),
        apiService.getParametroValor(_paramBizumActive),
        apiService.getParametroValor(_paramBizumHolder),
        apiService.getParametroValor(_paramBizumConcept),
        apiService.getParametroValorLocalized(
          _paramBizumLabel,
          languageCode: languageCode,
        ),
        apiService.getParametroValor(_paramTransferActive),
        apiService.getParametroValor(_paramTransferOwner),
        apiService.getParametroValor(_paramTransferIban),
        apiService.getParametroValor(_paramTransferBank),
        apiService.getParametroValor(_paramTransferConcept),
        apiService.getParametroValorLocalized(
          _paramTransferLabel,
          languageCode: languageCode,
        ),
        apiService.getParametroValor(_paramPrice1m),
        apiService.getParametroValor(_paramPrice3m),
        apiService.getParametroValor(_paramPrice6m),
        apiService.getParametroValor(_paramPrice12m),
        apiService.getParametroValorLocalized(
          _paramPriceText1m,
          languageCode: languageCode,
        ),
        apiService.getParametroValorLocalized(
          _paramPriceText3m,
          languageCode: languageCode,
        ),
        apiService.getParametroValorLocalized(
          _paramPriceText6m,
          languageCode: languageCode,
        ),
        apiService.getParametroValorLocalized(
          _paramPriceText12m,
          languageCode: languageCode,
        ),
        apiService.getParametroValorLocalized(
          _paramPaymentConceptTemplate,
          languageCode: languageCode,
        ),
        apiService.getParametroValorLocalized(
          _paramPaymentStepsPaypal,
          languageCode: languageCode,
        ),
        apiService.getParametroValorLocalized(
          _paramPaymentStepsBizum,
          languageCode: languageCode,
        ),
        apiService.getParametroValorLocalized(
          _paramPaymentStepsTransfer,
          languageCode: languageCode,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _content = _PremiumContent(
          introTitle: _textOrDefault(values[0], defaultContent.introTitle),
          introText: _textOrDefault(values[1], defaultContent.introText),
          benefits: _linesOrDefault(values[2], defaultContent.benefits),
          paymentMethods: _linesOrDefault(
            values[3],
            defaultContent.paymentMethods,
          ),
          paymentIntro: _textOrDefault(values[4], defaultContent.paymentIntro),
          activationNotice: _textOrDefault(
            values[5],
            defaultContent.activationNotice,
          ),
          paymentStepsPaypalTemplate: _textOrDefault(
            values[31],
            defaultContent.paymentStepsPaypalTemplate,
          ),
          paymentStepsBizumTemplate: _textOrDefault(
            values[32],
            defaultContent.paymentStepsBizumTemplate,
          ),
          paymentStepsTransferTemplate: _textOrDefault(
            values[33],
            defaultContent.paymentStepsTransferTemplate,
          ),
          paymentOptions: [
            _PaymentOption.paypal(
              label: _textOrDefault(values[7], l10n.premiumPayWithPaypal),
              url: values[6]?.trim() ?? '',
              active: values[8]?.trim() ?? '',
              email: values[9]?.trim() ?? '',
              concept: values[10]?.trim() ?? '',
            ),
            _PaymentOption.bizum(
              label: _textOrDefault(values[15], l10n.premiumPayWithBizum),
              phone: values[11]?.trim() ?? '',
              active: values[12]?.trim() ?? '',
              holder: values[13]?.trim() ?? '',
              concept: values[14]?.trim() ?? '',
            ),
            _PaymentOption.transfer(
              label: _textOrDefault(values[21], l10n.premiumPayWithTransfer),
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
        _content = defaultContent;
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
    final l10n = AppLocalizations.of(context)!;
    return l10n.premiumPeriodMonths(months);
  }

  String _resolvePriceAmount(int months) {
    final value = (_pricesByPeriod[months] ?? '').trim();
    if (value.isNotEmpty) return value;
    return '-';
  }

  String _resolvePriceDisplayText(int months) {
    final l10n = AppLocalizations.of(context)!;
    final configuredText = (_priceTextsByPeriod[months] ?? '').trim();
    if (configuredText.isNotEmpty) return configuredText;
    final amount = _resolvePriceAmount(months);
    if (amount == '-') {
      return l10n.premiumPriceUnavailable(_periodLabel(months));
    }
    return l10n.premiumPriceDisplay(amount, _periodLabel(months));
  }

  Future<void> _startPayment(_PaymentOption option) async {
    final authService = context.read<AuthService>();

    if (!authService.isLoggedIn || authService.isGuestMode) {
      await _showRegisterRequiredDialog();
      return;
    }

    if (!_emailVerified) {
      final l10n = AppLocalizations.of(context)!;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.premiumVerifyEmailBeforePayment),
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
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.drawerRegistrationRequiredTitle),
        content: Text(
          l10n.premiumRegistrationRequiredBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonClose),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/register');
            },
            child: Text(l10n.premiumRegisterFree),
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
    final l10n = AppLocalizations.of(context)!;
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
              decoration:
                  InputDecoration(labelText: l10n.premiumPaymentMethodLabel),
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
                  label: Text(l10n.premiumVerifyEmailAction),
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
                      ? l10n.homeRenewPremium
                      : l10n.premiumContinuePayment,
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
    final l10n = AppLocalizations.of(context)!;
    if (_emailVerified) {
      return Text(
        l10n.premiumVerifiedEmailStatus(
          _verifiedEmail.isNotEmpty ? _verifiedEmail : 'ok',
        ),
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final messagePrefix = needsRegistration
        ? l10n.premiumPaymentNeedsRegistration
        : l10n.premiumPaymentNeedsEmailVerification;
    final linkLabel = needsRegistration
        ? l10n.premiumGoToRegisterLink
        : l10n.homeGoToEditProfile;

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
    final l10n = AppLocalizations.of(context)!;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.app_registration, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.premiumGuestRegistrationBody,
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
              label: Text(l10n.premiumRegisterFree),
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
    final l10n = AppLocalizations.of(context)!;
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
      appBar: AppBar(title: Text(l10n.navPremium)),
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
                    l10n.premiumBenefitsSectionTitle,
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
                            ? l10n.navPreviewGuestUser
                            : l10n.navPreviewRegisteredUser,
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
                    l10n.premiumPaymentSectionTitle,
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
                        ? l10n.premiumAfterRegistrationMessage
                        : l10n.premiumFinalActivationMessage,
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

  factory _PremiumContent.defaults([AppLocalizations? l10n]) {
    return _PremiumContent(
      introTitle:
          l10n?.premiumDefaultIntroTitle ?? 'Desbloquea tu experiencia Premium',
      introText: l10n?.premiumDefaultIntroText ??
          'Accede a contenidos exclusivos, recursos avanzados y seguimiento reforzado para sacar más partido a tu plan.',
      benefits: [
        l10n?.premiumDefaultBenefit1 ??
            'Acceso a funcionalidades exclusivas para usuarios Premium, como Vídeos Ejercicios y futuras mejoras.',
        l10n?.premiumDefaultBenefit2 ??
            'Biblioteca de sustituciones saludables: equivalencias rápidas del tipo “si no tengo X, usa Y” para no romper el plan.',
        l10n?.premiumDefaultBenefit3 ??
            'Experiencia más completa dentro de la app con contenido diferencial y acceso ampliado.',
        l10n?.premiumDefaultBenefit4 ??
            'Posibilidad de recibir propuestas personalizadas del nutricionista según el servicio contratado.',
      ],
      paymentMethods: [
        l10n?.premiumDefaultPaymentMethod1 ??
            'El nutricionista puede ofrecer métodos como PayPal, Bizum, transferencia bancaria u otras opciones personalizadas.',
        l10n?.premiumDefaultPaymentMethod2 ??
            'Estos datos son configurables desde parámetros globales para adaptar la propuesta comercial a cada profesional.',
      ],
      paymentIntro: l10n?.premiumDefaultPaymentIntro ??
          'Intrucciones para realizar el pago y activar tu cuenta Premium.',
      activationNotice: l10n?.premiumDefaultActivationNotice ??
          'Una vez recibido el pago, tu perfil Premium se activará en un plazo aproximado de 24/48/72 horas, en función del método elegido.',
      paymentStepsPaypalTemplate: l10n?.premiumDefaultPaypalSteps(
            '{boton_abrir_url_paypal}',
            '{email_paypal}',
            '{url_paypal}',
          ) ??
          'Abre la pasarela de pago en: {url_paypal}.\nRealiza el pago con la cuenta PayPal ({email_paypal}) e importe indicado.\nSi lo necesitas, usa el botón {boton_abrir_url_paypal}.',
      paymentStepsBizumTemplate: l10n?.premiumDefaultBizumSteps(
            '{boton_copiar_telefono}',
            '{telefono_nutricionista}',
          ) ??
          'Realiza el Bizum al teléfono {telefono_nutricionista}.\nAñade el concepto antes de confirmar el pago.\nSi lo necesitas, usa el botón {boton_copiar_telefono}.',
      paymentStepsTransferTemplate: l10n?.premiumDefaultTransferSteps ??
          'Realiza la transferencia con los datos mostrados en pantalla.\nComprueba el importe y añade el concepto antes de enviar.\nSi lo necesitas, copia los datos bancarios disponibles.',
      paymentOptions: const [],
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

List<_PremiumPeriodChoice> _premiumPeriodChoices(AppLocalizations l10n) => [
      _PremiumPeriodChoice(
        months: 12,
        label: l10n.premiumPeriodMonths(12),
        badge: l10n.premiumPeriodBadgeMaxDiscount,
        color: const Color(0xFFE67E22),
        softColor: const Color(0xFFFFE4BF),
      ),
      _PremiumPeriodChoice(
        months: 6,
        label: l10n.premiumPeriodMonths(6),
        badge: l10n.premiumPeriodBadgeHighSaving,
        color: const Color(0xFF1F9D74),
        softColor: const Color(0xFFDDF6EC),
      ),
      _PremiumPeriodChoice(
        months: 3,
        label: l10n.premiumPeriodMonths(3),
        badge: l10n.premiumPeriodBadgeMediumSaving,
        color: const Color(0xFF2D7FF9),
        softColor: const Color(0xFFDCEBFF),
      ),
      _PremiumPeriodChoice(
        months: 1,
        label: l10n.premiumPeriodMonths(1),
        badge: l10n.premiumPeriodBadgeNoDiscount,
        color: const Color(0xFF6B7280),
        softColor: const Color(0xFFE9EDF2),
      ),
    ];

Widget _buildPremiumPeriodSelector({
  required BuildContext context,
  required int selectedMonths,
  required ValueChanged<int> onChanged,
}) {
  final l10n = AppLocalizations.of(context)!;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l10n.premiumPeriodLabel,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _premiumPeriodChoices(l10n).map((choice) {
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
    final l10n = AppLocalizations.of(context)!;
    return l10n.premiumPeriodMonths(months);
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
    final l10n = AppLocalizations.of(context)!;
    final configuredText = (widget.priceTextsByPeriod[months] ?? '').trim();
    if (configuredText.isNotEmpty) return configuredText;
    final amount = _resolvePriceAmount(months);
    if (amount == '-') {
      return l10n.premiumPriceUnavailable(_periodLabel(months));
    }
    return l10n.premiumPriceDisplay(amount, _periodLabel(months));
  }

  String _resolvePeriodText(int months) {
    final l10n = AppLocalizations.of(context)!;
    if (months == 12) {
      return l10n.premiumPeriodSummaryMaxDiscount;
    }
    if (months == 6) {
      return l10n.premiumPeriodSummaryHighDiscount;
    }
    if (months == 3) {
      return l10n.premiumPeriodSummaryDiscount;
    }
    return l10n.premiumPeriodSummarySingleMonth;
  }

  String _resolvePaymentConcept(AuthService authService) {
    final l10n = AppLocalizations.of(context)!;
    final nick = (authService.userNick ?? '').trim();
    final safeNick = nick.isNotEmpty ? nick : l10n.commonUser;
    return l10n.premiumPaymentConcept(safeNick);
  }

  List<String> _resolveMethodSteps(AuthService authService) {
    final l10n = AppLocalizations.of(context)!;
    final nick = (authService.userNick ?? '').trim();
    final email = widget.verifiedEmail.trim();

    String applyPlaceholders(String input) {
      return input
          .replaceAll('{nick_usuario}', nick)
          .replaceAll('{email_usuario}', email)
          .replaceAll('{telefono_nutricionista}', widget.nutritionistPhone)
          .replaceAll('{url_paypal}', widget.paypalUrl)
          .replaceAll('{email_paypal}', widget.paypalEmail)
          .replaceAll('{boton_copiar_telefono}', l10n.premiumCopyPhone)
          .replaceAll('{botón_copiar_telefono}', l10n.premiumCopyPhone)
          .replaceAll('{boton_abrir_url_paypal}', l10n.premiumOpenPayment)
          .replaceAll('{botón_abrir_url_paypal}', l10n.premiumOpenPayment)
          .replaceAll('{boton_copiar_concepto}', l10n.premiumCopyConcept)
          .replaceAll('{botón_copiar_concepto}', l10n.premiumCopyConcept);
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
    final l10n = AppLocalizations.of(context)!;
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
        content: Text(l10n.commonCopiedToClipboardLabel(label)),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _openUrl(String rawUrl) async {
    final l10n = AppLocalizations.of(context)!;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;
    final normalizedUrl =
        (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
            ? trimmed
            : 'https://$trimmed';
    if (Uri.tryParse(normalizedUrl) == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.premiumInvalidUrl),
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
            content: Text(l10n.premiumOpenPaymentError('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.premiumOpenPaymentError('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _notifyPaymentDone() async {
    final l10n = AppLocalizations.of(context)!;
    if (!widget.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.premiumVerifyEmailBeforeNotifyPayment),
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
            languageCode: Localizations.localeOf(context).languageCode,
          );
      if (!mounted) return;
      final homeRoute =
          authService.isPatientAreaUser ? 'paciente_home' : 'home';
      Navigator.of(context).pushNamedAndRemoveUntil(
        homeRoute,
        (route) => false,
        arguments: {
          premiumPaymentConfirmationArgumentKey: true,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.premiumNotifyPaymentError('$e')),
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
    final l10n = AppLocalizations.of(context)!;
    final authService = context.watch<AuthService>();
    final concept = _resolvePaymentConcept(authService);
    final detailLines = _resolveMethodSteps(authService);
    final amountText = _resolvePriceAmount(_selectedPeriodMonths);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.premiumCompletePaymentTitle)),
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
            l10n.premiumPaymentConceptLabel,
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
                    l10n.premiumStepsFor(widget.option.label),
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
                  if (widget.option.kind == 'bizum' &&
                      widget.nutritionistPhone.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(
                            l10n.premiumBizumPhoneLabel,
                            widget.nutritionistPhone.trim(),
                          ),
                          icon: const Icon(Icons.copy_rounded),
                          label: Text(l10n.premiumCopyPhone),
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
                          label: Text(l10n.premiumOpenPayment),
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
            child: Text(
              l10n.premiumAfterPaymentNotice,
              style: const TextStyle(fontWeight: FontWeight.w800),
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
                    ? l10n.premiumSendingNotification
                    : l10n.premiumIHavePaid,
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
