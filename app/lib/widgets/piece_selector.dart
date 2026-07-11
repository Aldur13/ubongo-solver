import 'package:flutter/material.dart';
import 'package:ubongo_core/ubongo_core.dart';

import 'piece_shape_thumbnail.dart';

// Colors sampled from a photo of the user's physical piece set — one
// distinct color per piece (the real set doesn't repeat colors across its
// 12 pieces, unlike the placeholder cyclic palette this replaced). Best
// effort at matching each color to its corresponding catalog shape from
// the photo; report a mismatch by piece ID and it can be corrected the
// same way P11 was.
const _pieceColors = {
  'P1': Color(0xFF7A2F52), // maroon/plum
  'P2': Color(0xFF3DA8D6), // light blue
  'P3': Color(0xFF2A6E62), // dark teal
  'P4': Color(0xFFD2542C), // red-orange
  'P5': Color(0xFFA9C93B), // chartreuse
  'P6': Color(0xFFD16C8C), // pink
  'P7': Color(0xFFF0C233), // yellow
  'P8': Color(0xFF34876E), // teal-green
  'P9': Color(0xFF4C9E4C), // green
  'P10': Color(0xFFDE9A40), // amber
  'P11': Color(0xFFE67A22), // orange
  'P12': Color(0xFF5A6B93), // slate blue
};

Color _colorFor(String pieceId) => _pieceColors[pieceId] ?? Colors.grey;

/// The "Required pieces" picker: for each catalog piece, a shape diagram
/// (see [PieceShapeThumbnail] — deliberately a diagram, not a photo, since
/// the shapes are exact but the catalog is a placeholder) plus a +/-
/// quantity stepper, so "how many of this piece" is a single visible
/// number instead of counting repeated taps. Gray ("any piece this size")
/// requirements get their own stepper per cell count. Shared by the
/// fully-manual entry screen and the post-scan piece selection screen.
class PieceSelector extends StatelessWidget {
  final List<Piece> catalog;
  final int Function(Piece piece) solidCountOf;
  final void Function(Piece piece, int count) onSetSolidCount;
  final int Function(int cellCount) grayCountOf;
  final void Function(int cellCount, int count) onSetGrayCount;

  const PieceSelector({
    super.key,
    required this.catalog,
    required this.solidCountOf,
    required this.onSetSolidCount,
    required this.grayCountOf,
    required this.onSetGrayCount,
  });

  @override
  Widget build(BuildContext context) {
    final cellCounts = {for (final p in catalog) p.cellCount}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.extension, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('Required pieces', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        Text('Exact piece', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        for (var i = 0; i < catalog.length; i++)
          _PieceCountRow(
            thumbnail: PieceShapeThumbnail(
              cells: catalog[i].cells,
              color: _colorFor(catalog[i].id),
            ),
            label: '${catalog[i].id} — ${catalog[i].name} (${catalog[i].cellCount} cells)',
            count: solidCountOf(catalog[i]),
            onChanged: (count) => onSetSolidCount(catalog[i], count),
          ),
        const SizedBox(height: 12),
        Text('Any piece of this size', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        for (final cellCount in cellCounts)
          _PieceCountRow(
            thumbnail: AnyShapeThumbnail(cellCount: cellCount),
            label: 'Any $cellCount-cell piece',
            count: grayCountOf(cellCount),
            onChanged: (count) => onSetGrayCount(cellCount, count),
          ),
      ],
    );
  }
}

class _PieceCountRow extends StatelessWidget {
  final Widget thumbnail;
  final String label;
  final int count;
  final ValueChanged<int> onChanged;

  const _PieceCountRow({
    required this.thumbnail,
    required this.label,
    required this.count,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = count > 0;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 48,
            child: FittedBox(fit: BoxFit.scaleDown, child: thumbnail),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            visualDensity: VisualDensity.compact,
            onPressed: count > 0 ? () => onChanged(count - 1) : null,
          ),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(count + 1),
          ),
        ],
      ),
    );
  }
}
