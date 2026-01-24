import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Debug: Better overflow error reporting
  if (kDebugMode) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      
      // Log overflow errors with context
      if (details.exception.toString().contains('RenderFlex overflowed')) {
        debugPrint('═══ OVERFLOW ERROR ═══');
        debugPrint('${details.exception}');
        debugPrint('Stack trace (first 5 lines):');
        final stackLines = details.stack.toString().split('\n').take(5).join('\n');
        debugPrint(stackLines);
        debugPrint('═══════════════════════');
      }
    };
  }
  
  // Supabase initialization is handled by BootstrapScreen
  // to show proper loading/error states in the UI.
  
  runApp(
    const ProviderScope(
      child: SkinningApp(),
    ),
  );
}
