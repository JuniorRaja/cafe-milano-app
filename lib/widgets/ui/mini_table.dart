import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// A compact borderless table for the inside of a card: Item / Usual /
/// Suggested / Change. New — the app previously drew tabular data as stacks of
/// `Row`s with hand-tuned `SizedBox` widths that did not line up.
///
/// Cells are widgets so a [DeltaPill] or [StatusBadge] can sit in a column.
/// Column widths come from [flex]; the first column defaults to twice the rest.
class MiniTable extends StatelessWidget {
  const MiniTable({
    super.key,
    required this.headers,
    required this.rows,
    this.flex,
    this.alignments,
  });

  final List<String> headers;
  final List<List<Widget>> rows;

  /// One flex factor per column. Defaults to `[2, 1, 1, ...]`.
  final List<int>? flex;

  /// One alignment per column. Defaults to left for the first column, right
  /// for the rest — money lines up on its right edge or it is not a table.
  final List<Alignment>? alignments;

  int _flexAt(int i) => flex?[i] ?? (i == 0 ? 2 : 1);

  Alignment _alignAt(int i) =>
      alignments?[i] ?? (i == 0 ? Alignment.centerLeft : Alignment.centerRight);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s2,
            vertical: AppSpace.s1,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: AppRadius.rS,
          ),
          child: Row(
            children: [
              for (var i = 0; i < headers.length; i++)
                Expanded(
                  flex: _flexAt(i),
                  child: Align(
                    alignment: _alignAt(i),
                    child: Text(
                      headers[i].toUpperCase(),
                      style: AppType.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s2,
              vertical: AppSpace.s2,
            ),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++)
                  Expanded(
                    flex: _flexAt(i),
                    child: Align(
                      alignment: _alignAt(i),
                      child: DefaultTextStyle.merge(
                        style: AppType.bodyS.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        child: row[i],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
