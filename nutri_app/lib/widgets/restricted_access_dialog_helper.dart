import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/screens/contacto_nutricionista_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:url_launcher/url_launcher_string.dart';

class RestrictedAccessDialogHelper {
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? message,
    String? primaryActionLabel,
    IconData? primaryActionIcon,
    String? primaryRouteName,
    VoidCallback? onPrimaryAction,
  }) async {
    final apiService = ApiService();
    String email = '';
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    try {
      final emailParam = await apiService.getParametro('nutricionista_email');
      email = emailParam?['valor']?.toString() ?? '';
    } catch (_) {}

    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context)!;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
        title: Row(
          children: [
            Icon(
              Icons.lock_outline,
              color: Theme.of(dialogContext).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: l10n.commonClose,
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
                    const Icon(Icons.info_outline,
                        color: Colors.deepOrange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message ?? l10n.restrictedAccessGenericMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (primaryActionLabel != null &&
                  (onPrimaryAction != null ||
                      (primaryRouteName != null &&
                          primaryRouteName.trim().isNotEmpty))) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      if (primaryRouteName != null &&
                          primaryRouteName.trim().isNotEmpty) {
                        rootNavigator.pushNamed(primaryRouteName);
                        return;
                      }
                      onPrimaryAction?.call();
                    },
                    icon: Icon(primaryActionIcon ?? Icons.workspace_premium,
                        size: 18),
                    label: Text(primaryActionLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                l10n.restrictedAccessContactMethods,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _buildDialogContactRow(
                context: dialogContext,
                icon: Icons.email,
                label: l10n.commonEmail,
                value: email.isNotEmpty ? email : l10n.commonUnavailable,
                onTap: email.isNotEmpty
                    ? () => _launchUrl('mailto:$email')
                    : () {},
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    rootNavigator.push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const ContactoNutricionistaScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(l10n.restrictedAccessMoreContactOptions),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildDialogContactRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  static Future<void> _launchUrl(String url) async {
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
