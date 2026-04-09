import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:provider/provider.dart';

class _AppLanguageOption {
  const _AppLanguageOption({
    required this.code,
    required this.flagBuilder,
  });

  final String code;
  final Widget Function() flagBuilder;
}

const List<_AppLanguageOption> _languageOptions = [
  _AppLanguageOption(code: 'es', flagBuilder: _buildSpainFlag),
  _AppLanguageOption(code: 'en', flagBuilder: _buildUkFlag),
  _AppLanguageOption(code: 'it', flagBuilder: _buildItalyFlag),
  _AppLanguageOption(code: 'de', flagBuilder: _buildGermanyFlag),
  _AppLanguageOption(code: 'fr', flagBuilder: _buildFranceFlag),
  _AppLanguageOption(code: 'pt', flagBuilder: _buildPortugalFlag),
];

Widget _buildFlagFrame({required Widget child}) {
  return Container(
    width: 22,
    height: 16,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0x1F000000)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: child,
  );
}

Widget _buildHorizontalTricolor({
  required Color top,
  required Color middle,
  required Color bottom,
}) {
  return _buildFlagFrame(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            heightFactor: 1 / 3,
            widthFactor: 1,
            child: ColoredBox(color: top),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: FractionallySizedBox(
            heightFactor: 1 / 3,
            widthFactor: 1,
            child: ColoredBox(color: middle),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 1 / 3,
            widthFactor: 1,
            child: ColoredBox(color: bottom),
          ),
        ),
      ],
    ),
  );
}

Widget _buildVerticalTricolor({
  required Color left,
  required Color center,
  required Color right,
  int leftFlex = 1,
  int centerFlex = 1,
  int rightFlex = 1,
}) {
  final totalFlex = leftFlex + centerFlex + rightFlex;
  final leftWidth = leftFlex / totalFlex;
  final centerWidth = centerFlex / totalFlex;
  final rightStart = (leftFlex + centerFlex) / totalFlex;

  return _buildFlagFrame(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: leftWidth,
            heightFactor: 1,
            child: ColoredBox(color: left),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 22 * leftWidth),
            child: FractionallySizedBox(
              widthFactor: centerWidth,
              heightFactor: 1,
              alignment: Alignment.centerLeft,
              child: ColoredBox(color: center),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 1 - rightStart,
            heightFactor: 1,
            child: ColoredBox(color: right),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSpainFlag() => _buildHorizontalTricolor(
      top: const Color(0xFFAA151B),
      middle: const Color(0xFFF1BF00),
      bottom: const Color(0xFFAA151B),
    );

Widget _buildItalyFlag() => _buildVerticalTricolor(
      left: const Color(0xFF009246),
      center: Colors.white,
      right: const Color(0xFFCE2B37),
    );

Widget _buildGermanyFlag() => _buildHorizontalTricolor(
      top: Colors.black,
      middle: const Color(0xFFDD0000),
      bottom: const Color(0xFFFFCE00),
    );

Widget _buildFranceFlag() => _buildVerticalTricolor(
      left: const Color(0xFF0055A4),
      center: Colors.white,
      right: const Color(0xFFEF4135),
    );

Widget _buildPortugalFlag() => _buildVerticalTricolor(
      left: const Color(0xFF006600),
      center: const Color(0xFF006600),
      right: const Color(0xFFFF0000),
      leftFlex: 2,
      centerFlex: 1,
      rightFlex: 2,
    );

Widget _buildUkFlag() {
  return _buildFlagFrame(
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF012169)),
        Center(
          child: Container(width: 22, height: 4, color: Colors.white),
        ),
        Center(
          child: Container(width: 4, height: 16, color: Colors.white),
        ),
        Center(
          child:
              Container(width: 22, height: 2, color: const Color(0xFFC8102E)),
        ),
        Center(
          child:
              Container(width: 2, height: 16, color: const Color(0xFFC8102E)),
        ),
      ],
    ),
  );
}

class AppLanguageDropdown extends StatelessWidget {
  const AppLanguageDropdown({
    super.key,
    this.compact = false,
    this.compactHeight = 34,
  });

  final bool compact;
  final double compactHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<ConfigService>(
      builder: (context, configService, _) {
        final selectedCode = configService.appLocale.languageCode;

        Widget buildOption(_AppLanguageOption option,
            {required bool compactUi}) {
          return Row(
            mainAxisSize: compactUi ? MainAxisSize.min : MainAxisSize.max,
            children: [
              option.flagBuilder(),
              SizedBox(width: compactUi ? 4 : 8),
              if (compactUi)
                Text(
                  option.code.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                )
              else
                Expanded(
                  child: Text(
                    _labelForCode(l10n, option.code),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          );
        }

        Widget buildDropdown() {
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: compact,
              value: selectedCode,
              icon: Icon(
                Icons.arrow_drop_down,
                size: compact ? 18 : 24,
              ),
              items: _languageOptions.map((option) {
                return DropdownMenuItem<String>(
                  value: option.code,
                  child: buildOption(option, compactUi: compact),
                );
              }).toList(),
              selectedItemBuilder: (context) {
                return _languageOptions
                    .map((option) => buildOption(option, compactUi: compact))
                    .toList();
              },
              onChanged: (value) {
                if (value == null) return;
                context.read<ConfigService>().setPreferredLanguageCode(value);
              },
            ),
          );
        }

        if (compact) {
          return Container(
            height: compactHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: buildDropdown(),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.commonLanguage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: buildDropdown(),
            ),
          ],
        );
      },
    );
  }

  String _labelForCode(AppLocalizations l10n, String code) {
    switch (code) {
      case 'es':
        return l10n.languageSpanish;
      case 'en':
        return l10n.languageEnglish;
      case 'it':
        return l10n.languageItalian;
      case 'de':
        return l10n.languageGerman;
      case 'fr':
        return l10n.languageFrench;
      case 'pt':
        return l10n.languagePortuguese;
      default:
        return code.toUpperCase();
    }
  }
}
