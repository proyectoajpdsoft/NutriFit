import 'package:flutter/material.dart';
import 'package:nutri_app/services/app_version_service.dart';

class AppVersionLabel extends StatelessWidget {
  final String prefix;
  final String suffix;
  final TextStyle? style;

  const AppVersionLabel({
    super.key,
    this.prefix = '',
    this.suffix = '',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: AppVersionService.getVersion(),
      builder: (context, snapshot) {
        final version = snapshot.data ?? '...';
        return Text(
          '$prefix$version$suffix',
          style: style,
        );
      },
    );
  }
}
