import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/admin_guard.dart';
import '../../widgets/admin/breadcrumbs.dart';

/// Main admin layout with sidebar navigation and content area.
/// This layout wraps all admin screens and provides consistent navigation.
class AdminLayout extends StatefulWidget {
  final Widget child;
  final String currentRoute;
  final List<BreadcrumbItem>? breadcrumbs;

  const AdminLayout({
    super.key,
    required this.child,
    required this.currentRoute,
    this.breadcrumbs,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  final bool _isDrawerOpen = true;

  @override
  Widget build(BuildContext context) {
    // Protect admin routes
    return AdminGuardWidget(
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundLight,
            appBar: _buildAppBar(context),
            drawer: _buildDrawer(context),
            body: Row(
              children: [
                // Sidebar for desktop
                if (MediaQuery.of(context).size.width >= 768 && _isDrawerOpen)
                  _buildSidebar(context),
                // Main content area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Breadcrumbs
                      if (widget.breadcrumbs != null &&
                          widget.breadcrumbs!.isNotEmpty)
                        Breadcrumbs(items: widget.breadcrumbs!),
                      // Content
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return AppBar(
      title: const Text('Admin Dashboard'),
      actions: [
        // Theme toggle
        IconButton(
          icon: Icon(themeProvider.isDark ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => themeProvider.toggleTheme(),
          tooltip: 'Toggle theme',
        ),
        // User profile dropdown
        _buildUserProfileMenu(context),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildUserProfileMenu(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.profile;

    return PopupMenuButton<String>(
      icon: CircleAvatar(
        child: Text(
          profile?.fullName?.substring(0, 1).toUpperCase() ?? 'A',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      tooltip: 'User menu',
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          value: 'profile',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.fullName ?? 'Admin',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                authProvider.userEmail ?? '',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (authProvider.isAdmin)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ADMIN',
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: const ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'logout') {
          await authProvider.logout();
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        }
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    // For mobile, use standard drawer
    if (MediaQuery.of(context).size.width < 768) {
      return Drawer(child: _buildNavigationMenu(context));
    }
    return const SizedBox.shrink();
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: _buildNavigationMenu(context),
    );
  }

  Widget _buildNavigationMenu(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: Theme.of(context).primaryColor),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.admin_panel_settings,
                size: 40,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              const Flexible(
                child: Text(
                  'Pinjam In',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Admin Panel',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.8 * 255).round()),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        _buildNavigationItem(
          context,
          icon: Icons.dashboard,
          title: 'Dashboard',
          route: '/admin',
        ),
        _buildNavigationItem(
          context,
          icon: Icons.people,
          title: 'Users',
          route: '/admin/users',
        ),
        _buildNavigationItem(
          context,
          icon: Icons.inventory,
          title: 'Items',
          route: '/admin/items',
        ),
        _buildNavigationItem(
          context,
          icon: Icons.storage,
          title: 'Storage',
          route: '/admin/storage',
        ),
        // Analytics parent with subpages: Users and Items
        ExpansionTile(
          leading: Icon(
            Icons.analytics,
            color: widget.currentRoute.startsWith('/admin/analytics')
                ? Theme.of(context).primaryColor
                : null,
          ),
          title: Text(
            'Analytics',
            style: TextStyle(
              fontWeight: widget.currentRoute.startsWith('/admin/analytics')
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: widget.currentRoute.startsWith('/admin/analytics')
                  ? Theme.of(context).primaryColor
                  : null,
            ),
          ),
          initiallyExpanded: widget.currentRoute.startsWith('/admin/analytics'),
          children: [
            ListTile(
              leading: const SizedBox(width: 10),
              title: const Text('Users'),
              selected: widget.currentRoute == '/admin/analytics',
              onTap: () => Navigator.of(
                context,
              ).pushReplacementNamed('/admin/analytics'),
            ),
            ListTile(
              leading: const SizedBox(width: 10),
              title: const Text('Items'),
              selected: widget.currentRoute == '/admin/analytics/items',
              onTap: () => Navigator.of(
                context,
              ).pushReplacementNamed('/admin/analytics/items'),
            ),
          ],
        ),
        _buildNavigationItem(
          context,
          icon: Icons.history,
          title: 'Audit Logs',
          route: '/admin/audit',
        ),
        const Divider(),
        _buildNavigationItem(
          context,
          icon: Icons.home,
          title: 'Back to App',
          route: '/home',
        ),
      ],
    );
  }

  Widget _buildNavigationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    final isSelected = widget.currentRoute == route;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).primaryColor : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(
        context,
      ).primaryColor.withAlpha((0.1 * 255).round()),
      onTap: () {
        Navigator.of(context).pushReplacementNamed(route);
      },
    );
  }
}
