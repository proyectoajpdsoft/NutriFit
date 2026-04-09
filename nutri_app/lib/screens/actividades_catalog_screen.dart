import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';

class ActividadesCatalogScreen extends StatelessWidget {
  const ActividadesCatalogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navActivities),
      ),
      body: Center(
        child: Text(l10n.activitiesCatalogTitle),
      ),
    );
  }
}
