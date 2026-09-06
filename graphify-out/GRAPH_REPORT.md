# Graph Report - cafe-milano-app  (2026-09-06)

## Corpus Check
- 298 files · ~259,594 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2532 nodes · 3988 edges · 160 communities (139 shown, 17 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 117 edges (avg confidence: 0.8)
- Token cost: 517,000 input · 45,070 output

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Community 14
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 25
- Community 26
- Community 27
- Community 28
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 35
- Community 36
- Community 37
- Community 38
- Community 39
- Community 40
- Community 41
- Community 42
- Community 43
- Community 44
- Community 45
- Community 46
- Community 47
- Community 48
- Community 49
- Community 50
- Community 51
- Community 52
- Community 53
- Community 54
- Community 55
- Community 56
- Community 57
- Community 58
- Community 59
- Community 60
- Community 61
- Community 62
- Community 63
- Community 64
- Community 65
- Community 66
- Community 67
- Community 68
- Community 69
- Community 70
- Community 71
- Community 72
- Community 73
- Community 74
- Community 75
- Community 76
- Community 77
- Community 78
- Community 79
- Community 80
- Community 81
- Community 82
- Community 83
- Community 84
- Community 85
- Community 86
- Community 87
- Community 88
- Community 89
- Community 90
- Community 91
- Community 92
- Community 93
- Community 94
- Community 95
- Community 96
- Community 97
- Community 98
- Community 99
- Community 100
- Community 101
- Community 102
- Community 103
- Community 104
- Community 105
- Community 106
- Community 107
- Community 108
- Community 109
- Community 110
- Community 111
- Community 112
- Community 113
- Community 114
- Community 115
- Community 116
- Community 117
- Community 118
- Community 119
- Community 120
- Community 121
- Community 122
- Community 123
- Community 124
- Community 125
- Community 126
- Community 127
- Community 128
- Community 129
- Community 130
- Community 131
- Community 132
- Community 133
- Community 134
- Community 135
- Community 136
- Community 137
- Community 138
- Community 139
- Community 140
- Community 141
- Community 142
- Community 143
- Community 144
- Community 145
- Community 146
- Community 147
- Community 151
- Community 152
- Community 153
- Community 155
- Community 156
- Community 157
- Community 158
- Community 159

## God Nodes (most connected - your core abstractions)
1. `brandProvider` - 47 edges
2. `databaseProvider` - 38 edges
3. `Win32Window` - 24 edges
4. `AppDatabase` - 20 edges
5. `milano_orders (package)` - 19 edges
6. `10b — Navigation & settings restructure` - 15 edges
7. `todayProvider` - 14 edges
8. `05 — Ledger: payments & running balance` - 14 edges
9. `10c — Screen restyle` - 14 edges
10. `16 — Weekly AI business report` - 14 edges

## Surprising Connections (you probably didn't know these)
- `Working principles (ask don't assume, simplest solution first)` --conceptually_related_to--> `Repository invariants (18 rules)`  [INFERRED]
  claude.md → AGENTS.md
- `Every schema change bumps schemaVersion + explicit onUpgrade` --semantically_similar_to--> `backup_service.dart same-commit schema-change rule`  [INFERRED] [semantically similar]
  docs/archive/v2-implementation-plan.md → AGENTS.md
- `App holds no inventory and one user, no roles` --conceptually_related_to--> `Locked decisions 2026-08-19 (Supabase online-only, counter stock shop #1, 3 roles, hybrid nav, swipe-by-5)`  [AMBIGUOUS]
  AGENTS.md → docs/archive/v5-revamp-plan.md
- `Analyzer Phase 0 guardrail lint set` --conceptually_related_to--> `Test suite (15 files, 229 tests, money-carrying code)`  [INFERRED]
  analysis_options.yaml → docs/development.md
- `The readiness gate (8 checks)` --references--> `milano_orders (package)`  [INFERRED]
  docs/roadmap.md → pubspec.yaml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Lifecycle audit phases folded into releases** — docs_roadmap_document, docs_flutter_lifecycle_audit_document, docs_roadmap_release_18_foundation_guardrails, docs_roadmap_release_10b_navigation, docs_roadmap_release_10c_screen_restyle, docs_roadmap_release_12_dashboard_tabs, docs_roadmap_release_14a_repository_seam [EXTRACTED 0.90]
- **Six-phase lifecycle migration plan** — docs_flutter_lifecycle_audit_migration_plan, docs_flutter_lifecycle_audit_phase_0_guardrails, docs_flutter_lifecycle_audit_app_lifecycle_listener, docs_flutter_lifecycle_audit_asyncvalue_discipline, docs_flutter_lifecycle_audit_riverpod_modernisation, docs_flutter_lifecycle_audit_repository_seam, docs_flutter_lifecycle_audit_theme_from_tree [EXTRACTED 0.90]
- **Ledger sequence (FK prep → foundation → allocation → statements)** — docs_features_03_db_integrity_feature, docs_features_05_ledger_foundation_feature, docs_features_06_ledger_manual_allocation_feature, docs_features_07_ledger_statements_feature, docs_features_05_ledger_foundation_fifo_allocation, docs_features_05_ledger_foundation_data_model [EXTRACTED 1.00]
- **UI overhaul block (10 → 10a/18/10b/10c)** — docs_features_10_ui_overhaul_feature, docs_features_10a_design_system_feature, docs_features_18_foundation_guardrails_feature, docs_features_10b_navigation_feature, docs_features_10c_screen_restyle_feature [EXTRACTED 1.00]
- **Component kit loading / empty / failed states** — lib_widgets_ui_readme_component_kit, lib_widgets_ui_readme_app_error_view, lib_widgets_ui_readme_empty_state, docs_flutter_lifecycle_audit_asyncvalue_discipline [INFERRED 0.80]
- **Ledger / receivables subsystem across the roadmap** — docs_archive_v4_implementation_plan_ledger_foundation, docs_archive_v4_implementation_plan_ledger_integration, docs_archive_v4_implementation_plan_fifo_allocation, docs_archive_v5_revamp_plan_overview, docs_architecture_data_model_v6 [INFERRED 0.80]
- **Money precision concern (floats vs integer cents)** — agents_money_util, docs_code_review_report_money_floats, docs_areas_of_improvement_integer_cents, docs_architecture_data_model_v6 [INFERRED 0.80]
- **Flutter lifecycle audit phases spread across releases** — docs_features_18_foundation_guardrails_flutter_lifecycle_audit, docs_features_10b_navigation_lifecycle_phase1, docs_features_10c_screen_restyle_async_discipline, docs_features_12_dashboard_tabs_phase4, docs_features_14a_repository_seam_repositories, docs_features_18_foundation_guardrails_lint_ratchet [INFERRED 0.85]
- **Provider seam refactor (doc 14a) — layering violation across docs** — agents_layering_rule, agents_database_provider_violation, docs_code_review_report_layering_violations, docs_areas_of_improvement_provider_seam_refactor [INFERRED 0.85]

## Communities (160 total, 17 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.02
Nodes (129): DailyOrder, double get, ageInDays, _allocate, allocated, allocatedAmount, amount, amountDue (+121 more)

### Community 1 - "Community 1"
Cohesion: 0.03
Nodes (67): AppRoutes, backupRestore, billing, buildRouter, businessInfo, catalogShare, categories, dashboard (+59 more)

### Community 2 - "Community 2"
Cohesion: 0.05
Nodes (57): PluginRegistry, RECT, unique_ptr, RegisterPlugins(), DartProject, HWND, LPARAM, LRESULT (+49 more)

### Community 3 - "Community 3"
Cohesion: 0.04
Nodes (55): AppColors, AppRadius, AppShadow, AppSpace, AppType, barTop, bg, body (+47 more)

### Community 4 - "Community 4"
Cohesion: 0.05
Nodes (34): Any, Cocoa, file_picker, file_selector_macos, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate (+26 more)

### Community 5 - "Community 5"
Cohesion: 0.04
Nodes (42): ReadOnce, build, onChanged, onInfo, subtitle, title, _ToggleTile, value (+34 more)

### Community 6 - "Community 6"
Cohesion: 0.05
Nodes (43): DateTimeRange?, area, AttentionFlagType, categoryBreadth, categoryEmoji, categoryEmojis, categoryId, categoryName (+35 more)

### Community 7 - "Community 7"
Cohesion: 0.05
Nodes (43): BillStatus, LedgerEntry, LedgerType, shopLedgerProvider, shopStatsProvider, shopByIdProvider, build, _activeFilterCount (+35 more)

### Community 8 - "Community 8"
Cohesion: 0.06
Nodes (36): AsyncValue, ../ledger/record_payment_sheet.dart, brand, createState, _Hero, onSelected, onSort, _OwedList (+28 more)

### Community 9 - "Community 9"
Cohesion: 0.05
Nodes (37): build, _confirm, createState, _ctrl, _digitWheel, dispose, _hundreds, icon (+29 more)

### Community 10 - "Community 10"
Cohesion: 0.06
Nodes (35): activeCatIds, address, buf, _buildCatalogText, _buildCategoryHeader, _buildCoverPage, _buildPdfBytes, _buildPhotoBox (+27 more)

### Community 11 - "Community 11"
Cohesion: 0.06
Nodes (33): app_card.dart, app_error_view.dart, app_scaffold.dart, app_search_field.dart, app_skeleton.dart, confirm_dialog.dart, delta_pill.dart, empty_state.dart (+25 more)

### Community 12 - "Community 12"
Cohesion: 0.06
Nodes (34): dart:typed_data, address, area, base, billed, buildStatementData, buildStatementPdf, bytes (+26 more)

### Community 13 - "Community 13"
Cohesion: 0.06
Nodes (34): active, _back, _categoryId, createState, date, _db, _debounce, dispose (+26 more)

### Community 14 - "Community 14"
Cohesion: 0.06
Nodes (33): category_provider.dart, date_provider.dart, categoryScoresDataProvider, catIdsByShop, catMap, cats, db, flags (+25 more)

### Community 15 - "Community 15"
Cohesion: 0.08
Nodes (27): GoRouter, package:flutter/material.dart, package:go_router/go_router.dart, package:milano_orders/app.dart, package:milano_orders/screens/order_entry/order_entry_screen.dart, package:milano_orders/widgets/shell/destinations.dart, Route /outstanding, Route /shops/3/ledger (+19 more)

### Community 16 - "Community 16"
Cohesion: 0.06
Nodes (30): backup, _backupFilePrefix, _buildBackupJson, businessInfoJson, create, data, dir, exportAndShareBackup (+22 more)

### Community 17 - "Community 17"
Cohesion: 0.08
Nodes (26): class, dart:io, _WhatCountsNote, createState, _generating, _initialized, _priceLabel, _selectedIds (+18 more)

### Community 18 - "Community 18"
Cohesion: 0.13
Nodes (27): ConsumerState, ConsumerStatefulWidget, allCategoriesProvider, kitchenLinesForDateProvider, catalogueCoverageProvider, allProductsProvider, allShopsProvider, build (+19 more)

### Community 19 - "Community 19"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 20 - "Community 20"
Cohesion: 0.08
Nodes (23): EdgeInsetsGeometry, build, child, ListFadeIn, actionLabel, build, caption, onAction (+15 more)

### Community 21 - "Community 21"
Cohesion: 0.16
Nodes (25): 10 — UI overhaul (block index), AppScaffold (single header idiom), Component kit (lib/widgets/ui/), 10a — Design system & UI foundation, Four performance fixes (blur, autoDispose, splash, stagger), tool/check_tokens.sh ratchet, Design tokens (lib/theme/tokens.dart), Bricolage Grotesque font swap (replaces Raleway) (+17 more)

### Community 22 - "Community 22"
Cohesion: 0.09
Nodes (23): ../app_background.dart, app_drawer.dart, ../floating_nav_bar.dart, GlobalKey, InheritedWidget, AppShell, _AppShellState, _barVisible (+15 more)

### Community 23 - "Community 23"
Cohesion: 0.09
Nodes (21): IconButton, package:milano_orders/screens/kitchen/kitchen_screen.dart, package:milano_orders/theme/app_theme.dart, package:milano_orders/theme/brand_config.dart, package:milano_orders/utils/money.dart, package:milano_orders/widgets/ui/ui.dart, brand, main (+13 more)

### Community 24 - "Community 24"
Cohesion: 0.10
Nodes (23): activeProductsProvider, activeShopsProvider, build, _controllers, createState, dispose, _loadingPrices, _matches (+15 more)

### Community 25 - "Community 25"
Cohesion: 0.15
Nodes (23): _, @DriftAccessor, @DriftDatabase, _$BackupDaoMixin, _$BusinessInfoDaoMixin, _$CategoryDaoMixin, _$DashboardDaoMixin, DatabaseAccessor (+15 more)

### Community 26 - "Community 26"
Cohesion: 0.09
Nodes (22): BillDue, billDue, child, createState, _expandedOrderId, index, isExpanded, _markPaid (+14 more)

### Community 27 - "Community 27"
Cohesion: 0.10
Nodes (21): bool get, _allSelected, build, createState, id, initial, leading, MultiSelectList (+13 more)

### Community 28 - "Community 28"
Cohesion: 0.10
Nodes (21): Category?, databaseProvider, _confirmDeletePayment, _clearQuantities, _confirmOrder, _init, _loadStandingOrder, _setQty (+13 more)

### Community 29 - "Community 29"
Cohesion: 0.17
Nodes (22): ConsumerWidget, OrdersApp, categoryMixProvider, _ShopRow, OutstandingListScreen, _LedgerRow, _OpenBillRow, _StatsHeader (+14 more)

### Community 30 - "Community 30"
Cohesion: 0.09
Nodes (21): CurvedAnimation, build, _controller, createState, _curved, destination, didChangeDependencies, dispose (+13 more)

### Community 31 - "Community 31"
Cohesion: 0.11
Nodes (18): dart:convert, package:drift/native.dart, package:milano_orders/database/app_database.dart, package:milano_orders/services/ledger_statement_service.dart, _freshDb, main, main, _freshDb (+10 more)

### Community 32 - "Community 32"
Cohesion: 0.10
Nodes (19): watch, package:flutter_riverpod/flutter_riverpod.dart, package:milano_orders/screens/settings/prices/price_matrix_screen.dart, package:milano_orders/screens/settings/standing_orders/standing_orders_screen.dart, package:milano_orders/widgets/product_qty_row.dart, bunId, db, io (+11 more)

### Community 33 - "Community 33"
Cohesion: 0.10
Nodes (20): package:milano_orders/providers/category_provider.dart, package:milano_orders/providers/price_provider.dart, package:milano_orders/providers/product_provider.dart, package:milano_orders/providers/settings_summary_provider.dart, package:milano_orders/screens/settings/categories/category_list_screen.dart, package:milano_orders/screens/settings/products/product_list_screen.dart, package:milano_orders/screens/settings/settings_screen.dart, package:milano_orders/screens/settings/shops/shop_list_screen.dart (+12 more)

### Community 34 - "Community 34"
Cohesion: 0.10
Nodes (19): app_button.dart, IconData?, cancelLabel, confirmDestructive, confirmed, confirmLabel, destructive, false (+11 more)

### Community 35 - "Community 35"
Cohesion: 0.13
Nodes (20): AppLifecycleListener, selectedDateProvider, todayProvider, pendingWritesProvider, initState, _shareOne, build, DateSelector (+12 more)

### Community 36 - "Community 36"
Cohesion: 0.10
Nodes (20): category_emoji.dart, buf, byCategory, byName, emoji, groupKitchenLines, groups, items (+12 more)

### Community 37 - "Community 37"
Cohesion: 0.10
Nodes (20): createState, dispose, _formatPrice, _formKey, initState, _kOtherUnit, _kUnitOptions, _loading (+12 more)

### Community 38 - "Community 38"
Cohesion: 0.10
Nodes (20): _areaCtrl, build, createState, _delete, dispose, _formKey, initState, _load (+12 more)

### Community 39 - "Community 39"
Cohesion: 0.13
Nodes (19): OutstandingSummary, billDuesForDateProvider, db, outstandingByShopProvider, outstandingSummaryProvider, periodMoneyProvider, ShopLedgerQuery, build (+11 more)

### Community 40 - "Community 40"
Cohesion: 0.10
Nodes (19): IconData get, activeIcon, appDestinations, best, bottomBarDestinations, bottomBarRoutes, DestGroup, destinationForLocation (+11 more)

### Community 41 - "Community 41"
Cohesion: 0.10
Nodes (19): _ByItemView, _ByShopView, _cmpShops, createState, dispose, _EmptyState, groups, initState (+11 more)

### Community 42 - "Community 42"
Cohesion: 0.10
Nodes (18): AppTone, build, icon, label, margin, NoteBanner, onTap, text (+10 more)

### Community 43 - "Community 43"
Cohesion: 0.10
Nodes (18): AppSearchField, autofocus, build, controller, hintText, onChanged, padding, build (+10 more)

### Community 44 - "Community 44"
Cohesion: 0.20
Nodes (19): backup_service.dart recurring trap, 03 — FK enforcement + indexes, Per-connection foreign key enforcement, Schema indexes migration v4→v5, Catch-up payment vs opening balance, Ledger data model (Payments, PaymentAllocations, opening balance), 05 — Ledger: payments & running balance, FIFO auto-allocation (+11 more)

### Community 45 - "Community 45"
Cohesion: 0.12
Nodes (17): ShopConcentrationRow, shopConcentrationProvider, billDetailText, billsSummaryText, buf, grand, sorted, toString (+9 more)

### Community 46 - "Community 46"
Cohesion: 0.11
Nodes (17): int?, build, _Chip, chips, count, data, FilterChipData, FilterChipRow (+9 more)

### Community 47 - "Community 47"
Cohesion: 0.12
Nodes (17): _controllers, createState, dispose, _loadingOrders, _matches, onQuery, onSave, _onShopChanged (+9 more)

### Community 48 - "Community 48"
Cohesion: 0.11
Nodes (16): greetingFor, hour, package:clock/clock.dart, package:milano_orders/providers/bootstrap_provider.dart, package:milano_orders/providers/pending_writes.dart, package:milano_orders/screens/home/home_shops_screen.dart, package:milano_orders/widgets/shell/app_bootstrap_gate.dart, package:milano_orders/widgets/shell/app_lifecycle_scope.dart (+8 more)

### Community 49 - "Community 49"
Cohesion: 0.11
Nodes (16): AppErrorView, build, cause, message, onRetry, retryLabel, build, caption (+8 more)

### Community 50 - "Community 50"
Cohesion: 0.12
Nodes (15): app_database.dart, backup, db, existing, file, raw, seedDefaultCategories, seedFromBackup (+7 more)

### Community 51 - "Community 51"
Cohesion: 0.15
Nodes (17): Error observability (FlutterError.onError, ProviderObserver), ProviderContainer never disposed, Linux build target (milano_orders, APPLICATION_ID com.cafemilano.cafe_milano), Linux runner executable target, drift, fl_chart, flutter_riverpod, go_router (+9 more)

### Community 52 - "Community 52"
Cohesion: 0.12
Nodes (16): PaymentMode, FormState, _amountCtrl, createState, dispose, _formKey, initState, _mode (+8 more)

### Community 53 - "Community 53"
Cohesion: 0.15
Nodes (16): ../letter_avatar.dart, build, _controller, createState, dispose, _list, _max, _pick (+8 more)

### Community 54 - "Community 54"
Cohesion: 0.12
Nodes (16): _applyToggle, kDashAttentionFlags, kDashCategoryCards, kDashCategoryMix, kDashHeatmap, kDashOperationalPatterns, kDashOutstanding, kDashProductLeaderboard (+8 more)

### Community 55 - "Community 55"
Cohesion: 0.12
Nodes (16): build, createState, dispose, _entries, _expandedKey, icon, initState, key (+8 more)

### Community 56 - "Community 56"
Cohesion: 0.17
Nodes (17): KpiHelpScreen, _KpiHelpScreenState, _LedgerFilterSheet, _LedgerFilterSheetState, FloatingNavBar, _FloatingNavBarState, _QtyEditSheet, _QtyEditSheetState (+9 more)

### Community 57 - "Community 57"
Cohesion: 0.12
Nodes (15): build, DeltaPill, dense, inverted, label, value, _alignAt, alignments (+7 more)

### Community 58 - "Community 58"
Cohesion: 0.12
Nodes (16): badge, build, footer, leading, ListRow, margin, onLongPress, onTap (+8 more)

### Community 59 - "Community 59"
Cohesion: 0.12
Nodes (14): package:flutter_test/flutter_test.dart, package:milano_orders/services/kitchen_list.dart, package:milano_orders/utils/greeting.dart, package:milano_orders/utils/relative_day.dart, at, main, bake, cat (+6 more)

### Community 60 - "Community 60"
Cohesion: 0.13
Nodes (15): package:milano_orders/models/dashboard_models.dart, package:milano_orders/providers/business_info_provider.dart, package:milano_orders/providers/dashboard_provider.dart, package:milano_orders/providers/dashboard_settings_provider.dart, package:milano_orders/providers/database_provider.dart, package:milano_orders/screens/dashboard/dashboard_screen.dart, package:milano_orders/widgets/dashboard/pulse_card.dart, ProviderContainer (+7 more)

### Community 61 - "Community 61"
Cohesion: 0.13
Nodes (15): package:milano_orders/providers/date_provider.dart, package:milano_orders/providers/ledger_provider.dart, package:milano_orders/providers/shop_provider.dart, package:milano_orders/screens/finances/finances_screen.dart, package:milano_orders/utils/ledger_period.dart, package:milano_orders/widgets/shell/app_drawer.dart, package:milano_orders/widgets/shell/shop_picker_sheet.dart, ScaffoldState (+7 more)

### Community 62 - "Community 62"
Cohesion: 0.12
Nodes (14): AnimatedSlide, package:milano_orders/widgets/floating_nav_bar.dart, package:milano_orders/widgets/shell/app_shell.dart, package:milano_orders/widgets/shell/branch_scroll.dart, Scaffold, ScrollableState, branch, main (+6 more)

### Community 63 - "Community 63"
Cohesion: 0.12
Nodes (15): FloatingActionButtonLocation?, actions, AppScaffold, background, body, bottom, build, caption (+7 more)

### Community 64 - "Community 64"
Cohesion: 0.14
Nodes (13): BoolColumn get, DateTimeColumn get, id, isConfirmed, orderDate, shopId, area, id (+5 more)

### Community 65 - "Community 65"
Cohesion: 0.13
Nodes (14): BorderRadius, BoxBorder?, RecentShopIds, AppCard, border, borderRadius, build, child (+6 more)

### Community 66 - "Community 66"
Cohesion: 0.14
Nodes (13): daily_orders.dart, id, orderId, OrderLines, productId, qty, unitPrice, amount (+5 more)

### Community 67 - "Community 67"
Cohesion: 0.13
Nodes (14): DashboardPreset, _formatDateIndicator, _presetLabels, _refreshDashboard, ../../providers/business_info_provider.dart, ../../utils/greeting.dart, ../../widgets/dashboard/attention_flags.dart, ../../widgets/dashboard/category_scorecards.dart (+6 more)

### Community 68 - "Community 68"
Cohesion: 0.16
Nodes (15): businessInfoProvider, dashboardRangeProvider, dashboardSettingsProvider, lastBackupExportProvider, build, DashboardScreen, _pickPeriod, _exportStatement (+7 more)

### Community 69 - "Community 69"
Cohesion: 0.13
Nodes (14): _addressCtrl, build, createState, dispose, _formKey, initState, _loading, _logoPath (+6 more)

### Community 70 - "Community 70"
Cohesion: 0.13
Nodes (14): appName, appNameRest, currencySymbol, deep, deepest, locale, logoAsset, mark (+6 more)

### Community 71 - "Community 71"
Cohesion: 0.18
Nodes (14): backup_service.dart same-commit schema-change rule, Five compositional patterns from the reference screens, Schema v6 data model (frozen, 10 tables), Category-first design philosophy (each category a mini business unit), DashboardDao grouped SQL aggregations (batched, no N+1), Five dashboard sections (Pulse, Category Scorecards, Revenue Anatomy, Operational Patterns, Attention Flags), Every schema change bumps schemaVersion + explicit onUpgrade, Catalog PDF menu-card redesign (cover, category sections, 2-col grid) (+6 more)

### Community 72 - "Community 72"
Cohesion: 0.14
Nodes (12): ../../app.dart, _buildHeatmap, _dayLabels, _emptyState, _failedState, _loading, build, LetterAvatar (+4 more)

### Community 73 - "Community 73"
Cohesion: 0.15
Nodes (13): 01 — In-app update check, Token-free GitHub release lookup, GitHub Pages download page, checkForUpdate, client, downloadUrl, message, releaseNotes (+5 more)

### Community 74 - "Community 74"
Cohesion: 0.16
Nodes (12): price, primaryKey, productId, shopId, defaultQty, primaryKey, productId, shopId (+4 more)

### Community 75 - "Community 75"
Cohesion: 0.23
Nodes (13): Release APK GitHub Actions workflow, Bakery Order Manager PRD (original requirements), Problem: replace paper + WhatsApp order consolidation loop, Dashboard implementation plan (v1.5, 3 phases), BakeOrder v1.0 implementation plan (Phases 1-10), Archived plans index (superseded, kept for why), Release keystore + 4 GitHub Actions secrets setup, Release planner (signing, APK size, GitHub Release CI) (+5 more)

### Community 76 - "Community 76"
Cohesion: 0.18
Nodes (12): category_sparkline.dart, CategoryScorecard, categoryScorecardsProvider, weekdayHeatmapProvider, build, CategoryScorecardsWidget, _emptyState, _loadingCard (+4 more)

### Community 77 - "Community 77"
Cohesion: 0.15
Nodes (12): Checkbox, FilledButton, package:milano_orders/providers/order_provider.dart, package:milano_orders/screens/orders/orders_screen.dart, package:milano_orders/services/bill_share.dart, bill, buildBilling, day (+4 more)

### Community 78 - "Community 78"
Cohesion: 0.15
Nodes (12): Color, CustomPainter, build, CategorySparkline, color, data, height, lineColor (+4 more)

### Community 79 - "Community 79"
Cohesion: 0.15
Nodes (12): destinations.dart, active, AppDrawer, _body, createState, destination, _DrawerRow, _go (+4 more)

### Community 80 - "Community 80"
Cohesion: 0.21
Nodes (13): AsyncValue discipline (Phase 3), Debounced writes cancelled not flushed (data loss), Flutter Practices & Lifecycle Audit, Busy-flag / try / catch-SnackBar / finally pattern, Loading and error collapsed into empty (maybeWhen orElse), DB failure renders as 'No orders for this date', Six-phase migration plan, OrderDraftController with flush() (+5 more)

### Community 81 - "Community 81"
Cohesion: 0.18
Nodes (12): bootstrapProvider, AppBootstrapGate, _AppBootstrapGateState, _BootstrapErrorScreen, build, child, createState, error (+4 more)

### Community 82 - "Community 82"
Cohesion: 0.21
Nodes (12): pendingConfirmationsProvider, revenueDeltaProvider, shopsServedTodayProvider, todayRevenueProvider, build, _buildDelta, child, label (+4 more)

### Community 83 - "Community 83"
Cohesion: 0.15
Nodes (12): bold, kPdfBrown, kPdfGold, label, loadPdfTheme, name, pdfPageFooter, pdfWhiteBackground (+4 more)

### Community 84 - "Community 84"
Cohesion: 0.15
Nodes (12): AppButton, AppButtonVariant, build, busy, danger, expand, icon, label (+4 more)

### Community 85 - "Community 85"
Cohesion: 0.17
Nodes (11): AnimationController, double?, borderRadius, build, _controller, createState, didChangeDependencies, dispose (+3 more)

### Community 86 - "Community 86"
Cohesion: 0.20
Nodes (12): AppLifecycleListener at root, Overnight 'today' staleness defect, Self-correcting todayProvider, Theme and router resolved from the tree (ThemeExtension), Release 10a — Design system, Release 10b — Navigation, Release 10c — Screen restyle, money.dart / BrandConfig.money (+4 more)

### Community 87 - "Community 87"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 88 - "Community 88"
Cohesion: 0.17
Nodes (10): int get, main, widgetsBinding, flushAll, _flushers, pendingCount, PendingWrites, register (+2 more)

### Community 89 - "Community 89"
Cohesion: 0.20
Nodes (11): AttentionFlag, attentionFlagsProvider, AttentionFlagsWidget, _AttentionFlagsWidgetState, build, createState, _dismissedIndices, _expanded (+3 more)

### Community 90 - "Community 90"
Cohesion: 0.18
Nodes (11): App holds no inventory and one user, no roles, Order entry rebuilds all 28 product rows per tap, bypasses providers, 68% of routes buried behind the Profile tab, Binding decisions from 2026-08-19 (carried forward), Schema numbering reassigned vs v5-revamp-plan, Tap-to-edit quantity modal (numeric field + steppers), Counter stock module (Cafe Milano shop #1 only, derived Sold), Four design principles (recognition over recall, one decision per glance, confirm by feel, latency is UX) (+3 more)

### Community 91 - "Community 91"
Cohesion: 0.25
Nodes (11): Supabase Auth with public signup disabled, Biometric unlock gate (local_auth), 14 — Supabase, auth & biometric unlock, Supabase Postgres port (v6 mirrored), RLS binary door, no roles, Repository layer (lib/repositories/, intent-shaped methods), weekly-report Supabase Edge Function (pg_cron), 16 — Weekly AI business report (+3 more)

### Community 92 - "Community 92"
Cohesion: 0.18
Nodes (10): OrderDaySummary, _EmptyState, onTap, shop, summary, ../../providers/order_provider.dart, Shop, ../../widgets/date_selector.dart (+2 more)

### Community 93 - "Community 93"
Cohesion: 0.20
Nodes (10): BranchScrollScope, _BranchScrollScopeState, build, child, _controller, createState, didChangeDependencies, dispose (+2 more)

### Community 94 - "Community 94"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 95 - "Community 95"
Cohesion: 0.24
Nodes (10): AppLifecycleScope (single AppLifecycleListener), AppRoutes constants and param builders, shell/destinations.dart single source of destinations, Repository invariants (18 rules), 0 of 35 providers autoDispose (stream leak over a session), App lifecycle (bootstrapProvider, AppBootstrapGate, todayProvider, PendingWrites), package:clock for wall-clock day reads (testable rollover), Route table over StatefulShellRoute, five bottom-bar branches (+2 more)

### Community 96 - "Community 96"
Cohesion: 0.20
Nodes (8): ../../database/app_database.dart, db, _Actions, _matches, shop, _ShopAction, _toggleActive, ../../providers/shop_provider.dart

### Community 97 - "Community 97"
Cohesion: 0.20
Nodes (7): database_provider.dart, CatalogueCoverage, watch, pricesForShopProvider, standingOrdersForShopProvider, watch, watch

### Community 98 - "Community 98"
Cohesion: 0.20
Nodes (9): CategoryMixRow, _buildContent, _buildTrend, color, _emptyState, _kSliceColors, rank, row (+1 more)

### Community 99 - "Community 99"
Cohesion: 0.20
Nodes (9): activeCategoriesProvider, categoriesProvider, watch, build, OrderEntryScreen, _OrderEntryScreenState, CatalogSharePickerScreen, _CatalogSharePickerScreenState (+1 more)

### Community 100 - "Community 100"
Cohesion: 0.22
Nodes (9): ordersForDateProvider, orderSummariesForDateProvider, orderWithLinesProvider, watch, build, HomeShopsScreen, build, AppRoutes.orderEntryFor (+1 more)

### Community 101 - "Community 101"
Cohesion: 0.20
Nodes (9): count, countLakh, countTrim, _format, money, moneyCompact, moneyDecimal, moneyLakh (+1 more)

### Community 102 - "Community 102"
Cohesion: 0.25
Nodes (9): CI Drift build_runner codegen step, Milano Orders (single-user Android bakery app), riverpod_lint deliberately excluded (drift/sqlite3 downgrade cost), Working principles (ask don't assume, simplest solution first), Dart/Flutter DevTools extension config stub, Architecture reference doc, Tech stack (Flutter 3.44.2, Drift/SQLite, Riverpod 2.x, go_router 14.x), Development guide (setup, test, build, release) (+1 more)

### Community 103 - "Community 103"
Cohesion: 0.28
Nodes (9): BrandConfig (brand name, color, logo indirection), money.dart single currency formatter, Analyzer Phase 0 guardrail lint set, No design tokens (14 font sizes, 111 greys, 117 spacing literals), tokens.dart design system (AppColors, AppType, AppSpace, AppRadius, AppShadow), Rebrand BakeOrder to Milano Orders, Store money as integer cents (drop RealColumn + epsilon), Strength: strong lib/widgets/ui component library (20+ widgets) (+1 more)

### Community 104 - "Community 104"
Cohesion: 0.22
Nodes (8): categories.dart, categoryId, id, isActive, name, photoPath, price, unit

### Community 105 - "Community 105"
Cohesion: 0.25
Nodes (8): ProductLeaderRow, productLeaderboardProvider, build, _buildTable, _emptyState, ProductLeaderboardCard, rank, row

### Community 106 - "Community 106"
Cohesion: 0.22
Nodes (8): build, _busy, createState, _export, _import, package:file_picker/file_picker.dart, ../../../providers/database_provider.dart, ../../../services/backup_service.dart

### Community 107 - "Community 107"
Cohesion: 0.22
Nodes (8): AppProviderObserver, installErrorHandlers, previous, providerDidFail, reportError, _tag, where, ProviderObserver

### Community 108 - "Community 108"
Cohesion: 0.25
Nodes (8): @DataClassName, BusinessInfo, DailyOrders, PaymentAllocations, Products, ShopPrices, Shops, Table

### Community 109 - "Community 109"
Cohesion: 0.25
Nodes (7): dart:async, build, refresh, _rollover, _scheduleRollover, _startOfDay, Timer?

### Community 110 - "Community 110"
Cohesion: 0.25
Nodes (8): Blurred full-screen PNG repainting under every screen, App audit 1.7.0 (current-state record), v1 non-goals (no cloud sync, no auth, no OCR, no P&L), LetterAvatar shared widget, AppBackground CustomPaint vector motif, Provider signatures stay stable so Supabase port leaves screens untouched, session_provider with hardcoded owner role until Supabase port, Supabase, auth, three-tier roles + RLS policies

### Community 111 - "Community 111"
Cohesion: 0.39
Nodes (8): 04 — Dashboard query cleanup + repo hygiene, Query discipline (no N+1, no duplicate aggregate, shared providers), todayProvider (midnight-normalised DateTime), 10b — Navigation & settings restructure, Application lifecycle Phase 1 (ProviderScope, bootstrap, self-correcting today), 11 — Counter stock (DROPPED), 12 — Dashboard tabs + reports, Dashboard four-tab split (Sales/Products/Shops/Alerts)

### Community 112 - "Community 112"
Cohesion: 0.32
Nodes (8): Outstanding receivables card + list screen, BrandConfig brand seam, App drawer + /profile→/settings restructure, drawer_destinations.dart (destinations as data), 17 — White-label, One Supabase project per tenant, tenant_config table (single row per tenant project), Terms terminology lookup (lib/config/terms.dart)

### Community 113 - "Community 113"
Cohesion: 0.25
Nodes (7): IntColumn get, address, id, logoPath, name, phone, primaryKey

### Community 114 - "Community 114"
Cohesion: 0.25
Nodes (7): amount, id, mode, note, paidAt, Payments, shopId

### Community 115 - "Community 115"
Cohesion: 0.25
Nodes (7): kLastBackupExportedAt, prefs, raw, recordBackupExport, setString, package:shared_preferences/shared_preferences.dart, return

### Community 116 - "Community 116"
Cohesion: 0.25
Nodes (7): _dayNumber, days, relativeDayLabel, weekday, weeks, _weekStart, package:intl/intl.dart

### Community 117 - "Community 117"
Cohesion: 0.33
Nodes (7): pubspec version-change release trigger, tool/check_tokens.sh token-literal guardrail, deprecated_member_use_from_same_package as migration progress bar, Manual pubspec version bump triggers release (not semantic-release), Migrate deprecated color constants to AppColors, Eight-step release readiness gate, Release process (master is production, one branch per release)

### Community 118 - "Community 118"
Cohesion: 0.29
Nodes (6): AsyncNotifier, ../database/dev_seed.dart, Bootstrap, build, package:flutter/foundation.dart, _FailingBootstrap

### Community 119 - "Community 119"
Cohesion: 0.38
Nodes (7): 02 — Shipped-data cleanup, Release seed removal / empty first install, Same-weekday median + trend + standing-order clamp, 15 — Auto order suggestions, No LLM — checkable arithmetic only, Fixed reason-code enum (no free text), order_suggestion_service.dart (pure Dart, no DB)

### Community 120 - "Community 120"
Cohesion: 0.33
Nodes (7): Repository seam (lib/repositories/), Branching policy — master is production, one branch per release, Milano Orders Roadmap, The readiness gate (8 checks), Release 14 — Supabase auth, Release 14a — Repository seam, Versioning rules (minor/patch/major)

### Community 121 - "Community 121"
Cohesion: 0.29
Nodes (6): Categories, id, isActive, name, sortOrder, TextColumn get

### Community 122 - "Community 122"
Cohesion: 0.29
Nodes (7): DashboardRange, DashboardSettings, DashboardRangeNotifier, DashboardSettingsNotifier, StateNotifier, _FixedRange, _FixedSettings

### Community 123 - "Community 123"
Cohesion: 0.33
Nodes (5): brand_config.dart, buildAppTheme, buttonBase, scheme, tokens.dart

### Community 124 - "Community 124"
Cohesion: 0.33
Nodes (6): DateTime, getCategorySparklines, getWeekdayHeatmap, TodayNotifier, Notifier, _FixedToday

### Community 125 - "Community 125"
Cohesion: 0.33
Nodes (6): legacyRedirectFor (keeps pre-10b /profile/* URLs working), MasterListPage (shared Shops/Products/Categories screen), Areas of improvement (priority matrix), Code review report (lib/, 1.10.0+14, schema v6), Test suite (15 files, 229 tests, money-carrying code), Widget-test gotchas (Drift teardown Timer, pumpAndSettle vs indeterminate animation)

### Community 126 - "Community 126"
Cohesion: 0.33
Nodes (6): Original v1 Drift schema (shops, products, shop_prices, standing_orders, daily_orders, order_lines), Core screens (Home, Order Entry, Kitchen List, Billing, Settings), Locked schema/nav deviations from PRD (area, unit, photoPath, unitPrice), OrderLines.unitPrice price snapshot at save time, Two-way pricing (Product.price default + ShopPrices override), Emoji, one-item-per-line WhatsApp message format

### Community 127 - "Community 127"
Cohesion: 0.33
Nodes (6): Three-digit quantity wheel + Input tab, 08 — Digit-wheel quantity entry + haptics, Haptics pass (lightImpact / heavyImpact), Long-press ±5 repeating stepper, Order-entry per-tap full-list rebuild fix, Order-entry debounce flush fix (data-loss defect)

### Community 128 - "Community 128"
Cohesion: 0.47
Nodes (6): Release 17 — White-label, AppErrorView, theme/brand_config.dart (white-label seam), brandProvider, The component kit (widgets/ui), EmptyState

### Community 129 - "Community 129"
Cohesion: 0.33
Nodes (5): _ArrowBtn, icon, onPressed, ../../providers/date_provider.dart, ../utils/relative_day.dart

### Community 130 - "Community 130"
Cohesion: 0.50
Nodes (5): Two contradictory freshness models (FutureProvider vs StreamProvider), DashboardSettingsNotifier default-state flash and dropped writes, Riverpod modernisation (Notifier/AsyncNotifier), Release 12 — Dashboard tabs, shared_preferences

### Community 131 - "Community 131"
Cohesion: 0.40
Nodes (5): build, _empty, AppRoutes.catalogShare, AppRoutes.productEditFor, AppRoutes.productNew

### Community 132 - "Community 132"
Cohesion: 0.50
Nodes (5): _, AppHaptics, success, tap, package:flutter/services.dart

### Community 133 - "Community 133"
Cohesion: 1.00
Nodes (4): databaseProvider screen-call violation (24 calls, 12 files), The layering rule (tables to daos to providers to screens), Complete the provider seam refactor (doc 14a), Finding: 24+ layering violations (screens call databaseProvider)

### Community 134 - "Community 134"
Cohesion: 0.50
Nodes (4): @immutable, BrandConfig, MoneyFormat, AppDestination

### Community 135 - "Community 135"
Cohesion: 0.50
Nodes (3): emojiFor, _kEmojiMap, lower

### Community 136 - "Community 136"
Cohesion: 0.50
Nodes (3): package:drift/drift.dart, _freshDb, main

### Community 138 - "Community 138"
Cohesion: 0.67
Nodes (3): Dropped: 11 — Counter stock, No stock counting decision, Drift schema frozen at v6

### Community 139 - "Community 139"
Cohesion: 0.67
Nodes (3): Exception, InvalidBackupException, UpdateCheckException

## Ambiguous Edges - Review These
- `App holds no inventory and one user, no roles` → `Locked decisions 2026-08-19 (Supabase online-only, counter stock shop #1, 3 roles, hybrid nav, swipe-by-5)`  [AMBIGUOUS]
  AGENTS.md · relation: conceptually_related_to
- `Dart/Flutter DevTools extension config stub` → `Tech stack (Flutter 3.44.2, Drift/SQLite, Riverpod 2.x, go_router 14.x)`  [AMBIGUOUS]
  devtools_options.yaml · relation: conceptually_related_to
- `App audit 1.7.0 (current-state record)` → `AppBackground CustomPaint vector motif`  [AMBIGUOUS]
  docs/app-audit.md · relation: references

## Knowledge Gaps
- **1391 isolated node(s):** `AppRoutes`, `kBrandGold`, `kBrandBrown`, `kBrandMaroon`, `kSurface` (+1386 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1627 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `App holds no inventory and one user, no roles` and `Locked decisions 2026-08-19 (Supabase online-only, counter stock shop #1, 3 roles, hybrid nav, swipe-by-5)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Dart/Flutter DevTools extension config stub` and `Tech stack (Flutter 3.44.2, Drift/SQLite, Riverpod 2.x, go_router 14.x)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `App audit 1.7.0 (current-state record)` and `AppBackground CustomPaint vector motif`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `17 — White-label` connect `Community 112` to `Community 73`, `Community 44`, `Community 111`, `Community 21`, `Community 91`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **Why does `10a — Design system & UI foundation` connect `Community 21` to `Community 112`, `Community 91`, `Community 119`, `Community 111`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **Why does `Milano Orders Roadmap` connect `Community 120` to `Community 80`, `Community 130`, `Community 128`, `Community 86`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **What connects `AppRoutes`, `kBrandGold`, `kBrandBrown` to the rest of the system?**
  _1391 weakly-connected nodes found - possible documentation gaps or missing edges._