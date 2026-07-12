import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_models.dart';

// SharedPreferences keys
const kDashPulse = 'dash_pulse';
const kDashCategoryCards = 'dash_category_cards';
const kDashRevenueAnatomy = 'dash_revenue_anatomy';
const kDashOperationalPatterns = 'dash_operational_patterns';
const kDashAttentionFlags = 'dash_attention_flags';
const kDashCategoryMix = 'dash_sub_category_mix';
const kDashShopConcentration = 'dash_sub_shop_concentration';
const kDashProductLeaderboard = 'dash_sub_product_leaderboard';
const kDashHeatmap = 'dash_sub_heatmap';
const kDashRevenueTrend = 'dash_sub_revenue_trend';

final dashboardSettingsProvider =
    StateNotifierProvider<DashboardSettingsNotifier, DashboardSettings>((ref) {
  return DashboardSettingsNotifier();
});

class DashboardSettingsNotifier extends StateNotifier<DashboardSettings> {
  DashboardSettingsNotifier() : super(const DashboardSettings()) {
    _load();
  }

  SharedPreferences? _prefs;

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    state = DashboardSettings(
      showPulse: _prefs!.getBool(kDashPulse) ?? true,
      showCategoryCards: _prefs!.getBool(kDashCategoryCards) ?? true,
      showRevenueAnatomy: _prefs!.getBool(kDashRevenueAnatomy) ?? true,
      showOperationalPatterns: _prefs!.getBool(kDashOperationalPatterns) ?? true,
      showAttentionFlags: _prefs!.getBool(kDashAttentionFlags) ?? true,
      showCategoryMix: _prefs!.getBool(kDashCategoryMix) ?? true,
      showShopConcentration: _prefs!.getBool(kDashShopConcentration) ?? true,
      showProductLeaderboard: _prefs!.getBool(kDashProductLeaderboard) ?? true,
      showHeatmap: _prefs!.getBool(kDashHeatmap) ?? true,
      showRevenueTrend: _prefs!.getBool(kDashRevenueTrend) ?? true,
    );
  }

  Future<void> toggle(String key, bool value) async {
    // Prevent disabling the last section
    final updated = _applyToggle(key, value);
    if (updated.enabledSectionCount == 0) return;

    state = updated;
    await _prefs?.setBool(key, value);
  }

  DashboardSettings _applyToggle(String key, bool value) {
    switch (key) {
      case kDashPulse:
        return state.copyWith(showPulse: value);
      case kDashCategoryCards:
        return state.copyWith(showCategoryCards: value);
      case kDashRevenueAnatomy:
        return state.copyWith(showRevenueAnatomy: value);
      case kDashOperationalPatterns:
        return state.copyWith(showOperationalPatterns: value);
      case kDashAttentionFlags:
        return state.copyWith(showAttentionFlags: value);
      case kDashCategoryMix:
        return state.copyWith(showCategoryMix: value);
      case kDashShopConcentration:
        return state.copyWith(showShopConcentration: value);
      case kDashProductLeaderboard:
        return state.copyWith(showProductLeaderboard: value);
      case kDashHeatmap:
        return state.copyWith(showHeatmap: value);
      case kDashRevenueTrend:
        return state.copyWith(showRevenueTrend: value);
      default:
        return state;
    }
  }
}
