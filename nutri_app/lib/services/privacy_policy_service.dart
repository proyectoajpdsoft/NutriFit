import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

abstract class PrivacyPolicyBlock {
  const PrivacyPolicyBlock();
}

class PrivacyPolicyParagraphBlock extends PrivacyPolicyBlock {
  const PrivacyPolicyParagraphBlock(this.text);

  final String text;
}

class PrivacyPolicyBulletListBlock extends PrivacyPolicyBlock {
  const PrivacyPolicyBulletListBlock(this.items);

  final List<String> items;
}

class PrivacyPolicyStepListBlock extends PrivacyPolicyBlock {
  const PrivacyPolicyStepListBlock(this.items);

  final List<String> items;
}

class PrivacyPolicySection {
  const PrivacyPolicySection({
    required this.title,
    this.blocks = const <PrivacyPolicyBlock>[],
  });

  final String title;
  final List<PrivacyPolicyBlock> blocks;
}

class PrivacyPolicyService {
  const PrivacyPolicyService._();

  static String policyTitle(AppLocalizations l10n) => l10n.privacyPolicyTitle;

  static String lastUpdated(AppLocalizations l10n) =>
      l10n.privacyPolicyLastUpdated;

  static List<PrivacyPolicySection> sections(AppLocalizations l10n) => [
        PrivacyPolicySection(
          title: l10n.privacyPolicySection1Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection1Paragraph1),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection1Paragraph2),
            PrivacyPolicyBulletListBlock([
              l10n.privacyPolicySection1Bullet1,
              l10n.privacyPolicySection1Bullet2,
              l10n.privacyPolicySection1Bullet3,
              l10n.privacyPolicySection1Bullet4,
            ]),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection2Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection2Paragraph1),
            PrivacyPolicyBulletListBlock([
              l10n.privacyPolicySection2Bullet1,
              l10n.privacyPolicySection2Bullet2,
              l10n.privacyPolicySection2Bullet3,
            ]),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection3Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection3Paragraph1),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection4Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection4Paragraph1),
            PrivacyPolicyBulletListBlock([
              l10n.privacyPolicySection4Bullet1,
              l10n.privacyPolicySection4Bullet2,
              l10n.privacyPolicySection4Bullet3,
              l10n.privacyPolicySection4Bullet4,
              l10n.privacyPolicySection4Bullet5,
              l10n.privacyPolicySection4Bullet6,
              l10n.privacyPolicySection4Bullet7,
              l10n.privacyPolicySection4Bullet8,
              l10n.privacyPolicySection4Bullet9,
              l10n.privacyPolicySection4Bullet10,
            ]),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection4Paragraph2),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection5Title,
          blocks: [
            PrivacyPolicyBulletListBlock([
              l10n.privacyPolicySection5Bullet1,
              l10n.privacyPolicySection5Bullet2,
              l10n.privacyPolicySection5Bullet3,
              l10n.privacyPolicySection5Bullet4,
              l10n.privacyPolicySection5Bullet5,
              l10n.privacyPolicySection5Bullet6,
              l10n.privacyPolicySection5Bullet7,
              l10n.privacyPolicySection5Bullet8,
              l10n.privacyPolicySection5Bullet9,
              l10n.privacyPolicySection5Bullet10,
              l10n.privacyPolicySection5Bullet11,
            ]),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection6Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection6Paragraph1),
            PrivacyPolicyBulletListBlock([
              l10n.privacyPolicySection6Bullet1,
              l10n.privacyPolicySection6Bullet2,
              l10n.privacyPolicySection6Bullet3,
              l10n.privacyPolicySection6Bullet4,
            ]),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection6Paragraph2),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection7Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection7Paragraph1),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection7Paragraph2),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection8Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection8Paragraph1),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection8Paragraph2),
            PrivacyPolicyStepListBlock([
              l10n.privacyPolicySection8Step1,
              l10n.privacyPolicySection8Step2,
              l10n.privacyPolicySection8Step3,
              l10n.privacyPolicySection8Step4,
              l10n.privacyPolicySection8Step5,
            ]),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection8Paragraph3),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection8Paragraph4),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection9Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection9Paragraph1),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection9Paragraph2),
            PrivacyPolicyBulletListBlock([
              l10n.privacyPolicySection9Bullet1,
              l10n.privacyPolicySection9Bullet2,
              l10n.privacyPolicySection9Bullet3,
            ]),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection9Paragraph3),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection10Title,
          blocks: [
            PrivacyPolicyParagraphBlock(
              l10n.privacyPolicySection10Paragraph1,
            ),
            PrivacyPolicyBulletListBlock([
              l10n.privacyPolicySection10Bullet1,
              l10n.privacyPolicySection10Bullet2,
              l10n.privacyPolicySection10Bullet3,
              l10n.privacyPolicySection10Bullet4,
              l10n.privacyPolicySection10Bullet5,
            ]),
            PrivacyPolicyParagraphBlock(
              l10n.privacyPolicySection10Paragraph2,
            ),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection11Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection11Paragraph1),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection11Paragraph2),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection12Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection12Paragraph1),
            PrivacyPolicyBulletListBlock([
              l10n.privacyPolicySection12Bullet1,
              l10n.privacyPolicySection12Bullet2,
              l10n.privacyPolicySection12Bullet3,
              l10n.privacyPolicySection12Bullet4,
              l10n.privacyPolicySection12Bullet5,
              l10n.privacyPolicySection12Bullet6,
              l10n.privacyPolicySection12Bullet7,
            ]),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection12Paragraph2),
            PrivacyPolicyBulletListBlock([
              l10n.privacyPolicySection12Bullet8,
              l10n.privacyPolicySection12Bullet9,
            ]),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection12Paragraph3),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection12Paragraph4),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection12Paragraph5),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection13Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection13Paragraph1),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection14Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection14Paragraph1),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection14Paragraph2),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection15Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection15Paragraph1),
          ],
        ),
        PrivacyPolicySection(
          title: l10n.privacyPolicySection16Title,
          blocks: [
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection16Paragraph1),
            PrivacyPolicyParagraphBlock(l10n.privacyPolicySection16Paragraph2),
          ],
        ),
      ];

  static Future<void> printPolicyPdf(BuildContext context) async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
          build: (context) => [
            pw.Text(
              policyTitle(l10n),
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              l10n.privacyLastUpdatedLabel(lastUpdated(l10n)),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 16),
            ...sections(l10n).expand(_buildPdfSection),
          ],
        ),
      );

      final bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Privacy_Policy_NutriFitApp.pdf',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.privacyPdfGenerateError(error.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static List<pw.Widget> _buildPdfSection(PrivacyPolicySection section) {
    return [
      pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 10, bottom: 6),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF7EAF4),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          section.title,
          style: const pw.TextStyle(fontSize: 12).copyWith(
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      ...section.blocks.expand(_buildPdfBlock),
    ];
  }

  static List<pw.Widget> _buildPdfBlock(PrivacyPolicyBlock block) {
    if (block is PrivacyPolicyParagraphBlock) {
      return [
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(
            block.text,
            style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2),
            textAlign: pw.TextAlign.justify,
          ),
        ),
      ];
    }

    if (block is PrivacyPolicyBulletListBlock) {
      return block.items
          .map(
            (bullet) => pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ', style: const pw.TextStyle(fontSize: 10.5)),
                  pw.Expanded(
                    child: pw.Text(
                      bullet,
                      style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2),
                      textAlign: pw.TextAlign.justify,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false);
    }

    if (block is PrivacyPolicyStepListBlock) {
      return block.items
          .asMap()
          .entries
          .map(
            (entry) => pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${entry.key + 1}. ',
                    style: const pw.TextStyle(fontSize: 10.5),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      entry.value,
                      style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false);
    }

    return const <pw.Widget>[];
  }
}
