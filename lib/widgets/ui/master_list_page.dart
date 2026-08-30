import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'app_scaffold.dart';
import 'app_search_field.dart';
import 'stat_band.dart';

/// The shape every master list shares: header, search, a line of counts, then
/// the rows.
///
/// Shops, Products and Categories were three different screens doing the same
/// job three ways — two `AppBar`s with a subtitle crammed into the title and
/// one `ReorderableListView` with no header at all, none of them searchable,
/// each row carrying an Active chip, an edit button and sometimes a delete
/// button inline. This is that screen, written once.
///
/// The caller owns filtering: [builder] is handed the current query and
/// returns the list. Filtering is the one part that genuinely differs — a
/// product matches on its category too, a shop on its area.
class MasterListPage extends StatefulWidget {
  const MasterListPage({
    super.key,
    required this.caption,
    required this.title,
    required this.searchHint,
    required this.builder,
    this.stats,
    this.actions = const [],
    this.leading,
    this.floatingActionButton,
  });

  final String caption;
  final String title;
  final String searchHint;

  /// Builds the list for [query]. Called on every keystroke.
  final Widget Function(BuildContext context, String query) builder;

  /// The line of counts under the search box. Null hides the band entirely
  /// rather than showing an empty strip.
  final List<StatBandItem>? stats;

  final List<Widget> actions;
  final Widget? leading;
  final Widget? floatingActionButton;

  @override
  State<MasterListPage> createState() => _MasterListPageState();
}

class _MasterListPageState extends State<MasterListPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;

    return AppScaffold(
      caption: widget.caption,
      title: widget.title,
      leading: widget.leading,
      actions: widget.actions,
      background: AppColors.bg,
      floatingActionButton: widget.floatingActionButton,
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchField(
            controller: _controller,
            hintText: widget.searchHint,
            onChanged: (value) => setState(() => _query = value),
          ),
          if (stats != null && stats.isNotEmpty)
            StatBand(
              items: stats,
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                0,
                AppSpace.s4,
                AppSpace.s3,
              ),
            ),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
      body: widget.builder(context, _query.trim().toLowerCase()),
    );
  }
}
