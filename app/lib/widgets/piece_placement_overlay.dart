import 'package:flutter/material.dart';
import 'package:ubongo_core/ubongo_core.dart';

/// Derives per-cell colors and labels from a solved [Solution] so it can
/// be handed straight to [GridOverlayWidget].
class PiecePlacementOverlay {
  static const _palette = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];

  static Color colorForSlot(int slotIndex) => _palette[slotIndex % _palette.length];

  static Map<CellCoord, Color> colorsFor(Solution solution) {
    final map = <CellCoord, Color>{};
    for (final placed in solution.placements) {
      final color = colorForSlot(placed.slotIndex);
      for (final cell in placed.cells) {
        map[cell] = color;
      }
    }
    return map;
  }

  static Map<CellCoord, String> labelsFor(Solution solution) {
    final map = <CellCoord, String>{};
    for (final placed in solution.placements) {
      for (final cell in placed.cells) {
        map[cell] = placed.piece.id;
      }
    }
    return map;
  }
}
