import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap_screen.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import '../shared/widgets/no_scrollbar_scroll_behavior.dart';

/// The root widget for The Skinning Shed application.
class SkinningApp extends ConsumerWidget {
  const SkinningApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // BootstrapScreen handles Supabase initialization before
    // rendering the main app. Shows loading/error states as needed.
    return BootstrapScreen(
      child: _MainApp(),
    );
  }
}

/// The main app widget, only rendered after bootstrap succeeds.
class _MainApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'The Skinning Shed',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Dark theme uses same light theme for now (2025 premium light-first design)
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.light,
      scrollBehavior: const NoScrollbarScrollBehavior(),
      routerConfig: router,
    );
  }
}
