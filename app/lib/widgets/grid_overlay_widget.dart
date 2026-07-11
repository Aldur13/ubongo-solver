import 'package:flutter/material.dart';
import 'package:ubongo_core/ubongo_core.dart';

/// Minimum on-screen size (in logical pixels) a tappable cell should ever
/// be rendered at — Material's own minimum recommended touch target.
/// Callers that let [GridOverlayWidget] size itself down to fit a screen
/// (e.g. a 10+-column grid on a narrow phone) should instead give this
/// widget a fixed size of at least `width/height * kMinGridCellSize` per
/// axis and let the user pan/zoom (e.g. via `InteractiveViewer`) rather
/// than shrinking cells past this — see `GridMarkupScreen` and
/// `ManualEntryScreen` for the pattern.
const kMinGridCellSize = 48.0;

/// A [width] x [height] grid, shared by the manual board-markup screens
/// (interactive: tapping toggles a cell) and the solution screen
/// (read-only: cells colored/labeled by piece placement).
class GridOverlayWidget extends StatelessWidget {
  final int width;
  final int height;
  final Set<CellCoord> filledCells;
  final Map<CellCoord, Color>? cellColors;
  final Map<CellCoord, String>? cellLabels;
  final void Function(CellCoord cell)? onCellTap;

  /// Set false when the caller already constrains this widget's aspect
  /// ratio itself (e.g. stacking it over a background image at the same
  /// width/height ratio) — avoids nesting a redundant AspectRatio.
  final bool useAspectRatio;

  const GridOverlayWidget({
    super.key,
    required this.width,
    required this.height,
    this.filledCells = const {},
    this.cellColors,
    this.cellLabels,
    this.onCellTap,
    this.useAspectRatio = true,
  });

  @override
  Widget build(BuildContext context) {
    final defaultFillColor = Theme.of(context).colorScheme.primaryContainer;
    final grid = GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: width),
      itemCount: width * height,
      itemBuilder: (context, index) {
        final x = index % width;
        final y = index ~/ width;
        final cell = CellCoord(y, x);
        final isFilled = filledCells.contains(cell);
        final color = cellColors?[cell] ??
            (isFilled ? defaultFillColor : Colors.transparent);
        final label = cellLabels?[cell];

        return GestureDetector(
          onTap: onCellTap == null ? null : () => onCellTap!(cell),
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: label == null
                ? null
                : Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
          ),
        );
      },
    );

    return useAspectRatio ? AspectRatio(aspectRatio: width / height, child: grid) : grid;
  }
}
