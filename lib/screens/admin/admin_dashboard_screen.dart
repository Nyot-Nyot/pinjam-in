import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../widgets/admin/breadcrumbs.dart';
import 'admin_layout.dart';

/// AdminDashboardScreen - Main dashboard for admin panel
/// Displays key metrics, charts, and recent activity
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        return AdminLayout(
          currentRoute: '/admin',
          breadcrumbs: const [
            BreadcrumbItem(label: 'Admin'),
            BreadcrumbItem(label: 'Dashboard'),
          ],
          child: adminProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : adminProvider.error != null
              ? _buildErrorWidget(context, adminProvider)
              : RefreshIndicator(
                  onRefresh: () => adminProvider.refreshStats(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome header
                        _buildWelcomeHeader(context),
                        const SizedBox(height: 32),

                        // Metrics cards
                        _buildMetricsSection(
                          context,
                          adminProvider.dashboardStats!,
                        ),
                        const SizedBox(height: 32),

                        // Charts row
                        _buildChartsSection(
                          context,
                          adminProvider.userGrowth,
                          adminProvider.dashboardStats!,
                        ),
                        const SizedBox(height: 32),

                        // Quick actions
                        _buildQuickActionsSection(context),
                        const SizedBox(height: 32),

                        // Recent activity
                        _buildRecentActivitySection(
                          context,
                          adminProvider.recentActivity,
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildErrorWidget(BuildContext context, AdminProvider adminProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              adminProvider.error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => adminProvider.retry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Admin Dashboard',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Overview of your application metrics and activity',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildMetricsSection(
    BuildContext context,
    Map<String, dynamic> stats,
  ) {
    final totalUsers = stats['total_users'] ?? 0;
    final activeUsers = stats['active_users'] ?? 0;
    final totalItems = stats['total_items'] ?? 0;
    final overdueItems = stats['overdue_items'] ?? 0;
    final totalStorageFiles = stats['total_storage_files'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Total Users',
                    '$totalUsers',
                    Icons.people,
                    Colors.blue,
                    subtitle: '$activeUsers active',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Total Items',
                    '$totalItems',
                    Icons.inventory_2,
                    Colors.green,
                    subtitle: '${stats['borrowed_items'] ?? 0} borrowed',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Overdue Items',
                    '$overdueItems',
                    Icons.warning_amber_rounded,
                    Colors.red,
                    subtitle: 'Need attention',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Storage Files',
                    '$totalStorageFiles',
                    Icons.storage,
                    Colors.orange,
                    subtitle: 'Photos uploaded',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(
    BuildContext context,
    List<Map<String, dynamic>> userGrowth,
    Map<String, dynamic> stats,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUserGrowthChart(context, userGrowth),
        const SizedBox(height: 24),
        _buildItemsStatusChart(context, stats),
      ],
    );
  }

  Widget _buildUserGrowthChart(
    BuildContext context,
    List<Map<String, dynamic>> userGrowth,
  ) {
    if (userGrowth.isEmpty) {
      return _buildEmptyChartCard(
        context,
        'User Growth',
        'No user growth data available',
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Growth (Last 30 Days)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: userGrowth.length / 5,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= userGrowth.length) {
                            return const SizedBox();
                          }
                          final date = DateTime.parse(
                            userGrowth[value.toInt()]['date'] as String,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MM/dd').format(date),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: userGrowth.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          (entry.value['cumulative_users'] as num).toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  minY: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsStatusChart(
    BuildContext context,
    Map<String, dynamic> stats,
  ) {
    final borrowedItems = (stats['borrowed_items'] as num?)?.toDouble() ?? 0;
    final returnedItems = (stats['returned_items'] as num?)?.toDouble() ?? 0;
    final overdueItems = (stats['overdue_items'] as num?)?.toDouble() ?? 0;

    if (borrowedItems == 0 && returnedItems == 0 && overdueItems == 0) {
      return _buildEmptyChartCard(
        context,
        'Items Status',
        'No items data available',
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items Status Distribution',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Center(
                    child: SizedBox(
                      height: 180,
                      width: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: [
                            if (borrowedItems > 0)
                              PieChartSectionData(
                                color: Colors.blue,
                                value: borrowedItems,
                                title: '${borrowedItems.toInt()}',
                                radius: 50,
                                titleStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            if (returnedItems > 0)
                              PieChartSectionData(
                                color: Colors.green,
                                value: returnedItems,
                                title: '${returnedItems.toInt()}',
                                radius: 50,
                                titleStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            if (overdueItems > 0)
                              PieChartSectionData(
                                color: Colors.red,
                                value: overdueItems,
                                title: '${overdueItems.toInt()}',
                                radius: 50,
                                titleStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildChartLegend('Borrowed', Colors.blue),
                      const SizedBox(height: 12),
                      _buildChartLegend('Returned', Colors.green),
                      const SizedBox(height: 12),
                      _buildChartLegend('Overdue', Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChartCard(
    BuildContext context,
    String title,
    String message,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.show_chart, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildActionButton(context, 'Manage Users', Icons.person_add, () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User management coming soon...')),
              );
            }),
            _buildActionButton(context, 'View Analytics', Icons.analytics, () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analytics page coming soon...')),
              );
            }),
            _buildActionButton(context, 'Audit Logs', Icons.history, () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Audit logs coming soon...')),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }

  Widget _buildRecentActivitySection(
    BuildContext context,
    List<Map<String, dynamic>> recentActivity,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (recentActivity.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No recent activity',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Activity will appear here once admin actions are performed',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: recentActivity.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final activity = recentActivity[index];
                return _buildActivityItem(context, activity);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    Map<String, dynamic> activity,
  ) {
    final actionType = activity['action_type'] as String;
    final tableName = activity['table_name'] as String;
    final createdAt = DateTime.parse(activity['created_at'] as String);
    final metadata = activity['metadata'] as Map<String, dynamic>?;

    IconData icon;
    Color color;

    switch (actionType.toLowerCase()) {
      case 'create':
        icon = Icons.add_circle_outline;
        color = Colors.green;
      case 'update':
        icon = Icons.edit_outlined;
        color = Colors.blue;
      case 'delete':
        icon = Icons.delete_outline;
        color = Colors.red;
      default:
        icon = Icons.info_outline;
        color = Colors.grey;
    }

    final relativeTime = _getRelativeTime(createdAt);
    final description = _getActivityDescription(
      actionType,
      tableName,
      metadata,
    );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(description, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(
        relativeTime,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
      ),
    );
  }

  String _getActivityDescription(
    String actionType,
    String tableName,
    Map<String, dynamic>? metadata,
  ) {
    final action = actionType.toLowerCase();
    final table = tableName.toLowerCase();

    switch (table) {
      case 'profiles':
        if (action == 'create') return 'Created new user';
        if (action == 'update') {
          if (metadata?['field'] == 'role') {
            return 'Updated user role to ${metadata?['new_value']}';
          }
          if (metadata?['field'] == 'status') {
            return 'Updated user status to ${metadata?['new_value']}';
          }
          return 'Updated user profile';
        }
        if (action == 'delete') return 'Deleted user';
      case 'items':
        if (action == 'create') return 'Created new item';
        if (action == 'update') {
          if (metadata?['field'] == 'status') {
            return 'Updated item status to ${metadata?['new_value']}';
          }
          return 'Updated item';
        }
        if (action == 'delete') return 'Deleted item';
      default:
        return '$action $table';
    }

    return '$action $table';
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }
}
