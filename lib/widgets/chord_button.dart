import 'package:flutter/material.dart';

/// Large, touch-friendly button for selecting a chord.
class ChordButton extends StatelessWidget {
  final String label;
  final String? romanNumeral;
  final VoidCallback onTap;
  final bool highlighted;

  const ChordButton({
    super.key,
    required this.label,
    this.romanNumeral,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: highlighted
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 80, minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: highlighted
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
              ),
              if (romanNumeral != null) ...[
                const SizedBox(height: 2),
                Text(
                  romanNumeral!,
                  style: TextStyle(
                    fontSize: 13,
                    color: highlighted
                        ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
