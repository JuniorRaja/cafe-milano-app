import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The app's one search box.
///
/// Five screens grew their own — settings, the shop picker, and the three
/// master lists — each with a slightly different hint, a different clear
/// affordance, and a different idea of padding. A search box is a control the
/// user learns once.
///
/// Stateless by design: the caller owns the [controller] and the query, because
/// the caller is what filters. This widget only draws it.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
    this.autofocus = false,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.s4,
      0,
      AppSpace.s4,
      AppSpace.s3,
    ),
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Say what is searched — "Search shops", not "Search". The user is on a
  /// screen full of things and needs to know which of them this filters.
  final String hintText;

  final bool autofocus;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          autofocus: autofocus,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          style: AppType.body,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppType.body.copyWith(color: AppColors.textTertiary),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.textTertiary,
                    tooltip: 'Clear',
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s3,
              vertical: AppSpace.s3,
            ),
            border: const OutlineInputBorder(
              borderRadius: AppRadius.rM,
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.rM,
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadius.rM,
              borderSide: BorderSide(color: AppColors.brandDeep),
            ),
          ),
        ),
      ),
    );
  }
}
