import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';

String deleteAccountConfirmationKeyword(BuildContext context) {
  final languageCode = Localizations.localeOf(context).languageCode;
  return languageCode.toLowerCase().startsWith('es') ? 'ELIMINAR' : 'DELETE';
}

Future<bool> showTypedDeleteAccountConfirmation(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final keyword = deleteAccountConfirmationKeyword(context);
  final controller = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.privacyDeleteTypedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.privacyDeleteDialogWarning),
          const SizedBox(height: 10),
          Text(l10n.privacyDeleteTypedPrompt(keyword)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: l10n.privacyDeleteTypedHint(keyword),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            if (controller.text.trim() != keyword) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text(l10n.privacyDeleteTypedMismatch(keyword)),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.of(dialogContext).pop(true);
          },
          child: Text(l10n.privacyDeleteMyData),
        ),
      ],
    ),
  );

  controller.dispose();
  return result == true;
}
