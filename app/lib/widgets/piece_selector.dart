import 'package:flutter/material.dart';
import 'package:ubongo_core/ubongo_core.dart';

/// The "Required pieces" picker: the current slot list (each removable)
/// plus chips to add a solid (exact) piece or a gray (any-N-cell) slot.
/// Shared by the fully-manual entry screen and the post-scan piece
/// selection screen — both just click pieces onto a puzzle, whether or
/// not a photo was involved.
class PieceSelector extends StatelessWidget {
  final List<PieceSlot> slots;
  final ValueChanged<PieceSlot> onAdd;
  final void Function(int index) onRemove;

  const PieceSelector({
    super.key,
    required this.slots,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Required pieces', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _SlotList(slots: slots, onRemove: onRemove),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final piece in UbongoCatalog.classic)
              ActionChip(
                label: Text('${piece.id} (${piece.cellCount})'),
                onPressed: () => onAdd(SolidSlot(piece)),
              ),
            for (final n in {for (final p in UbongoCatalog.classic) p.cellCount})
              ActionChip(
                avatar: const Icon(Icons.help_outline, size: 16),
                label: Text('Any $n-cell'),
                onPressed: () => onAdd(GraySlot(n)),
              ),
          ],
        ),
      ],
    );
  }
}

class _SlotList extends StatelessWidget {
  final List<PieceSlot> slots;
  final void Function(int index) onRemove;

  const _SlotList({required this.slots, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const Text('No pieces added yet.');
    return Column(
      children: [
        for (var i = 0; i < slots.length; i++)
          ListTile(
            dense: true,
            title: Text(switch (slots[i]) {
              SolidSlot(:final piece) => '${piece.id} — ${piece.name}',
              GraySlot(:final cellCount) => 'Any piece, $cellCount cells',
            }),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => onRemove(i),
            ),
          ),
      ],
    );
  }
}
