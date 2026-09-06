import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'app_button.dart';

/// One row of a [MultiSelectList].
class SelectOption {
  const SelectOption({
    required this.id,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
  });

  final int id;
  final String title;
  final String? subtitle;

  /// Right-hand text, usually money. Format through `BrandConfig.money`.
  final String? trailing;

  final Widget? leading;
}

/// A list of things to tick, with a select-all header that says how many are
/// ticked.
///
/// Written once because the app now asks this question in two places — which
/// products go in the shared catalogue, and which shops go in the shared bills
/// — and a partial selection is the kind of thing that has to behave the same
/// both times. The caller owns the [selected] set, because the caller is what
/// acts on it.
class MultiSelectList extends StatelessWidget {
  const MultiSelectList({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.noun = 'selected',
    this.padding = EdgeInsets.zero,
  });

  final List<SelectOption> options;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  /// Completes "3 of 8 …" in the header. Say what is being counted when it is
  /// not obvious from the rows.
  final String noun;

  final EdgeInsetsGeometry padding;

  bool get _allSelected =>
      options.isNotEmpty && selected.length == options.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s1,
            AppSpace.s2,
            AppSpace.s1,
          ),
          child: Row(
            children: [
              Text(
                '${selected.length} of ${options.length} $noun',
                style: AppType.bodyS.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              AppButton.text(
                label: _allSelected ? 'Clear' : 'Select all',
                onPressed: () => onChanged(
                  _allSelected ? <int>{} : options.map((o) => o.id).toSet(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: ListView.builder(
            padding: padding,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = selected.contains(option.id);
              return CheckboxListTile(
                value: isSelected,
                // The whole row toggles, not just the box. A 20px target in a
                // list you are meant to sweep through is a mis-tap waiting to
                // happen.
                onChanged: (_) => onChanged(
                  isSelected
                      ? (selected.toSet()..remove(option.id))
                      : (selected.toSet()..add(option.id)),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                secondary: option.trailing == null && option.leading == null
                    ? null
                    : _Secondary(option: option),
                title: Text(option.title, style: AppType.titleS),
                subtitle: option.subtitle == null
                    ? null
                    : Text(
                        option.subtitle!,
                        style: AppType.bodyS
                            .copyWith(color: AppColors.textSecondary),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The right-hand side of a row: an amount, a thumbnail, or both.
class _Secondary extends StatelessWidget {
  const _Secondary({required this.option});

  final SelectOption option;

  @override
  Widget build(BuildContext context) {
    final leading = option.leading;
    final trailing = option.trailing;
    if (trailing == null) return leading!;

    final money = Text(
      trailing,
      style: AppType.titleS.copyWith(color: AppColors.textPrimary),
    );
    if (leading == null) return money;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [leading, const SizedBox(width: AppSpace.s2), money],
    );
  }
}

/// [MultiSelectList] in a bottom sheet, with a confirm button.
///
/// Returns the chosen ids, or null if the sheet was dismissed — which is not
/// the same as choosing nothing, and callers must not treat it as such.
Future<Set<int>?> showMultiSelectSheet(
  BuildContext context, {
  required String title,
  required List<SelectOption> options,
  required String Function(int count) confirmLabel,
  String noun = 'selected',
  Set<int>? initial,
}) {
  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    // These sheets are opened from screens inside the shell, which draws a nav
    // bar and a FAB above its body. On the branch navigator the sheet comes up
    // underneath both.
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => _MultiSelectSheet(
      title: title,
      options: options,
      confirmLabel: confirmLabel,
      noun: noun,
      initial: initial ?? options.map((o) => o.id).toSet(),
    ),
  );
}

class _MultiSelectSheet extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.confirmLabel,
    required this.noun,
    required this.initial,
  });

  final String title;
  final List<SelectOption> options;
  final String Function(int count) confirmLabel;
  final String noun;
  final Set<int> initial;

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late Set<int> _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s4,
                AppSpace.s4,
                AppSpace.s2,
              ),
              child: Text(widget.title, style: AppType.titleM),
            ),
            Flexible(
              child: MultiSelectList(
                options: widget.options,
                selected: _selected,
                noun: widget.noun,
                onChanged: (next) => setState(() => _selected = next),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: AppButton(
                label: widget.confirmLabel(_selected.length),
                expand: true,
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
