import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinjam_in/src/features/auth/presentation/widget/auth_gate.dart';
import 'package:pinjam_in/src/features/items/presentation/screen/add_item_screen.dart';

final GoRouter router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const AuthGate();
      },
      routes: [
        GoRoute(
          path: 'add-item',
          builder: (BuildContext context, GoRouterState state) {
            return const AddItemScreen();
          },
        ),
      ],
    ),
  ],
);
