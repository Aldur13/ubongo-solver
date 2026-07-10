import 'cell_coord.dart';
import 'orientation.dart';

/// A single Ubongo puzzle piece: a fixed polyomino shape, identified by
/// [id], with all its distinct rotation/reflection orientations
/// precomputed.
class Piece {
  final String id;
  final String name;
  final Set<CellCoord> cells;
  final List<Orientation> orientations;

  Piece({
    required this.id,
    required this.name,
    required Set<CellCoord> cells,
    bool allowReflection = true,
  })  : cells = cells,
        orientations =
            generateOrientations(cells, allowReflection: allowReflection);

  int get cellCount => cells.length;

  @override
  String toString() => 'Piece($id, $name, $cellCount cells)';
}

CellCoord _c(int row, int col) => CellCoord(row, col);

/// PLACEHOLDER piece catalog.
///
/// This is NOT the verified real-world classic-Ubongo piece set — it's a
/// stand-in set of 12 distinct polyomino shapes (sizes 2-5, matching the
/// game's documented piece-size range) used so the solver, app, and tests
/// have something concrete to run against.
///
/// Before relying on this for real physical cards, replace it with the
/// actual catalog inventoried from a physical copy (shape, color, and
/// letter/id for each of the 12 pieces) — see the project plan's
/// "Piece catalog accuracy" risk note.
class UbongoCatalog {
  static final List<Piece> classic = [
    Piece(id: 'P1', name: 'placeholder-domino', cells: {
      _c(0, 0), _c(0, 1),
    }),
    Piece(id: 'P2', name: 'placeholder-triomino-straight', cells: {
      _c(0, 0), _c(0, 1), _c(0, 2),
    }),
    Piece(id: 'P3', name: 'placeholder-triomino-corner', cells: {
      _c(0, 0), _c(0, 1), _c(1, 0),
    }),
    Piece(id: 'P4', name: 'placeholder-tetromino-square', cells: {
      _c(0, 0), _c(0, 1), _c(1, 0), _c(1, 1),
    }),
    Piece(id: 'P5', name: 'placeholder-tetromino-line', cells: {
      _c(0, 0), _c(0, 1), _c(0, 2), _c(0, 3),
    }),
    Piece(id: 'P6', name: 'placeholder-tetromino-L', cells: {
      _c(0, 0), _c(1, 0), _c(2, 0), _c(2, 1),
    }),
    Piece(id: 'P7', name: 'placeholder-tetromino-T', cells: {
      _c(0, 0), _c(0, 1), _c(0, 2), _c(1, 1),
    }),
    Piece(id: 'P8', name: 'placeholder-tetromino-S', cells: {
      _c(0, 1), _c(0, 2), _c(1, 0), _c(1, 1),
    }),
    Piece(id: 'P9', name: 'placeholder-pentomino-P', cells: {
      _c(0, 0), _c(0, 1), _c(1, 0), _c(1, 1), _c(2, 0),
    }),
    Piece(id: 'P10', name: 'placeholder-pentomino-L', cells: {
      _c(0, 0), _c(1, 0), _c(2, 0), _c(3, 0), _c(3, 1),
    }),
    Piece(id: 'P11', name: 'placeholder-pentomino-T', cells: {
      _c(0, 0), _c(0, 1), _c(0, 2), _c(1, 1), _c(2, 1),
    }),
    Piece(id: 'P12', name: 'placeholder-pentomino-Z', cells: {
      _c(0, 0), _c(0, 1), _c(1, 1), _c(2, 1), _c(2, 2),
    }),
  ];
}
