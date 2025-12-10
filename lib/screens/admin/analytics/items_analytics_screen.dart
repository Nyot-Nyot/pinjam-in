import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/admin_provider.dart';
import '../../../widgets/admin/breadcrumbs.dart';
import '../admin_layout.dart';

class ItemsAnalyticsScreen extends StatelessWidget {
  final bool wrapWithAdminLayout;
  const ItemsAnalyticsScreen({Key? key, this.wrapWithAdminLayout = true})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, admin, child) {
        final content = AdminLayout(
          currentRoute: '/admin/analytics/items',
          breadcrumbs: const [
            BreadcrumbItem(label: 'Admin'),
            BreadcrumbItem(label: 'Analytics'),
            BreadcrumbItem(label: 'Items'),
          ],
          child: admin.isLoading
              ? const Center(child: CircularProgressIndicator())
              : admin.error != null
              ? _buildError(context, admin)
              : RefreshIndicator(
                  onRefresh: admin.refreshStats,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAnalyticsTabs(context, '/admin/analytics/items'),
                        const SizedBox(height: 8),
                        Text(
                          'Overview of item metrics and trends',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Export CSV (placeholder)'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.download),
                              label: const Text('Export CSV'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildMetrics(context, admin.itemStatistics ?? {}),
                        const SizedBox(height: 24),
                        _buildGrowthChart(context, admin.itemGrowth),
                        const SizedBox(height: 24),
                        _buildTopItems(context, admin.mostBorrowedItems),
                        const SizedBox(height: 24),
                        _buildUsersMostOverdue(context, admin.usersMostOverdue),
                      ],
                    ),
                  ),
                ),
        );
        if (!wrapWithAdminLayout) return content.child as Widget;
        return content;
      },
    );
  }

  Widget _buildAnalyticsTabs(BuildContext context, String currentRoute) {
    final isUser = currentRoute == '/admin/analytics';
    final isItem = currentRoute == '/admin/analytics/items';
    return LayoutBuilder(
      builder: (context, constraints) {
        final small = constraints.maxWidth < 520;
        if (small) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Items Analytics',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      if (!isUser)
                        Navigator.of(
                          context,
                        ).pushReplacementNamed('/admin/analytics');
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isUser
                          ? Theme.of(context).primaryColor.withOpacity(0.12)
                          : null,
                    ),
                    child: Text(
                      'Users',
                      style: TextStyle(
                        color: isUser ? Theme.of(context).primaryColor : null,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      if (!isItem)
                        Navigator.of(
                          context,
                        ).pushReplacementNamed('/admin/analytics/items');
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isItem
                          ? Theme.of(context).primaryColor.withOpacity(0.12)
                          : null,
                    ),
                    child: Text(
                      'Items',
                      style: TextStyle(
                        color: isItem ? Theme.of(context).primaryColor : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Items Analytics',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    if (!isUser)
                      Navigator.of(
                        context,
                      ).pushReplacementNamed('/admin/analytics');
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isUser
                        ? Theme.of(context).primaryColor.withOpacity(0.12)
                        : null,
                  ),
                  child: Text(
                    'Users',
                    style: TextStyle(
                      color: isUser ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    if (!isItem)
                      Navigator.of(
                        context,
                      ).pushReplacementNamed('/admin/analytics/items');
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isItem
                        ? Theme.of(context).primaryColor.withOpacity(0.12)
                        : null,
                  ),
                  child: Text(
                    'Items',
                    style: TextStyle(
                      color: isItem ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildError(BuildContext context, AdminProvider admin) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to load analytics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(admin.error ?? 'Unknown error', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => admin.retry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(BuildContext context, Map<String, dynamic> stats) {
    final totalItems = stats['total_items'] ?? 0;
    final borrowedItems = stats['borrowed_items'] ?? 0;
    final returnedItems = stats['returned_items'] ?? 0;
    final overdueItems = stats['overdue_items'] ?? 0;
    final returnRate = stats['returned_percentage'] ?? 0;

    final cards = [
      _metricCard(
        context,
        'Total Items',
        '$totalItems',
        Icons.inventory,
        Colors.blue,
        subtitle: 'Borrowed: $borrowedItems',
      ),
      _metricCard(
        context,
        'Return Rate',
        '$returnRate%',
        Icons.cached,
        Colors.green,
        subtitle: '$returnedItems returned',
      ),
      _metricCard(
        context,
        'Overdue',
        '$overdueItems',
        Icons.warning,
        Colors.red,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            int columns = 1;
            if (width > 1000)
              columns = 3;
            else if (width > 600)
              columns = 2;
            final cardWidth = (width / columns) - (12 * (columns - 1));
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards
                  .map((c) => SizedBox(width: cardWidth, child: c))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _metricCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthChart(
    BuildContext context,
    List<Map<String, dynamic>> growth,
  ) {
    if (growth.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('No growth data available'),
        ),
      );
    }
    final spots = List.generate(growth.length, (i) {
      final item = growth[i];
      final val = (item['count'] ?? item['new_items'] ?? 0) as num;
      return FlSpot(i.toDouble(), val.toDouble());
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items Created (last ${growth.length} days)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) => Text(''),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) =>
                            Text('${value.toInt()}'),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: true),
                    ),
                  ],
                  minY: 0,
                  maxY:
                      spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) *
                          1.2 +
                      1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopItems(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('No top items data available'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most Borrowed Items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: items.map((it) {
                final name =
                    it['name']?.toString() ??
                    (it['key']?.toString() ?? 'Unknown');
                final count = it['count'] ?? it['borrow_count'] ?? 0;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.inventory),
                  title: Text(name),
                  trailing: Text('$count'),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersMostOverdue(
    BuildContext context,
    List<Map<String, dynamic>> users,
  ) {
    if (users.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Users with Most Overdue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: users.map((u) {
                final name = (u['full_name'] ?? u['email'] ?? 'Unknown')
                    .toString();
                final overdue = u['overdue_items'] ?? 0;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    child: Text(
                      (name.isNotEmpty
                          ? name.substring(0, 1).toUpperCase()
                          : '?'),
                    ),
                  ),
                  title: Text(name),
                  trailing: Text('$overdue overdue'),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
