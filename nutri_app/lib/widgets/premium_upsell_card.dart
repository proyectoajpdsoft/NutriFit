import 'package:flutter/material.dart';

class PremiumUpsellCard extends StatelessWidget {
  const PremiumUpsellCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.subtitleHighlight,
    this.subtitleHighlightColor,
    this.buttonLabel = 'Hazte premium',
    this.onPressed,
  });

  final String title;
  final String subtitle;
  final String? subtitleHighlight;
  final Color? subtitleHighlightColor;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [Colors.purple.shade50, Colors.deepPurple.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.purple.shade100),
        ),
        child: Column(
          children: [
            Icon(
              Icons.workspace_premium,
              size: 44,
              color: Colors.deepPurple.shade400,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.deepPurple.shade600,
                  height: 1.35,
                ),
                children: [
                  TextSpan(text: subtitle),
                  if ((subtitleHighlight ?? '').isNotEmpty)
                    TextSpan(
                      text: subtitleHighlight,
                      style: TextStyle(
                        color: subtitleHighlightColor ??
                            Colors.deepOrange.shade700,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.workspace_premium),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
