import 'package:flutter/material.dart';
import 'package:nutri_app/services/config_service.dart';

class PasswordPolicyRequirements {
  const PasswordPolicyRequirements({
    required this.minLength,
    required this.requireUpperLower,
    required this.requireNumbers,
    required this.requireSpecialChars,
  });

  final int minLength;
  final bool requireUpperLower;
  final bool requireNumbers;
  final bool requireSpecialChars;

  factory PasswordPolicyRequirements.fromConfig(ConfigService config) {
    return PasswordPolicyRequirements(
      minLength: config.passwordMinLength,
      requireUpperLower: config.passwordRequireUpperLower,
      requireNumbers: config.passwordRequireNumbers,
      requireSpecialChars: config.passwordRequireSpecialChars,
    );
  }

  factory PasswordPolicyRequirements.fromRecoveryPolicy(
    Map<String, dynamic> policy,
  ) {
    final min = int.tryParse(policy['min_length']?.toString() ?? '') ?? 8;
    return PasswordPolicyRequirements(
      minLength: min > 0 ? min : 8,
      requireUpperLower: policy['require_upper_lower'] == true,
      requireNumbers: policy['require_numbers'] == true,
      requireSpecialChars: policy['require_special_chars'] == true,
    );
  }
}

class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist({
    super.key,
    required this.policy,
    required this.password,
    this.title = 'Requisitos de contraseña:',
  });

  final PasswordPolicyRequirements policy;
  final String password;
  final String title;

  bool get _hasUpper => password.contains(RegExp(r'[A-Z]'));
  bool get _hasLower => password.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => password.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial => password.contains(RegExp(r'[*,.+\-#$?¿!¡_()\/\\%&]'));

  Widget _requirementItem(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.cancel,
            color: met ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: met ? Colors.green.shade700 : Colors.red.shade700,
                fontSize: 13,
                fontWeight: met ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 8),
          _requirementItem(
            'Mínimo ${policy.minLength} caracteres',
            password.length >= policy.minLength,
          ),
          if (policy.requireUpperLower)
            _requirementItem('Al menos una mayúscula y una minúscula',
                _hasUpper && _hasLower),
          if (policy.requireNumbers)
            _requirementItem('Al menos un número (0-9)', _hasNumber),
          if (policy.requireSpecialChars)
            _requirementItem(
              'Al menos un carácter especial (*,.+-#\$?¿!¡_()/\\%&)',
              _hasSpecial,
            ),
        ],
      ),
    );
  }
}
