import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supabase initialization is handled by BootstrapScreen
  // to show proper loading/error states in the UI.
  
  runApp(
    const ProviderScope(
      child: SkinningApp(),
    ),
  );
}
