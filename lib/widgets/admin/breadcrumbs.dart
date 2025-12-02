import 'package:flutter/material.dart';

/// Breadcrumbs widget untuk menampilkan navigation path
/// Example: Home > Admin > Users > User Detail
class Breadcrumbs extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const Breadcrumbs({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ),
            _buildBreadcrumbItem(context, items[i], i == items.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _buildBreadcrumbItem(
    BuildContext context,
    BreadcrumbItem item,
    bool isLast,
  ) {
    if (isLast || item.onTap == null) {
      return Text(
        item.label,
        style: TextStyle(
          color: isLast
              ? Theme.of(context).textTheme.bodyLarge?.color
              : Colors.grey[600],
          fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }

    return InkWell(
      onTap: item.onTap,
      child: Text(
        item.label,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }
}

/// Item untuk breadcrumb
class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;

  const BreadcrumbItem({
    required this.label,
    this.onTap,
  });
}
