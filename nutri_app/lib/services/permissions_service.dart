import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  /// URL Launcher disabled - feature temporarily disabled
  // /// Abre una URL, solicitando permisos solo para tel:
  // static Future<void> launchUrl(
  //   Uri uri, {
  //   url_launcher.LaunchMode mode = url_launcher.LaunchMode.externalApplication,
  //   required BuildContext context,
  // }) async {
  //   // Solo para tel: solicitar permiso antes de lanzar
  //   if (uri.scheme == 'tel') {
  //     final hasPermission = await requestPermission(Permission.phone, context);
  //     if (!hasPermission) {
  //       return;
  //     }
  //   }
  //
  //   // Lanzar la URL directamente y verificar el retorno
  //   try {
  //     final launched = await url_launcher.launchUrl(uri, mode: mode);
  //     if (!launched && context.mounted) {
  //       // URL no se pudo abrir
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('No se pudo abrir el enlace'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Error al abrir el enlace'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   }
  // }

  /// Solicita el permiso requerido y retorna true si se concede
  static Future<bool> requestPermission(
      Permission permission, BuildContext context) async {
    final status = await permission.request();

    if (status.isDenied) {
      _showPermissionDeniedDialog(context, permission);
      return false;
    } else if (status.isPermanentlyDenied) {
      _showPermissionPermanentlyDeniedDialog(context, permission);
      return false;
    } else if (status.isGranted) {
      return true;
    } else if (status.isRestricted || status.isLimited) {
      _showPermissionLimitedDialog(context, permission);
      return false;
    }
    return false;
  }

  /// Verifica si un permiso está concedido
  static Future<bool> hasPermission(Permission permission) async {
    return await permission.status.isGranted;
  }

  /// Solicita múltiples permisos
  static Future<Map<Permission, PermissionStatus>> requestMultiplePermissions(
    List<Permission> permissions,
  ) async {
    return await permissions.request();
  }

  static void _showPermissionDeniedDialog(
      BuildContext context, Permission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso denegado'),
        content: Text(_getPermissionMessage(permission)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  static void _showPermissionPermanentlyDeniedDialog(
      BuildContext context, Permission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso denegado permanentemente'),
        content: Text(
          '${_getPermissionMessage(permission)}\n\nPuedes cambiar esto en la configuración de la aplicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Abrir configuración'),
          ),
        ],
      ),
    );
  }

  static void _showPermissionLimitedDialog(
      BuildContext context, Permission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso limitado'),
        content: Text(_getPermissionMessage(permission)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  static String _getPermissionMessage(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'Necesitamos acceso a la cámara para que puedas tomar una foto de perfil.';
      case Permission.contacts:
        return 'Necesitamos acceso a tus contactos para esta acción.';
      case Permission.phone:
        return 'Necesitamos permiso para realizar llamadas desde la aplicación.';
      case Permission.storage:
        return 'Necesitamos acceso al almacenamiento para guardar y acceder a archivos.';
      default:
        return 'Esta aplicación necesita permisos para continuar.';
    }
  }
}
