import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The single header idiom. Replaces 5 hand-rolled headers **and** 15
/// `AppBar`s.
///
/// The five hand-rolled headers already expressed the same composition —
/// a small uppercase [caption] over a large [title], optional [actions] on the
/// right, and something pinned beneath (a date selector, a tab bar) — just
/// five times, five slightly different ways. That composition is the API.
///
/// The header is a plain [Column], not an `AppBar`: it does not float, does not
/// tint on scroll, and does not fight the decorative background behind the
/// shell screens. [background] defaults to transparent for exactly that
/// reason; pass `AppColors.bg` on pushed screens that sit above the shell.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.caption,
    this.leading,
    this.actions = const [],
    this.bottom,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.background = Colors.transparent,
    this.showBack,
    this.onBack,
  });

  /// Screen title, `titleL`.
  final String title;

  /// Small uppercase line above the title, `caption`. e.g. `WELCOME BACK`.
  final String? caption;

  /// Replaces the automatic back button. 10b puts the drawer hamburger here.
  final Widget? leading;

  final List<Widget> actions;

  /// Pinned directly under the header: a date selector, a tab bar, a filter
  /// row. Not part of the scrolling [body].
  final Widget? bottom;

  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color background;

  /// Defaults to "show it when there is something to pop".
  final bool? showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: title,
              caption: caption,
              leading: leading,
              actions: actions,
              showBack: showBack,
              onBack: onBack,
            ),
            ?bottom,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.caption,
    required this.leading,
    required this.actions,
    required this.showBack,
    required this.onBack,
  });

  final String title;
  final String? caption;
  final Widget? leading;
  final List<Widget> actions;
  final bool? showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final back = showBack ?? (onBack != null || Navigator.of(context).canPop());

    // An `IconButton` is a 48px target around a 24px glyph, so it carries 12px
    // of its own inset. Paying the page gutter as well put the hamburger's
    // glyph at 28 while everything under it sat at 16, which is what the device
    // pass saw as "very padded to the left". The gutter is reduced by the
    // button's own inset so the glyph lands on the grid and the target keeps
    // its full 48px.
    const iconInset = AppSpace.s3;
    final leadsWithAButton = leading != null || back;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        leadsWithAButton ? AppSpace.s4 - iconInset : AppSpace.s4,
        AppSpace.s3,
        AppSpace.s2,
        AppSpace.s2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.s2),
              child: leading,
            )
          else if (back)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.s1),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.textPrimary,
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (caption != null)
                  Text(
                    caption!.toUpperCase(),
                    style: AppType.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                Text(
                  title,
                  style: AppType.titleL.copyWith(color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
