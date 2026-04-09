import 'package:package_info_plus/package_info_plus.dart';

class AppVersionService {
  static Future<PackageInfo>? _packageInfoFuture;
  static Future<String>? _versionFuture;
  static Future<String>? _versionLabelFuture;

  static Future<String> getVersion() {
    _versionFuture ??= _loadVersion();
    return _versionFuture!;
  }

  static Future<String> getVersionLabel() {
    _versionLabelFuture ??= _loadVersionLabel();
    return _versionLabelFuture!;
  }

  static Future<String> getVersionKey() async {
    final packageInfo = await _loadPackageInfo();
    final version = packageInfo.version.trim();
    final buildNumber = packageInfo.buildNumber.trim();

    if (version.isEmpty && buildNumber.isEmpty) {
      return 'unknown';
    }
    if (buildNumber.isEmpty) {
      return version;
    }
    if (version.isEmpty) {
      return buildNumber;
    }
    return '$version+$buildNumber';
  }

  static Future<PackageInfo> _loadPackageInfo() {
    _packageInfoFuture ??= PackageInfo.fromPlatform();
    return _packageInfoFuture!;
  }

  static Future<String> _loadVersion() async {
    final packageInfo = await _loadPackageInfo();
    final version = packageInfo.version.trim();
    if (version.isEmpty) {
      return 'Versión no disponible';
    }
    return version;
  }

  static Future<String> _loadVersionLabel() async {
    final packageInfo = await _loadPackageInfo();
    final version = packageInfo.version.trim();
    final buildNumber = packageInfo.buildNumber.trim();

    if (version.isEmpty && buildNumber.isEmpty) {
      return 'Versión no disponible';
    }
    if (buildNumber.isEmpty) {
      return version;
    }
    if (version.isEmpty) {
      return buildNumber;
    }
    return '$version ($buildNumber)';
  }
}
