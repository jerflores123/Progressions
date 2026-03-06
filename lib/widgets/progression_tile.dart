import 'package:flutter/material.dart';

import '../models/progression.dart';

/// A tile displaying a chord in the progression with a measure selector and
/// a remove button.  When [showDragHandle] is true an explicit drag handle is
/// rendered (used inside ReorderableListView).
class ProgressionTile extends StatelessWidget {
  final ChordEntry entry;
  final int index;
  final bool isActive;
  final ValueChanged<int> onMeasuresChanged;
  final VoidCallback onRemove;
  final bool showDragHandle;

  const ProgressionTile({
    super.key,
    required this.entry,
    required this.index,
    this.isActive = false,
    required this.onMeasuresChanged,
    required this.onRemove,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = isActive
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final fgColor = isActive
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: colorScheme.primary, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Index badge
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.primary.withOpacity(0.2),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Chord name
          Expanded(
            child: Text(
              entry.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
          ),
          // Measure selector chips
          ...[1, 2, 4].map((m) => Padding(
                padding: const EdgeInsets.only(left: 4),
                child: ChoiceChip(
                  label: Text('$m'),
                  selected: entry.measures == m,
                  onSelected: (_) => onMeasuresChanged(m),
                  selectedColor: colorScheme.primary,
                  labelStyle: TextStyle(
                    color: entry.measures == m
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              )),
          const SizedBox(width: 8),
          // Remove button
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onRemove,
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // Drag handle (only inside ReorderableListView)
          if (showDragHandle) ...[
            const SizedBox(width: 4),
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle, size: 24),
            ),
          ],
        ],
      ),
    );
  }
}
