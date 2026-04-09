import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';

import 'restricted_access_dialog_helper.dart';

class PremiumFeatureDialogHelper {
  static Future<void> show(
    BuildContext context, {
    String? title,
    required String message,
    String? primaryActionLabel,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return RestrictedAccessDialogHelper.show(
      context,
      title: title ?? l10n.commonPremiumFeatureTitle,
      message: message,
      primaryActionLabel: primaryActionLabel ?? l10n.navPremium,
      primaryActionIcon: Icons.workspace_premium,
      primaryRouteName: '/premium_info',
    );
  }
}
