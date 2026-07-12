part of '../app_database.dart';

@DriftAccessor(tables: [DailyOrders, OrderLines, Products, Categories, Shops])
class DashboardDao extends DatabaseAccessor<AppDatabase>
    with _$DashboardDaoMixin {
  DashboardDao(super.db);

  // ─── Pulse ──────────────────────────────────────────────────────────────

  /// Total revenue for a given date.
  Future<double> getRevenueForDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final query = customSelect(
      'SELECT COALESCE(SUM(ol.qty * ol.unit_price), 0.0) AS total '
      'FROM order_lines ol '
      'INNER JOIN daily_orders o ON ol.order_id = o.id '
      'WHERE o.order_date = ?',
      variables: [Variable.withDateTime(dayStart)],
      readsFrom: {orderLines, dailyOrders},
    );
    final row = await query.getSingle();
    return row.read<double>('total');
  }

  /// Count of distinct shops that have orders on [date].
  Future<int> getShopsServedForDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final query = customSelect(
      'SELECT COUNT(DISTINCT o.shop_id) AS cnt '
      'FROM daily_orders o '
      'WHERE o.order_date = ?',
      variables: [Variable.withDateTime(dayStart)],
      readsFrom: {dailyOrders},
    );
    final row = await query.getSingle();
    return row.read<int>('cnt');
  }

  /// Count of total active shops.
  Future<int> getTotalActiveShops() async {
    final query = customSelect(
      'SELECT COUNT(*) AS cnt FROM shops WHERE is_active = 1',
      readsFrom: {shops},
    );
    final row = await query.getSingle();
    return row.read<int>('cnt');
  }

  /// Count of unconfirmed orders for [date].
  Future<int> getPendingCountForDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final query = customSelect(
      'SELECT COUNT(*) AS cnt FROM daily_orders '
      'WHERE order_date = ? AND is_confirmed = 0',
      variables: [Variable.withDateTime(dayStart)],
      readsFrom: {dailyOrders},
    );
    final row = await query.getSingle();
    return row.read<int>('cnt');
  }

  // ─── Category Scorecards ────────────────────────────────────────────────

  /// Revenue, pieces, shopCount per category for a date range.
  Future<List<Map<String, dynamic>>> getCategoryScores(
      DateTime start, DateTime end) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final query = customSelect(
      'SELECT p.category_id AS categoryId, '
      'COALESCE(SUM(ol.qty * ol.unit_price), 0.0) AS revenue, '
      'COALESCE(SUM(ol.qty), 0) AS pieces, '
      'COUNT(DISTINCT o.shop_id) AS shops '
      'FROM order_lines ol '
      'INNER JOIN daily_orders o ON ol.order_id = o.id '
      'INNER JOIN products p ON ol.product_id = p.id '
      'WHERE o.order_date >= ? AND o.order_date <= ? '
      'GROUP BY p.category_id',
      variables: [Variable.withDateTime(startDay), Variable.withDateTime(endDay)],
      readsFrom: {orderLines, dailyOrders, products},
    );
    final rows = await query.get();
    return rows
        .map((r) => {
              'categoryId': r.read<int?>('categoryId'),
              'revenue': r.read<double>('revenue'),
              'pieces': r.read<int>('pieces'),
              'shops': r.read<int>('shops'),
            })
        .toList();
  }

  /// 7-day sparklines for all categories (daily piece totals).
  Future<List<Map<String, dynamic>>> getCategorySparklines(
      DateTime sevenDaysAgo) async {
    final startDay =
        DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day);
    final query = customSelect(
      'SELECT p.category_id AS categoryId, o.order_date AS orderDate, '
      'SUM(ol.qty) AS pieces '
      'FROM order_lines ol '
      'INNER JOIN daily_orders o ON ol.order_id = o.id '
      'INNER JOIN products p ON ol.product_id = p.id '
      'WHERE o.order_date >= ? '
      'GROUP BY p.category_id, o.order_date '
      'ORDER BY o.order_date',
      variables: [Variable.withDateTime(startDay)],
      readsFrom: {orderLines, dailyOrders, products},
    );
    final rows = await query.get();
    return rows
        .map((r) => {
              'categoryId': r.read<int?>('categoryId'),
              'orderDate': r.read<DateTime>('orderDate'),
              'pieces': r.read<int>('pieces'),
            })
        .toList();
  }

  /// Top product per category by revenue in range.
  Future<List<Map<String, dynamic>>> getStarProducts(
      DateTime start, DateTime end) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final query = customSelect(
      'SELECT p.category_id AS categoryId, p.name AS productName, '
      'SUM(ol.qty * ol.unit_price) AS rev '
      'FROM order_lines ol '
      'INNER JOIN daily_orders o ON ol.order_id = o.id '
      'INNER JOIN products p ON ol.product_id = p.id '
      'WHERE o.order_date >= ? AND o.order_date <= ? '
      'GROUP BY p.category_id, ol.product_id '
      'ORDER BY rev DESC',
      variables: [Variable.withDateTime(startDay), Variable.withDateTime(endDay)],
      readsFrom: {orderLines, dailyOrders, products},
    );
    final rows = await query.get();
    return rows
        .map((r) => {
              'categoryId': r.read<int?>('categoryId'),
              'productName': r.read<String>('productName'),
              'rev': r.read<double>('rev'),
            })
        .toList();
  }

  // ─── Revenue Anatomy ───────────────────────────────────────────────────

  /// Top shops by revenue with category breadth.
  Future<List<Map<String, dynamic>>> getShopConcentration(
      DateTime start, DateTime end,
      {int limit = 5}) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final query = customSelect(
      'SELECT s.id AS shopId, s.name AS shopName, s.area AS area, '
      'SUM(ol.qty * ol.unit_price) AS rev, '
      'COUNT(DISTINCT p.category_id) AS catCount '
      'FROM order_lines ol '
      'INNER JOIN daily_orders o ON ol.order_id = o.id '
      'INNER JOIN shops s ON o.shop_id = s.id '
      'INNER JOIN products p ON ol.product_id = p.id '
      'WHERE o.order_date >= ? AND o.order_date <= ? '
      'GROUP BY o.shop_id '
      'ORDER BY rev DESC '
      'LIMIT ?',
      variables: [
        Variable.withDateTime(startDay),
        Variable.withDateTime(endDay),
        Variable.withInt(limit),
      ],
      readsFrom: {orderLines, dailyOrders, shops, products},
    );
    final rows = await query.get();
    return rows
        .map((r) => {
              'shopId': r.read<int>('shopId'),
              'shopName': r.read<String>('shopName'),
              'area': r.read<String?>('area'),
              'rev': r.read<double>('rev'),
              'catCount': r.read<int>('catCount'),
            })
        .toList();
  }

  /// Category emojis for a given shop in a date range.
  Future<List<int?>> getShopCategoryIds(
      int shopId, DateTime start, DateTime end) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final query = customSelect(
      'SELECT DISTINCT p.category_id AS categoryId '
      'FROM order_lines ol '
      'INNER JOIN daily_orders o ON ol.order_id = o.id '
      'INNER JOIN products p ON ol.product_id = p.id '
      'WHERE o.shop_id = ? AND o.order_date >= ? AND o.order_date <= ?',
      variables: [
        Variable.withInt(shopId),
        Variable.withDateTime(startDay),
        Variable.withDateTime(endDay),
      ],
      readsFrom: {orderLines, dailyOrders, products},
    );
    final rows = await query.get();
    return rows.map((r) => r.read<int?>('categoryId')).toList();
  }

  /// Top products by revenue.
  Future<List<Map<String, dynamic>>> getProductLeaderboard(
      DateTime start, DateTime end,
      {int limit = 10}) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final query = customSelect(
      'SELECT p.id AS productId, p.name AS productName, '
      'p.category_id AS categoryId, '
      'SUM(ol.qty * ol.unit_price) AS rev, '
      'SUM(ol.qty) AS qty, '
      'COUNT(DISTINCT o.shop_id) AS shops '
      'FROM order_lines ol '
      'INNER JOIN daily_orders o ON ol.order_id = o.id '
      'INNER JOIN products p ON ol.product_id = p.id '
      'WHERE o.order_date >= ? AND o.order_date <= ? '
      'GROUP BY ol.product_id '
      'ORDER BY rev DESC '
      'LIMIT ?',
      variables: [
        Variable.withDateTime(startDay),
        Variable.withDateTime(endDay),
        Variable.withInt(limit),
      ],
      readsFrom: {orderLines, dailyOrders, products},
    );
    final rows = await query.get();
    return rows
        .map((r) => {
              'productId': r.read<int>('productId'),
              'productName': r.read<String>('productName'),
              'categoryId': r.read<int?>('categoryId'),
              'rev': r.read<double>('rev'),
              'qty': r.read<int>('qty'),
              'shops': r.read<int>('shops'),
            })
        .toList();
  }

  // ─── Operational Patterns ──────────────────────────────────────────────

  /// Weekday heatmap: avg pieces per category per weekday (last 4 weeks).
  Future<List<Map<String, dynamic>>> getWeekdayHeatmap(
      DateTime fourWeeksAgo) async {
    final startDay =
        DateTime(fourWeeksAgo.year, fourWeeksAgo.month, fourWeeksAgo.day);
    final query = customSelect(
      'SELECT sub.categoryId, sub.weekday, AVG(sub.daily_total) AS avg_pieces '
      'FROM ( '
      '  SELECT p.category_id AS categoryId, '
      '    CAST(strftime(\'%w\', o.order_date) AS INTEGER) AS weekday, '
      '    SUM(ol.qty) AS daily_total '
      '  FROM order_lines ol '
      '  INNER JOIN daily_orders o ON ol.order_id = o.id '
      '  INNER JOIN products p ON ol.product_id = p.id '
      '  WHERE o.order_date >= ? '
      '  GROUP BY o.order_date, p.category_id '
      ') sub '
      'GROUP BY sub.categoryId, sub.weekday',
      variables: [Variable.withDateTime(startDay)],
      readsFrom: {orderLines, dailyOrders, products},
    );
    final rows = await query.get();
    return rows
        .map((r) => {
              'categoryId': r.read<int?>('categoryId'),
              'weekday': r.read<int>('weekday'),
              'avg_pieces': r.read<double>('avg_pieces'),
            })
        .toList();
  }

  // ─── Attention Flags ───────────────────────────────────────────────────

  /// Active shops with no orders in the last 7 days.
  Future<List<int>> getInactiveShopIds(DateTime sevenDaysAgo) async {
    final startDay =
        DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day);
    final query = customSelect(
      'SELECT s.id AS shopId FROM shops s '
      'WHERE s.is_active = 1 '
      'AND s.id NOT IN ('
      '  SELECT DISTINCT o.shop_id FROM daily_orders o '
      '  WHERE o.order_date >= ?'
      ')',
      variables: [Variable.withDateTime(startDay)],
      readsFrom: {shops, dailyOrders},
    );
    final rows = await query.get();
    return rows.map((r) => r.read<int>('shopId')).toList();
  }

  /// Revenue per category for a given date range (used for flag comparisons).
  Future<Map<int?, double>> getCategoryRevenuesForRange(
      DateTime start, DateTime end) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final query = customSelect(
      'SELECT p.category_id AS categoryId, '
      'COALESCE(SUM(ol.qty * ol.unit_price), 0.0) AS revenue '
      'FROM order_lines ol '
      'INNER JOIN daily_orders o ON ol.order_id = o.id '
      'INNER JOIN products p ON ol.product_id = p.id '
      'WHERE o.order_date >= ? AND o.order_date <= ? '
      'GROUP BY p.category_id',
      variables: [Variable.withDateTime(startDay), Variable.withDateTime(endDay)],
      readsFrom: {orderLines, dailyOrders, products},
    );
    final rows = await query.get();
    return {
      for (final r in rows) r.read<int?>('categoryId'): r.read<double>('revenue')
    };
  }

  /// Categories that had orders on at least 3 of the last 7 days but none today.
  Future<List<int?>> getZeroDayCategoryIds(DateTime today) async {
    final dayStart = DateTime(today.year, today.month, today.day);
    final sevenDaysAgo = dayStart.subtract(const Duration(days: 7));
    final query = customSelect(
      'SELECT p.category_id AS categoryId, '
      'COUNT(DISTINCT o.order_date) AS active_days '
      'FROM order_lines ol '
      'INNER JOIN daily_orders o ON ol.order_id = o.id '
      'INNER JOIN products p ON ol.product_id = p.id '
      'WHERE o.order_date >= ? AND o.order_date < ? '
      'GROUP BY p.category_id '
      'HAVING active_days >= 3',
      variables: [Variable.withDateTime(sevenDaysAgo), Variable.withDateTime(dayStart)],
      readsFrom: {orderLines, dailyOrders, products},
    );
    final frequentCats = await query.get();
    final frequentCatIds =
        frequentCats.map((r) => r.read<int?>('categoryId')).toSet();

    // Check which of those have zero today
    final todayQuery = customSelect(
      'SELECT DISTINCT p.category_id AS categoryId '
      'FROM order_lines ol '
      'INNER JOIN daily_orders o ON ol.order_id = o.id '
      'INNER JOIN products p ON ol.product_id = p.id '
      'WHERE o.order_date = ?',
      variables: [Variable.withDateTime(dayStart)],
      readsFrom: {orderLines, dailyOrders, products},
    );
    final todayCats = await todayQuery.get();
    final todayCatIds =
        todayCats.map((r) => r.read<int?>('categoryId')).toSet();

    return frequentCatIds.difference(todayCatIds).toList();
  }
}
