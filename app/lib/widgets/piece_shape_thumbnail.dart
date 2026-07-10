import 'package:flutter/material.dart';
import 'package:ubongo_core/ubongo_core.dart';

/// A small diagram of a piece's actual shape — literally the squares it's
/// made of, colored in — rather than a text label or a photo. This is
/// deliberately not a photo of a real physical piece: the catalog these
/// shapes come from is a placeholder (not yet inventoried from a real
/// Ubongo copy), so a stock photo would show a *different* shape than
/// what the solver actually reasons about. Drawing the exact cells this
/// piece occupies is unambiguous and always accurate, whatever the
/// catalog turns out to be.
class PieceShapeThumbnail extends StatelessWidget {
  final Set<CellCoord> cells;
  final Color color;
  final double cellSize;

  const PieceShapeThumbnail({
    super.key,
    required this.cells,
    required this.color,
    this.cellSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final maxRow = cells.map((c) => c.row).reduce((a, b) => a > b ? a : b);
    final maxCol = cells.map((c) => c.col).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      width: (maxCol + 1) * cellSize,
      height: (maxRow + 1) * cellSize,
      child: Stack(
        children: [
          for (final cell in cells)
            Positioned(
              left: cell.col * cellSize,
              top: cell.row * cellSize,
              width: cellSize,
              height: cellSize,
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A generic "N cells, any shape" placeholder — used for gray/"any
/// piece this size" slots, where there genuinely isn't one fixed shape
/// to draw. A row of N dashed outline squares reads as "this many
/// squares, shape flexible" rather than implying a specific piece.
class AnyShapeThumbnail extends StatelessWidget {
  final int cellCount;
  final double cellSize;

  const AnyShapeThumbnail({super.key, required this.cellCount, this.cellSize = 12});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cellCount * cellSize,
      height: cellSize,
      child: Row(
        children: [
          for (var i = 0; i < cellCount; i++)
            Padding(
              padding: const EdgeInsets.all(1),
              child: Container(
                width: cellSize - 2,
                height: cellSize - 2,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
